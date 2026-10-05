import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:lets_speake_manager/Api/ApiendPoints.dart';
import 'package:lets_speake_manager/Navigation/AdminShellNavigation.dart';

class AdminFeedbackScreen extends StatefulWidget {
  const AdminFeedbackScreen({super.key});

  @override
  State<AdminFeedbackScreen> createState() => _AdminFeedbackScreenState();
}

class _AdminFeedbackScreenState extends State<AdminFeedbackScreen>
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

  static const Color successGreen = Color(0xFF16A66A);
  static const Color alertRed = Color(0xFFE45757);
  static const Color warningOrange = Color(0xFFF2B84B);
  static final Color navy10 = navy.withOpacity(0.10);

  void _openAdminDrawerOrBack() {
    if (AdminShellNavigation.scaffoldKey.currentState != null) {
      AdminShellNavigation.openDrawer();
    } else {
      Get.back();
    }
  }

  final box = GetStorage();
  bool isLoading = true;
  List<dynamic> feedbackList = [];
  Timer? _autoRefreshTimer; // 🚀 Background auto-refresh timer

  String filterMode = "all"; // 'all', 'online', 'offline'
  DateTime? selectedDate; // null means 'All Dates'

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    fetchFeedbacks();

    // 🚀 Automatically check for new student feedback every 10 seconds in the background
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      fetchFeedbacks(silent: true);
    });
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      fetchFeedbacks(silent: true);
    }
  }

  Future<void> fetchFeedbacks({bool silent = false}) async {
    if (!silent && mounted) setState(() => isLoading = true);
    String? token = box.read('token');

    String queryParams = "?mode=$filterMode";
    if (selectedDate != null) {
      final String formattedDate = DateFormat(
        'yyyy-MM-dd',
      ).format(selectedDate!);
      queryParams += "&date=$formattedDate";
    }

    try {
      final response = await http.get(
        Uri.parse("${ApiEndpoints.feedbacks}$queryParams"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            feedbackList = data['feedbacks'] ?? [];
            isLoading = false;
          });
        }
      } else {
        if (mounted && !silent) setState(() => isLoading = false);
      }
    } catch (e) {
      debugPrint("Error fetching feedback: $e");
      if (mounted && !silent) setState(() => isLoading = false);
    }
  }

  Future<void> deleteFeedbackItem(String id) async {
    HapticFeedback.mediumImpact();
    String? token = box.read('token');
    try {
      final response = await http.delete(
        Uri.parse("${ApiEndpoints.feedbacks}/$id"),
        headers: {"Authorization": "Bearer $token"},
      );

      if (response.statusCode == 200) {
        setState(() {
          feedbackList.removeWhere((item) => item['_id'] == id);
        });
        Get.snackbar(
          "Removed",
          "Feedback review deleted successfully",
          backgroundColor: successGreen,
          colorText: Colors.white,
          snackPosition: SnackPosition.TOP,
          margin: const EdgeInsets.all(16),
          borderRadius: 12,
        );
      }
    } catch (e) {
      Get.snackbar(
        "Error",
        "Could not delete feedback: $e",
        backgroundColor: alertRed,
        colorText: Colors.white,
      );
    }
  }

  Future<void> _openCalendarPicker() async {
    HapticFeedback.selectionClick();
    final DateTime now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? now,
      firstDate: DateTime(2023),
      lastDate: DateTime(2030),
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
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => selectedDate = picked);
      fetchFeedbacks();
    }
  }

  double get averageRating {
    if (feedbackList.isEmpty) return 0.0;
    double total = 0;
    for (var f in feedbackList) {
      total += (f['rating'] as num? ?? 5).toDouble();
    }
    return total / feedbackList.length;
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isWeb = width >= 900;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(isWeb ? 60 : 54),
        child: Container(
          height: isWeb ? 60 : 54,
          decoration: const BoxDecoration(
            color: cardColor,
            border: Border(
              bottom: BorderSide(
                color: borderColor,
                width: 1,
              ),
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
                  color: navy,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(
                  Icons.rate_review_rounded,
                  color: Colors.white,
                  size: isWeb ? 20 : 18,
                ),
              ),
              SizedBox(width: isWeb ? 11 : 9),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Student Feedback',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        color: textColor,
                        fontSize: isWeb ? 18 : 15,
                        fontWeight: FontWeight.w700,
                        height: 1.05,
                      ),
                    ),
                    if (isWeb)
                      Text(
                        'Review student feedback and ratings',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          color: secondaryText,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w500,
                          height: 1.1,
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.only(right: isWeb ? 9 : 5),
                child: IconButton(
                  tooltip: 'Refresh feedback',
                  onPressed: () => fetchFeedbacks(),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 42,
                    minHeight: 42,
                  ),
                  splashRadius: 20,
                  icon: isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: navy,
                          ),
                        )
                      : const Icon(
                          Icons.refresh_rounded,
                          color: textColor,
                          size: 23,
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1250),
            child: Column(
              children: [
                _buildOverviewHeader(isWeb: isWeb),
                _buildFilterSection(isWeb: isWeb),
                Expanded(
                  child: isLoading && feedbackList.isEmpty
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: navy,
                            strokeWidth: 2.5,
                          ),
                        )
                      : feedbackList.isEmpty
                      ? _buildEmptyState()
                      : RefreshIndicator(
                          color: navy,
                          backgroundColor: Colors.white,
                          onRefresh: fetchFeedbacks,
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final columns = constraints.maxWidth >= 1150
                                  ? 2
                                  : 1;

                              final padding = EdgeInsets.fromLTRB(
                                isWeb ? 24 : 14,
                                2,
                                isWeb ? 24 : 14,
                                24,
                              );

                              if (columns == 1) {
                                return ListView.separated(
                                  physics: const AlwaysScrollableScrollPhysics(
                                    parent: BouncingScrollPhysics(),
                                  ),
                                  padding: padding,
                                  itemCount: feedbackList.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(height: 9),
                                  itemBuilder: (context, index) =>
                                      _buildFeedbackCard(
                                        feedbackList[index],
                                        compact: false,
                                      ),
                                );
                              }

                              return GridView.builder(
                                physics: const AlwaysScrollableScrollPhysics(
                                  parent: BouncingScrollPhysics(),
                                ),
                                padding: padding,
                                itemCount: feedbackList.length,
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 2,
                                      crossAxisSpacing: 10,
                                      mainAxisSpacing: 10,
                                      mainAxisExtent: 190,
                                    ),
                                itemBuilder: (context, index) =>
                                    _buildFeedbackCard(
                                      feedbackList[index],
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

  Widget _buildOverviewHeader({required bool isWeb}) {
    final rating = averageRating.clamp(0.0, 5.0);

    return Padding(
      padding: EdgeInsets.fromLTRB(isWeb ? 24 : 14, 12, isWeb ? 24 : 14, 10),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 620;

          final ratingCard = Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              children: [
                Container(
                  width: 43,
                  height: 43,
                  decoration: BoxDecoration(
                    color: yellow.withOpacity(.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.star_rounded,
                    color: Color(0xFFD29B00),
                    size: 25,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Average rating',
                        style: GoogleFonts.poppins(
                          color: secondaryText,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Row(
                        children: [
                          Text(
                            rating.toStringAsFixed(1),
                            style: GoogleFonts.poppins(
                              color: textColor,
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(width: 7),
                          ...List.generate(5, (index) {
                            final filled = index + 1 <= rating.floor();
                            final half =
                                !filled && index < rating && rating - index < 1;
                            return Icon(
                              half
                                  ? Icons.star_half_rounded
                                  : filled
                                  ? Icons.star_rounded
                                  : Icons.star_outline_rounded,
                              color: const Color(0xFFD29B00),
                              size: 14,
                            );
                          }),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );

          final reviewsCard = Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: navy10,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: navy.withOpacity(.16)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.forum_rounded, color: navy, size: 19),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${feedbackList.length}',
                      style: GoogleFonts.poppins(
                        color: navy,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'Reviews',
                      style: GoogleFonts.poppins(
                        color: secondaryText,
                        fontSize: 8.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );

          if (compact) {
            return Column(
              children: [
                Row(
                  children: [
                    Expanded(child: ratingCard),
                    const SizedBox(width: 8),
                    reviewsCard,
                  ],
                ),
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: ratingCard),
              const SizedBox(width: 10),
              reviewsCard,
            ],
          );
        },
      ),
    );
  }

  Widget _buildFilterSection({required bool isWeb}) {
    return Padding(
      padding: EdgeInsets.fromLTRB(isWeb ? 24 : 14, 0, isWeb ? 24 : 14, 10),
      child: Container(
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: borderColor),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 700;

            final dateButton = Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _openCalendarPicker,
                borderRadius: BorderRadius.circular(11),
                child: Container(
                  height: 45,
                  padding: const EdgeInsets.symmetric(horizontal: 11),
                  decoration: BoxDecoration(
                    color: selectedDate != null ? navy : softSurface,
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(
                      color: selectedDate != null ? navy : borderColor,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.calendar_month_rounded,
                        size: 17,
                        color: selectedDate != null ? Colors.white : navy,
                      ),
                      const SizedBox(width: 7),
                      Text(
                        selectedDate == null
                            ? 'All dates'
                            : DateFormat('d MMM yyyy').format(selectedDate!),
                        style: GoogleFonts.poppins(
                          color: selectedDate != null
                              ? Colors.white
                              : textColor,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );

            final quickDates = Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDatePill(
                  label: 'All',
                  isSelected: selectedDate == null,
                  onTap: () {
                    setState(() => selectedDate = null);
                    fetchFeedbacks();
                  },
                ),
                _buildDatePill(
                  label: 'Today',
                  isSelected: _isToday(selectedDate),
                  onTap: () {
                    setState(() => selectedDate = DateTime.now());
                    fetchFeedbacks();
                  },
                ),
                _buildDatePill(
                  label: 'Yesterday',
                  isSelected: _isYesterday(selectedDate),
                  onTap: () {
                    setState(
                      () => selectedDate = DateTime.now().subtract(
                        const Duration(days: 1),
                      ),
                    );
                    fetchFeedbacks();
                  },
                ),
              ],
            );

            final channelFilters = Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildFilterChip('All', 'all', navy),
                _buildFilterChip('Online', 'online', blue),
                _buildFilterChip('Offline', 'offline', const Color(0xFF9A7500)),
              ],
            );

            if (compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        dateButton,
                        const SizedBox(width: 7),
                        quickDates,
                      ],
                    ),
                  ),
                  const SizedBox(height: 9),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: channelFilters,
                  ),
                ],
              );
            }

            return Row(
              children: [
                dateButton,
                const SizedBox(width: 8),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: quickDates,
                  ),
                ),
                const SizedBox(width: 8),
                channelFilters,
              ],
            );
          },
        ),
      ),
    );
  }

  bool _isToday(DateTime? date) {
    if (date == null) return false;
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  bool _isYesterday(DateTime? date) {
    if (date == null) return false;
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return date.year == yesterday.year &&
        date.month == yesterday.month &&
        date.day == yesterday.day;
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 460),
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
                  Icons.rate_review_outlined,
                  color: navy,
                  size: 28,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'No feedback found',
                style: GoogleFonts.poppins(
                  color: textColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                selectedDate == null
                    ? 'No student reviews have been submitted yet.'
                    : 'No reviews were submitted on ${DateFormat('d MMM yyyy').format(selectedDate!)}.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  color: secondaryText,
                  fontSize: 10.5,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 14),
              TextButton.icon(
                onPressed: fetchFeedbacks,
                icon: const Icon(Icons.refresh_rounded, size: 17),
                label: Text(
                  'Refresh',
                  style: GoogleFonts.poppins(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeedbackCard(dynamic item, {required bool compact}) {
    final int rating = (item['rating'] as num? ?? 5).toInt();
    final String mode = (item['mode'] ?? 'online').toString().toUpperCase();
    final bool isOnline = mode == 'ONLINE';
    final String studentName = (item['name'] ?? 'Student').toString();
    final String phone = (item['phone'] ?? '').toString();
    final String comment = (item['comment'] ?? '').toString().trim();

    String dateStr = 'N/A';
    if (item['createdAt'] != null) {
      try {
        dateStr = DateFormat(
          'd MMM yyyy, hh:mm a',
        ).format(DateTime.parse(item['createdAt'].toString()).toLocal());
      } catch (_) {}
    }

    final modeColor = isOnline ? blue : const Color(0xFF9A7500);

    return Container(
      padding: const EdgeInsets.all(13),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: modeColor.withOpacity(.10),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  studentName.isNotEmpty ? studentName[0].toUpperCase() : 'S',
                  style: GoogleFonts.poppins(
                    color: modeColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      studentName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        color: textColor,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (phone.isNotEmpty)
                      Text(
                        phone,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          color: secondaryText,
                          fontSize: 8.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
              ),
              _modeBadge(mode, modeColor),
              const SizedBox(width: 3),
              IconButton(
                tooltip: 'Delete feedback',
                onPressed: () =>
                    _confirmDeleteFeedback(item['_id'].toString(), studentName),
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  color: alertRed,
                  size: 19,
                ),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              ...List.generate(5, (index) {
                return Icon(
                  index < rating
                      ? Icons.star_rounded
                      : Icons.star_outline_rounded,
                  color: const Color(0xFFD29B00),
                  size: 16,
                );
              }),
              const SizedBox(width: 7),
              Text(
                '$rating/5',
                style: GoogleFonts.poppins(
                  color: textColor,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: softSurface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              comment.isEmpty ? 'No written comment.' : comment,
              maxLines: compact ? 3 : 4,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                color: textColor,
                fontSize: 9.8,
                height: 1.45,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 7),
          Row(
            children: [
              const Icon(
                Icons.access_time_rounded,
                size: 12,
                color: secondaryText,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  dateStr,
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
          ),
        ],
      ),
    );
  }

  Widget _modeBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(.09),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: color.withOpacity(.18)),
      ),
      child: Text(
        text,
        style: GoogleFonts.poppins(
          color: color,
          fontSize: 7.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Future<void> _confirmDeleteFeedback(String id, String studentName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Delete feedback?',
            style: GoogleFonts.poppins(
              color: textColor,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Text(
            'Remove the feedback submitted by $studentName?',
            style: GoogleFonts.poppins(
              color: secondaryText,
              fontSize: 11,
              height: 1.4,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                'Cancel',
                style: GoogleFonts.poppins(
                  color: secondaryText,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: alertRed,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(9),
                ),
              ),
              child: Text(
                'Delete',
                style: GoogleFonts.poppins(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await deleteFeedbackItem(id);
    }
  }

  Widget _buildDatePill({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(9),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? navy : softSurface,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: isSelected ? navy : borderColor),
            ),
            child: Text(
              label,
              style: GoogleFonts.poppins(
                color: isSelected ? Colors.white : textColor,
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String mode, Color color) {
    final isSelected = filterMode == mode;

    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() => filterMode = mode);
            fetchFeedbacks();
          },
          borderRadius: BorderRadius.circular(9),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? color : softSurface,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: isSelected ? color : borderColor),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (mode == 'online')
                  const Icon(Icons.wifi_rounded, size: 13, color: Colors.white)
                else if (mode == 'offline')
                  const Icon(
                    Icons.location_on_rounded,
                    size: 13,
                    color: Colors.white,
                  ),
                if (mode != 'all') const SizedBox(width: 4),
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    color: isSelected ? Colors.white : textColor,
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
}