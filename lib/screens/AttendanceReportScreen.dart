import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:lets_speake_manager/Api/ApiendPoints.dart';
import 'package:lets_speake_manager/Api/api_headers.dart';
import 'package:lets_speake_manager/Api/batch_slots.dart';

/// Attendance (Monthly calendar • 3 months • 6 months • Yearly graph)
/// + for students: trainer's speaking-practice ratings (day & stage wise) and test results.
/// Works for trainers (salary) and students (progress).
///   Get.to(() => AttendanceReportScreen(userId: id, name: 'Venkat', role: 'teacher'));
class AttendanceReportScreen extends StatefulWidget {
  final String userId;
  final String name;
  final String role; // "teacher" | "student" | ...
  final bool startWithYear;

  const AttendanceReportScreen({
    super.key,
    required this.userId,
    required this.name,
    this.role = 'student',
    this.startWithYear = false,
  });

  @override
  State<AttendanceReportScreen> createState() => _AttendanceReportScreenState();
}

class _AttendanceReportScreenState extends State<AttendanceReportScreen> {
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

  static const Color presentColor = Color(0xFF16A66A);
  static const Color lateColor = Color(0xFFE0A21B);
  static const Color partialColor = Color(0xFF7CA4D8);
  static const Color absentColor = Color(0xFFE45757);
  static const Color holidayColor = Color(0xFFB8C7D3);

  static const List<String> monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  String period = 'month'; // month | 3m | 6m | year
  bool get showYear => period == 'year';
  bool get isRange => period == '3m' || period == '6m';
  late int year;
  late int month;

  bool isLoading = true;
  String? errorText;
  Map<String, dynamic>? report;

