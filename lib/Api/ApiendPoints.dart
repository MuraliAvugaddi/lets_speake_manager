class ApiEndpoints {
  //static const String baseUrl = "http://10.13.73.18:5000/api";
  static const String baseUrl =
      "https://lets-talk-backend-o06t.onrender.com/api";
  // "http://192.168.1.3:5000/api";

  // Auth Endpoints
  static const String login = "$baseUrl/login";
  static const String register = "$baseUrl/register";

  // User Management
  static const String users = "$baseUrl/users";
  static const String updateAccess = "$baseUrl/update-access";
  static const String updateStudentStatus =
      "$baseUrl/admin/update-student-status"; // <--- ADD THIS LINE

  // Attendance
  static const String usersByStage = "$baseUrl/admin/users-by-stage";
  static const String adminAttendance = "$baseUrl/admin/attendance";
  static const String userAttendance = "$baseUrl/user/my-attendance";

  // Notifications
  static const String notification = "$baseUrl/admin/notification";

  // Feedbacks
  static const String feedbacks = "$baseUrl/admin/feedbacks";

  // Tests & Results
  static const String updateTest = "$baseUrl/test/admin/update-test";
  static const String deleteTest = "$baseUrl/test/admin/delete-test";
  static const String testResults = "$baseUrl/test/admin/results";
  static const String userTestResults = "$baseUrl/test/user/my-results";

  // Live Links
  static const String updateLiveLink = "$baseUrl/live/admin/update";
  static const String deleteLiveLink = "$baseUrl/live/admin/delete";
}
