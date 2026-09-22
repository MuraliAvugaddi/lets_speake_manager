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
class AdminShellNavigation {
  AdminShellNavigation._();

  static final GlobalKey<ScaffoldState> scaffoldKey =
      GlobalKey<ScaffoldState>();

  /// 0 Students, 1 Tests, 2 Student Attendance,
  /// 3 Teacher Attendance, 4 Fees, 5 Feedback, 6 Student Detail.
  static final RxInt selectedIndex = 0.obs;

  static final Rxn<dynamic> detailUser = Rxn<dynamic>();

  /// Must match the breakpoint used by Homescreen.
  static const double desktopBreakpoint = 1000;

  /// Whether the permanent desktop/web sidebar should be used.
  static bool isDesktop(BuildContext context) {
    return MediaQuery.sizeOf(context).width >= desktopBreakpoint;
  }

  /// Use this in individual screens before showing a hamburger button.
  static bool shouldShowMenuButton(BuildContext context) {
    return !isDesktop(context);
  }

  static void selectModule(int index) {
    detailUser.value = null;
    selectedIndex.value = index;
    closeDrawer();
  }

  static void openUserControl(dynamic user) {
    detailUser.value = user;
    selectedIndex.value = 6;
    closeDrawer();
  }

  static void openDrawer() {
    scaffoldKey.currentState?.openDrawer();
  }

  static void closeDrawer() {
    scaffoldKey.currentState?.closeDrawer();
  }

  static void goHome() {
    detailUser.value = null;
    selectedIndex.value = 0;
    closeDrawer();
  }

  static void closeDetail() {
    detailUser.value = null;
    selectedIndex.value = 0;
    closeDrawer();
  }
}
