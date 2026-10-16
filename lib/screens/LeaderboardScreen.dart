import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:lets_speake_manager/Api/ApiendPoints.dart';
import 'package:lets_speake_manager/Api/api_headers.dart';
import 'package:lets_speake_manager/screens/AttendanceReportScreen.dart';

/// Best trainer / best student of the month or year.
///   Get.to(() => const LeaderboardScreen(role: 'teacher'));
class LeaderboardScreen extends StatefulWidget {
  final String role; // 'teacher' | 'student'
  const LeaderboardScreen({super.key, this.role = 'teacher'});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  static const Color navy = Color(0xFF155A88);
  static const Color deepNavy = Color(0xFF0E466D);
  static const Color blue = Color(0xFF2C6F9F);
  static const Color teal = Color(0xFF28C2C2);
  static const Color yellow = Color(0xFFF7DF55);
  static const Color gold = Color(0xFFE3B21B);
  static const Color silver = Color(0xFF9AAAB8);
  static const Color bronze = Color(0xFFC07A45);

  static const Color textColor = Color(0xFF173A52);
  static const Color secondaryText = Color(0xFF678196);
  static const Color borderColor = Color(0xFFD5E5EE);
  static const Color softSurface = Color(0xFFF4F9FC);
  static const Color backgroundColor = Color(0xFFE8F2F8);
  static const Color cardColor = Color(0xFFFFFFFF);
  static const Color success = Color(0xFF16A66A);
  static const Color error = Color(0xFFE45757);
  static const Color late = Color(0xFFE0A21B);

  static const List<String> monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  late String role;
  bool yearly = false;
  late int year;
  late int month;

  bool isLoading = true;
  String? errorText;
  Map<String, dynamic>? data;

  bool get isTrainer => role == 'teacher';

