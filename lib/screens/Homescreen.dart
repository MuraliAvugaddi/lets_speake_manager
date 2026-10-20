import 'package:flutter/material.dart';

import 'package:get/get.dart';

import 'package:get_storage/get_storage.dart';

import 'package:google_fonts/google_fonts.dart';

import 'package:lets_speake_manager/Navigation/AdminShellNavigation.dart';

import 'package:lets_speake_manager/screens/AdimeStudentAttdance_screen.dart';

import 'package:lets_speake_manager/screens/AdminDashboardScreen.dart';

import 'package:lets_speake_manager/screens/AdminFeedbackScreen.dart';

import 'package:lets_speake_manager/screens/AdminFeeVerificationScreen.dart';

import 'package:lets_speake_manager/screens/AdminFeesManageScreen.dart';

import 'package:lets_speake_manager/screens/AdminSectionMergeScreen.dart';

import 'package:lets_speake_manager/screens/AdminTeacherAttendanceScreen.dart';

import 'package:lets_speake_manager/screens/AdminTestManageScreen.dart';

import 'package:lets_speake_manager/screens/AdminUserControlScreen.dart';

import 'package:lets_speake_manager/screens/LoginScreen.dart';

import 'package:lets_speake_manager/screens/AdminPromoScreen.dart';

import 'package:lets_speake_manager/screens/AdminSpecialClassScreen.dart';

import 'package:lets_speake_manager/screens/LeaderboardScreen.dart';

class Adime_home_screen extends StatefulWidget {
  const Adime_home_screen({super.key});

  @override
  State<Adime_home_screen> createState() => _Adime_home_screenState();
}

class _Adime_home_screenState extends State<Adime_home_screen> {
  // ============================================================
  // COLORS
  // ============================================================

  static const Color navy = Color(0xFF0A4A75);
  static const Color blue = Color(0xFF2E86C9);
  static const Color teal = Color(0xFF19B8B8);
  static const Color yellow = Color(0xFFF4C542);

  static const Color background = Color(0xFFF5FAFD);
  static const Color surface = Colors.white;
  static const Color softSurface = Color(0xFFEAF4FA);
  static const Color border = Color(0xFFD5E5EE);
  static const Color text = Color(0xFF173A52);
  static const Color secondaryText = Color(0xFF6B8496);
  static const Color success = Color(0xFF16A66A);
  static const Color error = Color(0xFFE45757);

  // ============================================================
  // ADMIN MODULES
  // ============================================================

  static const List<_AdminModule> modules = [
    _AdminModule(
      index: 0,
      title: 'Students',
      subtitle: 'Access, accounts & analytics',
      icon: Icons.people_alt_rounded,
      color: navy,
    ),

    _AdminModule(
      index: 1,
      title: 'Tests',
      subtitle: 'Questions, publishing & results',
      icon: Icons.assignment_rounded,
      color: blue,
    ),

    _AdminModule(
      index: 2,
      title: 'Attendance',
      subtitle: 'Student daily attendance',
      icon: Icons.fact_check_rounded,
      color: success,
    ),

    _AdminModule(
      index: 3,
      title: 'Trainer Attendance',
      subtitle: 'Teacher attendance monitor',
      icon: Icons.co_present_rounded,
      color: teal,
    ),

    _AdminModule(
      index: 4,
      title: 'Fees',
      subtitle: 'Fee status & reminders',
      icon: Icons.account_balance_wallet_rounded,
      color: yellow,
    ),

    _AdminModule(
      index: 5,
      title: 'Feedback',
      subtitle: 'Reviews & student feedback',
      icon: Icons.rate_review_rounded,
      color: blue,
    ),

    // SECTION MERGE
    _AdminModule(
      index: 6,
      title: 'Section Merge',
      subtitle: 'Merge & manage sections',
      icon: Icons.merge_type_rounded,
      color: teal,
    ),

    // FEE VERIFICATION
    _AdminModule(
      index: 7,
      title: 'Fee Verification',
      subtitle: 'Verify tuition payments',
      icon: Icons.verified_rounded,
      color: success,
    ),
  ];

