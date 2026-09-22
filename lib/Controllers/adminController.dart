import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:get_storage/get_storage.dart';
import 'package:lets_speake_manager/Api/ApiendPoints.dart';

class AdminController extends GetxController {
  var usersList = <dynamic>[].obs;
  var isLoading = false.obs;
  var isMoreLoading = false.obs;
  var searchQuery = ''.obs;

  int currentPage = 1;
  int totalPages = 1;
  final int limit = 50; // Increased limit to ensure all users load easily

  final box = GetStorage();

  @override
  void onInit() {
    super.onInit();
    fetchAllUsers(isRefresh: true);
  }

  Future<void> fetchAllUsers({bool isRefresh = false}) async {
    if (isRefresh) {
      isLoading.value = true;
      currentPage = 1;
      usersList.clear();
    } else {
      if (currentPage >= totalPages) return;
      isMoreLoading.value = true;
      currentPage++;
    }

    String? token = box.read('token');

    try {
      // 🚀 Query the robust all-students endpoint to guarantee pulling all student profiles
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
      } else {
        if (isRefresh) {
          Get.snackbar(
            "Error",
            "Failed to load user records from server",
            backgroundColor: Colors.redAccent,
            colorText: Colors.white,
          );
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
      } else {
        throw Exception("Failed to update access");
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
        Get.snackbar(
          "Success",
          "User deleted successfully",
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
        usersList.removeWhere((user) => (user['_id'] ?? user['id']) == userId);
      } else {
        Get.snackbar(
          "Error",
          "Could not delete user",
          backgroundColor: Colors.redAccent,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      Get.snackbar(
        "Error",
        "Connection failed: $e",
        backgroundColor: Colors.redAccent,
        colorText: Colors.white,
      );
    }
  }
}
