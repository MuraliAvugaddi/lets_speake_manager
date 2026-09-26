import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:get_storage/get_storage.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO; // Add socket client
import 'package:lets_speake_manager/Api/ApiendPoints.dart';

class AdminController extends GetxController {
  var usersList = <dynamic>[].obs;
  var isLoading = false.obs;
  var isMoreLoading = false.obs;
  var searchQuery = ''.obs;

  int currentPage = 1;
  int totalPages = 1;
  final int limit = 50;

  final box = GetStorage();
  Timer? _pollingTimer;
  late IO.Socket _socket; // Socket instance for instant updates

  @override
  void onInit() {
    super.onInit();
    fetchAllUsers(isRefresh: true);
    _initSocketListener(); // 🚀 Setup instant real-time updates

    // Safety fallback: poll every 30 seconds just in case a socket packet drops
    _pollingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      fetchAllUsers(isRefresh: true, silent: true);
    });
  }

  // 🚀 Instant real-time listener using your backend Socket.io
  void _initSocketListener() {
    try {
      // Connect to your backend base URL (extracting domain from ApiEndpoints)
      final uri = Uri.parse(ApiEndpoints.baseUrl);
      final host = "${uri.scheme}://${uri.host}:${uri.port}";

      _socket = IO.io(host, <String, dynamic>{
        'transports': ['websocket'],
        'autoConnect': true,
      });

      _socket.onConnect((_) {
        debugPrint("🔌 Admin connected to Socket.io for instant updates");
        // Join an admin room if your backend supports it
        _socket.emit('join_admin_room');
      });

      // Listen for any user changes (registrations, access updates, deletions)
      _socket.on('user_updated', (_) {
        debugPrint("⚡ Real-time update received: Refreshing users instantly.");
        fetchAllUsers(isRefresh: true, silent: true);
      });

      _socket.on('new_user_registered', (_) {
        debugPrint("⚡ New student registered: Refreshing list instantly.");
        fetchAllUsers(isRefresh: true, silent: true);
      });
    } catch (e) {
      debugPrint("Socket init error: $e");
    }
  }

  @override
  void onClose() {
    _pollingTimer?.cancel();
    _socket.dispose(); // Clean up socket connection
    super.onClose();
  }

  Future<void> fetchAllUsers({bool isRefresh = false, bool silent = false}) async {
    if (isRefresh) {
      if (!silent) isLoading.value = true;
      currentPage = 1;
      if (!silent) usersList.clear();
    } else {
      if (currentPage >= totalPages) return;
      isMoreLoading.value = true;
      currentPage++;
    }

    String? token = box.read('token');

    try {
      final response = await http.get(
        Uri.parse(
          "${ApiEndpoints.baseUrl}/admin/all-students?mode=all&language=all",
        ),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        List<dynamic> newUsers = [];

        if (data is Map) {
          if (data.containsKey('students')) {
            newUsers = data['students'];
          } else if (data.containsKey('users')) {
            newUsers = data['users'];
          }
          totalPages = data['totalPages'] ?? 1;
        } else if (data is List) {
          newUsers = data;
        }

        if (isRefresh) {
          usersList.assignAll(newUsers);
        } else {
          usersList.addAll(newUsers);
        }
      }
    } catch (e) {
      debugPrint("Error fetching users: $e");
    } finally {
      isLoading.value = false;
      isMoreLoading.value = false;
    }
  }

  // --- UPDATE ACCESS & LEARNING MODE ---
  Future<void> updateUserAccess(
    String userId,
    Map englishAccess,
    Map hindiAccess,
    String mode,
  ) async {
    String? token = box.read('token');
    try {
      final response = await http.put(
        Uri.parse(ApiEndpoints.updateAccess),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode({
          "userId": userId,
          "englishAccess": englishAccess,
          "hindiAccess": hindiAccess,
          "mode": mode.toLowerCase(),
        }),
      );

      if (response.statusCode == 200) {
        int index = usersList.indexWhere(
          (u) => (u['_id'] ?? u['id']) == userId,
        );
        if (index != -1) {
          var userObj = Map<String, dynamic>.from(usersList[index]);
          userObj['englishAccess'] = englishAccess;
          userObj['hindiAccess'] = hindiAccess;
          userObj['mode'] = mode.toLowerCase();
          usersList[index] = userObj;
        }
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteUser(String userId) async {
    String? token = box.read('token');
    try {
      final response = await http.delete(
        Uri.parse("${ApiEndpoints.users}/$userId"),
        headers: {"Authorization": "Bearer $token"},
      );

      if (response.statusCode == 200) {
        usersList.removeWhere((user) => (user['_id'] ?? user['id']) == userId);
      }
    } catch (e) {
      debugPrint("Delete error: $e");
    }
  }
}