  // ENGAGE — screens for announcements, special days and rankings
  // (index 8 stays reserved for Student/User Control)
  static const List<_AdminModule> engageModules = [
    _AdminModule(
      index: 9,
      title: 'Posters & Reels',
      subtitle: 'Popup on the student home screen',
      icon: Icons.perm_media_rounded,
      color: Color(0xFFD6336C),
    ),
    _AdminModule(
      index: 10,
      title: 'Special Classes',
      subtitle: 'Rain day online • Principal class',
      icon: Icons.campaign_rounded,
      color: Color(0xFF7B2FF7),
    ),
    _AdminModule(
      index: 11,
      title: 'Leaderboard',
      subtitle: 'Best trainers, students & top rated',
      icon: Icons.emoji_events_rounded,
      color: Color(0xFFE3B21B),
    ),
  ];

  // ============================================================
  // PAGES
  // 0-7  = management modules
  // 8    = Student/User Control
  // 9-11 = engage modules
  // ============================================================

  static const int pageCount = 12;

  final List<Widget?> _pages = List<Widget?>.filled(pageCount, null);

  dynamic _lastDetailUser;

  // ============================================================
  // PAGE BUILDER
  // ============================================================

  Widget _pageAt(int index) {
    // ------------------------------------------------------------
    // INDEX 8 = STUDENT / USER CONTROL
    // ------------------------------------------------------------

    if (index == 8) {
      final user = AdminShellNavigation.detailUser.value;

      if (user != null) {
        if (!identical(_lastDetailUser, user)) {
          _pages[8] = AdminUserControlScreen(user: user);

          _lastDetailUser = user;
        }
      }

      // Safety fallback
      _pages[8] ??= const AdminDashboardScreen();

      return _pages[8]!;
    }

    // ------------------------------------------------------------
    // INDEX 0-7, 9-11 = NORMAL MODULES
    // ------------------------------------------------------------

    if (_pages[index] == null) {
      _pages[index] = _buildModule(index);
    }

    return _pages[index]!;
  }

  // ============================================================
  // LOGOUT
  // ============================================================

  void _logout() {
    GetStorage().erase();

    Get.offAll(() => const AdminLoginScreen());

    Get.snackbar(
      'Logged Out',
      'Successfully signed out of Admin Center.',
      backgroundColor: error,
      colorText: Colors.white,
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.all(16),
      borderRadius: 12,
    );
  }

  // ============================================================
  // MODULE BUILDER
  // ============================================================

  Widget _buildModule(int index) {
    switch (index) {
      case 0:
        return const AdminDashboardScreen();

      case 1:
        return const AdminTestManageScreen();

      case 2:
        return const AdimeStudentAttdance_screen();

      case 3:
        return const AdminTeacherAttendanceScreen();

      case 4:
        return const AdminFeesManageScreen();

      case 5:
        return const AdminFeedbackScreen();

      // SECTION MERGE
      case 6:
        return const AdminSectionMergeScreen();

      // FEE VERIFICATION
      case 7:
        return const AdminFeeVerificationScreen();

      // ENGAGE
      case 9:
        return const AdminPromoScreen(embedded: true);

      case 10:
        return const AdminSpecialClassScreen(embedded: true);

      case 11:
        return const LeaderboardScreen(embedded: true, role: 'student');

      default:
        return const SizedBox.shrink();
    }
  }

  // ============================================================
  // NAVIGATION ITEM
  // ============================================================

