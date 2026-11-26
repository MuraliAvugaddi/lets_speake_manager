import 'dart:convert';

import 'package:lets_speake_manager/Api/admin_badges.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:lets_speake_manager/Api/ApiendPoints.dart';
import 'package:lets_speake_manager/Api/api_headers.dart';
import 'package:lets_speake_manager/Api/batch_slots.dart';
import 'package:lets_speake_manager/Navigation/AdminShellNavigation.dart';
import 'package:url_launcher/url_launcher.dart';

const Color _primary = Color(0xFF0F5A87);
const Color _teal = Color(0xFF28C2C2);
const Color _bg = Color(0xFFF0F5F9);
const Color _soft = Color(0xFFF5F9FC);
const Color _text = Color(0xFF173E5C);
const Color _muted = Color(0xFF6A8295);
const Color _border = Color(0xFFDDE8F0);
const Color _green = Color(0xFF16A34A);
const Color _amber = Color(0xFFD97706);
const Color _purple = Color(0xFF7C3AED);
const Color _orange = Color(0xFFE07A3F);
const Color _red = Color(0xFFDC2626);
const Color _wa = Color(0xFF25D366);

// ======================================================================
// helpers
// ======================================================================
String _ymd(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

DateTime _today() {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day);
}

/// class day of a request ("2026-11-27"); old requests → day it was sent
String _day(Map<String, dynamic> r) {
  final f = '${r['forDate'] ?? ''}';
  if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(f)) return f;
  final t = DateTime.tryParse('${r['createdAt'] ?? r['lastActivityAt'] ?? ''}')?.toLocal();
  return t == null ? '' : _ymd(t);
}

String _dayTitle(String ymd) {
  final d = DateTime.tryParse(ymd);
  if (d == null) return 'Earlier';
  final diff = DateTime(d.year, d.month, d.day).difference(_today()).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Tomorrow';
  if (diff == -1) return 'Yesterday';
  return DateFormat(d.year == DateTime.now().year ? 'EEE, d MMM' : 'EEE, d MMM yyyy').format(d);
}

String _when(String iso) {
  final t = DateTime.tryParse(iso)?.toLocal();
  if (t == null) return '';
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return 'Just now';
  if (d.inMinutes < 60) return '${d.inMinutes} min ago';
  if (_ymd(t) == _ymd(DateTime.now())) return DateFormat('h:mm a').format(t);
  return DateFormat('d MMM, h:mm a').format(t);
}

String _time(String iso) {
  final t = DateTime.tryParse(iso)?.toLocal();
  return t == null ? '' : DateFormat('h:mm a').format(t);
}

int _batchMin(Map<String, dynamic> r) => BatchSlots.find(r['batchTime'])?.startMinutes ?? 9999;

Color _statusColor(String s) => s == 'escalated'
    ? _purple
    : s == 'accepted'
        ? _green
        : s == 'solved'
            ? _teal
            : _amber;

String _statusText(String s) => s == 'escalated'
    ? 'Needs manager'
    : s == 'accepted'
        ? 'Accepted'
        : s == 'solved'
            ? 'Solved'
            : 'Waiting for trainer';

IconData _statusIcon(String s) => s == 'escalated'
    ? Icons.support_agent_rounded
    : s == 'accepted'
        ? Icons.check_circle_rounded
        : s == 'solved'
            ? Icons.verified_rounded
            : Icons.hourglass_top_rounded;

(String, IconData, Color) _type(String t) => t == 'other_batch'
    ? ('Join another batch', Icons.swap_horiz_rounded, _primary)
    : t == 'absent'
        ? ("Can't attend", Icons.event_busy_rounded, _orange)
        : ('Other', Icons.chat_bubble_outline_rounded, const Color(0xFF0E9AA7));

Widget _statusBadge(String s) {
  final c = _statusColor(s);
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(color: c.withValues(alpha: .12), borderRadius: BorderRadius.circular(20)),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(_statusIcon(s), size: 12, color: c),
        const SizedBox(width: 4),
        Text(_statusText(s), style: GoogleFonts.poppins(color: c, fontSize: 10.5, fontWeight: FontWeight.w700)),
      ],
    ),
  );
}

