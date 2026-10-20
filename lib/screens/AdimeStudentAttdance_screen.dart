import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:lets_speake_manager/Api/ApiendPoints.dart';
import 'package:lets_speake_manager/Api/api_headers.dart';
import 'package:lets_speake_manager/Api/batch_slots.dart';
import 'package:lets_speake_manager/Navigation/AdminShellNavigation.dart';
import 'package:lets_speake_manager/screens/AttendanceReportScreen.dart';
import 'package:lets_speake_manager/screens/AdminHolidayScreen.dart';
import 'package:lets_speake_manager/screens/LeaderboardScreen.dart';

class AdimeStudentAttdance_screen extends StatefulWidget {
  const AdimeStudentAttdance_screen({super.key});

  @override
  State<AdimeStudentAttdance_screen> createState() =>
      _AdimeStudentAttdance_screenState();
}

class _AdimeStudentAttdance_screenState
    extends State<AdimeStudentAttdance_screen>
    with WidgetsBindingObserver {
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

  int selectedCategory = 0; // 0: All, 1: English, 2: Hindi, 3: Let's Club
  DateTime selectedDate = DateTime.now();
  String selectedStage = "All";
  String selectedBatch = "All";
  String selectedMode = "All";
  String selectedStatus = "All";
  String selectedPractice = "All"; // All | Practiced | Not practiced
  String searchQuery = "";

  final TextEditingController searchController = TextEditingController();
  List<dynamic> combinedList = [];
  List<dynamic> otherBatchList = []; // joined a class outside their own batch
  List<Map<String, dynamic>> batchSummary = []; // per timing: total / on time / late / absent / other
  Map<String, dynamic>? _holiday; // 🏖 selected date is a holiday (from batch-summary)
  bool isLoading = false;

  final List<String> stages = [
    "All",
    "Stage 1",
    "Stage 2",
    "Stage 3",
    "Stage 4",
    "Stage 5",
    "Stage 6",
    "Stage 7",
  ];

  // Same 7 timings as the student app (backend accepts these labels directly)
  final List<String> batches = ["All", ...BatchSlots.all.map((b) => b.label)];

  final List<String> modes = ["All", "Online", "Offline"];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // 🚀 Register lifecycle observer
    final now = DateTime.now();
    selectedDate = DateTime(now.year, now.month, now.day);
    fetchAttendanceData();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this); // 🚀 Clean up observer
    searchController.dispose();
    super.dispose();
  }

  // 🚀 Automatically re-fetches attendance data when coming back to screen/foreground
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      fetchAttendanceData(silent: true);
    }
  }

  Future<void> fetchAttendanceData({bool silent = false}) async {
    if (!mounted) return;
    if (!silent) setState(() => isLoading = true);

    String dateStr = DateFormat('d-M-yyyy').format(selectedDate);

    String lang = "all";
    if (selectedCategory == 1) lang = "English";
    if (selectedCategory == 2) lang = "Hindi";
    if (selectedCategory == 3) lang = "Club";

    String stageParam = selectedStage == "All" ? "all" : selectedStage;
    String batchParam = selectedBatch == "All"
        ? "all"
        : Uri.encodeQueryComponent(selectedBatch);
    String modeParam = selectedMode == "All" ? "all" : selectedMode;

    try {
      final url =
          "${ApiEndpoints.adminAttendance}?date=$dateStr&stage=$stageParam&batchTime=$batchParam&mode=$modeParam&language=$lang&role=student";
      final visitorsUrl =
          "${ApiEndpoints.adminAttendance.replaceFirst(RegExp(r'/attendance$'), '/batch-visitors')}?date=$dateStr&stage=$stageParam&language=$lang";
      final summaryUrl =
          "${ApiEndpoints.adminAttendance.replaceFirst(RegExp(r'/attendance$'), '/batch-summary')}?date=$dateStr&stage=$stageParam&language=$lang&mode=$modeParam";
      final results = await Future.wait([
        http.get(Uri.parse(url), headers: ApiHeaders.auth()),
        http.get(Uri.parse(visitorsUrl), headers: ApiHeaders.auth()),
        lang == "Club"
            ? Future.value(http.Response('{"batches":[]}', 200))
            : http.get(Uri.parse(summaryUrl), headers: ApiHeaders.auth()),
      ]);
      final response = results[0];
      try {
        final sm = results[2].statusCode == 200 ? jsonDecode(results[2].body) : null;
        _holiday = (sm is Map && sm['holiday'] is Map) ? Map<String, dynamic>.from(sm['holiday']) : null;
        final List bl = (sm is Map && sm['batches'] is List) ? sm['batches'] : [];
        batchSummary = bl
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .where((b) {
              final c = Map<String, dynamic>.from(b['counts'] ?? {});
              return _n(c['total']) > 0 || _n(c['fromOther']) > 0;
            })
            .toList();
      } catch (_) {
        batchSummary = [];
      }
      if (results[1].statusCode == 200) {
        final v = jsonDecode(results[1].body);
        otherBatchList = (v is Map && v['visitors'] is List)
            ? v['visitors']
            : [];
      } else {
        otherBatchList = [];
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            combinedList = data is List ? data : [];
            isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => isLoading = false);
      }
    } catch (e) {
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
              surface: Colors.white,
              onSurface: textColor,
            ),
            dialogBackgroundColor: const Color(0xFFFFFFFF),
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
      fetchAttendanceData();
    }
  }

  List<dynamic> get filteredStudents {
    return combinedList.where((s) {
      final name = (s['userName'] ?? s['name'] ?? '').toString().toLowerCase();
      final phone = (s['userPhone'] ?? s['phone'] ?? '')
          .toString()
          .toLowerCase();
      final status = (s['status'] ?? 'Absent').toString();

      final matchQuery =
          searchQuery.isEmpty ||
          name.contains(searchQuery.toLowerCase().trim()) ||
          phone.contains(searchQuery.toLowerCase().trim());

      final matchStatus =
          selectedStatus == "All" ||
          (selectedStatus == "Partial/Late"
              ? (status == "Partial" || status == "Late")
              : status == selectedStatus);

      final practiced = s['practiced'] == true;
      final matchPractice =
          selectedPractice == "All" ||
          (selectedPractice == "Practiced" ? practiced : !practiced);

      return matchQuery && matchStatus && matchPractice;
    }).toList();
  }

  int get totalCount => combinedList.length;
  int get presentCount =>
      combinedList.where((s) => s['status'] == 'Present').length;
  int get partialCount => combinedList
      .where((s) => s['status'] == 'Partial' || s['status'] == 'Late')
      .length;
  int get absentCount =>
      combinedList.where((s) => s['status'] == 'Absent').length;
  // 🎤 Speaking practice marked by the trainer in the live class
  int get practicedCount =>
      combinedList.where((s) => s['practiced'] == true).length;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isWeb = width >= 900;
    final isTablet = width >= 600 && width < 900;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(isWeb ? 60 : 54),
        child: Container(
          height: isWeb ? 60 : 54,
          decoration: const BoxDecoration(
            color: cardColor,
            border: Border(bottom: BorderSide(color: borderColor, width: 1)),
          ),
          child: Row(
            children: [
              SizedBox(
                width: isWeb ? 58 : 50,
                child: Center(
                  child: IconButton(
                    tooltip: 'Menu',
                    onPressed: _openAdminDrawerOrBack,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 42,
                      minHeight: 42,
                    ),
                    splashRadius: 20,
                    icon: const Icon(
                      Icons.menu_rounded,
                      color: textColor,
                      size: 25,
                    ),
                  ),
                ),
              ),
              Container(
                width: isWeb ? 38 : 34,
                height: isWeb ? 38 : 34,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [deepNavy, navy]),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(
                  Icons.fact_check_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Student Attendance',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        color: textColor,
                        fontSize: isWeb ? 18 : 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (isWeb)
                      Text(
                        'Monitor daily attendance and student status',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          color: secondaryText,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Holidays',
                onPressed: () async {
                  await Get.to(() => const AdminHolidayScreen());
                  fetchAttendanceData(silent: true);
                },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 42, minHeight: 42),
                splashRadius: 20,
                icon: const Icon(Icons.beach_access_rounded, color: Color(0xFF7A5AF8), size: 22),
              ),
              IconButton(
                tooltip: 'Leaderboard',
                onPressed: () =>
                    Get.to(() => const LeaderboardScreen(role: 'student')),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 42, minHeight: 42),
                splashRadius: 20,
                icon: const Icon(
                  Icons.emoji_events_rounded,
                  color: Color(0xFFE3B21B),
                  size: 23,
                ),
              ),
              IconButton(
                tooltip: 'Refresh attendance',
                onPressed: isLoading ? null : fetchAttendanceData,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 42, minHeight: 42),
                splashRadius: 20,
                icon: const Icon(
                  Icons.refresh_rounded,
                  color: textColor,
                  size: 23,
                ),
              ),
              SizedBox(width: isWeb ? 8 : 4),
            ],
          ),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1400),
            child: Column(
              children: [
                _buildToolbar(isWeb: isWeb, isTablet: isTablet),
                _buildFilterBar(isWeb: isWeb, isTablet: isTablet),
                _buildCategoryTabs(isWeb: isWeb),
                _buildHolidayBanner(isWeb: isWeb),
                _buildMetrics(isWeb: isWeb),
                _buildPracticeBar(isWeb: isWeb),
                _buildBatchSummaryStrip(isWeb: isWeb),
                _buildOtherBatchBanner(isWeb: isWeb),
                Expanded(
                  child: _buildStudentContent(isWeb: isWeb, isTablet: isTablet),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildToolbar({required bool isWeb, required bool isTablet}) {
    return Container(
      color: cardColor,
      padding: EdgeInsets.fromLTRB(isWeb ? 24 : 14, 12, isWeb ? 24 : 14, 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 620;

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

          final search = SizedBox(
            height: 46,
            child: TextField(
              controller: searchController,
              onChanged: (value) => setState(() => searchQuery = value),
              style: GoogleFonts.poppins(
                color: textColor,
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                hintText: 'Search students by name or phone...',
                hintStyle: GoogleFonts.poppins(
                  color: secondaryText,
                  fontSize: 11,
                ),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: navy,
                  size: 19,
                ),
                suffixIcon: searchQuery.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        onPressed: () {
                          searchController.clear();
                          setState(() => searchQuery = '');
                        },
                        icon: const Icon(
                          Icons.close_rounded,
                          color: secondaryText,
                          size: 17,
                        ),
                      ),
                filled: true,
                fillColor: softSurface,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: borderColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: navy, width: 1.2),
                ),
              ),
            ),
          );

          if (compact) {
            return Column(
              children: [
                Row(
                  children: [
                    Expanded(child: dateButton),
                    const SizedBox(width: 8),
                    Container(
                      height: 46,
                      width: 46,
                      decoration: BoxDecoration(
                        color: teal.withOpacity(.10),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        tooltip: 'Refresh',
                        onPressed: isLoading ? null : fetchAttendanceData,
                        icon: const Icon(
                          Icons.refresh_rounded,
                          color: navy,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 9),
                search,
              ],
            );
          }

          return Row(
            children: [
              dateButton,
              const SizedBox(width: 12),
              Expanded(child: search),
              const SizedBox(width: 10),
              Container(
                height: 46,
                width: 46,
                decoration: BoxDecoration(
                  color: teal.withOpacity(.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  tooltip: 'Refresh',
                  onPressed: isLoading ? null : fetchAttendanceData,
                  icon: const Icon(
                    Icons.refresh_rounded,
                    color: navy,
                    size: 20,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFilterBar({required bool isWeb, required bool isTablet}) {
    return Container(
      color: cardColor,
      padding: EdgeInsets.fromLTRB(isWeb ? 24 : 14, 0, isWeb ? 24 : 14, 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 620;

          final stage = _buildFilterDropdown(
            label: 'Stage',
            value: selectedStage,
            items: stages,
            icon: Icons.layers_rounded,
            onChanged: (value) {
              if (value != null) {
                setState(() => selectedStage = value);
                fetchAttendanceData();
              }
            },
          );

          final batch = _buildFilterDropdown(
            label: 'Batch',
            value: selectedBatch,
            items: batches,
            icon: Icons.schedule_rounded,
            onChanged: (value) {
              if (value != null) {
                setState(() => selectedBatch = value);
                fetchAttendanceData();
              }
            },
          );

          final mode = _buildFilterDropdown(
            label: 'Mode',
            value: selectedMode,
            items: modes,
            icon: Icons.wifi_rounded,
            onChanged: (value) {
              if (value != null) {
                setState(() => selectedMode = value);
                fetchAttendanceData();
              }
            },
          );

          if (compact) {
            return Column(
              children: [
                Row(
                  children: [
                    Expanded(child: stage),
                    const SizedBox(width: 8),
                    Expanded(child: mode),
                  ],
                ),
                const SizedBox(height: 8),
                batch,
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: stage),
              const SizedBox(width: 10),
              Expanded(flex: 2, child: batch),
              const SizedBox(width: 10),
              Expanded(child: mode),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFilterDropdown({
    required String label,
    required String value,
    required List<String> items,
    required IconData icon,
    required ValueChanged<String?> onChanged,
  }) {
    final currentValue = items.contains(value) ? value : items.first;

    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: softSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: navy10,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: navy, size: 16),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: currentValue,
                isExpanded: true,
                dropdownColor: Colors.white,
                icon: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: secondaryText,
                  size: 19,
                ),
                style: GoogleFonts.poppins(
                  color: textColor,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                ),
                items: items.map((item) {
                  return DropdownMenuItem<String>(
                    value: item,
                    child: Text(
                      item,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        color: textColor,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                }).toList(),
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryTabs({required bool isWeb}) {
    return Container(
      color: cardColor,
      padding: EdgeInsets.fromLTRB(isWeb ? 24 : 14, 0, isWeb ? 24 : 14, 10),
      child: SizedBox(
        height: 44,
        child: ListView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          children: [
            _buildCategoryTab(0, 'All Students'),
            _buildCategoryTab(1, 'English Class'),
            _buildCategoryTab(2, 'Hindi Class'),
            _buildCategoryTab(3, "Let's Club"),
          ],
        ),
      ),
    );
  }

  Widget _buildMetrics({required bool isWeb}) {
    return Padding(
      padding: EdgeInsets.fromLTRB(isWeb ? 24 : 14, 4, isWeb ? 24 : 14, 10),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 500;

          final cards = [
            _buildMetricCard(
              'Total',
              '$totalCount',
              navy10,
              'All',
              Icons.people_alt_rounded,
              navy,
            ),
            _buildMetricCard(
              'Present',
              '$presentCount',
              success.withOpacity(.10),
              'Present',
              Icons.check_circle_rounded,
              success,
            ),
            _buildMetricCard(
              'Partial / Late',
              '$partialCount',
              warning.withOpacity(.13),
              'Partial/Late',
              Icons.schedule_rounded,
              const Color(0xFFC78B00),
            ),
            _buildMetricCard(
              'Absent',
              '$absentCount',
              error.withOpacity(.10),
              'Absent',
              Icons.cancel_rounded,
              error,
            ),
          ];

          if (compact) {
            return Row(
              children: [
                Expanded(child: cards[0]),
                const SizedBox(width: 6),
                Expanded(child: cards[1]),
                const SizedBox(width: 6),
                Expanded(child: cards[2]),
                const SizedBox(width: 6),
                Expanded(child: cards[3]),
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: cards[0]),
              const SizedBox(width: 10),
              Expanded(child: cards[1]),
              const SizedBox(width: 10),
              Expanded(child: cards[2]),
              const SizedBox(width: 10),
              Expanded(child: cards[3]),
            ],
          );
        },
      ),
    );
  }

  /// 🎤 Speaking practice filter: who practiced in the live class today
  Widget _buildPracticeBar({required bool isWeb}) {
    if (combinedList.isEmpty) return const SizedBox.shrink();
    final int notPracticed = totalCount - practicedCount;

    Widget chip(
      String key,
      String label,
      int count,
      Color color,
      IconData icon,
    ) {
      final bool selected = selectedPractice == key;
      return Padding(
        padding: const EdgeInsets.only(right: 7),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => setState(() => selectedPractice = key),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: selected ? color : cardColor,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: selected ? color : borderColor),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 14, color: selected ? Colors.white : color),
                  const SizedBox(width: 5),
                  Text(
                    '$label  $count',
                    style: GoogleFonts.poppins(
                      color: selected ? Colors.white : textColor,
                      fontSize: 10.5,
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

    return Padding(
      padding: EdgeInsets.fromLTRB(isWeb ? 24 : 14, 0, isWeb ? 24 : 14, 10),
      child: SizedBox(
        height: 36,
        child: ListView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Center(
                child: Text(
                  'Speaking practice',
                  style: GoogleFonts.poppins(
                    color: secondaryText,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            chip('All', 'All', totalCount, navy, Icons.people_alt_rounded),
            chip(
              'Practiced',
              'Practiced',
              practicedCount,
              success,
              Icons.record_voice_over_rounded,
            ),
            chip(
              'Not practiced',
              'Not practiced',
              notPracticed,
              error,
              Icons.voice_over_off,
            ),
          ],
        ),
      ),
    );
  }

  String _fmtTime(dynamic iso) {
    if (iso == null) return '';
    try {
      return DateFormat('hh:mm a').format(DateTime.parse(iso.toString()).toLocal());
    } catch (_) {
      return '';
    }
  }

  int _n(dynamic v) {
    if (v is int) return v;
    if (v is double) return v.toInt();
    return int.tryParse('${v ?? ''}') ?? 0;
  }

  // =====================================================================
  // ⏰ BATCH-WISE SUMMARY STRIP — one chip per timing (attended / total),
  // tap → on time / late / absent / from other timing / joined other timing
  // =====================================================================
  Widget _buildBatchSummaryStrip({required bool isWeb}) {
    if (batchSummary.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.fromLTRB(isWeb ? 24 : 14, 0, isWeb ? 24 : 14, 10),
      child: SizedBox(
        height: 62,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: batchSummary.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, i) {
            final b = batchSummary[i];
            final c = Map<String, dynamic>.from(b['counts'] ?? {});
            final total = _n(c['total']);
            final attended = _n(c['attended']);
            final late = _n(c['late']) + _n(c['partial']);
            final absent = _n(c['absent']);
            final other = _n(c['fromOther']) + _n(c['elsewhere']);
            return InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => _openBatchSheet(b),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: borderColor),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.schedule_rounded, size: 13, color: navy),
                        const SizedBox(width: 4),
                        Text(
                          BatchSlots.shortOf(b['batch'], fallback: 'No timing'),
                          style: GoogleFonts.poppins(
                            color: textColor,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '$attended/$total',
                          style: GoogleFonts.poppins(
                            color: teal,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '$late late • $absent absent${other > 0 ? ' • $other other timing' : ''}',
                      style: GoogleFonts.poppins(
                        color: secondaryText,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _openBatchSheet(Map<String, dynamic> b) {
    List<Map<String, dynamic>> listOf(String key) => ((b[key] as List?) ?? [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    final c = Map<String, dynamic>.from(b['counts'] ?? {});
    final label = BatchSlots.shortOf(b['batch'], fallback: 'No timing');

    final sections = <List<dynamic>>[
      ['On time', listOf('present'), success, Icons.check_circle_rounded],
      ['Late', [...listOf('late'), ...listOf('partial')], const Color(0xFFC78B00), Icons.schedule_rounded],
      ['Absent', listOf('absent'), error, Icons.cancel_rounded],
      ['Came from another timing', listOf('fromOther'), blue, Icons.login_rounded],
      ['Attended another timing (counted)', listOf('elsewhere'), navy, Icons.swap_horiz_rounded],
    ];

    Widget stat(String t, int v, Color col) => Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: col.withOpacity(.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Text(
                  '$v',
                  style: GoogleFonts.poppins(
                    color: col,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  t,
                  style: GoogleFonts.poppins(color: secondaryText, fontSize: 9.5),
                ),
              ],
            ),
          ),
        );

    Get.bottomSheet(
      Container(
        constraints: BoxConstraints(maxHeight: Get.height * .82),
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
        decoration: const BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: borderColor,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '$label batch',
              style: GoogleFonts.poppins(
                color: textColor,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              '${DateFormat('d MMM yyyy').format(selectedDate)} • ${_n(c['attended'])} of ${_n(c['total'])} attended',
              style: GoogleFonts.poppins(color: secondaryText, fontSize: 10.5),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                stat('On time', _n(c['present']), success),
                const SizedBox(width: 6),
                stat('Late', _n(c['late']) + _n(c['partial']), const Color(0xFFC78B00)),
                const SizedBox(width: 6),
                stat('Absent', _n(c['absent']), error),
                const SizedBox(width: 6),
                stat('Other', _n(c['fromOther']) + _n(c['elsewhere']), blue),
              ],
            ),
            const SizedBox(height: 6),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final sec in sections)
                    if ((sec[1] as List).isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.only(top: 12, bottom: 6),
                        child: Row(
                          children: [
                            Icon(sec[3] as IconData, size: 16, color: sec[2] as Color),
                            const SizedBox(width: 6),
                            Text(
                              '${sec[0]} • ${(sec[1] as List).length}',
                              style: GoogleFonts.poppins(
                                color: sec[2] as Color,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      for (final p in (sec[1] as List).cast<Map<String, dynamic>>())
                        _batchPersonRow(p, sec[0] as String),
                    ],
                ],
              ),
            ),
          ],
        ),
      ),
      isScrollControlled: true,
    );
  }

  Widget _batchPersonRow(Map<String, dynamic> p, String group) {
    final name = (p['name'] ?? 'Student').toString();
    final phone = (p['phone'] ?? '').toString();
    final mins = _n(p['minutes']);
    String detail;
    if (group.startsWith('Came from')) {
      detail = 'Own: ${BatchSlots.shortOf(p['ownBatch'], fallback: 'not set')}';
    } else if (group.startsWith('Attended another')) {
      detail = 'Joined ${BatchSlots.shortOf(p['joinedBatch'], fallback: 'another timing')}';
    } else if (group == 'Absent') {
      detail = 'Not joined';
    } else {
      detail = '$mins mins';
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          CircleAvatar(
            radius: 15,
            backgroundColor: navy10,
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : 'S',
              style: GoogleFonts.poppins(
                color: navy,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    color: textColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (phone.isNotEmpty)
                  Text(
                    phone,
                    style: GoogleFonts.poppins(color: secondaryText, fontSize: 9.5),
                  ),
              ],
            ),
          ),
          Text(
            detail,
            style: GoogleFonts.poppins(color: secondaryText, fontSize: 10.5),
          ),
        ],
      ),
    );
  }

  /// ⚠️ Students who joined a class outside their own batch time
  Widget _buildOtherBatchBanner({required bool isWeb}) {
    if (otherBatchList.isEmpty) return const SizedBox.shrink();
    final int n = otherBatchList.length;
    return Padding(
      padding: EdgeInsets.fromLTRB(isWeb ? 24 : 14, 0, isWeb ? 24 : 14, 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(13),
          onTap: _openOtherBatchSheet,
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF4E5),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: warning.withOpacity(.55)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.swap_horiz_rounded,
                  color: Color(0xFFC78B00),
                  size: 20,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    '$n ${n == 1 ? 'student' : 'students'} joined a different batch — not counted as attendance',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      color: textColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'View',
                  style: GoogleFonts.poppins(
                    color: navy,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: navy, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openOtherBatchSheet() {
    String fmtTime(dynamic v) {
      if (v == null) return '';
      try {
        return DateFormat(
          'hh:mm a',
        ).format(DateTime.parse(v.toString()).toLocal());
      } catch (_) {
        return '';
      }
    }

    Get.bottomSheet(
      Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .8,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 4,
                margin: const EdgeInsets.only(top: 10, bottom: 12),
                decoration: BoxDecoration(
                  color: borderColor,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 6),
                child: Row(
                  children: [
                    const Icon(
                      Icons.swap_horiz_rounded,
                      color: Color(0xFFC78B00),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Joined another batch',
                            style: GoogleFonts.poppins(
                              color: textColor,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            '${DateFormat('d MMM yyyy').format(selectedDate)} • attendance counted, joined another timing',
                            style: GoogleFonts.poppins(
                              color: secondaryText,
                              fontSize: 10.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(14, 6, 14, 16),
                  itemCount: otherBatchList.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final v = otherBatchList[i];
                    final name = (v['userName'] ?? 'Student').toString();
                    final phone = (v['userPhone'] ?? '').toString();
                    final own = BatchSlots.shortOf(
                      v['ownBatch'],
                      fallback: 'Not set',
                    );
                    final joinedRaw = (v['joinedBatch'] ?? '').toString();
                    final joined = BatchSlots.shortOf(
                      joinedRaw,
                      fallback: joinedRaw,
                    );
                    final time = fmtTime(v['joinedAt']);
                    final stage = (v['stage'] ?? '').toString().toUpperCase();
                    final lang = (v['language'] ?? '').toString();
                    final count = int.tryParse('${v['joinCount'] ?? 1}') ?? 1;
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: softSurface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: borderColor),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
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
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              _smallBadge('$lang • $stage', navy),
                            ],
                          ),
                          if (phone.isNotEmpty)
                            Text(
                              phone,
                              style: GoogleFonts.poppins(
                                color: secondaryText,
                                fontSize: 10,
                              ),
                            ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: _batchBox('Own batch', own, success),
                              ),
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 6),
                                child: Icon(
                                  Icons.arrow_forward_rounded,
                                  size: 16,
                                  color: secondaryText,
                                ),
                              ),
                              Expanded(
                                child: _batchBox('Joined', joined, error),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${time.isNotEmpty ? 'At $time' : ''}${count > 1 ? ' • joined $count times' : ''}',
                            style: GoogleFonts.poppins(
                              color: secondaryText,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      isScrollControlled: true,
    );
  }

  Widget _batchBox(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              color: secondaryText,
              fontSize: 9,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              color: color,
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  // 🏖 holiday banner for the selected date
  Widget _buildHolidayBanner({required bool isWeb}) {
    String? title = _holiday?['title']?.toString();
    title ??= combinedList
        .map((s) => (s['holiday'] ?? '').toString())
        .firstWhere((t) => t.isNotEmpty, orElse: () => '');
    if (title == null || title.isEmpty) return const SizedBox.shrink();
    final who = (_holiday?['appliesTo'] ?? 'all').toString();
    return Container(
      width: double.infinity,
      margin: EdgeInsets.fromLTRB(isWeb ? 24 : 14, 4, isWeb ? 24 : 14, 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF1EDFF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF7A5AF8).withOpacity(.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.beach_access_rounded, color: Color(0xFF7A5AF8), size: 20),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              '$title — holiday${who == 'trainers' ? ' (trainers only)' : ''}. Students who did not come are shown as Holiday, not Absent. Anyone who joined is still counted.',
              style: GoogleFonts.poppins(color: const Color(0xFF4A3AA8), fontSize: 10.5, fontWeight: FontWeight.w600, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }

  /// ⏱️ Every join / leave of today: "05:34 AM → 05:50 AM (16 min)"
  void _showTimeline(String name, dynamic student) {
    final List raw = student['sessions'] is List ? student['sessions'] : const [];
    final bool isOnline = (student['userMode'] ?? student['mode'] ?? '').toString().toLowerCase() == 'online';
    final String inTime = _fmtTime(student['joinedAt'] ?? student['firstJoinAt'] ?? student['markedAt']);
    final int lateBy = _n(student['lateByMinutes']);
    final int total = _n(student['totalMinutesSpent'] ?? student['totalMinutes']);
    final String batch = BatchSlots.shortOf(
      (student['studentBatch']?.toString().isNotEmpty == true) ? student['studentBatch'] : student['batchTime'],
      fallback: '',
    );

    DateTime? parse(dynamic v) {
      if (v == null) return null;
      try {
        return DateTime.parse(v.toString()).toLocal();
      } catch (_) {
        return null;
      }
    }

    final rows = <Widget>[];
    for (var i = 0; i < raw.length; i++) {
      final m = raw[i] is Map ? raw[i] as Map : const {};
      final a = parse(m['in']);
      final b = parse(m['out']);
      if (a == null) continue;
      final mins = (b ?? DateTime.now()).difference(a).inMinutes;
      rows.add(Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: navy.withOpacity(.10), shape: BoxShape.circle),
              child: Text('${i + 1}', style: GoogleFonts.poppins(color: navy, fontSize: 10, fontWeight: FontWeight.w800)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '${DateFormat('hh:mm a').format(a)}  →  ${b == null ? 'still in class' : DateFormat('hh:mm a').format(b)}',
                style: GoogleFonts.poppins(color: textColor, fontSize: 12.5, fontWeight: FontWeight.w600),
              ),
            ),
            Text('$mins min', style: GoogleFonts.poppins(color: secondaryText, fontSize: 11, fontWeight: FontWeight.w600)),
          ],
        ),
      ));
    }

    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 22),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(width: 40, height: 4, decoration: BoxDecoration(color: borderColor, borderRadius: BorderRadius.circular(4))),
              ),
              const SizedBox(height: 14),
              Text(name, style: GoogleFonts.poppins(color: textColor, fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(
                [
                  if (batch.isNotEmpty) 'Class $batch',
                  if (inTime.isNotEmpty) '${isOnline ? 'First joined' : 'GPS check-in'} $inTime',
                  lateBy > 0 ? '$lateBy min late' : 'on time',
                  if (isOnline) '$total min in class',
                ].join(' • '),
                style: GoogleFonts.poppins(color: lateBy > 0 ? const Color(0xFFC78B00) : success, fontSize: 11.5, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 14),
              if (!isOnline)
                Text('Offline class — attendance is the GPS check-in time (minutes are not counted).',
                    style: GoogleFonts.poppins(color: secondaryText, fontSize: 11.5))
              else if (rows.isEmpty)
                Text('No join/leave details for this day.', style: GoogleFonts.poppins(color: secondaryText, fontSize: 11.5))
              else ...[
                Text('In class', style: GoogleFonts.poppins(color: secondaryText, fontSize: 11, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                ...rows,
              ],
            ],
          ),
        ),
      ),
      isScrollControlled: true,
    );
  }

  void _showPracticeInfo(String name, dynamic student) {
    final bool practiced = student['practiced'] == true;
    String detail = '$name has not done speaking practice in this class today.';
    if (practiced) {
      final trainer = (student['practiceTrainer'] ?? '').toString();
      String time = '';
      final at = student['practicedAt'];
      if (at != null) {
        try {
          time = DateFormat(
            'hh:mm a',
          ).format(DateTime.parse(at.toString()).toLocal());
        } catch (_) {}
      }
      final int rating = _n(student['practiceRating']);
      final String note = (student['practiceNote'] ?? '').toString().trim();
      detail =
          '$name practiced${time.isNotEmpty ? ' at $time' : ''}'
          '${trainer.isNotEmpty ? ' with $trainer' : ''}.'
          '${rating > 0 ? '\nRating: ${'★' * rating}${'☆' * (5 - rating)} ($rating/5)' : '\nNot rated yet.'}'
          '${note.isNotEmpty ? '\nNote: $note' : ''}';
    }
    Get.snackbar(
      practiced ? 'Speaking practice done' : 'Not practiced yet',
      detail,
      backgroundColor: practiced ? success : const Color(0xFF8A9BA8),
      colorText: Colors.white,
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.all(14),
      duration: const Duration(seconds: 5),
    );
  }

  Widget _buildStudentContent({required bool isWeb, required bool isTablet}) {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: navy, strokeWidth: 2.5),
      );
    }

    if (filteredStudents.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      color: navy,
      backgroundColor: Colors.white,
      onRefresh: fetchAttendanceData,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 1150
              ? 3
              : constraints.maxWidth >= 720
              ? 2
              : 1;

          final horizontal = isWeb ? 24.0 : 14.0;

          if (columns == 1) {
            return ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              padding: EdgeInsets.fromLTRB(horizontal, 2, horizontal, 24),
              itemCount: filteredStudents.length,
              itemBuilder: (context, index) {
                return _buildStudentTile(
                  filteredStudents[index],
                  compact: false,
                );
              },
            );
          }

          return GridView.builder(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: EdgeInsets.fromLTRB(horizontal, 2, horizontal, 24),
            itemCount: filteredStudents.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              mainAxisExtent: 126,
            ),
            itemBuilder: (context, index) {
              return _buildStudentTile(filteredStudents[index], compact: true);
            },
          );
        },
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
                  Icons.event_busy_rounded,
                  color: navy,
                  size: 28,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'No attendance records',
                style: GoogleFonts.poppins(
                  color: textColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'No student attendance was found for ${DateFormat('d MMM yyyy').format(selectedDate)} with the current filters.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  color: secondaryText,
                  fontSize: 10.5,
                  height: 1.45,
                ),
              ),
              if (searchQuery.isNotEmpty ||
                  selectedStatus != 'All' ||
                  selectedPractice != 'All')
                Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: TextButton(
                    onPressed: () {
                      searchController.clear();
                      setState(() {
                        searchQuery = '';
                        selectedStatus = 'All';
                        selectedPractice = 'All';
                      });
                    },
                    child: Text(
                      'Clear filters',
                      style: GoogleFonts.poppins(
                        color: navy,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryTab(int index, String title) {
    final isSelected = selectedCategory == index;

    return Padding(
      padding: const EdgeInsets.only(right: 7),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() => selectedCategory = index);
            fetchAttendanceData();
          },
          borderRadius: BorderRadius.circular(11),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: isSelected ? navy : softSurface,
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: isSelected ? navy : borderColor),
            ),
            alignment: Alignment.center,
            child: Text(
              title,
              style: GoogleFonts.poppins(
                color: isSelected ? Colors.white : textColor,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                fontSize: 10.5,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMetricCard(
    String title,
    String count,
    Color color,
    String statusKey,
    IconData icon,
    Color iconColor,
  ) {
    final isSelected = selectedStatus == statusKey;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => setState(() => selectedStatus = statusKey),
        borderRadius: BorderRadius.circular(13),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          constraints: const BoxConstraints(minHeight: 68),
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
              color: isSelected ? iconColor : borderColor,
              width: isSelected ? 1.3 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(.72),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, color: iconColor, size: 16),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      count,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        color: textColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      title,
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
    );
  }

  Widget _buildStudentTile(dynamic student, {required bool compact}) {
    final String name = (student['userName'] ?? student['name'] ?? 'Unknown')
        .toString();
    final String phone =
        (student['userPhone'] ?? student['phone'] ?? 'No Phone').toString();
    final String mode = (student['userMode'] ?? student['mode'] ?? 'offline')
        .toString()
        .toUpperCase();
    final bool isOnline = mode == 'ONLINE';
    final String status = (student['status'] ?? 'Absent').toString();
    final int totalMins =
        int.tryParse(
          (student['totalMinutesSpent'] ?? student['totalMinutes'] ?? 0)
              .toString(),
        ) ??
        0;
    // The timing the student chose (falls back to the record's own batch)
    final String batch = BatchSlots.shortOf(
      (student['studentBatch']?.toString().isNotEmpty == true)
          ? student['studentBatch']
          : student['batchTime'],
      fallback: 'No timing',
    );
    final String lang = (student['language'] ?? 'English').toString();
    final bool practiced = student['practiced'] == true;
    final int rating = _n(student['practiceRating']);
    // ⏱️ First join (online) / GPS check-in time (offline)
    final String inTime = _fmtTime(student['joinedAt'] ?? student['firstJoinAt'] ?? student['markedAt']);
    final bool liveNow = student['inClassNow'] == true;
    // ⏰ minutes after the on-time limit (class start + 7 min)
    final int lateBy = _n(student['lateByMinutes']);
    final String arrival = inTime.isEmpty ? '' : (lateBy > 0 ? ' • ${lateBy}m late' : ' • on time');

    Color statusColor = success;
    if (status == 'Partial' || status == 'Late') {
      statusColor = const Color(0xFFC78B00);
    } else if (status == 'Holiday') {
      statusColor = const Color(0xFF7A5AF8);
    } else if (status == 'Absent') {
      statusColor = error;
    }

    final modeColor = isOnline ? blue : const Color(0xFF8B6A00);

    return Container(
      margin: compact ? EdgeInsets.zero : const EdgeInsets.only(bottom: 9),
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
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isOnline
                    ? [navy.withOpacity(.12), teal.withOpacity(.12)]
                    : [const Color(0xFFF7F0D8), const Color(0xFFFFF9E9)],
              ),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : 'U',
              style: GoogleFonts.poppins(
                color: isOnline ? navy : const Color(0xFF8B6A00),
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
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
                    if (student['otherBatch'] == true ||
                        (student['otherBatchJoin'] ?? '')
                            .toString()
                            .isNotEmpty) ...[
                      const SizedBox(width: 5),
                      _smallBadge(
                        'Joined ${BatchSlots.shortOf(student['joinedBatch'] ?? student['otherBatchJoin'], fallback: 'other timing')}',
                        const Color(0xFFC78B00),
                      ),
                    ],
                    const SizedBox(width: 5),
                    _smallBadge(lang, navy),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        phone,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          color: secondaryText,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 5),
                    InkWell(
                      borderRadius: BorderRadius.circular(6),
                      onTap: () => _showPracticeInfo(name, student),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: (practiced ? success : secondaryText)
                              .withOpacity(.10),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              practiced
                                  ? Icons.record_voice_over_rounded
                                  : Icons.voice_over_off,
                              size: 11,
                              color: practiced ? success : secondaryText,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              practiced
                                  ? (rating > 0 ? 'Practiced ★$rating' : 'Practiced')
                                  : 'No practice',
                              style: GoogleFonts.poppins(
                                color: practiced ? success : secondaryText,
                                fontSize: 7.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                InkWell(
                  borderRadius: BorderRadius.circular(6),
                  onTap: inTime.isEmpty ? null : () => _showTimeline(name, student),
                  child: Row(
                  children: [
                    _smallBadge(mode, modeColor),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.schedule_rounded,
                            size: 12,
                            color: totalMins > 0 ? success : secondaryText,
                          ),
                          const SizedBox(width: 3),
                          Flexible(
                            child: Text(
                              (isOnline ? '$totalMins/90m • $batch' : batch) +
                                  (inTime.isNotEmpty
                                      ? (isOnline ? ' • In $inTime' : ' • GPS $inTime')
                                      : '') +
                                  arrival +
                                  (status == 'Holiday' ? ' • ${student['holiday'] ?? 'Holiday'}' : '') +
                                  (liveNow ? ' • Live' : ''),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(
                                color: totalMins > 0 ? success : secondaryText,
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (inTime.isNotEmpty) ...[
                      const SizedBox(width: 4),
                      const Icon(Icons.timeline_rounded, size: 13, color: secondaryText),
                    ],
                  ],
                ),
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
              status,
              style: GoogleFonts.poppins(
                color: statusColor,
                fontSize: 9,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          SizedBox(
            width: 30,
            child: _reportMenu(
              userId: (student['userId'] ?? '').toString(),
              name: name,
              role: 'student',
            ),
          ),
        ],
      ),
    );
  }

  /// ⋮ menu → monthly calendar / yearly graph for this person
  Widget _reportMenu({
    required String userId,
    required String name,
    required String role,
  }) {
    return PopupMenuButton<String>(
      tooltip: 'Attendance report',
      padding: EdgeInsets.zero,
      icon: const Icon(Icons.more_vert_rounded, color: secondaryText, size: 20),
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (value) {
        if (userId.isEmpty) return;
        Get.to(
          () => AttendanceReportScreen(
            userId: userId,
            name: name,
            role: role,
            startWithYear: value == 'year',
          ),
        );
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          value: 'month',
          child: Row(
            children: [
              const Icon(Icons.calendar_month_rounded, color: navy, size: 18),
              const SizedBox(width: 10),
              Text(
                'Monthly attendance',
                style: GoogleFonts.poppins(
                  color: textColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'year',
          child: Row(
            children: [
              const Icon(Icons.bar_chart_rounded, color: navy, size: 18),
              const SizedBox(width: 10),
              Text(
                'Yearly graph',
                style: GoogleFonts.poppins(
                  color: textColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _smallBadge(String text, Color color) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 75),
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