  Widget _navItem(_AdminModule item) {
    final index = item.index;
    return Obx(() {
      final selected = AdminShellNavigation.selectedIndex.value == index;

      return Padding(
        padding: const EdgeInsets.only(bottom: 5),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(13),
            onTap: () {
              AdminShellNavigation.selectModule(index);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
              decoration: BoxDecoration(
                color: selected ? navy : Colors.transparent,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Row(
                children: [
                  Container(
                    width: 37,
                    height: 37,
                    decoration: BoxDecoration(
                      color: selected
                          ? Colors.white.withValues(alpha: .13)
                          : item.color.withValues(alpha: .10),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      item.icon,
                      size: 19,
                      color: selected ? Colors.white : item.color,
                    ),
                  ),

                  const SizedBox(width: 10),

                  Expanded(
                    child: Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        color: selected ? Colors.white : text,
                        fontSize: 12.5,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }

  Widget _groupTitle(String title, {EdgeInsets padding = const EdgeInsets.fromLTRB(10, 14, 10, 9)}) {
    return Padding(
      padding: padding,
      child: Text(
        title,
        style: GoogleFonts.poppins(
          color: secondaryText,
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
        ),
      ),
    );
  }

  // ============================================================
  // SYSTEM STATUS
  // ============================================================

  Widget _status() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: softSurface,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: success,
              shape: BoxShape.circle,
            ),
          ),

          const SizedBox(width: 8),

          Text(
            'System live',
            style: GoogleFonts.poppins(
              color: text,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // LOGOUT BUTTON
  // ============================================================

  Widget _logoutButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _logout,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: error.withValues(alpha: .07),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: error.withValues(alpha: .16)),
          ),
          child: Row(
            children: [
              const Icon(Icons.logout_rounded, color: error, size: 18),

              const SizedBox(width: 10),

              Text(
                'Logout',
                style: GoogleFonts.poppins(
                  color: error,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // DESKTOP SIDEBAR
  // ============================================================

  Widget _sidebar() {
    return Container(
      width: 252,
      decoration: const BoxDecoration(
        color: surface,
        border: Border(right: BorderSide(color: border)),
      ),
      child: SafeArea(
        right: false,
        child: Column(
          children: [
            // ----------------------------------------------------
            // TITLE
            // ----------------------------------------------------
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Let's Speak",
                      style: GoogleFonts.poppins(
                        color: navy,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),

                    Text(
                      'Admin Portal',
                      style: GoogleFonts.poppins(
                        color: secondaryText,
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const Divider(height: 1, color: border),

            // ----------------------------------------------------
            // MANAGEMENT TITLE
            // ----------------------------------------------------
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 20, 18, 9),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'MANAGEMENT',
                  style: GoogleFonts.poppins(
                    color: secondaryText,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
            ),

            // ----------------------------------------------------
            // NAVIGATION
            // ----------------------------------------------------
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  for (final m in modules) _navItem(m),
                  _groupTitle('ENGAGE'),
                  for (final m in engageModules) _navItem(m),
                ],
              ),
            ),

            // ----------------------------------------------------
            // STATUS
            // ----------------------------------------------------
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: _status(),
            ),

            // ----------------------------------------------------
            // LOGOUT
            // ----------------------------------------------------
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 18),
              child: _logoutButton(),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // MOBILE / TABLET DRAWER
  // ============================================================

  Widget _drawer() {
    return Drawer(
      width: 286,
      backgroundColor: surface,
      child: SafeArea(
        child: Column(
          children: [
            // ----------------------------------------------------
            // TITLE + CLOSE BUTTON
            // ----------------------------------------------------
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 20, 10, 18),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      "Let's Speak\nAdmin Portal",
                      style: GoogleFonts.poppins(
                        color: navy,
                        fontSize: 16,
                        height: 1.25,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),

                  IconButton(
                    onPressed: AdminShellNavigation.closeDrawer,
                    icon: const Icon(Icons.close_rounded, color: secondaryText),
                  ),
                ],
              ),
            ),

            const Divider(height: 1, color: border),

            // ----------------------------------------------------
            // NAVIGATION
            // ----------------------------------------------------
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 18, 12, 10),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                    child: Text(
                      'MANAGEMENT',
                      style: GoogleFonts.poppins(
                        color: secondaryText,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ),

                  for (final m in modules) _navItem(m),
                  _groupTitle('ENGAGE'),
                  for (final m in engageModules) _navItem(m),
                ],
              ),
            ),

            // ----------------------------------------------------
            // STATUS
            // ----------------------------------------------------
            Padding(padding: const EdgeInsets.all(12), child: _status()),

            // ----------------------------------------------------
            // LOGOUT
            // ----------------------------------------------------
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 18),
              child: _logoutButton(),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: AdminShellNavigation.scaffoldKey,
      backgroundColor: background,

      // Drawer navigation is for mobile/tablet only.
      // Desktop/web uses the permanent sidebar.
      drawer: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= 1000) {
            return const SizedBox.shrink();
          }

          return _drawer();
        },
      ),

      body: LayoutBuilder(
        builder: (context, constraints) {
          final desktop = constraints.maxWidth >= 1000;

          return Row(
            children: [
              if (desktop) _sidebar(),

              Expanded(
                child: Obx(
                  () => IndexedStack(
                    index: AdminShellNavigation.selectedIndex.value,

                    children: List<Widget>.generate(pageCount, (i) {
                      if (i == AdminShellNavigation.selectedIndex.value) {
                        return _pageAt(i);
                      }

                      return _pages[i] ?? const SizedBox.shrink();
                    }),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ================================================================
// ADMIN MODULE MODEL
// ================================================================

class _AdminModule {
  final int index; // page index in the IndexedStack
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _AdminModule({
    required this.index,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
  });
}
