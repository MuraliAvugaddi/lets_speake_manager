import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:lets_speake_manager/Api/ApiendPoints.dart';
import 'package:lets_speake_manager/Api/api_headers.dart';

/// 📋 Surendra Sir Special Class — who attended and who was absent.
/// Trainers / Students → Present / Absent → filter by English/Hindi, Online/Offline, Stage.
/// Grouped stage-wise ("English · Stage 1"). A student with 2 stages shows in both groups.
class AdminAssemblyReportScreen extends StatefulWidget {
  const AdminAssemblyReportScreen({super.key});

  @override
  State<AdminAssemblyReportScreen> createState() => _AdminAssemblyReportScreenState();
}

class _AdminAssemblyReportScreenState extends State<AdminAssemblyReportScreen> {
  static const Color textColor = Color(0xFF173A52);
  static const Color secondaryText = Color(0xFF6B8496);
  static const Color borderColor = Color(0xFFD5E5EE);
  static const Color bg = Color(0xFFF5FAFD);
  static const Color purple = Color(0xFF7B2FF7);
  static const Color green = Color(0xFF16A66A);
  static const Color red = Color(0xFFE45757);
  static const Color amber = Color(0xFFE09B1A);
  static const Color blue = Color(0xFF2E86C9);

  DateTime day = DateTime.now();
  bool loading = true;
  String error = '';
  Map<String, dynamic> report = {};
  List<Map<String, dynamic>> people = [];
  Timer? _auto;

  // filters
  String role = 'student'; // student | trainer
  bool showPresent = true;
  String language = 'All'; // All | English | Hindi
  String mode = 'All'; // All | online | offline
  int stage = 0; // 0 = all
  String search = '';

  String get _dateKey =>
      '${day.day.toString().padLeft(2, '0')}-${day.month.toString().padLeft(2, '0')}-${day.year}';

  bool get _isToday {
    final n = DateTime.now();
    return n.year == day.year && n.month == day.month && n.day == day.day;
  }

