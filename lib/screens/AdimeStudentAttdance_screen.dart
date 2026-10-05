import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:get/get_navigation/src/extension_navigation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:lets_speake_manager/Api/ApiendPoints.dart';
import 'package:lets_speake_manager/Navigation/AdminShellNavigation.dart';

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
  String searchQuery = "";

  final TextEditingController searchController = TextEditingController();
  List<dynamic> combinedList = [];
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

  final List<String> batches = [
    "All",
    "5:30 AM - 7:00 AM",
    "7:00 AM - 8:30 AM",
    "9:00 AM - 10:30 AM",
    "10:30 AM - 12:00 PM",
    "3:30 PM - 5:00 PM",
    "5:00 PM - 6:30 PM",
    "6:30 PM - 8:00 PM",
  ];

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
    String batchParam = selectedBatch == "All" ? "all" : selectedBatch;
    String modeParam = selectedMode == "All" ? "all" : selectedMode;

    try {
      final url =
          "${ApiEndpoints.adminAttendance}?date=$dateStr&stage=$stageParam&batchTime=$batchParam&mode=$modeParam&language=$lang&role=student";
      final response = await http.get(Uri.parse(url));

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

      return matchQuery && matchStatus;
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
            border: Border(
              bottom: BorderSide(color: borderColor, width: 1),
            ),
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
                  gradient: const LinearGradient(
                    colors: [deepNavy, navy],
                  ),
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
                tooltip: 'Refresh attendance',
                onPressed: isLoading ? null : fetchAttendanceData,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                  minWidth: 42,
                  minHeight: 42,
                ),
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
                _buildMetrics(isWeb: isWeb),
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
              if (searchQuery.isNotEmpty || selectedStatus != 'All')
                Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: TextButton(
                    onPressed: () {
                      searchController.clear();
                      setState(() {
                        searchQuery = '';
                        selectedStatus = 'All';
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
    final String batch = (student['batchTime'] ?? 'N/A').toString();
    final String lang = (student['language'] ?? 'English').toString();

    Color statusColor = success;
    if (status == 'Partial' || status == 'Late') {
      statusColor = const Color(0xFFC78B00);
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
                    const SizedBox(width: 5),
                    _smallBadge(lang, navy),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  phone,
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
                              isOnline ? '$totalMins / 90 mins' : batch,
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
              status,
              style: GoogleFonts.poppins(
                color: statusColor,
                fontSize: 9,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
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