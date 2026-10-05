import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:lets_speake_manager/Api/ApiendPoints.dart';
import 'package:lets_speake_manager/Controllers/adminController.dart';
import 'package:lets_speake_manager/Navigation/AdminShellNavigation.dart';

class AdminUserControlScreen extends StatefulWidget {
  final dynamic user;
  const AdminUserControlScreen({super.key, required this.user});

  @override
  State<AdminUserControlScreen> createState() => _AdminUserControlScreenState();
}

class _AdminUserControlScreenState extends State<AdminUserControlScreen> {
  static const Color textColor = Color(0xFF173A52);
  static const Color secondaryText = Color(0xFF6B8496);
  static const Color borderColor = Color(0xFFD5E5EE);
  static const Color softSurface = Color(0xFFEAF4FA);

  /// Return from this student's control page to the Students module.
  void _goBackToStudents() {
    if (AdminShellNavigation.detailUser.value != null) {
      AdminShellNavigation.goHome();
      return;
    }

    if (Get.key.currentState?.canPop() ?? false) {
      Get.back();
      return;
    }

    AdminShellNavigation.openDrawer();
  }

  final AdminController adminController = Get.find<AdminController>();

  late Map<String, dynamic> englishAccess;
  late Map<String, dynamic> hindiAccess;
  late String selectedMode;
  late String selectedSection;
  late String selectedFeeStatus;

  bool isSaving = false;
  bool isLoadingAnalytics = true;
  List<dynamic> studentAttendanceLog = [];
  List<dynamic> studentTestResults = [];

  // --- BRAND PALETTE ---
  final Color bgDark = const Color(0xFFF5FAFD);
  final Color cardBg = const Color(0xFFFFFFFF);
  final Color surfaceSubtle = const Color(0xFFEAF4FA);
  final Color accentPurple = const Color(0xFF0A4A75);
  final Color accentBlue = const Color(0xFF2E86C9);
  final Color successGreen = const Color(0xFF16A66A);
  final Color alertRed = const Color(0xFFE45757);
  final Color warningOrange = const Color(0xFFF4C542);
  final Color goldenYellow = const Color(0xFFF4C542);

  final List<String> stageKeys = const [
    'stage1',
    'stage2',
    'stage3',
    'stage4',
    'stage5',
    'stage6',
    'stage7',
  ];

  @override
  void initState() {
    super.initState();
    _initializeUserData();
  }