  @override
  void initState() {
    super.initState();
    _load();
    // today's class: refresh every 30 s so new joins appear without pulling
    _auto = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_isToday && mounted) _load(silent: true);
    });
  }

  @override
  void dispose() {
    _auto?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        loading = true;
        error = '';
      });
    }
    try {
      final res = await http
          .get(Uri.parse('${ApiEndpoints.baseUrl}/class-mode/assembly/report?date=$_dateKey'), headers: ApiHeaders.auth())
          .timeout(const Duration(seconds: 30));
      final data = jsonDecode(res.body);
      if (res.statusCode != 200) throw Exception(data is Map ? (data['message'] ?? 'Error ${res.statusCode}') : 'Error');
      if (!mounted) return;
      setState(() {
        report = Map<String, dynamic>.from(data);
        people = ((data['people'] ?? []) as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
        loading = false;
        error = '';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        if (!silent) error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: day,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
    );
    if (d != null) {
      setState(() => day = d);
      _load();
    }
  }

  // ---------------- filtering ----------------
  List<Map<String, dynamic>> _classesOf(Map<String, dynamic> p) =>
      ((p['classes'] ?? []) as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();

  bool _classMatches(Map<String, dynamic> c) {
    if (language != 'All' && c['language'] != language) return false;
    if (stage != 0 && c['stage'] != 'stage$stage') return false;
    return true;
  }

  /// people of the selected role, after language / mode / stage / search (present + absent)
  List<Map<String, dynamic>> get _base {
    final q = search.trim().toLowerCase();
    return people.where((p) {
      if (p['role'] != role) return false;
      if (mode != 'All' && p['mode'] != mode) return false;
      if (!_classesOf(p).any(_classMatches)) return false;
      if (q.isNotEmpty) {
        final name = (p['name'] ?? '').toString().toLowerCase();
        final phone = (p['phone'] ?? '').toString();
        if (!name.contains(q) && !phone.contains(q)) return false;
      }
      return true;
    }).toList();
  }

  static int _stageNo(String s) => int.tryParse(s.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

  /// flattened rows: group header + people, grouped "English · Stage 1"
  List<_Row> _rows(List<Map<String, dynamic>> base) {
    final groups = <String, List<Map<String, dynamic>>>{};
    for (final p in base) {
      for (final c in _classesOf(p).where(_classMatches)) {
        final key = '${c['language']}|${c['stage']}';
        groups.putIfAbsent(key, () => []).add(p);
      }
    }
    final keys = groups.keys.toList()
      ..sort((a, b) {
        final pa = a.split('|'), pb = b.split('|');
        final l = pa[0].compareTo(pb[0]);
        return l != 0 ? l : _stageNo(pa[1]).compareTo(_stageNo(pb[1]));
      });
    final out = <_Row>[];
    for (final k in keys) {
      final list = groups[k]!;
      final present = list.where((p) => p['present'] == true).length;
      final shown = list.where((p) => (p['present'] == true) == showPresent).toList();
      if (shown.isEmpty) continue;
      final parts = k.split('|');
      out.add(_Row.header('${parts[0]} · Stage ${_stageNo(parts[1])}', present, list.length - present));
      for (final p in shown) {
        out.add(_Row.person(p));
      }
    }
    return out;
  }

  void _copyList(List<Map<String, dynamic>> base) {
    final list = base.where((p) => (p['present'] == true) == showPresent).toList();
    if (list.isEmpty) return;
    final title = '${report['title'] ?? 'Special class'} — $_dateKey\n'
        '${showPresent ? 'Present' : 'Absent'} ${role == 'student' ? 'students' : 'trainers'} (${list.length})';
    final lines = list.map((p) => '${p['name']} ${p['phone'] ?? ''}'.trim()).join('\n');
    Clipboard.setData(ClipboardData(text: '$title\n$lines'));
    Get.snackbar('Copied', '${list.length} names copied — paste in WhatsApp',
        backgroundColor: green, colorText: Colors.white, snackPosition: SnackPosition.TOP);
  }

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    final base = _base;
    final presentCount = base.where((p) => p['present'] == true).length;
    final absentCount = base.length - presentCount;
    final rows = loading || error.isNotEmpty ? <_Row>[] : _rows(base);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        foregroundColor: textColor,
        title: Text('Special class attendance',
            style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: textColor)),
        actions: [
          IconButton(
            tooltip: 'Copy this list',
            onPressed: loading ? null : () => _copyList(base),
            icon: const Icon(Icons.copy_rounded),
          ),
          IconButton(tooltip: 'Refresh', onPressed: loading ? null : _load, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            children: [
              _top(),
              Expanded(
                child: loading
                    ? const Center(child: CircularProgressIndicator(color: purple))
                    : error.isNotEmpty
                        ? _message(Icons.error_outline_rounded, 'Could not load', error, retry: true)
                        : CustomScrollView(
                            slivers: [
                              SliverToBoxAdapter(child: _filters(presentCount, absentCount)),
                              if (rows.isEmpty)
                                SliverToBoxAdapter(
                                  child: _message(
                                    showPresent ? Icons.event_busy_rounded : Icons.celebration_rounded,
                                    showPresent ? 'Nobody here yet' : 'Nobody absent 🎉',
                                    report['held'] == false
                                        ? 'No special class attendance on $_dateKey.'
                                        : 'Try another filter.',
                                  ),
                                )
                              else
                                SliverPadding(
                                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 24),
                                  sliver: SliverList(
                                    delegate: SliverChildBuilderDelegate(
                                      (_, i) => rows[i].isHeader ? _groupHeader(rows[i]) : _personTile(rows[i].person!),
                                      childCount: rows.length,
                                    ),
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

  Widget _top() {
    final s = (report['summary'] ?? {}) as Map;
    final st = Map<String, dynamic>.from((s['students'] ?? {}) as Map);
    final tr = Map<String, dynamic>.from((s['trainers'] ?? {}) as Map);
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text((report['title'] ?? 'Surendra Sir Special Class').toString(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: purple)),
              ),
              InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: _pickDate,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: purple.withOpacity(.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: purple.withOpacity(.25)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.calendar_month_rounded, size: 16, color: purple),
                      const SizedBox(width: 6),
                      Text(_isToday ? 'Today' : _dateKey,
                          style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700, color: purple)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _summaryCard('🎓 Students', st, role == 'student', () => setState(() => role = 'student'))),
              const SizedBox(width: 10),
              Expanded(child: _summaryCard('👨‍🏫 Trainers', tr, role == 'trainer', () => setState(() => role = 'trainer'))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryCard(String label, Map<String, dynamic> m, bool selected, VoidCallback onTap) {
    final total = (m['total'] ?? 0) as num;
    final present = (m['present'] ?? 0) as num;
    final absent = (m['absent'] ?? 0) as num;
    final pct = total == 0 ? 0.0 : present / total;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? purple : bg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? purple : borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: GoogleFonts.poppins(
                    fontSize: 12, fontWeight: FontWeight.w700, color: selected ? Colors.white : textColor)),
            const SizedBox(height: 4),
            Text('$present / $total',
                style: GoogleFonts.poppins(
                    fontSize: 20, fontWeight: FontWeight.w800, color: selected ? Colors.white : textColor)),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: pct.toDouble(),
                minHeight: 6,
                backgroundColor: selected ? Colors.white24 : borderColor,
                valueColor: AlwaysStoppedAnimation(selected ? Colors.white : green),
              ),
            ),
            const SizedBox(height: 6),
            Text('${(pct * 100).round()}% came • $absent absent',
                style: GoogleFonts.poppins(fontSize: 10.5, color: selected ? Colors.white70 : secondaryText)),
          ],
        ),
      ),
    );
  }

  Widget _filters(int presentCount, int absentCount) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Present / Absent
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              children: [
                Expanded(child: _seg('Present ($presentCount)', Icons.check_circle_rounded, green, showPresent,
                    () => setState(() => showPresent = true))),
                const SizedBox(width: 4),
                Expanded(child: _seg('Absent ($absentCount)', Icons.cancel_rounded, red, !showPresent,
                    () => setState(() => showPresent = false))),
              ],
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final l in ['All', 'English', 'Hindi'])
                  _chip(l == 'All' ? 'All languages' : l, language == l, () => setState(() => language = l)),
                _divider(),
                for (final m in ['All', 'online', 'offline'])
                  _chip(m == 'All' ? 'Online + offline' : (m == 'online' ? '🌐 Online' : '🏫 Offline'), mode == m,
                      () => setState(() => mode = m)),
              ],
            ),
          ),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var n = 0; n <= 7; n++)
                  _chip(n == 0 ? 'All stages' : 'Stage $n', stage == n, () => setState(() => stage = n)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            onChanged: (v) => setState(() => search = v),
            style: GoogleFonts.poppins(fontSize: 12.5, color: textColor),
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Search name or phone',
              hintStyle: GoogleFonts.poppins(fontSize: 12, color: secondaryText),
              prefixIcon: const Icon(Icons.search_rounded, size: 20, color: secondaryText),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 11),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: borderColor)),
              enabledBorder:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: borderColor)),
            ),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _seg(String text, IconData icon, Color color, bool selected, VoidCallback onTap) => InkWell(
        borderRadius: BorderRadius.circular(11),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(color: selected ? color : Colors.transparent, borderRadius: BorderRadius.circular(11)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: selected ? Colors.white : color),
              const SizedBox(width: 6),
              Text(text,
                  style: GoogleFonts.poppins(
                      fontSize: 12, fontWeight: FontWeight.w800, color: selected ? Colors.white : textColor)),
            ],
          ),
        ),
      );

  Widget _chip(String text, bool selected, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.only(right: 6),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: selected ? textColor : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: selected ? textColor : borderColor),
            ),
            child: Text(text,
                style: GoogleFonts.poppins(
                    fontSize: 11.5, fontWeight: FontWeight.w600, color: selected ? Colors.white : textColor)),
          ),
        ),
      );

  Widget _divider() => Container(width: 1, height: 22, color: borderColor, margin: const EdgeInsets.only(right: 6));

  Widget _groupHeader(_Row r) {
    final total = r.present + r.absent;
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 6),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(color: blue.withOpacity(.10), borderRadius: BorderRadius.circular(8)),
            child: Text(r.title, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w800, color: blue)),
          ),
          const SizedBox(width: 8),
          Text('✓ ${r.present}', style: GoogleFonts.poppins(fontSize: 11.5, fontWeight: FontWeight.w700, color: green)),
          const SizedBox(width: 8),
          Text('✗ ${r.absent}', style: GoogleFonts.poppins(fontSize: 11.5, fontWeight: FontWeight.w700, color: red)),
          const Spacer(),
          Text(total == 0 ? '' : '${(r.present * 100 / total).round()}%',
              style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: secondaryText)),
        ],
      ),
    );
  }

  Color _statusColor(String s) => s == 'Present'
      ? green
      : s == 'Late'
          ? amber
          : s == 'Partial'
              ? blue
              : red;

  String _time(dynamic iso) {
    if (iso == null) return '';
    final t = DateTime.tryParse(iso.toString())?.toLocal();
    if (t == null) return '';
    final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
    return '$h:${t.minute.toString().padLeft(2, '0')} ${t.hour >= 12 ? 'PM' : 'AM'}';
  }

  Widget _personTile(Map<String, dynamic> p) {
    final present = p['present'] == true;
    final status = (p['status'] ?? 'Absent').toString();
    final name = (p['name'] ?? '').toString();
    final offline = p['mode'] == 'offline';
    final section = (p['section'] ?? '').toString();
    final minutes = (p['minutes'] ?? 0) as num;
    final joined = _time(p['joinedAt']);
    final inClass = p['inClass'] == true;
    final details = <String>[
      (p['phone'] ?? '').toString(),
      if (present && joined.isNotEmpty) 'joined $joined',
      if (present && minutes > 0) '$minutes min',
      if (section.isNotEmpty && section != 'None') 'Sec $section',
    ].where((s) => s.isNotEmpty).join(' • ');

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: (present ? green : red).withOpacity(.12),
                child: Text(name.isEmpty ? '?' : name[0].toUpperCase(),
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w800, color: present ? green : red)),
              ),
              if (inClass)
                Positioned(
                  right: -1,
                  bottom: -1,
                  child: Container(
                    width: 11,
                    height: 11,
                    decoration: BoxDecoration(
                      color: green,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: textColor)),
                Text(details,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(fontSize: 10.5, color: secondaryText)),
              ],
            ),
          ),
          const SizedBox(width: 6),
          _tag(offline ? 'Offline' : 'Online', offline ? amber : blue),
          const SizedBox(width: 4),
          _tag(inClass ? 'In class' : status, inClass ? green : _statusColor(status)),
        ],
      ),
    );
  }

  Widget _tag(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(color: color.withOpacity(.12), borderRadius: BorderRadius.circular(7)),
        child: Text(text, style: GoogleFonts.poppins(fontSize: 9.5, fontWeight: FontWeight.w700, color: color)),
      );

  Widget _message(IconData icon, String title, String sub, {bool retry = false}) => Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: secondaryText),
            const SizedBox(height: 10),
            Text(title, style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w800, color: textColor)),
            const SizedBox(height: 4),
            Text(sub, textAlign: TextAlign.center, style: GoogleFonts.poppins(fontSize: 12, color: secondaryText)),
            if (retry) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(onPressed: _load, icon: const Icon(Icons.refresh_rounded), label: const Text('Try again')),
            ],
          ],
        ),
      );
}

class _Row {
  final bool isHeader;
  final String title;
  final int present;
  final int absent;
  final Map<String, dynamic>? person;

  _Row.header(this.title, this.present, this.absent)
      : isHeader = true,
        person = null;

  _Row.person(Map<String, dynamic> p)
      : isHeader = false,
        title = '',
        present = 0,
        absent = 0,
        person = p;
}
