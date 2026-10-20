import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Single navigation state shared by the responsive admin shell.
///
/// Desktop / Web:
/// - permanent sidebar
/// - no drawer navigation
///
/// Mobile / Tablet:
/// - drawer navigation
/// - screens can show a hamburger button.
///
/// Navigation indexes:
/// 0 = Students
/// 1 = Tests
/// 2 = Student Attendance
/// 3 = Teacher Attendance
/// 4 = Fees
/// 5 = Feedback
/// 6 = Section Merge
/// 7 = Fee Verification
/// 8 = Student/User Detail
/// 9 = Posters & Reels      (ENGAGE)
/// 10 = Special Classes     (ENGAGE: rain day / principal class)
/// 11 = Leaderboard         (ENGAGE)
class AdminShellNavigation {
  AdminShellNavigation._();

  static final GlobalKey<ScaffoldState> scaffoldKey =
      GlobalKey<ScaffoldState>();

  static const double desktopBreakpoint = 1000;

  // ENGAGE modules (sidebar group below MANAGEMENT)
  static const int postersIndex = 9;
  static const int specialClassesIndex = 10;
  static const int leaderboardIndex = 11;

  /// Currently selected main module.
  ///
  /// 0-6  = normal modules
  /// 7    = Fee Verification
  /// 8    = Student/User Control
  /// 9-11 = Posters & Reels, Special Classes, Leaderboard
  static final RxInt selectedIndex = 0.obs;

  /// Selected student for User Control screen.
  static final Rxn<dynamic> detailUser = Rxn<dynamic>();

  /// Whether desktop/web sidebar should be used.
  static bool isDesktop(BuildContext context) {
    return MediaQuery.sizeOf(context).width >= desktopBreakpoint;
  }

  /// Whether mobile/tablet should show drawer button.
  static bool shouldShowMenuButton(BuildContext context) {
    return !isDesktop(context);
  }

  /// Select a normal module.
  ///
  /// This clears any previously selected student.
  static void selectModule(int index) {
    detailUser.value = null;
    selectedIndex.value = index;
    closeDrawer();
  }

  /// Open Student/User Control screen.
  ///
  /// IMPORTANT:
  /// User Control now uses index 8.
  /// Section Merge remains at index 6.
  /// Fee Verification uses index 7.
  static void openUserControl(dynamic user) {
    detailUser.value = user;
    selectedIndex.value = 8;
    closeDrawer();
  }

  static void openDrawer() {
    scaffoldKey.currentState?.openDrawer();
  }

  static void closeDrawer() {
    scaffoldKey.currentState?.closeDrawer();
  }

  /// Return to Students screen.
  static void goHome() {
    detailUser.value = null;
    selectedIndex.value = 0;
    closeDrawer();
  }

  /// Close Student/User Control and return to Students.
  static void closeDetail() {
    detailUser.value = null;
    selectedIndex.value = 0;
    closeDrawer();
  }
}