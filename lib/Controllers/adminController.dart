import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:get_storage/get_storage.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:lets_speake_manager/Api/ApiendPoints.dart';
import 'package:lets_speake_manager/Api/api_headers.dart';

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
  Timer? _liveDebounce; // many student changes in a row → ONE list download
  late IO.Socket _socket;

  @override
  void onInit() {
    super.onInit();
    fetchAllUsers(isRefresh: true);
    _initSocketListener();

    // Safety fallback if a socket packet drops. The list is all 2,500 students,
    // so not too often — live changes already arrive by socket.
    _pollingTimer = Timer.periodic(const Duration(minutes: 2), (_) {
      fetchAllUsers(isRefresh: true, silent: true);
    });
  }

  void _initSocketListener() {
    try {
      final uri = Uri.parse(ApiEndpoints.baseUrl);
      final host = "${uri.scheme}://${uri.host}:${uri.port}";

      _socket = IO.io(host, <String, dynamic>{
        'transports': ['websocket'],
        'autoConnect': true,
        'auth': {'token': ApiHeaders.token ?? ''},
      });

      _socket.onConnect((_) {
        debugPrint("🔌 Admin connected to Socket.io for instant updates");
        _socket.emit('join_admin_room');
      });

      // 🚀 Listen for real-time student registrations or updates
      _socket.on('student_update', (_) {
        debugPrint(
          "⚡ Real-time student update received: Refreshing lists automatically.",
        );
        _refreshSoon();
      });

      _socket.on('new_user_registered', (_) {
        debugPrint("⚡ New student registered: Refreshing list instantly.");
        _refreshSoon();
      });
    } catch (e) {
      debugPrint("Socket init error: $e");
    }
  }

  /// 30 students change timing within a few seconds → one refresh, not 30
  void _refreshSoon() {
    _liveDebounce?.cancel();
    _liveDebounce = Timer(const Duration(seconds: 2), () => fetchAllUsers(isRefresh: true, silent: true));
  }

  @override
  void onClose() {
    _liveDebounce?.cancel();
    _pollingTimer?.cancel();
    _socket.dispose();
    super.onClose();
  }

  Future<void> fetchAllUsers({
    bool isRefresh = false,
    bool silent = false,
  }) async {
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

  /// Saves course access. Throws with the server's message when it is refused
  /// (e.g. "English Stage 2 and Hindi Stage 1 are both at 3:30 PM") —
  /// before, a refused save was ignored and the screen still said "Saved".
  Future<void> updateUserAccess(
    String userId,
    Map englishAccess,
    Map hindiAccess,
    String mode, {
    Map? englishBatch,
    Map? hindiBatch,
    String? batchTime,
    String? onlineSection,
  }) async {
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
          if (englishBatch != null) "englishBatch": englishBatch,
          if (hindiBatch != null) "hindiBatch": hindiBatch,
          if (batchTime != null) "batchTime": batchTime,
          if (onlineSection != null) "onlineSection": onlineSection,
        }),
      );

      if (response.statusCode != 200) {
        String msg = "Could not save course access (${response.statusCode}).";
        try {
          final body = jsonDecode(response.body);
          if (body is Map && body['message'] != null) msg = body['message'].toString();
        } catch (_) {}
        throw AccessSaveException(msg);
      }

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

/// A save the server refused (message is safe to show to the admin)
class AccessSaveException implements Exception {
  final String message;
  AccessSaveException(this.message);
  @override
  String toString() => message;
}
