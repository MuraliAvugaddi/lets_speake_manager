class ApiEndpoints {
  static const String baseUrl =
         "https://lets-talk-backend-o06t.onrender.com/api";
   //   "http://192.168.1.4:5001/api";

  // Auth Endpoints
  static const String login = "$baseUrl/login";
  static const String register = "$baseUrl/register";

  // User Management
  static const String users = "$baseUrl/users";
  static const String updateAccess = "$baseUrl/update-access";
  static const String updateStudentStatus =
      "$baseUrl/admin/update-student-status";

  // Section Merging Endpoints 🚀
  static const String sectionMerges = "$baseUrl/admin/section-merges";
  static const String mergeSections = "$baseUrl/admin/merge-sections";

  // Fee Verification Endpoints 🚀
  static const String pendingFees = "$baseUrl/fee/pending-fees";
  static const String verifyFee = "$baseUrl/fee/verify-fee";
  static const String feeHistory = "$baseUrl/fee/history";

  // Attendance & Others
  static const String usersByStage = "$baseUrl/admin/users-by-stage";
  static const String adminAttendance = "$baseUrl/admin/attendance";
  static const String userAttendance = "$baseUrl/user/my-attendance";
  static const String allStudents = "$baseUrl/admin/all-students";

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