Widget _tag(IconData icon, String text, Color c) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: c.withValues(alpha: .10), borderRadius: BorderRadius.circular(8)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: c),
          const SizedBox(width: 4),
          Text(text, style: GoogleFonts.poppins(color: c, fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );

Widget _batchLine(Map<String, dynamic> r) {
  final mine = BatchSlots.find(r['batchTime'])?.shortLabel ?? '';
  final want = BatchSlots.find(r['preferredBatch'])?.shortLabel ?? '';
  Widget pill(String t, Color c, {bool strike = false}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: c.withValues(alpha: .10), borderRadius: BorderRadius.circular(8)),
        child: Text(
          t,
          style: GoogleFonts.poppins(
            color: c,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            decoration: strike ? TextDecoration.lineThrough : null,
          ),
        ),
      );
  if (mine.isEmpty && want.isEmpty) return const SizedBox.shrink();
  return Wrap(
    crossAxisAlignment: WrapCrossAlignment.center,
    spacing: 6,
    runSpacing: 4,
    children: [
      const Icon(Icons.schedule_rounded, size: 14, color: _muted),
      if (mine.isNotEmpty) pill(mine, _muted, strike: want.isNotEmpty || r['type'] == 'absent'),
      if (want.isNotEmpty) ...[
        const Icon(Icons.arrow_forward_rounded, size: 14, color: _muted),
        pill(want, const Color(0xFF0B8E8F)),
      ],
    ],
  );
}

Widget _contactBtn(IconData icon, Color color, VoidCallback onTap, {String tip = ''}) => Tooltip(
      message: tip,
      child: Material(
        color: color.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: SizedBox(width: 38, height: 34, child: Icon(icon, color: color, size: 18)),
        ),
      ),
    );

String _digits(String p) {
  final d = p.replaceAll(RegExp(r'\D'), '');
  return d.length == 10 ? '91$d' : d;
}

Future<void> callStudent(String phone) async {
  await launchUrl(Uri(scheme: 'tel', path: phone));
}

Future<void> whatsappStudent(String phone, String name) async {
  final msg = Uri.encodeComponent("Hello $name, this is Let's Speak about your class request.");
  await launchUrl(Uri.parse('https://wa.me/${_digits(phone)}?text=$msg'), mode: LaunchMode.externalApplication);
}

// ======================================================================
// 🙋 STUDENT REQUESTS — manager view
//   • filters: status • online/offline • language • stage • section • batch • date (calendar)
//   • grouped by class day (or by batch)
//   • phone + WhatsApp → call, solve, "Mark solved" → student + trainer notified
// ======================================================================
class AdminRequestsScreen extends StatefulWidget {
  const AdminRequestsScreen({super.key});

  @override
  State<AdminRequestsScreen> createState() => _AdminRequestsScreenState();
}

class _AdminRequestsScreenState extends State<AdminRequestsScreen> {
  String status = 'escalated';
  String mode = 'all';
  String language = 'all';
  String stage = '';
  String section = '';
  String batch = '';
  String datePreset = 'all'; // all | today | tomorrow | yesterday | week | custom
  DateTimeRange? range;
  bool byBatch = false;

  bool loading = false;
  List<Map<String, dynamic>> rows = [];
  Map<String, dynamic> counts = {};