  @override
  void initState() {
    super.initState();
    role = widget.role == 'student' ? 'student' : 'teacher';
    final now = DateTime.now();
    year = now.year;
    month = now.month;
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
          "${ApiEndpoints.baseUrl}/leaderboard?role=$role&period=${yearly ? 'year' : 'month'}&year=$year&month=$month&limit=50",
        ),
        headers: ApiHeaders.auth(),
      );
      if (!mounted) return;
      if (res.statusCode == 200) {
        setState(() {
          data = Map<String, dynamic>.from(jsonDecode(res.body));
          isLoading = false;
        });
      } else {
        String msg = "Could not load leaderboard (${res.statusCode})";
        try {
          final body = jsonDecode(res.body);
          if (body is Map && body['message'] != null) msg = body['message'].toString();
        } catch (_) {}
        setState(() {
          errorText = msg;
          isLoading = false;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        errorText = "Connection error. Check the server.";
        isLoading = false;
      });
    }
  }

  void _shift(int delta) {
    final now = DateTime.now();
    if (yearly) {
      final y = year + delta;
      if (y > now.year || y < 2024) return;
      setState(() => year = y);
    } else {
      final total = year * 12 + (month - 1) + delta;
      final y = total ~/ 12;
      final m = total % 12 + 1;
      if (y * 12 + m > now.year * 12 + now.month) return;
      setState(() {
        year = y;
        month = m;
      });
    }
    _load();
  }

  // =========================================================
  @override
  Widget build(BuildContext context) {
    final isWeb = MediaQuery.sizeOf(context).width >= 900;
    final ranking = List<Map<String, dynamic>>.from(
      ((data?['ranking'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e)),
    );

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: cardColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Get.back(),
          icon: const Icon(Icons.arrow_back_rounded, color: textColor),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [gold, Color(0xFFF3CF4E)]),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.emoji_events_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Leaderboard',
                  style: GoogleFonts.poppins(color: textColor, fontSize: 16, fontWeight: FontWeight.w700),
                ),
                Text(
                  'Best ${isTrainer ? 'trainers' : 'students'} by attendance',
                  style: GoogleFonts.poppins(color: secondaryText, fontSize: 10),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: isLoading ? null : _load,
            icon: const Icon(Icons.refresh_rounded, color: textColor),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: RefreshIndicator(
              color: navy,
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                padding: EdgeInsets.fromLTRB(isWeb ? 24 : 14, 14, isWeb ? 24 : 14, 28),
                children: [
                  _toggles(),
                  const SizedBox(height: 10),
                  _periodNav(),
                  const SizedBox(height: 14),
                  if (isLoading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 80),
                      child: Center(child: CircularProgressIndicator(color: navy, strokeWidth: 2.4)),
                    )
                  else if (errorText != null)
                    _message(Icons.error_outline_rounded, errorText!, error)
                  else if (ranking.isEmpty)
                    _message(
                      Icons.hourglass_empty_rounded,
                      'No ranking yet for ${data?['periodLabel'] ?? 'this period'}.\nPeople need at least 3 working days in the period.',
                      secondaryText,
                    )
                  else ...[
                    _winnerCard(ranking.first),
                    const SizedBox(height: 14),
                    if (ranking.length >= 2) _podium(ranking),
                    if (ranking.length >= 2) const SizedBox(height: 14),
                    Text(
                      'Full ranking • ${data?['totalRanked'] ?? ranking.length} ${isTrainer ? 'trainers' : 'students'}',
                      style: GoogleFonts.poppins(color: textColor, fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    ...ranking.map(_rankRow),
                    const SizedBox(height: 10),
                    Text(
                      'Ranked by attendance %, then on-time (Present) days, then minutes in class. '
                      'Sundays are off days. Today counts after 8:15 PM.',
                      style: GoogleFonts.poppins(color: secondaryText, fontSize: 9.5, height: 1.4),
                    ),
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
  Widget _toggles() {
    Widget seg(String label, bool selected, VoidCallback onTap, {IconData? icon}) {
      return Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(vertical: 9),
            decoration: BoxDecoration(
              color: selected ? navy : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 15, color: selected ? Colors.white : secondaryText),
                  const SizedBox(width: 5),
                ],
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    color: selected ? Colors.white : secondaryText,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    Widget box(List<Widget> children) => Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: borderColor),
          ),
          child: Row(children: children),
        );

    return Column(
      children: [
        box([
          seg('Trainers', isTrainer, () {
            if (isTrainer) return;
            setState(() => role = 'teacher');
            _load();
          }, icon: Icons.school_rounded),
          const SizedBox(width: 4),
          seg('Students', !isTrainer, () {
            if (!isTrainer) return;
            setState(() => role = 'student');
            _load();
          }, icon: Icons.groups_rounded),
        ]),
        const SizedBox(height: 8),
        box([
          seg('This month', !yearly, () {
            if (!yearly) return;
            setState(() => yearly = false);
            _load();
          }, icon: Icons.calendar_month_rounded),
          const SizedBox(width: 4),
          seg('This year', yearly, () {
            if (yearly) return;
            setState(() => yearly = true);
            _load();
          }, icon: Icons.calendar_today_rounded),
        ]),
      ],
    );
  }

  Widget _periodNav() {
    final now = DateTime.now();
    final canNext = yearly ? year < now.year : (year * 12 + month) < (now.year * 12 + now.month);
    Widget arrow(IconData icon, bool enabled, VoidCallback onTap) => Material(
          color: enabled ? navy.withOpacity(.08) : softSurface,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: enabled ? onTap : null,
            child: SizedBox(width: 38, height: 38, child: Icon(icon, color: enabled ? navy : borderColor)),
          ),
        );

    return Row(
      children: [
        arrow(Icons.chevron_left_rounded, true, () => _shift(-1)),
        Expanded(
          child: Center(
            child: Text(
              yearly ? '$year' : '${monthNames[month - 1]} $year',
              style: GoogleFonts.poppins(color: textColor, fontSize: 15, fontWeight: FontWeight.w800),
            ),
          ),
        ),
        arrow(Icons.chevron_right_rounded, canNext, () => _shift(1)),
      ],
    );
  }

  Widget _message(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 30),
          const SizedBox(height: 8),
          Text(text, textAlign: TextAlign.center, style: GoogleFonts.poppins(color: textColor, fontSize: 12, height: 1.45)),
        ],
      ),
    );
  }

  void _openReport(Map<String, dynamic> p) {
    Get.to(() => AttendanceReportScreen(
          userId: (p['userId'] ?? '').toString(),
          name: (p['name'] ?? '').toString(),
          role: role,
          startWithYear: yearly,
        ));
  }

  // =========================================================
  Widget _winnerCard(Map<String, dynamic> p) {
    final name = (p['name'] ?? '').toString();
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => _openReport(p),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [deepNavy, navy, blue],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: navy.withOpacity(.25), blurRadius: 18, offset: const Offset(0, 8))],
        ),
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 66,
                  height: 66,
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(colors: [gold, yellow]),
                  ),
                  child: CircleAvatar(
                    backgroundColor: deepNavy,
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: GoogleFonts.poppins(color: yellow, fontSize: 24, fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
                const Positioned(
                  top: -14,
                  left: 0,
                  right: 0,
                  child: Center(child: Text('👑', style: TextStyle(fontSize: 20))),
                ),
              ],
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'BEST ${isTrainer ? 'TRAINER' : 'STUDENT'} • ${(data?['periodLabel'] ?? '').toString().toUpperCase()}',
                    style: GoogleFonts.poppins(
                      color: yellow,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: .8,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${p['percentage']}% attendance • ${p['attended']}/${p['workingDays']} days • ${p['hours']}h',
                    style: GoogleFonts.poppins(color: Colors.white.withOpacity(.8), fontSize: 11),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: Colors.white.withOpacity(.7)),
          ],
        ),
      ),
    );
  }

  Widget _podium(List<Map<String, dynamic>> r) {
    Widget step(Map<String, dynamic>? p, int place, double height, Color color) {
      if (p == null) return const Expanded(child: SizedBox.shrink());
      final name = (p['name'] ?? '').toString();
      return Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _openReport(p),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: color.withOpacity(.18),
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: GoogleFonts.poppins(color: color, fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(color: textColor, fontSize: 11, fontWeight: FontWeight.w700),
              ),
              Text(
                '${p['percentage']}%',
                style: GoogleFonts.poppins(color: secondaryText, fontSize: 10, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 5),
              Container(
                height: height,
                margin: const EdgeInsets.symmetric(horizontal: 6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color.withOpacity(.85), color.withOpacity(.55)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                ),
                alignment: Alignment.center,
                child: Text(
                  '$place',
                  style: GoogleFonts.poppins(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 14, 10, 0),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
      ),
      child: SizedBox(
        height: 175,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            step(r.length > 1 ? r[1] : null, 2, 62, silver),
            step(r[0], 1, 88, gold),
            step(r.length > 2 ? r[2] : null, 3, 46, bronze),
          ],
        ),
      ),
    );
  }

  Widget _rankRow(Map<String, dynamic> p) {
    final int rank = (p['rank'] as num?)?.toInt() ?? 0;
    final int pct = (p['percentage'] as num?)?.toInt() ?? 0;
    final medal = rank == 1 ? gold : rank == 2 ? silver : rank == 3 ? bronze : null;
    final name = (p['name'] ?? '').toString();
    final barColor = pct >= 75 ? success : (pct >= 50 ? late : error);

    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _openReport(p),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: medal?.withOpacity(.5) ?? borderColor),
          ),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: (medal ?? navy).withOpacity(.13),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$rank',
                  style: GoogleFonts.poppins(color: medal ?? navy, fontSize: 12, fontWeight: FontWeight.w800),
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
                      style: GoogleFonts.poppins(color: textColor, fontSize: 12.5, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: pct / 100,
                        minHeight: 6,
                        backgroundColor: softSurface,
                        valueColor: AlwaysStoppedAnimation<Color>(barColor),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${p['present']} present • ${p['late']} late • ${p['absent']} absent • ${p['hours']}h'
                      '${(p['phone'] ?? '').toString().isNotEmpty ? ' • ${p['phone']}' : ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(color: secondaryText, fontSize: 9.5),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '$pct%',
                style: GoogleFonts.poppins(color: barColor, fontSize: 15, fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
