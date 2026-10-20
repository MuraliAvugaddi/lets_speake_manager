import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:lets_speake_manager/Api/ApiendPoints.dart';
import 'package:lets_speake_manager/Api/api_headers.dart';
import 'package:lets_speake_manager/Navigation/AdminShellNavigation.dart';
import 'package:lets_speake_manager/screens/AttendanceReportScreen.dart';
import 'package:lets_speake_manager/screens/best_students_view.dart';

/// Best trainer / best student / top-rated student of the month or year.
///   Get.to(() => const LeaderboardScreen(role: 'teacher'));   // or 'student' / 'rating'
class LeaderboardScreen extends StatefulWidget {
  /// true = opened from the admin sidebar (menu button instead of back)
  final bool embedded;
  final String role; // 'teacher' | 'student' | 'rating'
  const LeaderboardScreen({super.key, this.embedded = false, this.role = 'teacher'});

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

  // ⭐ Top rated filters
  String rLanguage = 'English';
  String rStage = 'all';

  bool get isTrainer => role == 'teacher';
  bool get isRating => role == 'rating';

  @override
  void initState() {
    super.initState();
    role = ['student', 'rating'].contains(widget.role) ? widget.role : 'teacher';
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
      final period = yearly ? 'year' : 'month';
      final url = isRating
          ? "${ApiEndpoints.baseUrl}/leaderboard/ratings?period=$period&year=$year&month=$month&language=$rLanguage&stage=$rStage&limit=50"
          : "${ApiEndpoints.baseUrl}/leaderboard?role=$role&period=$period&year=$year&month=$month&limit=50";
      final res = await http.get(
        Uri.parse(url),
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
        leading: widget.embedded
            ? (AdminShellNavigation.shouldShowMenuButton(context)
                ? IconButton(
                    tooltip: 'Menu',
                    onPressed: AdminShellNavigation.openDrawer,
                    icon: const Icon(Icons.menu_rounded, color: textColor),
                  )
                : null)
            : IconButton(onPressed: () => Get.back(), icon: const Icon(Icons.arrow_back_rounded, color: textColor)),
        automaticallyImplyLeading: false,
        titleSpacing: widget.embedded && !AdminShellNavigation.shouldShowMenuButton(context) ? 20 : 0,
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
                  isRating
                      ? 'Top rated students by trainer stars'
                      : isTrainer
                          ? 'Best trainers by attendance'
                          : 'Best students: attendance + practice + tests',
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
      body: role == 'student'
          ? SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: Column(
                    children: [
                      Padding(
                        padding: EdgeInsets.fromLTRB(isWeb ? 24 : 14, 14, isWeb ? 24 : 14, 0),
                        child: _toggles(),
                      ),
                      Expanded(
                        child: BestStudentsView(
                          audience: 'admin',
                          padding: EdgeInsets.fromLTRB(isWeb ? 24 : 14, 10, isWeb ? 24 : 14, 28),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          : SafeArea(
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
                  if (isRating) ...[
                    const SizedBox(height: 10),
                    _ratingFilters(),
                  ],
                  const SizedBox(height: 14),
                  if (isRating && !isLoading && errorText == null)
                    ..._ratingBody(ranking)
                  else if (isLoading)
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
                      isTrainer
                          ? 'Ranked by attendance %, then on-time (Present) days, then minutes in class. '
                              'Sundays are off days. Today counts after 8:15 PM.'
                          : 'Score = attendance 50% + speaking-practice rating 30% (trainer stars ÷ 5) + test average 20%. '
                              'No rating / no test yet counts as 0. Sundays are off days. Today counts after 8:15 PM.',
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
            setState(() {
              role = 'teacher';
              data = null;
            });
            _load();
          }, icon: Icons.school_rounded),
          const SizedBox(width: 4),
          seg('Best students', role == 'student', () {
            if (role == 'student') return;
            setState(() {
              role = 'student';
              data = null;
            });
          }, icon: Icons.groups_rounded),
          const SizedBox(width: 4),
          seg('Top rated', isRating, () {
            if (isRating) return;
            setState(() {
              role = 'rating';
              data = null;
            });
            _load();
          }, icon: Icons.star_rounded),
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
          role: isTrainer ? 'teacher' : 'student',
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
                    _hasScore(p)
                        ? 'Score ${p['score']} • ${p['percentage']}% attendance • ${_stars(p)} practice • ${_tests(p)} tests'
                        : '${p['percentage']}% attendance • ${p['attended']}/${p['workingDays']} days • ${p['hours']}h',
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
                _hasScore(p) ? 'Score ${p['score']}' : '${p['percentage']}%',
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
    // Students: overall score (attendance + practice + tests). Trainers: attendance %.
    final int pct = _hasScore(p)
        ? (p['score'] as num?)?.toInt() ?? 0
        : (p['percentage'] as num?)?.toInt() ?? 0;
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
                      (_hasScore(p)
                              ? '${p['percentage']}% attendance • ${_stars(p)} practice (${p['practiceCount'] ?? 0}) • ${_tests(p)} tests (${p['testCount'] ?? 0})'
                              : '${p['present']} present • ${p['late']} late • ${p['absent']} absent • ${p['hours']}h') +
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
                _hasScore(p) ? '$pct' : '$pct%',
                style: GoogleFonts.poppins(color: barColor, fontSize: 15, fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // =========================================================
  // ⭐ TOP RATED
  // =========================================================
  Widget _ratingFilters() {
    Widget chip(String label, bool selected, VoidCallback onTap) => Padding(
          padding: const EdgeInsets.only(right: 6),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: selected ? navy : cardColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: selected ? navy : borderColor),
              ),
              child: Text(
                label,
                style: GoogleFonts.poppins(
                  color: selected ? Colors.white : textColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        );

    void pickStage(String s) {
      if (rStage == s) return;
      setState(() => rStage = s);
      _load();
    }

    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        children: [
          chip(rLanguage == 'English' ? '🇬🇧 English' : '🇮🇳 Hindi', false, () {
            setState(() => rLanguage = rLanguage == 'English' ? 'Hindi' : 'English');
            _load();
          }),
          Container(width: 1, margin: const EdgeInsets.fromLTRB(2, 6, 8, 6), color: borderColor),
          chip('All stages', rStage == 'all', () => pickStage('all')),
          for (int i = 1; i <= 7; i++) chip('Stage $i', rStage == 'stage$i', () => pickStage('stage$i')),
        ],
      ),
    );
  }

  List<Widget> _ratingBody(List<Map<String, dynamic>> ranking) {
    final winner = data?['winner'] is Map ? Map<String, dynamic>.from(data!['winner']) : null;
    final best = List<Map<String, dynamic>>.from(
      ((data?['bestByStage'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e)),
    );
    final minRatings = (data?['minRatings'] as num?)?.toInt() ?? 3;
    final stageText = rStage == 'all' ? 'all stages' : 'Stage ${rStage.replaceAll('stage', '')}';

    if (ranking.isEmpty) {
      return [
        _message(
          Icons.star_border_rounded,
          'No ratings yet for $rLanguage • $stageText in ${data?['periodLabel'] ?? 'this period'}.\n'
          'Trainers rate a student right after "Mark practiced".',
          secondaryText,
        ),
      ];
    }

    return [
      if (winner != null)
        _ratingWinner(winner)
      else
        _message(
          Icons.hourglass_top_rounded,
          'No winner yet — a student needs at least $minRatings ratings in ${data?['periodLabel'] ?? 'this period'}.',
          late,
        ),
      if (rStage == 'all' && best.isNotEmpty) ...[
        const SizedBox(height: 14),
        Text(
          'Best in each stage',
          style: GoogleFonts.poppins(color: textColor, fontSize: 13, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 104,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: best.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) => _stageBestCard(best[i]),
          ),
        ),
      ],
      const SizedBox(height: 14),
      Text(
        '${data?['totalRated'] ?? ranking.length} students rated • ${data?['totalRatings'] ?? 0} ratings',
        style: GoogleFonts.poppins(color: textColor, fontSize: 13, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 8),
      ...ranking.map((p) => _ratingRow(p, minRatings)),
      const SizedBox(height: 10),
      Text(
        'Ranked by average trainer rating (1–5★), then number of ratings, then 5★ count. '
        'To be named best, a student needs at least $minRatings ratings in the ${yearly ? 'year' : 'month'}.',
        style: GoogleFonts.poppins(color: secondaryText, fontSize: 9.5, height: 1.4),
      ),
    ];
  }

  Widget _starRow(double avg, {double size = 13, Color color = gold}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final v = avg - i;
        final icon = v >= .75 ? Icons.star_rounded : (v >= .25 ? Icons.star_half_rounded : Icons.star_outline_rounded);
        return Icon(icon, size: size, color: color);
      }),
    );
  }

  Widget _ratingWinner(Map<String, dynamic> p) {
    final name = (p['name'] ?? '').toString();
    final avg = (p['avg'] as num?)?.toDouble() ?? 0;
    final tags = List<String>.from((p['topTags'] as List?) ?? []);
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
            Container(
              width: 66,
              height: 66,
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [gold, yellow])),
              child: CircleAvatar(
                backgroundColor: deepNavy,
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: GoogleFonts.poppins(color: yellow, fontSize: 24, fontWeight: FontWeight.w800),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'TOP RATED • ${(data?['periodLabel'] ?? '').toString().toUpperCase()}',
                    style: GoogleFonts.poppins(color: yellow, fontSize: 9.5, fontWeight: FontWeight.w800, letterSpacing: .8),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      _starRow(avg, size: 15, color: yellow),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          '${avg.toStringAsFixed(1)} • ${p['rated']} ratings • ${p['fiveStar']}× 5★',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(color: Colors.white.withOpacity(.85), fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                  if (tags.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Strong in: ${tags.join(', ')}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(color: Colors.white.withOpacity(.7), fontSize: 10),
                    ),
                  ],
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: Colors.white.withOpacity(.7)),
          ],
        ),
      ),
    );
  }

  Widget _stageBestCard(Map<String, dynamic> b) {
    final stage = (b['stage'] ?? '').toString();
    final w = b['winner'] is Map ? Map<String, dynamic>.from(b['winner']) : null;
    final avg = (w?['avg'] as num?)?.toDouble() ?? 0;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () {
        setState(() => rStage = stage);
        _load();
      },
      child: Container(
        width: 150,
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: w == null ? borderColor : gold.withOpacity(.45)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Stage ${stage.replaceAll('stage', '')}',
                  style: GoogleFonts.poppins(color: secondaryText, fontSize: 10, fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                if (w != null) const Text('🏅', style: TextStyle(fontSize: 13)),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              w == null ? 'No ratings yet' : (w['name'] ?? '').toString(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                color: w == null ? secondaryText : textColor,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            if (w != null) ...[
              _starRow(avg, size: 12),
              const SizedBox(height: 2),
              Text(
                '${avg.toStringAsFixed(1)} • ${w['rated']} ratings • ${b['students']} rated',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(color: secondaryText, fontSize: 9),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _ratingRow(Map<String, dynamic> p, int minRatings) {
    final rank = (p['rank'] as num?)?.toInt() ?? 0;
    final avg = (p['avg'] as num?)?.toDouble() ?? 0;
    final qualified = p['qualified'] == true;
    final medal = !qualified ? null : (rank == 1 ? gold : rank == 2 ? silver : rank == 3 ? bronze : null);
    final name = (p['name'] ?? '').toString();
    final tags = List<String>.from((p['topTags'] as List?) ?? []);
    final stages = List<String>.from((p['stages'] as List?) ?? []).map((s) => 'S${s.replaceAll('stage', '')}').join(', ');
    final section = (p['section'] ?? '').toString();
    final color = avg >= 4 ? success : (avg >= 3 ? late : error);

    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _showRatingDetails(p),
        child: Opacity(
          opacity: qualified ? 1 : .72,
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
                  decoration: BoxDecoration(color: (medal ?? navy).withOpacity(.13), shape: BoxShape.circle),
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
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          _starRow(avg, size: 12),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              '${p['rated']} ratings • ${p['fiveStar']}× 5★',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(color: secondaryText, fontSize: 9.5),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        [
                          if (stages.isNotEmpty) stages,
                          if (section.isNotEmpty && section != 'None') 'Sec $section',
                          if (tags.isNotEmpty) tags.join(' · '),
                          if (!qualified) 'needs $minRatings+ ratings',
                        ].join('  •  '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(color: secondaryText, fontSize: 9),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  avg.toStringAsFixed(1),
                  style: GoogleFonts.poppins(color: color, fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showRatingDetails(Map<String, dynamic> p) {
    final avg = (p['avg'] as num?)?.toDouble() ?? 0;
    final tags = List<String>.from((p['topTags'] as List?) ?? []);
    final note = (p['lastNote'] ?? '').toString();
    final trainer = (p['lastTrainer'] ?? '').toString();
    final phone = (p['phone'] ?? '').toString();
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
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
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(color: borderColor, borderRadius: BorderRadius.circular(4)),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                (p['name'] ?? '').toString(),
                style: GoogleFonts.poppins(color: textColor, fontSize: 17, fontWeight: FontWeight.w800),
              ),
              if (phone.isNotEmpty)
                Text(phone, style: GoogleFonts.poppins(color: secondaryText, fontSize: 11)),
              const SizedBox(height: 10),
              Row(
                children: [
                  _starRow(avg, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    '${avg.toStringAsFixed(1)} / 5',
                    style: GoogleFonts.poppins(color: textColor, fontSize: 15, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${p['rated']} ratings • ${p['fiveStar']}× 5★ • ${data?['periodLabel'] ?? ''}',
                style: GoogleFonts.poppins(color: secondaryText, fontSize: 11),
              ),
              if (tags.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: tags
                      .map((t) => Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                            decoration: BoxDecoration(
                              color: teal.withOpacity(.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(t,
                                style: GoogleFonts.poppins(color: navy, fontSize: 10.5, fontWeight: FontWeight.w700)),
                          ))
                      .toList(),
                ),
              ],
              if (note.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: softSurface, borderRadius: BorderRadius.circular(12)),
                  child: Text(
                    '“$note”${trainer.isNotEmpty ? '\n— $trainer' : ''}',
                    style: GoogleFonts.poppins(color: textColor, fontSize: 11.5, height: 1.45),
                  ),
                ),
              ],
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Get.back();
                    _openReport(p);
                  },
                  icon: const Icon(Icons.insights_rounded, size: 16),
                  label: Text('Open attendance report',
                      style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: navy,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      isScrollControlled: true,
    );
  }

  // ⭐ helpers for the student score
  bool _hasScore(Map<String, dynamic> p) => p['score'] != null;
  String _stars(Map<String, dynamic> p) {
    final v = (p['practiceAvg'] as num?)?.toDouble() ?? 0;
    return v > 0 ? '★${v.toStringAsFixed(1)}' : '★ –';
  }

  String _tests(Map<String, dynamic> p) {
    final c = (p['testCount'] as num?)?.toInt() ?? 0;
    return c > 0 ? '${p['testAvg']}%' : '–';
  }
}