  static const _sections = ['A', 'B', 'C', 'D', 'E'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  bool get _hasFilters =>
      mode != 'all' || language != 'all' || stage.isNotEmpty || section.isNotEmpty || batch.isNotEmpty || datePreset != 'all';

  (String, String) get _dates {
    final t = _today();
    switch (datePreset) {
      case 'today':
        return (_ymd(t), _ymd(t));
      case 'tomorrow':
        final d = t.add(const Duration(days: 1));
        return (_ymd(d), _ymd(d));
      case 'yesterday':
        final d = t.subtract(const Duration(days: 1));
        return (_ymd(d), _ymd(d));
      case 'week':
        return (_ymd(t.subtract(const Duration(days: 6))), _ymd(t));
      case 'custom':
        if (range != null) return (_ymd(range!.start), _ymd(range!.end));
        return ('', '');
      default:
        return ('', '');
    }
  }

  Future<void> _load() async {
    setState(() => loading = true);
    try {
      final (from, to) = _dates;
      final qp = <String, String>{
        'status': status,
        if (mode != 'all') 'mode': mode,
        if (language != 'all') 'language': language,
        if (stage.isNotEmpty) 'stage': stage,
        if (section.isNotEmpty) 'section': section,
        if (batch.isNotEmpty) 'batch': batch,
        if (from.isNotEmpty) 'from': from,
        if (to.isNotEmpty) 'to': to,
        '_t': '${DateTime.now().millisecondsSinceEpoch}',
      };
      final uri = Uri.parse('${ApiEndpoints.requests}/manager').replace(queryParameters: qp);
      final res = await http.get(uri, headers: ApiHeaders.auth()).timeout(const Duration(seconds: 20));
      if (!mounted) return;
      if (res.statusCode == 200) {
        final d = jsonDecode(res.body);
        setState(() {
          rows = ((d['requests'] as List?) ?? const []).whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();
          counts = Map<String, dynamic>.from((d['counts'] as Map?) ?? {});
        });
      }
    } catch (_) {
      if (mounted) {
        Get.snackbar('Connection error', 'Unable to connect to the server.', backgroundColor: _red, colorText: Colors.white);
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _set(VoidCallback f) {
    setState(f);
    _load();
  }

  Future<void> _pickRange() async {
    final t = _today();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(t.year - 1),
      lastDate: t.add(const Duration(days: 31)),
      initialDateRange: range ?? DateTimeRange(start: t.subtract(const Duration(days: 6)), end: t),
      helpText: 'Class days',
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(colorScheme: Theme.of(ctx).colorScheme.copyWith(primary: _primary)),
        child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 420, maxHeight: 640), child: child)),
      ),
    );
    if (picked != null) {
      _set(() {
        range = picked;
        datePreset = 'custom';
      });
    }
  }

  void _clear() => _set(() {
        mode = 'all';
        language = 'all';
        stage = '';
        section = '';
        batch = '';
        datePreset = 'all';
        range = null;
      });

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.sizeOf(context).width < 700;
    final total = ['open', 'accepted', 'escalated', 'solved'].fold<int>(0, (s, k) => s + ((counts[k] ?? 0) as num).toInt());

    // ---- groups ----
    final groups = <String, List<Map<String, dynamic>>>{};
    for (final r in rows) {
      final k = byBatch ? (BatchSlots.find(r['batchTime'])?.label ?? '') : _day(r);
      groups.putIfAbsent(k, () => []).add(r);
    }
    final keys = groups.keys.toList();
    if (byBatch) {
      keys.sort((a, b) => (BatchSlots.find(a)?.startMinutes ?? 9999).compareTo(BatchSlots.find(b)?.startMinutes ?? 9999));
      for (final g in groups.values) {
        g.sort((a, b) => _day(b).compareTo(_day(a)));
      }
    } else {
      keys.sort((a, b) => b.compareTo(a));
      for (final g in groups.values) {
        g.sort((a, b) => _batchMin(a).compareTo(_batchMin(b)));
      }
    }

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        leading: IconButton(onPressed: AdminShellNavigation.openDrawer, icon: AdminMenuIcon(Icons.menu_rounded, color: _text)),
        titleSpacing: 0,
        title: Text(
          'Student Requests',
          style: GoogleFonts.poppins(color: _text, fontSize: isMobile ? 16 : 18, fontWeight: FontWeight.w700),
        ),
        actions: [
          if (loading)
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: _primary))),
            ),
          IconButton(onPressed: loading ? null : _load, icon: const Icon(Icons.refresh_rounded, color: _text)),
          const SizedBox(width: 6),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 28, vertical: 16),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ---- status cards ----
                    LayoutBuilder(builder: (_, c) {
                      final cols = c.maxWidth < 560 ? 2 : 5;
                      final w = (c.maxWidth - (cols - 1) * 10) / cols;
                      return Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _statCard(w, 'escalated', 'Needs manager', Icons.support_agent_rounded, _purple),
                          _statCard(w, 'open', 'Waiting for trainer', Icons.hourglass_top_rounded, _amber),
                          _statCard(w, 'accepted', 'Accepted', Icons.check_circle_rounded, _green),
                          _statCard(w, 'solved', 'Solved', Icons.verified_rounded, _teal),
                          _statCard(w, 'all', 'All', Icons.all_inbox_rounded, _primary, count: total),
                        ],
                      );
                    }),
                    const SizedBox(height: 14),

                    // ---- filters ----
                    _filtersCard(isMobile),
                    const SizedBox(height: 14),

                    // ---- results header ----
                    Row(
                      children: [
                        Text(
                          '${rows.length} request${rows.length == 1 ? '' : 's'}',
                          style: GoogleFonts.poppins(color: _text, fontSize: 14, fontWeight: FontWeight.w700),
                        ),
                        const Spacer(),
                        _groupToggle(),
                      ],
                    ),
                    const SizedBox(height: 4),

                    if (loading && rows.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(40),
                        child: Center(child: CircularProgressIndicator(color: _primary)),
                      )
                    else if (rows.isEmpty)
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(top: 10),
                        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: _border),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.inbox_rounded, size: 44, color: _muted.withValues(alpha: .6)),
                            const SizedBox(height: 8),
                            Text(
                              status == 'escalated' && !_hasFilters ? 'Nothing needs the manager right now 🎉' : 'No requests match these filters.',
                              style: GoogleFonts.poppins(color: _text, fontWeight: FontWeight.w600),
                            ),
                            if (_hasFilters)
                              TextButton(onPressed: _clear, child: Text('Clear filters', style: GoogleFonts.poppins(color: _primary))),
                          ],
                        ),
                      )
                    else
                      for (final k in keys) ...[
                        _groupHeader(k, groups[k]!.length),
                        LayoutBuilder(builder: (_, c) {
                          final two = c.maxWidth >= 820;
                          final w = two ? (c.maxWidth - 10) / 2 : c.maxWidth;
                          return Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [for (final r in groups[k]!) SizedBox(width: w, child: _card(r))],
                          );
                        }),
                      ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------------
  Widget _statCard(double w, String key, String label, IconData icon, Color c, {int? count}) {
    final sel = status == key;
    final n = count ?? ((counts[key] ?? 0) as num).toInt();
    return SizedBox(
      width: w,
      child: Material(
        color: sel ? c : Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _set(() => status = key),
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: sel ? c : _border),
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: sel ? Colors.white.withValues(alpha: .2) : c.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 18, color: sel ? Colors.white : c),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('$n', style: GoogleFonts.poppins(color: sel ? Colors.white : _text, fontSize: 18, fontWeight: FontWeight.w700, height: 1.1)),
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(color: sel ? Colors.white.withValues(alpha: .9) : _muted, fontSize: 11),
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

  Widget _filtersCard(bool isMobile) {
    final (from, to) = _dates;
    String rangeText() {
      if (from.isEmpty) return 'Pick dates';
      final f = DateFormat('d MMM').format(DateTime.parse(from));
      final t = DateFormat('d MMM').format(DateTime.parse(to));
      return from == to ? f : '$f – $t';
    }

    Widget dateChip(String key, String label) {
      final sel = datePreset == key;
      return InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => _set(() {
          datePreset = key;
          if (key != 'custom') range = null;
        }),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: sel ? _primary : _soft,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: sel ? _primary : _border),
          ),
          child: Text(label, style: GoogleFonts.poppins(color: sel ? Colors.white : _text, fontSize: 12, fontWeight: FontWeight.w600)),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: _border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.calendar_month_rounded, size: 17, color: _primary),
              const SizedBox(width: 6),
              Text('Class day', style: GoogleFonts.poppins(color: _text, fontSize: 13, fontWeight: FontWeight.w700)),
              const Spacer(),
              if (_hasFilters)
                TextButton.icon(
                  onPressed: _clear,
                  icon: const Icon(Icons.filter_alt_off_rounded, size: 16, color: _red),
                  label: Text('Clear filters', style: GoogleFonts.poppins(color: _red, fontSize: 12, fontWeight: FontWeight.w600)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              dateChip('all', 'All dates'),
              dateChip('today', 'Today'),
              dateChip('tomorrow', 'Tomorrow'),
              dateChip('yesterday', 'Yesterday'),
              dateChip('week', 'Last 7 days'),
              InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: _pickRange,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: datePreset == 'custom' ? _primary : _soft,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: datePreset == 'custom' ? _primary : _border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.date_range_rounded, size: 15, color: datePreset == 'custom' ? Colors.white : _primary),
                      const SizedBox(width: 6),
                      Text(
                        datePreset == 'custom' ? rangeText() : 'Calendar',
                        style: GoogleFonts.poppins(
                          color: datePreset == 'custom' ? Colors.white : _text,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (datePreset != 'all' && datePreset != 'custom' && from.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('Showing ${rangeText()}', style: GoogleFonts.poppins(color: _muted, fontSize: 11)),
            ),
          const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1, color: _border)),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _Drop(
                icon: Icons.wifi_tethering_rounded,
                label: 'Mode',
                value: mode,
                items: const [('all', 'Online & Offline'), ('online', '🌐 Online'), ('offline', '🏫 Offline')],
                onChanged: (v) => _set(() => mode = v),
              ),
              _Drop(
                icon: Icons.translate_rounded,
                label: 'Language',
                value: language,
                items: const [('all', 'All languages'), ('English', 'English'), ('Hindi', 'Hindi')],
                onChanged: (v) => _set(() => language = v),
              ),
              _Drop(
                icon: Icons.stairs_rounded,
                label: 'Stage',
                value: stage,
                items: [('', 'All stages'), for (var i = 1; i <= 7; i++) ('$i', 'Stage $i')],
                onChanged: (v) => _set(() => stage = v),
              ),
              _Drop(
                icon: Icons.groups_rounded,
                label: 'Section',
                value: section,
                items: [('', 'All sections'), for (final s in _sections) (s, 'Section $s')],
                onChanged: (v) => _set(() => section = v),
              ),
              _Drop(
                icon: Icons.schedule_rounded,
                label: 'Batch timing',
                value: batch,
                items: [('', 'All timings'), for (final b in BatchSlots.all) (b.label, '${b.title} • ${b.shortLabel}')],
                onChanged: (v) => _set(() => batch = v),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _groupToggle() => Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(color: const Color(0xFFE3ECF3), borderRadius: BorderRadius.circular(10)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final v in [false, true])
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => setState(() => byBatch = v),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(color: byBatch == v ? Colors.white : Colors.transparent, borderRadius: BorderRadius.circular(8)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(v ? Icons.access_time_rounded : Icons.calendar_today_rounded, size: 14, color: byBatch == v ? _primary : _muted),
                      const SizedBox(width: 5),
                      Text(
                        v ? 'By batch' : 'By day',
                        style: GoogleFonts.poppins(color: byBatch == v ? _primary : _muted, fontSize: 11.5, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      );

  Widget _groupHeader(String k, int n) {
    final b = BatchSlots.find(k);
    final title = byBatch ? (b?.title ?? 'No batch') : _dayTitle(k);
    final sub = byBatch
        ? (b?.shortLabel ?? '')
        : (DateTime.tryParse(k) != null ? DateFormat('EEEE, d MMMM').format(DateTime.parse(k)) : '');
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 18, 2, 10),
      child: Row(
        children: [
          Icon(byBatch ? Icons.access_time_rounded : Icons.calendar_today_rounded, size: 16, color: _primary),
          const SizedBox(width: 7),
          Text(title, style: GoogleFonts.poppins(color: _text, fontSize: 14, fontWeight: FontWeight.w700)),
          if (sub.isNotEmpty && sub != title) ...[
            const SizedBox(width: 8),
            Flexible(child: Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.poppins(color: _muted, fontSize: 12))),
          ],
          const SizedBox(width: 10),
          const Expanded(child: Divider(color: _border, height: 1)),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: _primary.withValues(alpha: .08), borderRadius: BorderRadius.circular(10)),
            child: Text('$n', style: GoogleFonts.poppins(color: _primary, fontSize: 11, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _card(Map<String, dynamic> r) {
    final s = '${r['status']}';
    final c = _statusColor(s);
    final (tLabel, tIcon, tColor) = _type('${r['type']}');
    final msgs = (r['messages'] as List?) ?? const [];
    final last = msgs.isEmpty ? <String, dynamic>{} : Map<String, dynamic>.from(msgs.last as Map);
    final name = '${r['studentName'] ?? ''}'.trim();
    final trainers = ((r['trainerNames'] as List?) ?? const []).join(', ');
    final phone = '${r['studentPhone'] ?? ''}';

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () async {
          await Get.to(() => AdminRequestDetailScreen(id: '${r['id']}'));
          _load();
        },
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: s == 'escalated' ? _purple.withValues(alpha: .45) : _border, width: s == 'escalated' ? 1.4 : 1),
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 4,
                  decoration: BoxDecoration(color: c, borderRadius: const BorderRadius.horizontal(left: Radius.circular(16))),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: _primary.withValues(alpha: .10),
                              child: Text(name.isEmpty ? '?' : name[0].toUpperCase(),
                                  style: GoogleFonts.poppins(color: _primary, fontWeight: FontWeight.w700)),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(name.isEmpty ? 'Student' : name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.poppins(color: _text, fontSize: 14.5, fontWeight: FontWeight.w700)),
                                  Text('${r['classLabel'] ?? ''}',
                                      maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.poppins(color: _muted, fontSize: 11)),
                                ],
                              ),
                            ),
                            _statusBadge(s),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            _tag(tIcon, tLabel, tColor),
                            if (_day(r).isNotEmpty) _tag(Icons.event_rounded, _dayTitle(_day(r)), _primary),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _batchLine(r),
                        const SizedBox(height: 8),
                        Text(
                          trainers.isEmpty ? 'Trainer: — (none set)' : 'Trainer: $trainers',
                          style: GoogleFonts.poppins(color: _muted, fontSize: 11),
                        ),
                        if ('${last['text'] ?? ''}'.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(9),
                            decoration: BoxDecoration(color: _soft, borderRadius: BorderRadius.circular(10)),
                            child: Text(
                              '${last['byName'] ?? ''}: ${last['text']}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(color: _text, fontSize: 12, height: 1.4),
                            ),
                          ),
                        ],
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            const Icon(Icons.update_rounded, size: 13, color: _muted),
                            const SizedBox(width: 4),
                            Text(_when('${r['lastActivityAt']}'), style: GoogleFonts.poppins(color: _muted, fontSize: 11)),
                            const Spacer(),
                            if (phone.isNotEmpty) ...[
                              _contactBtn(Icons.call_rounded, _primary, () => callStudent(phone), tip: 'Call $phone'),
                              const SizedBox(width: 6),
                              _contactBtn(Icons.chat_rounded, _wa, () => whatsappStudent(phone, name), tip: 'WhatsApp'),
                            ],
                          ],
                        ),
                      ],
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
}