  /// 🚀 FIX: Reset and deep copy state variables whenever the widget or target user changes
  @override
  void didUpdateWidget(covariant AdminUserControlScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user['_id'] != widget.user['_id'] ||
        oldWidget.user['id'] != widget.user['id']) {
      _initializeUserData();
      _fetchStudentDeepAnalytics();
    }
  }

  void _initializeUserData() {
    englishAccess = Map<String, dynamic>.from(
      jsonDecode(jsonEncode(widget.user['englishAccess'] ?? {})),
    );
    hindiAccess = Map<String, dynamic>.from(
      jsonDecode(jsonEncode(widget.user['hindiAccess'] ?? {})),
    );

    selectedMode = (widget.user['mode'] ?? 'online').toString().toLowerCase();

    final initialSection = (widget.user['onlineSection'] ?? '')
        .toString()
        .toUpperCase();
    selectedSection = ["A", "B", "C", "D", "E"].contains(initialSection)
        ? initialSection
        : '';

    selectedFeeStatus = (widget.user['feeStatus'] ?? 'unpaid')
        .toString()
        .toLowerCase();

    for (var key in stageKeys) {
      englishAccess.putIfAbsent(key, () => false);
      hindiAccess.putIfAbsent(key, () => false);
    }

    _fetchStudentDeepAnalytics();
  }

  Future<void> _fetchStudentDeepAnalytics() async {
    final String userId = (widget.user['_id'] ?? widget.user['id']).toString();
    if (mounted) setState(() => isLoadingAnalytics = true);

    try {
      final responses = await Future.wait([
        http.get(Uri.parse("${ApiEndpoints.userAttendance}?userId=$userId")),
        http.get(Uri.parse("${ApiEndpoints.userTestResults}?userId=$userId")),
      ]);

      if (responses[0].statusCode == 200) {
        final attData = jsonDecode(responses[0].body);
        studentAttendanceLog = attData['records'] ?? [];
      }

      if (responses[1].statusCode == 200) {
        final testData = jsonDecode(responses[1].body);
        studentTestResults = testData['results'] ?? [];
      }
    } catch (e) {
      debugPrint("Analytics Fetch Error: $e");
    } finally {
      if (mounted) setState(() => isLoadingAnalytics = false);
    }
  }

  int get presentSessions =>
      studentAttendanceLog.where((r) => r['status'] == 'Present').length;
  int get partialLateSessions => studentAttendanceLog
      .where((r) => r['status'] == 'Partial' || r['status'] == 'Late')
      .length;
  int get totalLoggedSessions => studentAttendanceLog.length;

  double get attendanceRate {
    if (totalLoggedSessions == 0) return 0.0;
    return ((presentSessions + (partialLateSessions * 0.5)) /
            totalLoggedSessions) *
        100;
  }

  int get totalMinutesSpent {
    int total = 0;
    for (var r in studentAttendanceLog) {
      total += (r['totalMinutesSpent'] as num? ?? 0).toInt();
    }
    return total;
  }

  double get averageTestScore {
    if (studentTestResults.isEmpty) return 0.0;
    int totalEarned = 0;
    int totalPossible = 0;
    for (var t in studentTestResults) {
      totalEarned += (t['score'] as num? ?? 0).toInt();
      totalPossible += (t['totalQuestions'] as num? ?? 1).toInt();
    }
    return totalPossible > 0 ? (totalEarned / totalPossible) * 100 : 0.0;
  }

  String get regularityStatus {
    if (totalLoggedSessions < 3) return "New Enrollee";
    if (attendanceRate >= 80) return "Consistent / Regular";
    if (attendanceRate >= 50) return "Moderate Attendance";
    return "Irregular / At-Risk";
  }

  Color get regularityColor {
    if (totalLoggedSessions < 3) return accentBlue;
    if (attendanceRate >= 80) return successGreen;
    if (attendanceRate >= 50) return warningOrange;
    return alertRed;
  }

  /// 🚀 FIXED: Counts online students belonging to section [sec] who have access to the specific [stageKey]
  int _getSectionStudentCount(String sec, String stageKey) {
    return adminController.usersList.where((u) {
      final isOnline = u['mode']?.toString().toLowerCase() == 'online';
      final assignedSec = u['onlineSection']?.toString().toUpperCase() ?? '';
      final engAccess = u['englishAccess'] as Map? ?? {};
      final hasStageAccess = engAccess[stageKey] == true;

      // Exclude the current student being edited
      final currentUserId = (widget.user['_id'] ?? widget.user['id']).toString();
      final uId = (u['_id'] ?? u['id']).toString();
      if (uId == currentUserId) return false;

      return isOnline && assignedSec == sec && hasStageAccess;
    }).length;
  }

  void _showSectionSelectionPopup(
    String stageTitle,
    String stageKey,
    Function(String chosenSection) onSelected,
  ) {
    String tempSection = selectedSection.isNotEmpty && selectedSection != 'None'
        ? selectedSection
        : "A";

    Get.dialog(
      Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 24),
        backgroundColor: cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: accentBlue.withOpacity(0.4), width: 1.2),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520, maxHeight: 620),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: accentBlue.withOpacity(0.10),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.class_rounded,
                        color: accentBlue,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Text(
                        "Select Section for $stageTitle",
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          color: textColor,
                          fontSize: 15,
                          height: 1.2,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  "Review live student counts per section and select where to place this student.",
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    color: secondaryText,
                    fontSize: 11.5,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 14),
                Flexible(
                  child: StatefulBuilder(
                    builder: (context, setDialogState) {
                      return ListView.separated(
                        shrinkWrap: true,
                        padding: EdgeInsets.zero,
                        physics: const BouncingScrollPhysics(),
                        itemCount: 5,
                        separatorBuilder: (_, __) => const SizedBox(height: 7),
                        itemBuilder: (context, index) {
                          final sec = ["A", "B", "C", "D", "E"][index];
                          final bool isChosen = tempSection == sec;
                          final int count = _getSectionStudentCount(sec, stageKey);

                          return Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () {
                                HapticFeedback.selectionClick();
                                setDialogState(() => tempSection = sec);
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                constraints: const BoxConstraints(
                                  minHeight: 58,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 9,
                                ),
                                decoration: BoxDecoration(
                                  color: isChosen
                                      ? accentBlue.withOpacity(0.10)
                                      : surfaceSubtle,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isChosen ? accentBlue : borderColor,
                                    width: isChosen ? 1.4 : 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 34,
                                      height: 34,
                                      decoration: BoxDecoration(
                                        color: isChosen
                                            ? accentBlue
                                            : borderColor.withOpacity(0.35),
                                        shape: BoxShape.circle,
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        sec,
                                        style: GoogleFonts.poppins(
                                          color: isChosen
                                              ? Colors.white
                                              : secondaryText,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        "Online Section $sec",
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.poppins(
                                          color: textColor,
                                          fontWeight: isChosen
                                              ? FontWeight.bold
                                              : FontWeight.w500,
                                          fontSize: 12.5,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 7),
                                    ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        maxWidth: 82,
                                      ),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 7,
                                          vertical: 5,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isChosen
                                              ? accentBlue.withOpacity(0.12)
                                              : textColor.withOpacity(0.05),
                                          borderRadius: BorderRadius.circular(
                                            7,
                                          ),
                                        ),
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Text(
                                            "$count Students",
                                            maxLines: 1,
                                            style: GoogleFonts.poppins(
                                              color: const Color(0xFFC68B00),
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Get.back(),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 11),
                        ),
                        child: Text(
                          "Cancel",
                          style: GoogleFonts.poppins(
                            color: secondaryText,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Get.back();
                          onSelected(tempSection);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accentBlue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          "Grant Access",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      barrierDismissible: false,
    );
  }

  void _bulkToggleStages(
    Map<String, dynamic> accessMap,
    bool enable, {
    required bool isEnglish,
  }) {
    if (enable && selectedMode == 'online' && isEnglish) {
      _showSectionSelectionPopup("All English Stages", "stage1", (chosenSec) {
        setState(() {
          selectedSection = chosenSec;
          for (var key in stageKeys) {
            accessMap[key] = true;
          }
        });
      });
      return;
    }

    HapticFeedback.selectionClick();
    setState(() {
      for (var key in stageKeys) {
        accessMap[key] = enable;
      }
      if (!isEnglish && enable) {
        selectedSection = 'None';
      }
    });
  }

  Future<void> _saveAllSettings() async {
    bool hasAnyEnglishAccess = englishAccess.values.any((v) => v == true);

    HapticFeedback.mediumImpact();
    setState(() => isSaving = true);
    try {
      final String userId = (widget.user['_id'] ?? widget.user['id'])
          .toString();

      await adminController.updateUserAccess(
        userId,
        englishAccess,
        hindiAccess,
        selectedMode,
      );

      final token = adminController.box.read('token');
      final response = await http.put(
        Uri.parse(ApiEndpoints.updateStudentStatus),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode({
          "userId": userId,
          "feeStatus": selectedFeeStatus,
          "onlineSection": selectedMode == 'online' && hasAnyEnglishAccess
              ? selectedSection
              : 'None',
          "mode": selectedMode,
        }),
      );

      if (response.statusCode == 200) {
        Get.snackbar(
          "Changes Synchronized",
          "Student permissions & sections updated live.",
          backgroundColor: successGreen.withOpacity(0.95),
          colorText: Colors.white,
          icon: const Icon(Icons.check_circle_rounded, color: Colors.white),
          snackPosition: SnackPosition.TOP,
          margin: const EdgeInsets.all(16),
          borderRadius: 14,
        );
      }
    } catch (e) {
      Get.snackbar(
        "Update Failed",
        "Connection error: $e",
        backgroundColor: alertRed.withOpacity(0.95),
        colorText: Colors.white,
        icon: const Icon(Icons.error_outline_rounded, color: Colors.white),
        snackPosition: SnackPosition.TOP,
        margin: const EdgeInsets.all(16),
        borderRadius: 14,
      );
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= 1050;
    final isTablet = width >= 700 && width < 1050;
    final isOnline = selectedMode == 'online';

    final studentName = (widget.user['name'] ?? 'Student').toString();
    final studentPhone = (widget.user['phone'] ?? 'No phone').toString();
    final initial = studentName.trim().isNotEmpty
        ? studentName.trim()[0].toUpperCase()
        : 'S';

    return Scaffold(
      backgroundColor: bgDark,
      appBar: AppBar(
        backgroundColor: cardBg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 62,
        leading: IconButton(
          tooltip: 'Back to Students',
          onPressed: _goBackToStudents,
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: textColor,
            size: 22,
          ),
        ),
        titleSpacing: 0,
        title: Text(
          'Student Control',
          style: GoogleFonts.poppins(
            color: textColor,
            fontSize: isDesktop ? 18 : 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          if (isDesktop)
            Padding(
              padding: const EdgeInsets.only(right: 18),
              child: _saveButton(compact: true),
            )
          else
            IconButton(
              tooltip: 'Save changes',
              onPressed: isSaving ? null : _saveAllSettings,
              icon: Icon(
                Icons.save_rounded,
                color: isSaving ? secondaryText : accentPurple,
              ),
            ),
        ],
      ),
      bottomNavigationBar: isDesktop
          ? null
          : SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 9, 14, 11),
                decoration: BoxDecoration(
                  color: cardBg,
                  border: const Border(top: BorderSide(color: borderColor)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(.06),
                      blurRadius: 18,
                      offset: const Offset(0, -5),
                    ),
                  ],
                ),
                child: _saveButton(compact: false),
              ),
            ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1220),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                isDesktop ? 26 : (isTablet ? 20 : 14),
                16,
                isDesktop ? 26 : (isTablet ? 20 : 14),
                isDesktop ? 26 : 18,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStudentHero(
                    studentName: studentName,
                    studentPhone: studentPhone,
                    initial: initial,
                    isOnline: isOnline,
                    isDesktop: isDesktop,
                  ),
                  const SizedBox(height: 14),
                  _buildAnalyticsCard(isDesktop: isDesktop, isTablet: isTablet),
                  const SizedBox(height: 14),
                  _buildConfigurationCard(
                    isOnline: isOnline,
                    isDesktop: isDesktop,
                  ),
                  const SizedBox(height: 14),
                  _buildAccessHeader(),
                  const SizedBox(height: 10),
                  if (isDesktop)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _buildCourseSection(
                            title: 'English',
                            subtitle: '7 stages',
                            accessMap: englishAccess,
                            accentColor: accentPurple,
                            isEnglish: true,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: _buildCourseSection(
                            title: 'Hindi',
                            subtitle: '7 stages',
                            accessMap: hindiAccess,
                            accentColor: accentBlue,
                            isEnglish: false,
                          ),
                        ),
                      ],
                    )
                  else ...[
                    _buildCourseSection(
                      title: 'English',
                      subtitle: '7 stages',
                      accessMap: englishAccess,
                      accentColor: accentPurple,
                      isEnglish: true,
                    ),
                    const SizedBox(height: 12),
                    _buildCourseSection(
                      title: 'Hindi',
                      subtitle: '7 stages',
                      accessMap: hindiAccess,
                      accentColor: accentBlue,
                      isEnglish: false,
                    ),
                  ],
                  if (isDesktop) const SizedBox(height: 6),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _saveButton({required bool compact}) {
    return SizedBox(
      height: compact ? 40 : 50,
      width: compact ? 164 : double.infinity,
      child: ElevatedButton.icon(
        onPressed: isSaving ? null : _saveAllSettings,
        icon: isSaving
            ? SizedBox(
                width: compact ? 15 : 18,
                height: compact ? 15 : 18,
                child: const CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : Icon(Icons.save_rounded, size: compact ? 16 : 18),
        label: Text(
          isSaving
              ? 'Saving...'
              : compact
              ? 'Save changes'
              : 'Save & publish changes',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: compact ? 11.5 : 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: accentPurple,
          foregroundColor: Colors.white,
          disabledBackgroundColor: accentPurple.withOpacity(.65),
          elevation: 0,
          padding: EdgeInsets.symmetric(horizontal: compact ? 13 : 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(compact ? 11 : 13),
          ),
        ),
      ),
    );
  }

  Widget _buildStudentHero({
    required String studentName,
    required String studentPhone,
    required String initial,
    required bool isOnline,
    required bool isDesktop,
  }) {
    final statusColor = regularityColor;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isDesktop ? 20 : 15),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0E466D), Color(0xFF155A88), Color(0xFF2C6F9F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: isDesktop ? 58 : 50,
            height: isDesktop ? 58 : 50,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(.13),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(.22)),
            ),
            alignment: Alignment.center,
            child: Text(
              initial,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: isDesktop ? 23 : 20,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  studentName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: isDesktop ? 18 : 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  studentPhone,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    color: Colors.white.withOpacity(.70),
                    fontSize: 10.5,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 5,
                  children: [
                    _heroChip(
                      icon: isOnline
                          ? Icons.wifi_rounded
                          : Icons.location_on_rounded,
                      label: isOnline ? 'Online' : 'Offline',
                    ),
                    if (isOnline &&
                        selectedSection.isNotEmpty &&
                        selectedSection != 'None')
                      _heroChip(
                        icon: Icons.groups_rounded,
                        label: 'Section $selectedSection',
                      ),
                  ],
                ),
              ],
            ),
          ),
          if (isDesktop) ...[
            const SizedBox(width: 14),
            _statusBadge(statusColor, regularityStatus),
          ],
        ],
      ),
    );
  }

  Widget _heroChip({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: const Color(0xFFF7DF55)),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusBadge(Color color, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(.20)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard({
    required String title,
    required Widget child,
    IconData? icon,
    Color? accent,
  }) {
    final color = accent ?? accentPurple;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: color.withOpacity(.09),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(icon, color: color, size: 17),
                ),
                const SizedBox(width: 9),
              ],
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.poppins(
                    color: textColor,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          child,
        ],
      ),
    );
  }

  Widget _buildAnalyticsCard({
    required bool isDesktop,
    required bool isTablet,
  }) {
    return _sectionCard(
      title: 'Learning overview',
      icon: Icons.insights_rounded,
      accent: accentBlue,
      child: Column(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 620;
              final cards = [
                _buildStatCard(
                  'Sessions',
                  '$totalLoggedSessions',
                  accentPurple,
                  const Color(0xFFF0F6FA),
                  Icons.event_available_rounded,
                ),
                _buildStatCard(
                  'Learning time',
                  '${(totalMinutesSpent / 60).toStringAsFixed(1)}h',
                  accentBlue,
                  const Color(0xFFF0F7FD),
                  Icons.schedule_rounded,
                ),
                _buildStatCard(
                  'Attendance',
                  '${attendanceRate.toStringAsFixed(0)}%',
                  successGreen,
                  const Color(0xFFF0FAF6),
                  Icons.check_circle_outline_rounded,
                ),
                _buildStatCard(
                  'Avg. test',
                  '${averageTestScore.toStringAsFixed(0)}%',
                  const Color(0xFFC68B00),
                  const Color(0xFFFFFBEE),
                  Icons.assessment_rounded,
                ),
              ];

              if (compact) {
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: cards
                      .map(
                        (card) => SizedBox(
                          width: (constraints.maxWidth - 8) / 2,
                          child: card,
                        ),
                      )
                      .toList(),
                );
              }

              return Row(
                children: [
                  for (int i = 0; i < cards.length; i++) ...[
                    Expanded(child: cards[i]),
                    if (i != cards.length - 1) const SizedBox(width: 8),
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Test performance by stage',
                  style: GoogleFonts.poppins(
                    color: textColor,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (isLoadingAnalytics)
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    color: accentBlue,
                    strokeWidth: 2,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          _buildPerformanceChart(),
        ],
      ),
    );
  }

  Widget _buildPerformanceChart() {
    if (isLoadingAnalytics) {
      return Container(
        height: 105,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: surfaceSubtle,
          borderRadius: BorderRadius.circular(12),
        ),
        child: CircularProgressIndicator(color: accentBlue, strokeWidth: 2),
      );
    }

    if (studentTestResults.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 14),
        decoration: BoxDecoration(
          color: surfaceSubtle,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: accentBlue.withOpacity(.09),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.bar_chart_rounded, color: accentBlue, size: 19),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'No test results yet',
                    style: GoogleFonts.poppins(
                      color: textColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    'Stage scores will appear here after a test is completed.',
                    style: GoogleFonts.poppins(
                      color: secondaryText,
                      fontSize: 9.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      height: 145,
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      decoration: BoxDecoration(
        color: surfaceSubtle,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: studentTestResults.length,
        separatorBuilder: (_, __) => const SizedBox(width: 13),
        itemBuilder: (context, index) {
          final result = studentTestResults[index];
          final stage = (result['stage'] ?? 'S1').toString().toUpperCase();
          final language = (result['language'] ?? 'English').toString();
          final score = (result['score'] as num? ?? 0).toInt();
          final total = (result['totalQuestions'] as num? ?? 1).toInt();
          final pct = total > 0
              ? (score / total).clamp(0.0, 1.0).toDouble()
              : 0.0;
          final barColor = pct >= .5 ? successGreen : alertRed;

          return SizedBox(
            width: 42,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  '${(pct * 100).toStringAsFixed(0)}%',
                  style: GoogleFonts.poppins(
                    color: barColor,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Expanded(
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      width: 24,
                      height: 72,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(7),
                        border: Border.all(color: borderColor),
                      ),
                      alignment: Alignment.bottomCenter,
                      child: FractionallySizedBox(
                        widthFactor: 1,
                        heightFactor: pct.clamp(.08, 1.0).toDouble(),
                        alignment: Alignment.bottomCenter,
                        child: Container(
                          decoration: BoxDecoration(
                            color: barColor,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  stage,
                  style: GoogleFonts.poppins(
                    color: textColor,
                    fontSize: 8.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  language.isNotEmpty ? language[0] : 'E',
                  style: GoogleFonts.poppins(
                    color: secondaryText,
                    fontSize: 7.5,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildConfigurationCard({
    required bool isOnline,
    required bool isDesktop,
  }) {
    return _sectionCard(
      title: 'Student settings',
      icon: Icons.tune_rounded,
      accent: accentPurple,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _settingBlock(
            title: 'Learning mode',
            subtitle: 'Where the student attends classes',
            child: _buildChoiceGroup(
              children: [
                _buildSegmentButton(
                  title: 'Online',
                  icon: Icons.wifi_rounded,
                  isSelected: isOnline,
                  activeColor: accentBlue,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => selectedMode = 'online');
                  },
                ),
                _buildSegmentButton(
                  title: 'Offline',
                  icon: Icons.location_on_rounded,
                  isSelected: !isOnline,
                  activeColor: const Color(0xFFC68B00),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => selectedMode = 'offline');
                  },
                ),
              ],
            ),
          ),
          if (selectedMode == 'online') ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 11,
                vertical: 9,
              ),
              decoration: BoxDecoration(
                color: accentBlue.withOpacity(.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: accentBlue.withOpacity(.16)),
              ),
              child: Row(
                children: [
                  Icon(Icons.groups_rounded, color: accentBlue, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      selectedSection.isEmpty || selectedSection == 'None'
                          ? 'No section assigned'
                          : 'Section $selectedSection assigned',
                      style: GoogleFonts.poppins(
                        color: secondaryText,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => _showSectionSelectionPopup(
                      'Student',
                      'stage1',
                      (chosen) => setState(() => selectedSection = chosen),
                    ),
                    child: Text(
                      'Change',
                      style: GoogleFonts.poppins(
                        color: accentBlue,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _settingBlock({
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.poppins(
            color: textColor,
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: GoogleFonts.poppins(color: secondaryText, fontSize: 9.5),
        ),
        const SizedBox(height: 7),
        child,
      ],
    );
  }

  Widget _buildAccessHeader() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Course access',
                style: GoogleFonts.poppins(
                  color: textColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Turn individual stages on or off for this student.',
                style: GoogleFonts.poppins(color: secondaryText, fontSize: 9.5),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
          decoration: BoxDecoration(
            color: accentBlue.withOpacity(.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.touch_app_rounded, color: accentBlue, size: 14),
              const SizedBox(width: 5),
              Text(
                'Tap a stage to change',
                style: GoogleFonts.poppins(
                  color: accentBlue,
                  fontSize: 8.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildChoiceGroup({required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: surfaceSubtle,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          for (int i = 0; i < children.length; i++) ...[
            Expanded(child: children[i]),
            if (i != children.length - 1) const SizedBox(width: 3),
          ],
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    Color valueColor,
    Color bgColor,
    IconData icon,
  ) {
    return Container(
      height: 70,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: valueColor.withOpacity(.16)),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: valueColor.withOpacity(.10),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, color: valueColor, size: 16),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    color: valueColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    color: secondaryText,
                    fontSize: 8.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentButton({
    required String title,
    required IconData icon,
    required bool isSelected,
    required Color activeColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected ? activeColor : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 14,
                color: isSelected ? Colors.white : secondaryText,
              ),
              const SizedBox(width: 5),
              Text(
                title,
                style: GoogleFonts.poppins(
                  color: isSelected ? Colors.white : secondaryText,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCourseSection({
    required String title,
    required String subtitle,
    required Map<String, dynamic> accessMap,
    required Color accentColor,
    required bool isEnglish,
  }) {
    final unlockedCount = stageKeys
        .where((key) => accessMap[key] == true)
        .length;
    final allUnlocked = unlockedCount == stageKeys.length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(.09),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isEnglish ? Icons.translate_rounded : Icons.language_rounded,
                  color: accentColor,
                  size: 18,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.poppins(
                        color: textColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '$unlockedCount of 7 stages enabled • $subtitle',
                      style: GoogleFonts.poppins(
                        color: secondaryText,
                        fontSize: 9,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => _bulkToggleStages(
                  accessMap,
                  !allUnlocked,
                  isEnglish: isEnglish,
                ),
                style: TextButton.styleFrom(
                  foregroundColor: allUnlocked ? alertRed : accentColor,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 6,
                  ),
                ),
                child: Text(
                  allUnlocked ? 'Turn all off' : 'Turn all on',
                  style: GoogleFonts.poppins(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(height: 1, color: borderColor),
          const SizedBox(height: 9),
          LayoutBuilder(
            builder: (context, constraints) {
              final twoColumns = constraints.maxWidth >= 560;
              final rows = List.generate(stageKeys.length, (index) {
                final key = stageKeys[index];
                final stageNumber = index + 1;
                final isUnlocked = accessMap[key] == true;

                return _buildStageAccessRow(
                  stageNumber: stageNumber,
                  isUnlocked: isUnlocked,
                  accentColor: accentColor,
                  onChanged: (value) {
                    if (value && selectedMode == 'online' && isEnglish) {
                      _showSectionSelectionPopup('$title Stage $stageNumber', key, (
                        chosenSec,
                      ) {
                        setState(() {
                          selectedSection = chosenSec;
                          accessMap[key] = true;
                        });
                      });
                      return;
                    }

                    HapticFeedback.selectionClick();
                    setState(() {
                      accessMap[key] = value;
                      final anyEnglishLeft = englishAccess.values.any(
                        (v) => v == true,
                      );
                      if (!anyEnglishLeft && selectedMode == 'online') {
                        selectedSection = 'None';
                      }
                    });
                  },
                );
              });

              if (!twoColumns) {
                return Column(
                  children: [
                    for (int i = 0; i < rows.length; i++) ...[
                      rows[i],
                      if (i != rows.length - 1) const SizedBox(height: 6),
                    ],
                  ],
                );
              }

              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: rows.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 7,
                  mainAxisSpacing: 6,
                  mainAxisExtent: 58,
                ),
                itemBuilder: (_, index) => rows[index],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStageAccessRow({
    required int stageNumber,
    required bool isUnlocked,
    required Color accentColor,
    required ValueChanged<bool> onChanged,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onChanged(!isUnlocked),
        borderRadius: BorderRadius.circular(11),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
          decoration: BoxDecoration(
            color: isUnlocked ? accentColor.withOpacity(.07) : surfaceSubtle,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(
              color: isUnlocked ? accentColor.withOpacity(.25) : borderColor,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 29,
                height: 29,
                decoration: BoxDecoration(
                  color: isUnlocked ? accentColor.withOpacity(.12) : cardBg,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isUnlocked
                        ? accentColor.withOpacity(.22)
                        : borderColor,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  stageNumber.toString().padLeft(2, '0'),
                  style: GoogleFonts.poppins(
                    color: isUnlocked ? accentColor : secondaryText,
                    fontSize: 8.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Stage $stageNumber',
                      style: GoogleFonts.poppins(
                        color: textColor,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      isUnlocked ? 'Enabled' : 'Locked',
                      style: GoogleFonts.poppins(
                        color: isUnlocked ? accentColor : secondaryText,
                        fontSize: 8,
                      ),
                    ),
                  ],
                ),
              ),
              _buildAccessToggle(value: isUnlocked, activeColor: accentColor),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAccessToggle({required bool value, required Color activeColor}) {
    return IgnorePointer(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 45,
        height: 25,
        padding: const EdgeInsets.all(2.5),
        decoration: BoxDecoration(
          color: value ? activeColor : const Color(0xFFD8E4EB),
          borderRadius: BorderRadius.circular(16),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 160),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 20,
            height: 20,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Icon(
              value ? Icons.check_rounded : Icons.remove_rounded,
              size: 12,
              color: value ? activeColor : secondaryText,
            ),
          ),
        ),
      ),
    );
  }
}