  bool get isTrainer => widget.role != 'student';

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    year = now.year;
    month = now.month;
    period = widget.startWithYear ? 'year' : 'month';
    _load();
  }

  Future<void> _load() async {
    setState(() {
      isLoading = true;
      errorText = null;
    });
    try {
      final res = await http.get(
        Uri.parse(
          "${ApiEndpoints.baseUrl}/attendance-report?userId=${widget.userId}&year=$year&month=$month&range=$period",
        ),
        headers: ApiHeaders.auth(),
      );
      if (!mounted) return;
      if (res.statusCode == 200) {
        setState(() {
          report = Map<String, dynamic>.from(jsonDecode(res.body));
          isLoading = false;
        });
      } else {
        String msg = "Could not load report (${res.statusCode})";
        try {
          final body = jsonDecode(res.body);
          if (body is Map && body['message'] != null) msg = body['message'].toString();
        } catch (_) {}
        setState(() {
          errorText = msg;
          isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        errorText = "Connection error. Check the server.";
        isLoading = false;
      });
    }
  }

  void _shiftMonth(int delta) {
    final total = year * 12 + (month - 1) + delta;
    final now = DateTime.now();
    final newYear = total ~/ 12;
    final newMonth = total % 12 + 1;
    if (newYear * 12 + newMonth > now.year * 12 + now.month) return; // no future months
    setState(() {
      year = newYear;
      month = newMonth;
    });
    _load();
  }

  void _shiftYear(int delta) {
    final now = DateTime.now();
    final newYear = year + delta;
    if (newYear > now.year || newYear < 2024) return;
    setState(() {
      year = newYear;
      if (year == now.year && month > now.month) month = now.month;
    });
    _load();
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Present':
        return presentColor;
      case 'Late':
        return lateColor;
      case 'Partial':
        return partialColor;
      case 'Absent':
        return absentColor;
      case 'Holiday':
        return holidayColor;
      default:
        return borderColor;
    }
  }

  // =========================================================
  // BUILD
  // =========================================================
  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isWeb = width >= 900;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: cardColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: isWeb ? 64 : 58,
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => Get.back(),
          icon: const Icon(Icons.arrow_back_rounded, color: textColor),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: navy.withOpacity(.10),
              child: Text(
                widget.name.trim().isNotEmpty ? widget.name.trim()[0].toUpperCase() : '?',
                style: GoogleFonts.poppins(color: navy, fontWeight: FontWeight.w800, fontSize: 14),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      color: textColor,
                      fontSize: isWeb ? 17 : 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    isTrainer ? 'Trainer attendance report' : 'Student attendance report',
                    style: GoogleFonts.poppins(color: secondaryText, fontSize: 10),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: isLoading ? null : _load,
            icon: const Icon(Icons.refresh_rounded, color: textColor),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: RefreshIndicator(
              color: navy,
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                padding: EdgeInsets.fromLTRB(isWeb ? 24 : 14, 14, isWeb ? 24 : 14, 28),
                children: [
                  _viewToggle(),
                  const SizedBox(height: 12),
                  _periodNavigator(),
                  const SizedBox(height: 12),
                  if (isLoading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 80),
                      child: Center(child: CircularProgressIndicator(color: navy, strokeWidth: 2.4)),
                    )
                  else if (errorText != null)
                    _errorBox()
                  else if (report != null) ...[
                    _summaryCards(_totals(), isWeb: isWeb),
                    const SizedBox(height: 12),
                    if (isTrainer) _payrollCard(_totals()),
                    if (isTrainer) const SizedBox(height: 12),
                    if (showYear)
                      _yearChart()
                    else if (isRange)
                      _yearChart(source: 'rangeMonths')
                    else
                      _calendar(isWeb: isWeb),
                    const SizedBox(height: 10),
                    _legend(),
                    if (!isTrainer) ...[
                      const SizedBox(height: 16),
                      _practiceCard(isWeb: isWeb),
                      const SizedBox(height: 12),
                      _testsCard(isWeb: isWeb),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // =========================================================
  // TOP CONTROLS
  // =========================================================
  Widget _viewToggle() {
    Widget seg(String label, IconData icon, bool selected, VoidCallback onTap) {
      return Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: selected ? navy : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 15, color: selected ? Colors.white : secondaryText),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    color: selected ? Colors.white : secondaryText,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          seg('Monthly', Icons.calendar_month_rounded, period == 'month', () => _setPeriod('month')),
          const SizedBox(width: 4),
          seg('3 Months', Icons.date_range_rounded, period == '3m', () => _setPeriod('3m')),
          const SizedBox(width: 4),
          seg('6 Months', Icons.event_note_rounded, period == '6m', () => _setPeriod('6m')),
          const SizedBox(width: 4),
          seg('Yearly', Icons.bar_chart_rounded, period == 'year', () => _setPeriod('year')),
        ],
      ),
    );
  }

  Widget _periodNavigator() {
    final now = DateTime.now();
    final canGoNext = showYear ? year < now.year : (year * 12 + month) < (now.year * 12 + now.month);
    final label = showYear
        ? '$year'
        : isRange
            ? (report?['rangeLabel'] ?? '${monthNames[month - 1]} $year').toString()
            : '${monthNames[month - 1]} $year';

    Widget arrow(IconData icon, bool enabled, VoidCallback onTap) {
      return Material(
        color: enabled ? navy.withOpacity(.08) : softSurface,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: enabled ? onTap : null,
          child: SizedBox(
            width: 40,
            height: 40,
            child: Icon(icon, color: enabled ? navy : borderColor, size: 22),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          arrow(Icons.chevron_left_rounded, true, () => showYear ? _shiftYear(-1) : _shiftMonth(-1)),
          Expanded(
            child: Column(
              children: [
                Text(
                  label,
                  style: GoogleFonts.poppins(color: textColor, fontSize: 15, fontWeight: FontWeight.w800),
                ),
                if (report != null && report!['user'] != null)
                  Text(
                    'Joined ${report!['user']['joinedOn'] ?? ''}'
                    '${(report!['weeklyOff'] as List?)?.isNotEmpty == true ? ' • ${(report!['weeklyOff'] as List).join(', ')} off' : ''}',
                    style: GoogleFonts.poppins(color: secondaryText, fontSize: 9.5),
                  ),
              ],
            ),
          ),
          arrow(Icons.chevron_right_rounded, canGoNext, () => showYear ? _shiftYear(1) : _shiftMonth(1)),
        ],
      ),
    );
  }

  Widget _errorBox() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: absentColor.withOpacity(.25)),
      ),
      child: Column(
        children: [
          const Icon(Icons.error_outline_rounded, color: absentColor, size: 30),
          const SizedBox(height: 8),
          Text(errorText ?? '', textAlign: TextAlign.center, style: GoogleFonts.poppins(color: textColor, fontSize: 12)),
          const SizedBox(height: 10),
          TextButton(onPressed: _load, child: const Text('Try again')),
        ],
      ),
    );
  }

  // =========================================================
  // SUMMARY
  // =========================================================
  Widget _summaryCards(Map<String, dynamic> s, {required bool isWeb}) {
    int n(String k) => (s[k] as num?)?.toInt() ?? 0;

    final items = [
      _Stat('Present', '${n('present')}', presentColor, Icons.check_circle_rounded),
      _Stat('Late', '${n('late')}', lateColor, Icons.schedule_rounded),
      if (n('partial') > 0) _Stat('Partial', '${n('partial')}', partialColor, Icons.timelapse_rounded),
      _Stat('Absent', '${n('absent')}', absentColor, Icons.cancel_rounded),
      _Stat('Attendance', '${n('percentage')}%', navy, Icons.insights_rounded),
      _Stat('Hours', '${s['hours'] ?? 0}', teal, Icons.timer_rounded),
    ];

    return LayoutBuilder(
      builder: (context, c) {
        final perRow = c.maxWidth >= 760 ? items.length : 3;
        final w = (c.maxWidth - (perRow - 1) * 8) / perRow;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: items.map((it) {
            return SizedBox(
              width: w,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: it.color.withOpacity(.22)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: it.color.withOpacity(.11),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Icon(it.icon, color: it.color, size: 16),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            it.value,
                            style: GoogleFonts.poppins(color: textColor, fontSize: 15, fontWeight: FontWeight.w800),
                          ),
                          Text(
                            it.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(color: secondaryText, fontSize: 9, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  /// Quick salary helper for trainers: days attended vs working days
  Widget _payrollCard(Map<String, dynamic> s) {
    int n(String k) => (s[k] as num?)?.toInt() ?? 0;
    final attended = n('attended');
    final working = n('workingDays');
    final ratio = working == 0 ? 0.0 : (attended / working).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [deepNavy, navy, blue]),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.payments_rounded, color: yellow, size: 18),
              const SizedBox(width: 7),
              Text(
                showYear ? 'Salary summary • $year' : 'Salary summary • ${monthNames[month - 1]}',
                style: GoogleFonts.poppins(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$attended',
                style: GoogleFonts.poppins(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800, height: 1),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 6, bottom: 3),
                child: Text(
                  '/ $working working days attended',
                  style: GoogleFonts.poppins(color: Colors.white.withOpacity(.75), fontSize: 11),
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 8,
              backgroundColor: Colors.white.withOpacity(.18),
              valueColor: const AlwaysStoppedAnimation<Color>(yellow),
            ),
          ),
          const SizedBox(height: 9),
          Wrap(
            spacing: 14,
            runSpacing: 4,
            children: [
              _payrollStat('Present', n('present')),
              _payrollStat('Late', n('late')),
              if (n('partial') > 0) _payrollStat('Partial', n('partial')),
              _payrollStat('Absent', n('absent')),
              _payrollStat('Holidays', n('holiday')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _payrollStat(String label, int value) {
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: '$value ',
            style: GoogleFonts.poppins(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800),
          ),
          TextSpan(
            text: label,
            style: GoogleFonts.poppins(color: Colors.white.withOpacity(.7), fontSize: 10.5),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // MONTHLY CALENDAR
  // =========================================================
  Widget _calendar({required bool isWeb}) {
    final days = List<Map<String, dynamic>>.from(
      (report!['days'] as List).map((e) => Map<String, dynamic>.from(e)),
    );
    if (days.isEmpty) return const SizedBox.shrink();

    final firstWeekday = (days.first['weekdayIndex'] as num).toInt(); // 0 = Sunday
    final cells = <Widget>[
      for (int i = 0; i < firstWeekday; i++) const SizedBox.shrink(),
      ...days.map(_dayCell),
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          Row(
            children: ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
                .map(
                  (d) => Expanded(
                    child: Center(
                      child: Text(
                        d,
                        style: GoogleFonts.poppins(
                          color: d == 'Sun' ? absentColor.withOpacity(.75) : secondaryText,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 8),
          GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
            childAspectRatio: isWeb ? 1.35 : 0.9,
            children: cells,
          ),
          const SizedBox(height: 6),
          Text(
            'Tap a day to see check-in time, minutes and stage.',
            style: GoogleFonts.poppins(color: secondaryText, fontSize: 9.5),
          ),
        ],
      ),
    );
  }

  Widget _dayCell(Map<String, dynamic> d) {
    final String status = (d['status'] ?? '').toString();
    final int minutes = (d['minutes'] as num?)?.toInt() ?? 0;
    final bool counted = ['Present', 'Late', 'Partial', 'Absent'].contains(status);
    final Color c = _statusColor(status);
    final bool faded = status == 'Upcoming' || status == 'NotJoined';

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => _showDayDetails(d),
      child: Container(
        decoration: BoxDecoration(
          color: faded ? softSurface : c.withOpacity(status == 'Holiday' ? .22 : .14),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: faded ? borderColor : c.withOpacity(.55), width: counted ? 1.3 : 1),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${d['day']}',
              style: GoogleFonts.poppins(
                color: faded ? secondaryText.withOpacity(.6) : textColor,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (counted)
              Text(
                status == 'Absent' ? 'A' : (minutes > 0 ? '${minutes}m' : status[0]),
                style: GoogleFonts.poppins(color: c, fontSize: 8.5, fontWeight: FontWeight.w800),
              )
            else if (status == 'Holiday')
              Text('Off', style: GoogleFonts.poppins(color: secondaryText, fontSize: 8.5, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }

  void _showDayDetails(Map<String, dynamic> d) {
    final String status = (d['status'] ?? '').toString();
    final details = List<Map<String, dynamic>>.from(
      ((d['details'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e)),
    );
    final Color c = _statusColor(status);
    final String statusText = {
          'Upcoming': 'Not finished yet',
          'NotJoined': 'Before joining date',
          'Holiday': 'Weekly off',
        }[status] ??
        status;

    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 22),
        decoration: const BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: borderColor, borderRadius: BorderRadius.circular(4)),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${d['weekday']}, ${d['date']}',
                      style: GoogleFonts.poppins(color: textColor, fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: c.withOpacity(.12),
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(color: c.withOpacity(.35)),
                    ),
                    child: Text(
                      statusText.toUpperCase(),
                      style: GoogleFonts.poppins(
                        color: status == 'Holiday' || status == 'Upcoming' || status == 'NotJoined'
                            ? secondaryText
                            : c,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (details.isEmpty)
                Text(
                  status == 'Absent'
                      ? 'No check-in or live class recorded on this day.'
                      : 'No attendance record for this day.',
                  style: GoogleFonts.poppins(color: secondaryText, fontSize: 12),
                )
              else
                ...details.map((r) {
                  final rc = _statusColor((r['status'] ?? '').toString());
                  final stage = (r['stage'] ?? '').toString().replaceAll('stage', 'Stage ');
                  final batch = BatchSlots.shortOf(r['batchTime'], fallback: '');
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: softSurface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: borderColor),
                    ),
                    child: Row(
                      children: [
                        Container(width: 4, height: 38, decoration: BoxDecoration(color: rc, borderRadius: BorderRadius.circular(3))),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${r['language'] ?? ''} • $stage${batch.isNotEmpty ? ' • $batch' : ''}',
                                style: GoogleFonts.poppins(color: textColor, fontSize: 12, fontWeight: FontWeight.w700),
                              ),
                              Text(
                                '${r['checkIn'] != null ? 'Checked in ${r['checkIn']}' : 'No check-in time'}'
                                ' • ${r['minutes'] ?? 0} mins'
                                '${r['mode'] != null ? ' • ${r['mode'].toString().toUpperCase()}' : ''}',
                                style: GoogleFonts.poppins(color: secondaryText, fontSize: 10.5),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          (r['status'] ?? '').toString(),
                          style: GoogleFonts.poppins(color: rc, fontSize: 11, fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        ),
      ),
      isScrollControlled: true,
    );
  }

  // =========================================================
  // YEARLY GRAPH (stacked bars, no chart package needed)
  // =========================================================
  Widget _yearChart({String source = 'yearSummary'}) {
    final months = List<Map<String, dynamic>>.from(
      ((report![source] ?? report!['yearSummary']) as List).map((e) => Map<String, dynamic>.from(e)),
    );
    int n(Map<String, dynamic> m, String k) => (m[k] as num?)?.toInt() ?? 0;
    final maxDays = months.fold<int>(0, (mx, m) => n(m, 'workingDays') > mx ? n(m, 'workingDays') : mx);
    const double chartHeight = 190;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Month by month',
            style: GoogleFonts.poppins(color: textColor, fontSize: 13.5, fontWeight: FontWeight.w700),
          ),
          Text(
            'Bar height = working days. Tap a month to open its calendar.',
            style: GoogleFonts.poppins(color: secondaryText, fontSize: 9.5),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: chartHeight + 44,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: months.map((m) {
                final working = n(m, 'workingDays');
                final pct = n(m, 'percentage');
                double h(int v) => maxDays == 0 ? 0 : chartHeight * v / maxDays;

                return Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: working == 0
                        ? null
                        : () {
                            setState(() {
                              if (m['year'] != null) year = n(m, 'year');
                              month = n(m, 'month');
                              period = 'month';
                            });
                            _load();
                          },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            working == 0 ? '' : '$pct%',
                            style: GoogleFonts.poppins(
                              color: pct >= 75 ? presentColor : (pct >= 50 ? lateColor : absentColor),
                              fontSize: 8.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 3),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: Column(
                              children: [
                                Container(height: h(n(m, 'absent')), color: absentColor),
                                Container(height: h(n(m, 'partial')), color: partialColor),
                                Container(height: h(n(m, 'late')), color: lateColor),
                                Container(height: h(n(m, 'present')), color: presentColor),
                              ],
                            ),
                          ),
                          if (working == 0)
                            Container(
                              height: 4,
                              decoration: BoxDecoration(color: borderColor, borderRadius: BorderRadius.circular(3)),
                            ),
                          const SizedBox(height: 6),
                          Text(
                            (m['label'] ?? '').toString(),
                            style: GoogleFonts.poppins(color: secondaryText, fontSize: 9, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 10),
          // Table with exact numbers per month
          ...months.where((m) => n(m, 'workingDays') > 0).map((m) {
            return Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                children: [
                  SizedBox(
                    width: 38,
                    child: Text(
                      (m['label'] ?? '').toString(),
                      style: GoogleFonts.poppins(color: textColor, fontSize: 10.5, fontWeight: FontWeight.w700),
                    ),
                  ),
                  _miniCount(n(m, 'present'), presentColor),
                  _miniCount(n(m, 'late'), lateColor),
                  if (n(m, 'partial') > 0) _miniCount(n(m, 'partial'), partialColor),
                  _miniCount(n(m, 'absent'), absentColor),
                  const Spacer(),
                  Text(
                    '${n(m, 'attended')}/${n(m, 'workingDays')} days • ${m['hours'] ?? 0}h',
                    style: GoogleFonts.poppins(color: secondaryText, fontSize: 10),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ---------------------------------------------------------
  // period helpers
  // ---------------------------------------------------------
  void _setPeriod(String p) {
    if (period == p) return;
    setState(() => period = p);
    _load();
  }

  Map<String, dynamic> _totals() {
    final r = report!;
    final raw = showYear ? r['yearTotals'] : (isRange ? (r['rangeTotals'] ?? r['monthSummary']) : r['monthSummary']);
    return Map<String, dynamic>.from(raw as Map);
  }

  String get _periodWord => showYear ? 'this year' : (isRange ? 'in these months' : 'this month');

  static const Color starColor = Color(0xFFF5B83D);

  Widget _stars(double rating, {double size = 14}) => Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(5, (i) {
          final full = rating >= i + 1;
          final half = !full && rating > i;
          return Icon(
            full ? Icons.star_rounded : (half ? Icons.star_half_rounded : Icons.star_outline_rounded),
            color: starColor,
            size: size,
          );
        }),
      );

  String _stageText(String stage) => stage.replaceAll('stage', 'Stage ');

  String _dateTime(dynamic iso, {bool withTime = true}) {
    final d = DateTime.tryParse('${iso ?? ''}')?.toLocal();
    if (d == null) return '';
    const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final t = '$h:${d.minute.toString().padLeft(2, '0')} ${d.hour >= 12 ? 'PM' : 'AM'}';
    return withTime ? '${d.day} ${m[d.month - 1]} ${d.year}, $t' : '${d.day} ${m[d.month - 1]} ${d.year}';
  }

  Widget _sectionCard({required IconData icon, required Color color, required String title, required String subtitle, Widget? trailing, required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: color.withOpacity(.12), borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: color, size: 19),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: GoogleFonts.poppins(color: textColor, fontSize: 13.5, fontWeight: FontWeight.w700)),
                    Text(subtitle, style: GoogleFonts.poppins(color: secondaryText, fontSize: 9.5)),
                  ],
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _emptyLine(String text) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(color: softSurface, borderRadius: BorderRadius.circular(12)),
        child: Text(text, textAlign: TextAlign.center, style: GoogleFonts.poppins(color: secondaryText, fontSize: 11)),
      );

  // =========================================================
  // 🎤 SPEAKING PRACTICE (trainer ratings, day + stage wise)
  // =========================================================
  Widget _practiceCard({required bool isWeb}) {
    final p = Map<String, dynamic>.from((report!['practice'] ?? const {}) as Map);
    final count = (p['count'] as num?)?.toInt() ?? 0;
    final rated = (p['rated'] as num?)?.toInt() ?? 0;
    final avg = (p['averageRating'] as num?)?.toDouble() ?? 0;
    final byStage = ((p['byStage'] ?? const []) as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    final days = ((p['days'] ?? const []) as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();

    return _sectionCard(
      icon: Icons.record_voice_over_rounded,
      color: teal,
      title: 'Speaking practice',
      subtitle: 'Trainer ratings $_periodWord • day wise and stage wise',
      trailing: count == 0
          ? null
          : Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(avg > 0 ? avg.toStringAsFixed(1) : '–',
                        style: GoogleFonts.poppins(color: textColor, fontSize: 18, fontWeight: FontWeight.w800)),
                    const SizedBox(width: 4),
                    const Icon(Icons.star_rounded, color: starColor, size: 20),
                  ],
                ),
                Text('$count practiced • $rated rated',
                    style: GoogleFonts.poppins(color: secondaryText, fontSize: 9.5)),
              ],
            ),
      children: count == 0
          ? [_emptyLine('No speaking practice $_periodWord yet.')]
          : [
              // stage wise
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: byStage.map((s) {
                  final a = (s['averageRating'] as num?)?.toDouble() ?? 0;
                  return Container(
                    padding: const EdgeInsets.fromLTRB(10, 8, 12, 8),
                    decoration: BoxDecoration(
                      color: softSurface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: borderColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${s['language']} • ${_stageText((s['stage'] ?? '').toString())}',
                            style: GoogleFonts.poppins(color: textColor, fontSize: 11, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _stars(a, size: 13),
                            const SizedBox(width: 6),
                            Text(a > 0 ? a.toStringAsFixed(1) : 'not rated',
                                style: GoogleFonts.poppins(color: secondaryText, fontSize: 10, fontWeight: FontWeight.w600)),
                            Text('  •  ${s['count']}×',
                                style: GoogleFonts.poppins(color: secondaryText, fontSize: 10)),
                          ],
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              Text('Day by day', style: GoogleFonts.poppins(color: textColor, fontSize: 11.5, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              ...days.map((d) {
                final r = (d['rating'] as num?)?.toInt() ?? 0;
                final tags = ((d['tags'] ?? const []) as List).map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
                final note = (d['note'] ?? '').toString();
                final noteExtra = note.isNotEmpty && note != tags.join(', ') ? note : '';
                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: softSurface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: isWeb ? 110 : 84,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text((d['date'] ?? '').toString(),
                                style: GoogleFonts.poppins(color: textColor, fontSize: 11, fontWeight: FontWeight.w700)),
                            Text('${d['language']} • ${_stageText((d['stage'] ?? '').toString())}',
                                style: GoogleFonts.poppins(color: secondaryText, fontSize: 9.5)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            r > 0
                                ? _stars(r.toDouble())
                                : Text('Practiced • not rated',
                                    style: GoogleFonts.poppins(color: secondaryText, fontSize: 10.5, fontWeight: FontWeight.w600)),
                            if (tags.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: 4,
                                runSpacing: 4,
                                children: tags
                                    .map((t) => Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                          decoration: BoxDecoration(
                                              color: teal.withOpacity(.12), borderRadius: BorderRadius.circular(6)),
                                          child: Text(t,
                                              style: GoogleFonts.poppins(
                                                  color: deepNavy, fontSize: 9.5, fontWeight: FontWeight.w600)),
                                        ))
                                    .toList(),
                              ),
                            ],
                            if (noteExtra.isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Text(noteExtra, style: GoogleFonts.poppins(color: textColor, fontSize: 10)),
                            ],
                          ],
                        ),
                      ),
                      if ((d['trainerName'] ?? '').toString().isNotEmpty)
                        Text('by ${d['trainerName']}',
                            style: GoogleFonts.poppins(color: secondaryText, fontSize: 9.5)),
                    ],
                  ),
                );
              }),
            ],
    );
  }

  // =========================================================
  // 📝 TEST RESULTS (+ when the admin published the test)
  // =========================================================
  Widget _testsCard({required bool isWeb}) {
    final t = Map<String, dynamic>.from((report!['tests'] ?? const {}) as Map);
    final list = ((t['results'] ?? const []) as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    final avg = (t['averagePercentage'] as num?)?.toInt() ?? 0;

    return _sectionCard(
      icon: Icons.assignment_turned_in_rounded,
      color: navy,
      title: 'Test results',
      subtitle: 'Tests taken $_periodWord',
      trailing: list.isEmpty
          ? null
          : Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('$avg%',
                    style: GoogleFonts.poppins(
                        color: avg >= 50 ? presentColor : absentColor, fontSize: 18, fontWeight: FontWeight.w800)),
                Text('average • ${list.length} test${list.length == 1 ? '' : 's'}',
                    style: GoogleFonts.poppins(color: secondaryText, fontSize: 9.5)),
              ],
            ),
      children: list.isEmpty
          ? [_emptyLine('No tests taken $_periodWord.')]
          : list.map((r) {
              final pct = (r['percentage'] as num?)?.toInt() ?? 0;
              final c = pct >= 50 ? presentColor : absentColor;
              final published = _dateTime(r['testPublishedAt']);
              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: softSurface, borderRadius: BorderRadius.circular(12)),
                child: Row(
                  children: [
                    Container(
                      width: 58,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        color: c.withOpacity(.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        children: [
                          Text('${r['score']}/${r['total']}',
                              style: GoogleFonts.poppins(color: textColor, fontSize: 12, fontWeight: FontWeight.w800)),
                          Text('$pct%', style: GoogleFonts.poppins(color: c, fontSize: 10, fontWeight: FontWeight.w800)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${r['language']} • ${_stageText((r['stage'] ?? '').toString())} test',
                              style: GoogleFonts.poppins(color: textColor, fontSize: 11.5, fontWeight: FontWeight.w700)),
                          Text('Taken: ${_dateTime(r['completedAt'])}',
                              style: GoogleFonts.poppins(color: secondaryText, fontSize: 10)),
                          Text(published.isEmpty ? 'Uploaded by admin: (older test, date not saved)' : 'Uploaded by admin: $published',
                              style: GoogleFonts.poppins(color: secondaryText, fontSize: 10)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: c.withOpacity(.12), borderRadius: BorderRadius.circular(8)),
                      child: Text(pct >= 50 ? 'Passed' : 'Below 50%',
                          style: GoogleFonts.poppins(color: c, fontSize: 9.5, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              );
            }).toList(),
    );
  }

  Widget _miniCount(int v, Color c) {
    return Container(
      margin: const EdgeInsets.only(right: 5),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(color: c.withOpacity(.12), borderRadius: BorderRadius.circular(6)),
      child: Text('$v', style: GoogleFonts.poppins(color: c, fontSize: 10, fontWeight: FontWeight.w800)),
    );
  }

  Widget _legend() {
    final items = [
      _Stat('Present', '', presentColor, Icons.circle),
      _Stat('Late', '', lateColor, Icons.circle),
      _Stat('Partial', '', partialColor, Icons.circle),
      _Stat('Absent', '', absentColor, Icons.circle),
      _Stat('Off day', '', holidayColor, Icons.circle),
    ];
    return Wrap(
      spacing: 14,
      runSpacing: 6,
      children: items
          .map(
            (it) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 10, height: 10, decoration: BoxDecoration(color: it.color, borderRadius: BorderRadius.circular(3))),
                const SizedBox(width: 5),
                Text(it.label, style: GoogleFonts.poppins(color: secondaryText, fontSize: 10, fontWeight: FontWeight.w600)),
              ],
            ),
          )
          .toList(),
    );
  }
}

class _Stat {
  final String label;
  final String value;
  final Color color;
  final IconData icon;
  const _Stat(this.label, this.value, this.color, this.icon);
}