/// compact labelled dropdown:  [icon  Label: Value ▾]
class _Drop extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final List<(String, String)> items;
  final ValueChanged<String> onChanged;
  const _Drop({required this.icon, required this.label, required this.value, required this.items, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final current = items.firstWhere((e) => e.$1 == value, orElse: () => items.first);
    final active = value != items.first.$1;
    return PopupMenuButton<String>(
      tooltip: label,
      onSelected: onChanged,
      position: PopupMenuPosition.under,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      itemBuilder: (_) => [
        for (final e in items)
          PopupMenuItem<String>(
            value: e.$1,
            height: 40,
            child: Row(
              children: [
                SizedBox(
                  width: 22,
                  child: e.$1 == value ? const Icon(Icons.check_rounded, size: 16, color: _primary) : null,
                ),
                Text(e.$2, style: GoogleFonts.poppins(fontSize: 12.5, color: _text, fontWeight: e.$1 == value ? FontWeight.w700 : FontWeight.w400)),
              ],
            ),
          ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: active ? _primary.withValues(alpha: .08) : _soft,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: active ? _primary : _border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: active ? _primary : _muted),
            const SizedBox(width: 6),
            Text('$label: ', style: GoogleFonts.poppins(color: _muted, fontSize: 12)),
            Text(current.$2, style: GoogleFonts.poppins(color: active ? _primary : _text, fontSize: 12, fontWeight: FontWeight.w700)),
            const SizedBox(width: 2),
            Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: active ? _primary : _muted),
          ],
        ),
      ),
    );
  }
}

