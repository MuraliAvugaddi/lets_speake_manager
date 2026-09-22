import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:get/get_navigation/src/extension_navigation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:lets_speake_manager/Api/ApiendPoints.dart';
import 'package:lets_speake_manager/Navigation/AdminShellNavigation.dart';
import 'package:lets_speake_manager/screens/register_account_screen.dart';


class AdminTeacherAttendanceScreen extends StatefulWidget {
  const AdminTeacherAttendanceScreen({super.key});

  @override
  State<AdminTeacherAttendanceScreen> createState() =>
      _AdminTeacherAttendanceScreenState();
}

class _AdminTeacherAttendanceScreenState
    extends State<AdminTeacherAttendanceScreen> {
  static const Color navy = Color(0xFF155A88);
  static const Color deepNavy = Color(0xFF0E466D);
  static const Color blue = Color(0xFF2C6F9F);
  static const Color teal = Color(0xFF28C2C2);
  static const Color yellow = Color(0xFFF7DF55);

  static const Color textColor = Color(0xFF173A52);
  static const Color secondaryText = Color(0xFF678196);
  static const Color borderColor = Color(0xFFD5E5EE);
  static const Color softSurface = Color(0xFFF4F9FC);
  static const Color backgroundColor = Color(0xFFE8F2F8);
  static const Color cardColor = Color(0xFFFFFFFF);

  static const Color success = Color(0xFF16A66A);
  static const Color error = Color(0xFFE45757);
  static const Color warning = Color(0xFFF2B84B);
  static final Color navy10 = navy.withOpacity(0.10);

  void _openAdminDrawerOrBack() {
    if (AdminShellNavigation.scaffoldKey.currentState != null) {
      AdminShellNavigation.openDrawer();
    } else {
      Get.back();
    }
  }

  String selectedMode = "All";
  String selectedLanguage = "All";
  String selectedStage = "All";
  String activeStatusFilter = "all";

  late DateTime selectedDate;

  List<Map<String, dynamic>> teacherList = [];
  bool isLoading = false;

  final List<String> allModes = ["All", "Online", "Offline"];
  final List<String> allLanguages = ["All", "English", "Hindi"];
  final List<String> allStages = [
    "All",
    "Stage 1",
    "Stage 2",
    "Stage 3",
    "Stage 4",
    "Stage 5",
    "Stage 6",
    "Stage 7",
  ];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    selectedDate = DateTime(now.year, now.month, now.day);
    fetchTeacherAttendance();
  }

  Future<void> fetchTeacherAttendance() async {
    if (!mounted) return;
    setState(() => isLoading = true);

    String day = selectedDate.day.toString().padLeft(2, '0');
    String month = selectedDate.month.toString().padLeft(2, '0');
    String year = selectedDate.year.toString();
    String dateStr = "$day-$month-$year";

    String queryStage = selectedStage == "All"
        ? "all"
        : selectedStage.replaceAll(RegExp(r'\s+'), '').toLowerCase();
    String queryMode = selectedMode == "All"
        ? "all"
        : selectedMode.toLowerCase();
    String queryLang = selectedLanguage == "All" ? "all" : selectedLanguage;

    try {
      final response = await http.get(
        Uri.parse(
          "${ApiEndpoints.baseUrl}/admin/teachers?mode=$queryMode&language=$queryLang&stage=$queryStage",
        ),
      );

      // 🚀 Added stage and language parameters here so admin matches the exact trainer stage
      final attendanceResponse = await http.get(
        Uri.parse(
          "${ApiEndpoints.baseUrl}/admin/attendance?date=$dateStr&stage=$queryStage&language=$queryLang&mode=$queryMode&role=teacher",
        ),
      );

      if (response.statusCode == 200 && attendanceResponse.statusCode == 200) {
        final decodedData = jsonDecode(response.body);
        List<dynamic> allTeachers = decodedData['teachers'] ?? [];
        List<dynamic> attendanceRecords = jsonDecode(attendanceResponse.body);

        List<Map<String, dynamic>> tempList = [];

        for (var teacher in allTeachers) {
          String userId = (teacher['_id'] ?? teacher['id']).toString();
          String userMode = (teacher['mode'] ?? 'online')
              .toString()
              .toLowerCase();

          var record = attendanceRecords.firstWhere(
            (att) => att['userId']?.toString() == userId,
            orElse: () => null,
          );

          String? formattedTime;
          if (record != null &&
              (record['markedAt'] != null || record['joinTime'] != null)) {
            try {
              // 🚀 Convert UTC server time to local device time so correct time shows accurately
              DateTime dt = DateTime.parse(
                record['markedAt'] ?? record['joinTime'],
              ).toLocal();
              formattedTime = DateFormat('hh:mm a').format(dt);
            } catch (_) {
              formattedTime = "Today";
            }
          }

          tempList.add({
            "teacherId": userId,
            "teacherName": teacher['name'] ?? "Unknown Teacher",
            "teacherPhone": teacher['phone'] ?? "No Phone",
            "mode": userMode,
            "status": record != null
                ? (record['status'] ?? "Present")
                : "Absent",
            "totalMinutes": record != null
                ? (record['totalMinutes'] ?? record['totalMinutesSpent'] ?? 0)
                : 0,
            "markedAtTime": formattedTime,
          });
        }

        if (mounted) {
          setState(() {
            teacherList = tempList;
            isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => isLoading = false);
      }
    } catch (e) {
      debugPrint("Teacher Attendance Fetch Error: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate.isAfter(today) ? today : selectedDate,
      firstDate: DateTime(2024),
      lastDate: today,
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(
              primary: navy,
              onPrimary: Colors.white,
              surface: cardColor,
              onSurface: textColor,
            ),
            dialogBackgroundColor: cardColor,
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: navy,
                textStyle: GoogleFonts.poppins(fontWeight: FontWeight.bold),
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        selectedDate = DateTime(picked.year, picked.month, picked.day);
      });
      fetchTeacherAttendance();
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isWeb = width >= 900;

    final totalCount = teacherList.length;
    final presentCount = teacherList
        .where((t) => t['status'] == 'Present')
        .length;
    final lateCount = teacherList
        .where((t) => t['status'] == 'Late' || t['status'] == 'Partial')
        .length;
    final absentCount = teacherList
        .where((t) => t['status'] == 'Absent')
        .length;

    final filteredList = teacherList.where((t) {
      if (activeStatusFilter == 'present') {
        return t['status'] == 'Present';
      }
      if (activeStatusFilter == 'late') {
        return t['status'] == 'Late' || t['status'] == 'Partial';
      }
      if (activeStatusFilter == 'absent') {
        return t['status'] == 'Absent';
      }
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: cardColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: isWeb ? 72 : 62,
        leading: IconButton(
          tooltip: 'Menu',
          onPressed: _openAdminDrawerOrBack,
          icon: const Icon(Icons.menu_rounded, color: textColor, size: 23),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            Container(
              width: isWeb ? 40 : 34,
              height: isWeb ? 40 : 34,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [deepNavy, navy]),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.co_present_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
            SizedBox(width: isWeb ? 11 : 8),
            Flexible(
              child: Text(
                'Teacher Attendance',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  color: textColor,
                  fontSize: isWeb ? 18 : 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        actions: [
          _buildTrainerRegistrationButton(isWeb: isWeb),
          if (isWeb) const SizedBox(width: 4),
          IconButton(
            tooltip: 'Select date',
            visualDensity: isWeb
                ? VisualDensity.standard
                : VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: BoxConstraints.tightFor(
              width: isWeb ? 40 : 34,
              height: isWeb ? 40 : 34,
            ),
            onPressed: () => _selectDate(context),
            icon: const Icon(
              Icons.calendar_month_rounded,
              color: textColor,
              size: 20,
            ),
          ),
          IconButton(
            tooltip: 'Refresh',
            visualDensity: isWeb
                ? VisualDensity.standard
                : VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: BoxConstraints.tightFor(
              width: isWeb ? 40 : 34,
              height: isWeb ? 40 : 34,
            ),
            onPressed: isLoading ? null : fetchTeacherAttendance,
            icon: const Icon(Icons.refresh_rounded, color: textColor, size: 21),
          ),
          if (isWeb) const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1400),
            child: Column(
              children: [
                _buildTopToolbar(isWeb: isWeb),
                _buildQuickTeacherFilters(isWeb: isWeb),
                _buildStatusSummary(
                  totalCount: totalCount,
                  presentCount: presentCount,
                  lateCount: lateCount,
                  absentCount: absentCount,
                  isWeb: isWeb,
                ),
                Expanded(
                  child: isLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: navy,
                            strokeWidth: 2.5,
                          ),
                        )
                      : filteredList.isEmpty
                      ? _buildEmptyState()
                      : RefreshIndicator(
                          color: navy,
                          backgroundColor: Colors.white,
                          onRefresh: fetchTeacherAttendance,
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final columns = constraints.maxWidth >= 1150
                                  ? 3
                                  : constraints.maxWidth >= 720
                                  ? 2
                                  : 1;

                              final horizontal = isWeb ? 24.0 : 14.0;

                              if (columns == 1) {
                                return ListView.separated(
                                  physics: const AlwaysScrollableScrollPhysics(
                                    parent: BouncingScrollPhysics(),
                                  ),
                                  padding: EdgeInsets.fromLTRB(
                                    horizontal,
                                    2,
                                    horizontal,
                                    24,
                                  ),
                                  itemCount: filteredList.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(height: 9),
                                  itemBuilder: (context, index) =>
                                      _buildTeacherCard(
                                        filteredList[index],
                                        compact: false,
                                      ),
                                );
                              }

                              return GridView.builder(
                                physics: const AlwaysScrollableScrollPhysics(
                                  parent: BouncingScrollPhysics(),
                                ),
                                padding: EdgeInsets.fromLTRB(
                                  horizontal,
                                  2,
                                  horizontal,
                                  24,
                                ),
                                itemCount: filteredList.length,
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: columns,
                                      crossAxisSpacing: 10,
                                      mainAxisSpacing: 10,
                                      mainAxisExtent: 126,
                                    ),
                                itemBuilder: (context, index) =>
                                    _buildTeacherCard(
                                      filteredList[index],
                                      compact: true,
                                    ),
                              );
                            },
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTrainerRegistrationButton({required bool isWeb}) {
    if (!isWeb) {
      return IconButton(
        tooltip: 'Trainer registration',
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(width: 34, height: 34),
        onPressed: () => Get.to(() => const RegisterAccountScreen()),
        icon: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: navy.withOpacity(.09),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: navy.withOpacity(.20)),
          ),
          child: const Icon(
            Icons.person_add_alt_1_rounded,
            color: navy,
            size: 17,
          ),
        ),
      );
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => Get.to(() => const RegisterAccountScreen()),
        borderRadius: BorderRadius.circular(9),
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 11),
          decoration: BoxDecoration(
            color: navy.withOpacity(.08),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: navy.withOpacity(.22)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.person_add_alt_1_rounded, color: navy, size: 16),
              const SizedBox(width: 6),
              Text(
                'Trainer Registration',
                style: GoogleFonts.poppins(
                  color: navy,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopToolbar({required bool isWeb}) {
    return Container(
      color: cardColor,
      padding: EdgeInsets.fromLTRB(isWeb ? 24 : 14, 12, isWeb ? 24 : 14, 10),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 650;

          final dateButton = Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _selectDate(context),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                height: 46,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: navy10,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: navy.withOpacity(.18)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.calendar_month_rounded,
                      color: navy,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      DateFormat('EEE, d MMM yyyy').format(selectedDate),
                      style: GoogleFonts.poppins(
                        color: textColor,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 5),
                    const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: secondaryText,
                      size: 18,
                    ),
                  ],
                ),
              ),
            ),
          );

          final countBadge = Container(
            height: 46,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: teal.withOpacity(.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: teal.withOpacity(.20)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.groups_rounded, color: navy, size: 18),
                const SizedBox(width: 7),
                Text(
                  '${teacherList.length} teachers',
                  style: GoogleFonts.poppins(
                    color: textColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          );

          if (compact) {
            return Column(
              children: [
                Row(
                  children: [
                    Expanded(child: dateButton),
                    const SizedBox(width: 8),
                    countBadge,
                  ],
                ),
              ],
            );
          }

          return Row(children: [dateButton, const Spacer(), countBadge]);
        },
      ),
    );
  }

  Widget _buildQuickTeacherFilters({required bool isWeb}) {
    return Container(
      color: cardColor,
      padding: EdgeInsets.fromLTRB(isWeb ? 24 : 14, 0, isWeb ? 24 : 14, 10),
      child: SizedBox(
        height: 48,
        child: ListView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          children: [
            _teacherQuickFilter(
              title: 'All Trainers',
              icon: Icons.groups_rounded,
              selected: selectedMode == 'All' && selectedLanguage == 'All',
              onTap: () => _applyTeacherFilter(mode: 'All', language: 'All'),
            ),
            _teacherQuickFilter(
              title: 'Online Trainers',
              icon: Icons.wifi_rounded,
              selected: selectedMode == 'Online',
              onTap: () => _applyTeacherFilter(mode: 'Online', language: 'All'),
            ),
            _teacherQuickFilter(
              title: 'Offline Trainers',
              icon: Icons.location_on_rounded,
              selected: selectedMode == 'Offline',
              onTap: () =>
                  _applyTeacherFilter(mode: 'Offline', language: 'All'),
            ),
            _teacherQuickFilter(
              title: 'English Trainers',
              icon: Icons.translate_rounded,
              selected: selectedLanguage == 'English',
              onTap: () =>
                  _applyTeacherFilter(mode: 'All', language: 'English'),
            ),
            _teacherQuickFilter(
              title: 'Hindi Trainers',
              icon: Icons.language_rounded,
              selected: selectedLanguage == 'Hindi',
              onTap: () => _applyTeacherFilter(mode: 'All', language: 'Hindi'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _teacherQuickFilter({
    required String title,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 7),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(11),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: selected ? navy : softSurface,
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: selected ? navy : borderColor),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: selected ? Colors.white : navy),
                const SizedBox(width: 6),
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    color: selected ? Colors.white : textColor,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _applyTeacherFilter({required String mode, required String language}) {
    setState(() {
      selectedMode = mode;
      selectedLanguage = language;
    });
    fetchTeacherAttendance();
  }

  Widget _buildStatusSummary({
    required int totalCount,
    required int presentCount,
    required int lateCount,
    required int absentCount,
    required bool isWeb,
  }) {
    return Padding(
      padding: EdgeInsets.fromLTRB(isWeb ? 24 : 14, 2, isWeb ? 24 : 14, 10),
      child: Row(
        children: [
          _statusCard(
            label: 'All',
            value: '$totalCount',
            icon: Icons.groups_rounded,
            color: navy,
            filter: 'all',
          ),
          const SizedBox(width: 8),
          _statusCard(
            label: 'Present',
            value: '$presentCount',
            icon: Icons.check_circle_rounded,
            color: success,
            filter: 'present',
          ),
          const SizedBox(width: 8),
          _statusCard(
            label: 'Late',
            value: '$lateCount',
            icon: Icons.schedule_rounded,
            color: const Color(0xFFC78B00),
            filter: 'late',
          ),
          const SizedBox(width: 8),
          _statusCard(
            label: 'Absent',
            value: '$absentCount',
            icon: Icons.cancel_rounded,
            color: error,
            filter: 'absent',
          ),
        ],
      ),
    );
  }

  Widget _statusCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    required String filter,
  }) {
    final selected = activeStatusFilter == filter;

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => setState(() => activeStatusFilter = filter),
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            constraints: const BoxConstraints(minHeight: 64),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
            decoration: BoxDecoration(
              color: selected ? color.withOpacity(.11) : cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected ? color : borderColor,
                width: selected ? 1.25 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 29,
                  height: 29,
                  decoration: BoxDecoration(
                    color: color.withOpacity(.10),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 15),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        value,
                        style: GoogleFonts.poppins(
                          color: textColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          color: secondaryText,
                          fontSize: 8.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 480),
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: navy10,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person_search_rounded,
                  color: navy,
                  size: 28,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'No trainer found',
                style: GoogleFonts.poppins(
                  color: textColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                'Try another trainer type, language, stage, date or attendance filter.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  color: secondaryText,
                  fontSize: 10.5,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTeacherCard(
    Map<String, dynamic> teacher, {
    required bool compact,
  }) {
    final String name = (teacher['teacherName'] ?? 'Unknown Teacher')
        .toString();
    final String phone = (teacher['teacherPhone'] ?? 'No Phone').toString();
    final String mode = (teacher['mode'] ?? 'offline').toString().toLowerCase();
    final String status = (teacher['status'] ?? 'Absent').toString();
    final String? markedTime = teacher['markedAtTime']?.toString();
    final int totalMinutes =
        int.tryParse((teacher['totalMinutes'] ?? 0).toString()) ?? 0;

    Color statusColor = success;
    if (status == 'Late' || status == 'Partial') {
      statusColor = const Color(0xFFC78B00);
    } else if (status == 'Absent') {
      statusColor = error;
    }

    final modeColor = mode == 'online' ? blue : const Color(0xFF8B6A00);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: borderColor),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08155A88),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 43,
            height: 43,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: mode == 'online'
                    ? [navy.withOpacity(.13), teal.withOpacity(.14)]
                    : [const Color(0xFFF7F0D8), const Color(0xFFFFF9E9)],
              ),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : 'T',
              style: GoogleFonts.poppins(
                color: modeColor,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          color: textColor,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    _badge(mode.toUpperCase(), modeColor),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  markedTime != null
                      ? 'Checked-in at $markedTime'
                      : mode == 'online'
                      ? 'Online class not started'
                      : 'Phone: $phone • Geofence pending',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    color: secondaryText,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _badge(
                      totalMinutes > 0 ? '$totalMinutes mins' : 'No duration',
                      totalMinutes > 0 ? success : secondaryText,
                    ),
                    if (mode == 'offline') ...[
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          phone,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            color: secondaryText,
                            fontSize: 8.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(.09),
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: statusColor.withOpacity(.25)),
            ),
            child: Text(
              status.toUpperCase(),
              style: GoogleFonts.poppins(
                color: statusColor,
                fontSize: 8.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 95),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(.09),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.poppins(
          color: color,
          fontSize: 7.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