// ======================================================================
// one request: details + chat + phone + Mark solved
// ======================================================================
class AdminRequestDetailScreen extends StatefulWidget {
  final String id;
  const AdminRequestDetailScreen({super.key, required this.id});

  @override
  State<AdminRequestDetailScreen> createState() => _AdminRequestDetailScreenState();
}

class _AdminRequestDetailScreenState extends State<AdminRequestDetailScreen> {
  Map<String, dynamic>? r;
  bool busy = false;
  final ctrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    ctrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final res = await http
          .get(Uri.parse('${ApiEndpoints.requests}/${widget.id}'), headers: ApiHeaders.auth())
          .timeout(const Duration(seconds: 20));
      if (res.statusCode == 200 && mounted) {
        setState(() => r = Map<String, dynamic>.from(jsonDecode(res.body)['request'] as Map));
      }
    } catch (_) {}
  }

  Future<void> _post(String path, String text, String done) async {
    setState(() => busy = true);
    try {
      final res = await http
          .post(
            Uri.parse('${ApiEndpoints.requests}/${widget.id}/$path'),
            headers: ApiHeaders.json(),
            body: jsonEncode({'text': text}),
          )
          .timeout(const Duration(seconds: 20));
      if (res.statusCode == 200) {
        ctrl.clear();
        await _load();
        Get.snackbar('Done', done, backgroundColor: _green, colorText: Colors.white, margin: const EdgeInsets.all(16));
      } else {
        String m = 'Something went wrong';
        try {
          m = jsonDecode(res.body)['message'] ?? m;
        } catch (_) {}
        Get.snackbar('Not done', m, backgroundColor: _red, colorText: Colors.white, margin: const EdgeInsets.all(16));
      }
    } catch (_) {
      Get.snackbar('Connection error', 'Unable to connect to the server.', backgroundColor: _red, colorText: Colors.white);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _solve() async {
    final c = TextEditingController();
    final want = BatchSlots.find(r?['preferredBatch'])?.shortLabel ?? '';
    final quick = [
      if (want.isNotEmpty) 'Moved to the $want batch for ${_dayTitle(_day(r ?? const {})).toLowerCase()}',
      'Called the student — sorted',
      'Leave approved',
    ];
    final ok = await Get.dialog<bool>(
      StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Row(
            children: [
              const Icon(Icons.verified_rounded, color: _green),
              const SizedBox(width: 8),
              Text('Mark as solved?', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 17)),
            ],
          ),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Student and trainer get a notification.', style: GoogleFonts.poppins(color: _muted, fontSize: 12)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final q in quick)
                      ActionChip(
                        label: Text(q, style: GoogleFonts.poppins(fontSize: 11.5, color: _text)),
                        backgroundColor: _soft,
                        side: const BorderSide(color: _border),
                        onPressed: () => setS(() => c.text = q),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: c,
                  minLines: 2,
                  maxLines: 4,
                  style: GoogleFonts.poppins(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'What was done?',
                    filled: true,
                    fillColor: _soft,
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _border)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _green, width: 1.5)),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Get.back(result: false), child: Text('Cancel', style: GoogleFonts.poppins(color: _muted))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _green,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => Get.back(result: true),
              child: Text('Mark solved', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
    if (ok == true) _post('solve', c.text.trim(), 'Solved ✅ — student and trainer were notified');
  }

  @override
  Widget build(BuildContext context) {
    final msgs = ((r?['messages'] as List?) ?? const []).map((m) => Map<String, dynamic>.from(m as Map)).toList();
    final solved = r?['status'] == 'solved';
    final phone = '${r?['studentPhone'] ?? ''}';
    final name = '${r?['studentName'] ?? ''}'.trim();

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        foregroundColor: _text,
        elevation: 0,
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 17,
              backgroundColor: _primary.withValues(alpha: .10),
              child: Text(name.isEmpty ? '?' : name[0].toUpperCase(), style: GoogleFonts.poppins(color: _primary, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name.isEmpty ? 'Request' : name, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700)),
                  Text('${r?['classLabel'] ?? ''}', style: GoogleFonts.poppins(fontSize: 11, color: _muted)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (phone.isNotEmpty) ...[
            _contactBtn(Icons.call_rounded, _primary, () => callStudent(phone), tip: 'Call $phone'),
            const SizedBox(width: 6),
            _contactBtn(Icons.chat_rounded, _wa, () => whatsappStudent(phone, name), tip: 'WhatsApp'),
            const SizedBox(width: 12),
          ],
        ],
      ),
      body: r == null
          ? const Center(child: CircularProgressIndicator(color: _primary))
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 860),
                child: Column(
                  children: [
                    _details(phone),
                    Expanded(child: _messages(msgs)),
                    if (!solved) _composer() else _solvedBar(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _details(String phone) {
    final s = '${r!['status']}';
    final (tLabel, tIcon, tColor) = _type('${r!['type']}');
    final day = _day(r!);
    final trainers = ((r!['trainerNames'] as List?) ?? const []).join(', ');
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: _border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _tag(tIcon, tLabel, tColor),
                    if (day.isNotEmpty)
                      _tag(
                        Icons.event_rounded,
                        '${_dayTitle(day)}${['Today', 'Tomorrow', 'Yesterday'].contains(_dayTitle(day)) ? ' • ${DateFormat('EEE, d MMM').format(DateTime.parse(day))}' : ''}',
                        _primary,
                      ),
                  ],
                ),
              ),
              _statusBadge(s),
            ],
          ),
          const SizedBox(height: 10),
          _batchLine(r!),
          const SizedBox(height: 10),
          Wrap(
            spacing: 22,
            runSpacing: 8,
            children: [
              _info('Trainer', trainers.isEmpty ? '— (none set)' : trainers),
              if (phone.isNotEmpty) _info('Phone', phone),
              if ('${r!['acceptedByName'] ?? ''}'.isNotEmpty) _info('Accepted by', '${r!['acceptedByName']}'),
              if ('${r!['escalatedByName'] ?? ''}'.isNotEmpty) _info('Sent to manager by', '${r!['escalatedByName']}'),
              if ('${r!['solvedByName'] ?? ''}'.isNotEmpty) _info('Solved by', '${r!['solvedByName']}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _messages(List<Map<String, dynamic>> msgs) {
    final rows = <Widget>[];
    String lastDay = '';
    for (final m in msgs) {
      final t = DateTime.tryParse('${m['at']}')?.toLocal();
      final d = t == null ? '' : _ymd(t);
      if (d.isNotEmpty && d != lastDay) {
        lastDay = d;
        rows.add(Center(
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 10),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(color: _border, borderRadius: BorderRadius.circular(10)),
            child: Text(_dayTitle(d), style: GoogleFonts.poppins(color: _muted, fontSize: 10.5, fontWeight: FontWeight.w600)),
          ),
        ));
      }
      rows.add(_bubble(m));
    }
    return ListView(reverse: true, padding: const EdgeInsets.fromLTRB(12, 8, 12, 12), children: rows.reversed.toList());
  }

  Widget _bubble(Map<String, dynamic> m) {
    final role = '${m['role']}';
    if (role == 'system') {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Center(
          child: Text('${m['text']}', textAlign: TextAlign.center, style: GoogleFonts.poppins(color: _muted, fontSize: 11, fontStyle: FontStyle.italic)),
        ),
      );
    }
    final mine = role == 'manager' || role == 'admin';
    final c = role == 'student' ? const Color(0xFF0B8E8F) : (role == 'teacher' ? _primary : _purple);
    final who = '${m['byName']} • ${role == 'student' ? 'Student' : role == 'teacher' ? 'Trainer' : 'Manager'}';
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
        constraints: const BoxConstraints(maxWidth: 560),
        decoration: BoxDecoration(
          color: mine ? _purple : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(mine ? 16 : 4),
            bottomRight: Radius.circular(mine ? 4 : 16),
          ),
          border: mine ? null : Border.all(color: c.withValues(alpha: .30)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(who, style: GoogleFonts.poppins(color: mine ? Colors.white70 : c, fontSize: 10.5, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            SelectableText('${m['text']}', style: GoogleFonts.poppins(color: mine ? Colors.white : _text, fontSize: 13, height: 1.4)),
            const SizedBox(height: 2),
            Align(
              alignment: Alignment.bottomRight,
              child: Text(_time('${m['at']}'), style: GoogleFonts.poppins(color: mine ? Colors.white60 : _muted, fontSize: 9.5)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _composer() => Container(
        decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: _border))),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: SafeArea(
          top: false,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: ctrl,
                  minLines: 1,
                  maxLines: 4,
                  style: GoogleFonts.poppins(fontSize: 13.5, color: _text),
                  decoration: InputDecoration(
                    hintText: 'Reply (student and trainer see it)…',
                    hintStyle: GoogleFonts.poppins(fontSize: 13, color: _muted),
                    filled: true,
                    fillColor: _soft,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 46,
                height: 46,
                child: IconButton.filled(
                  style: IconButton.styleFrom(backgroundColor: _teal),
                  onPressed: busy
                      ? null
                      : () {
                          final t = ctrl.text.trim();
                          if (t.isNotEmpty) _post('reply', t, 'Reply sent');
                        },
                  icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: busy ? null : _solve,
                icon: const Icon(Icons.verified_rounded, size: 18),
                label: Text('Mark solved', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _green,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  minimumSize: const Size(0, 46),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      );

  Widget _solvedBar() => Container(
        width: double.infinity,
        color: Colors.white,
        padding: const EdgeInsets.all(14),
        child: Text(
          '✅ Solved by ${r!['solvedByName'] ?? 'manager'}',
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(color: _green, fontWeight: FontWeight.w700),
        ),
      );

  Widget _info(String k, String v) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(k.toUpperCase(), style: GoogleFonts.poppins(color: _muted, fontSize: 9.5, fontWeight: FontWeight.w700, letterSpacing: .8)),
          Text(v, style: GoogleFonts.poppins(color: _text, fontSize: 12.5, fontWeight: FontWeight.w600)),
        ],
      );
}
