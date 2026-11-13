// =========================================================================
// 🎓 PROMOTE STUDENTS — move a whole class to the next stage in one go
//
//   1. pick English / Hindi + the FINISHED stage (each stage shows how many students)
//   2. Filter (side panel, like Fees): Online/Offline • Section • Timing • Attendance • Two stages
//      or tap a timing chip on top. Students are grouped by timing.
//   Top numbers: Left to promote • Promoted • Dropped  (tap Left / Promoted to switch the list)
//   ⋮ on a student: Open student • Mark as dropout
//   3. tick students (or "Select" a whole timing) → "Promote" →
//        • old stage  = study material only (no join class, no attendance, no tests)
//        • next stage = live class, attendance, tests, reminders (same timing)
//        • Stage 7    = course completed (all material open, no live class)
//
// A student may study TWO stages at two timings (Stage 1 at 5:30 AM + Stage 2 at 3:30 PM).
// They show "Also in Stage 2". Tick them only when this stage is really finished →
// only this stage closes, the other stays as it is. Nobody is ticked by itself.
// =========================================================================
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:lets_speake_manager/Api/ApiendPoints.dart';
import 'package:lets_speake_manager/Api/api_headers.dart';
import 'package:lets_speake_manager/Api/admin_live.dart';
import 'package:lets_speake_manager/Api/batch_slots.dart';
import 'package:lets_speake_manager/Navigation/AdminShellNavigation.dart';
import 'package:lets_speake_manager/screens/AdminDropoutsScreen.dart';

const Color _text = Color(0xFF173A52);
const Color _secondary = Color(0xFF6B8496);
const Color _border = Color(0xFFD5E5EE);
const Color _bg = Color(0xFFF5FAFD);
const Color _soft = Color(0xFFEAF4FA);
const Color _navy = Color(0xFF0A4A75);
const Color _deepNavy = Color(0xFF06324F);
const Color _blue = Color(0xFF2E86C9);
const Color _green = Color(0xFF16A66A);
const Color _red = Color(0xFFE45757);
const Color _amber = Color(0xFFE59E1B);
const Color _offline = Color(0xFF9A7500);
const Color _yellow = Color(0xFFF7DF55);

const String _noTiming = '__none__';

class AdminPromoteScreen extends StatefulWidget {
  final bool embedded; // inside the admin shell (sidebar / drawer)
  const AdminPromoteScreen({super.key, this.embedded = false});

  @override
  State<AdminPromoteScreen> createState() => _AdminPromoteScreenState();
}

class _AdminPromoteScreenState extends State<AdminPromoteScreen> {
  // what to promote
  String _language = 'English';
  int _stage = 1;

  // filters (all on this phone — no reload needed)
  String _mode = 'all'; // all | online | offline
  String _section = 'all'; // all | A..E
  String _timing = 'all'; // all | batch label | _noTiming
  String _att = 'all'; // all | good | mid | low | new
  String _both = 'all'; // all | both | only
  final TextEditingController _search = TextEditingController();

  String _view =
      'left'; // left = still in this stage • promoted = already finished it
  Map<String, dynamic> _summary = {};
  bool _loading = true;
  bool _saving = false;
  List<Map<String, dynamic>> _rows = [];
  Map<String, dynamic> _stageCounts = {};
  final Set<String> _picked = {};
  int _loadId = 0;
  void Function()? _stopLive;

  @override
  void initState() {
    super.initState();
    _load();
    // a student changed somewhere else (access / dropout / promote) → list updates by itself
    _stopLive = AdminLive.on(['student_update', 'dropout_update'], () {
      if (!_saving) _load(quiet: true);
    });
  }

  @override
  void dispose() {
    _search.dispose();
    _stopLive?.call();
    super.dispose();
  }

  String get _stageKey => 'stage$_stage';
  bool get _last => _stage >= 7;
  bool get _promotedView => _view == 'promoted';

  // ------------------------------------------------------------------ data
  Future<void> _load({bool quiet = false}) async {
    final id = ++_loadId;
    if (!quiet) {
      setState(() {
        _loading = true;
        _picked.clear();
      });
    }
    try {
      final uri = Uri.parse(ApiEndpoints.promoteCandidates).replace(
        queryParameters: {
          'language': _language,
          'stage': _stageKey,
          if (_promotedView) 'view': 'promoted',
          '_t': '${DateTime.now().millisecondsSinceEpoch}',
        },
      );
      final res = await http
          .get(uri, headers: ApiHeaders.auth())
          .timeout(const Duration(seconds: 25));
      if (id != _loadId || !mounted) return;
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        _rows = ((data['students'] ?? []) as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        if (data['stageCounts'] is Map)
          _stageCounts = Map<String, dynamic>.from(data['stageCounts']);
        if (data['summary'] is Map)
          _summary = Map<String, dynamic>.from(data['summary']);
        final ids = _rows.map(_idOf).toSet();
        _picked.removeWhere((x) => !ids.contains(x));
      } else {
        _toast('Could not load students (${res.statusCode})', _red);
      }
    } catch (e) {
      if (id == _loadId) _toast('No internet / server not reachable', _red);
    }
    if (id == _loadId && mounted) setState(() => _loading = false);
  }

  void _toast(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        content: Text(
          msg,
          style: GoogleFonts.poppins(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------------ helpers
  String _idOf(Map s) => '${s['_id'] ?? s['id']}';
  String _modeOf(Map s) =>
      (s['mode'] ?? '').toString().toLowerCase() == 'offline'
      ? 'offline'
      : 'online';
  String _sectionOf(Map s) =>
      (s['onlineSection'] ?? '').toString().toUpperCase();
  String _timingOf(Map s) {
    final l = BatchSlots.labelOf(s['batch']);
    return l.isEmpty ? _noTiming : l;
  }

  int _pctOf(Map s) => ((s['percent'] ?? 0) as num).toInt();
  int _classesOf(Map s) => ((s['classesInStage'] ?? 0) as num).toInt();
  List<String> _alsoIn(Map s) => (s['alreadyIn'] as List? ?? [])
      .map((e) => e.toString().replaceAll('stage', 'Stage '))
      .toList();

  String _attOf(Map s) {
    if (_classesOf(s) == 0) return 'new';
    final p = _pctOf(s);
    return p >= 75 ? 'good' : (p >= 50 ? 'mid' : 'low');
  }

  String _timingLabel(String t) =>
      t == _noTiming ? 'No timing set' : BatchSlots.shortOf(t);

  int _timingOrder(String t) {
    if (t == _noTiming) return 99999;
    final i = BatchSlots.all.indexWhere((b) => b.label == t);
    return i < 0 ? 9999 : i;
  }

  bool _passes(
    Map s, {
    required String mode,
    required String section,
    required String timing,
    required String att,
    required String both,
    String skip = '',
  }) {
    if (skip != 'mode' && mode != 'all' && _modeOf(s) != mode) return false;
    if (skip != 'section' &&
        section != 'all' &&
        !(_modeOf(s) == 'online' && _sectionOf(s) == section))
      return false;
    if (skip != 'timing' && timing != 'all' && _timingOf(s) != timing)
      return false;
    if (skip != 'att' && att != 'all' && _attOf(s) != att) return false;
    if (skip != 'both' && both != 'all') {
      final has = _alsoIn(s).isNotEmpty;
      if (both == 'both' && !has) return false;
      if (both == 'only' && has) return false;
    }
    final q = _search.text.trim().toLowerCase();
    if (q.isNotEmpty) {
      final name = (s['name'] ?? '').toString().toLowerCase();
      final phone = (s['phone'] ?? '').toString();
      if (!name.contains(q) && !phone.contains(q)) return false;
    }
    return true;
  }

  bool _shown(Map s, {String skip = ''}) => _passes(
    s,
    mode: _mode,
    section: _section,
    timing: _timing,
    att: _att,
    both: _both,
    skip: skip,
  );

  int get _activeFilters =>
      [_mode, _section, _timing, _att, _both].where((e) => e != 'all').length;

  void _clearFilters() => setState(() {
    _mode = 'all';
    _section = 'all';
    _timing = 'all';
    _att = 'all';
    _both = 'all';
    _search.clear();
  });

  Color _pctColor(int p) => p >= 75 ? _green : (p >= 50 ? _amber : _red);

  // ------------------------------------------------------------------ ⋮ menu actions
  /// The list has only a few fields → get the full student before opening / dropping
  Future<Map<String, dynamic>?> _fullStudent(String id) async {
    try {
      final res = await http
          .get(
            Uri.parse(
              '${ApiEndpoints.baseUrl}/admin/student/$id?_t=${DateTime.now().millisecondsSinceEpoch}',
            ),
            headers: ApiHeaders.auth(),
          )
          .timeout(const Duration(seconds: 20));
      if (res.statusCode != 200) {
        _toast('Could not open the student (${res.statusCode})', _red);
        return null;
      }
      final body = jsonDecode(res.body);
      final u = body is Map && body['user'] is Map ? body['user'] : body;
      return u is Map ? Map<String, dynamic>.from(u) : null;
    } catch (_) {
      _toast('No internet / server not reachable', _red);
      return null;
    }
  }

  Future<void> _openStudent(Map<String, dynamic> s) async {
    final u = await _fullStudent(_idOf(s));
    if (u == null || !mounted) return;
    AdminShellNavigation.openUserControl(u);
  }

  Future<void> _dropout(Map<String, dynamic> s) async {
    final u = await _fullStudent(_idOf(s));
    if (u == null || !mounted) return;
    final ok = await showMarkDropoutSheet(context, u);
    if (!ok || !mounted) return;
    setState(() => _picked.remove(_idOf(s)));
    _toast(
      '${s['name'] ?? 'Student'} marked as dropout. Study material stays open.',
      _amber,
    );
    _load(quiet: true);
  }

  // ------------------------------------------------------------------ promote
  Future<void> _promote() async {
    if (_picked.isEmpty || _saving) return;
    final n = _picked.length;
    final picked = _rows.where((r) => _picked.contains(_idOf(r))).toList();
    final twoStage = picked.where((r) => _alsoIn(r).isNotEmpty).length;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titlePadding: const EdgeInsets.fromLTRB(22, 22, 22, 6),
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _green.withOpacity(.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _last ? Icons.emoji_events_rounded : Icons.trending_up_rounded,
                color: _green,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _last
                    ? 'Complete the course?'
                    : 'Promote $n student${n == 1 ? '' : 's'}?',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: _text,
                ),
              ),
            ),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _fromTo(),
              const SizedBox(height: 14),
              if (!_last)
                _bullet(
                  Icons.mic_rounded,
                  _green,
                  'Stage ${_stage + 1}: live class, attendance, tests, reminders — same timing',
                ),
              _bullet(
                Icons.menu_book_rounded,
                _blue,
                'Stage $_stage: study material only — no join class, no attendance, no tests',
              ),
              _bullet(
                Icons.notifications_active_rounded,
                _amber,
                'Every student gets a "Promoted 🎉" message',
              ),
              if (twoStage > 0)
                _bullet(
                  Icons.info_outline_rounded,
                  _amber,
                  '$twoStage of them also study a higher stage — only Stage $_stage closes for them',
                ),
            ],
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(
                color: _secondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _green,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              _last ? 'Complete course' : 'Promote $n',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _saving = true);
    try {
      final res = await http
          .post(
            Uri.parse(ApiEndpoints.promote),
            headers: ApiHeaders.json(),
            body: jsonEncode({
              'userIds': _picked.toList(),
              'language': _language,
              'stage': _stageKey,
            }),
          )
          .timeout(const Duration(seconds: 90));
      final data = jsonDecode(res.body);
      if (res.statusCode == 200 && data is Map) {
        final skipped = (data['skipped'] as List? ?? [])
            .whereType<Map>()
            .toList();
        final promoted = (data['promoted'] as List? ?? []).length;
        _toast(
          (data['message'] ?? 'Done').toString(),
          promoted > 0 ? _green : _amber,
        );
        if (skipped.isNotEmpty && mounted) _showSkipped(skipped);
      } else {
        _toast(
          (data is Map ? data['message'] : null)?.toString() ??
              'Could not promote (${res.statusCode})',
          _red,
        );
      }
    } catch (e) {
      _toast('No internet / server not reachable', _red);
    }
    if (mounted) setState(() => _saving = false);
    _load();
  }

  Widget _bullet(IconData icon, Color c, String t) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: c),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            t,
            style: GoogleFonts.poppins(fontSize: 12, height: 1.4, color: _text),
          ),
        ),
      ],
    ),
  );

  Widget _fromTo() {
    Widget box(String top, String main, Color c) => Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: c.withOpacity(.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: c.withOpacity(.30)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              top,
              style: GoogleFonts.poppins(
                fontSize: 10,
                color: _secondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              main,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: c,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
    return Row(
      children: [
        box('$_language · finished', 'Stage $_stage', _blue),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Icon(Icons.arrow_forward_rounded, color: _secondary),
        ),
        box(
          _last ? 'Course' : 'New live class',
          _last ? 'Completed 🎓' : 'Stage ${_stage + 1}',
          _green,
        ),
      ],
    );
  }

  void _showSkipped(List<Map> skipped) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: Text(
          'Not promoted (${skipped.length})',
          style: GoogleFonts.poppins(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: _text,
          ),
        ),
        content: SizedBox(
          width: 420,
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final s in skipped)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    '• ${s['name'] ?? ''}: ${s['reason'] ?? ''}',
                    style: GoogleFonts.poppins(fontSize: 12, color: _secondary),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------ filter panel (same as Fees)
  void _openFilterPanel() {
    String dMode = _mode,
        dSection = _section,
        dTiming = _timing,
        dAtt = _att,
        dBoth = _both;
    String active = 'mode';

    final groups = <Map<String, dynamic>>[
      {'key': 'mode', 'title': 'Online / Offline', 'icon': Icons.wifi_rounded},
      if (_language == 'English')
        {
          'key': 'section',
          'title': 'Section',
          'icon': Icons.view_module_rounded,
        },
      {'key': 'timing', 'title': 'Timing', 'icon': Icons.schedule_rounded},
      {'key': 'att', 'title': 'Attendance', 'icon': Icons.fact_check_rounded},
      {'key': 'both', 'title': 'Two stages', 'icon': Icons.layers_rounded},
    ];

    Widget panel(BuildContext ctx, StateSetter setPanel, bool wide) {
      int countWith(String skip, bool Function(Map s) test) => _rows
          .where(
            (s) =>
                _passes(
                  s,
                  mode: dMode,
                  section: dSection,
                  timing: dTiming,
                  att: dAtt,
                  both: dBoth,
                  skip: skip,
                ) &&
                test(s),
          )
          .length;
      final total = _rows
          .where(
            (s) => _passes(
              s,
              mode: dMode,
              section: dSection,
              timing: dTiming,
              att: dAtt,
              both: dBoth,
            ),
          )
          .length;

      bool isSet(String key) =>
          {
            'mode': dMode,
            'section': dSection,
            'timing': dTiming,
            'att': dAtt,
            'both': dBoth,
          }[key] !=
          'all';

      Widget option(
        String label,
        bool selected,
        int count,
        VoidCallback onTap, {
        Color color = _navy,
        String? sub,
      }) => InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          setPanel(onTap);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: selected ? color : Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? color : const Color(0xFFB7C9D6),
                    width: 1.6,
                  ),
                ),
                child: selected
                    ? const Icon(
                        Icons.check_rounded,
                        size: 15,
                        color: Colors.white,
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: GoogleFonts.poppins(
                        color: _text,
                        fontSize: 12.5,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                    if (sub != null)
                      Text(
                        sub,
                        style: GoogleFonts.poppins(
                          color: _secondary,
                          fontSize: 10,
                        ),
                      ),
                  ],
                ),
              ),
              Text(
                '$count',
                style: GoogleFonts.poppins(
                  color: _secondary,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );

      List<Widget> options() {
        switch (active) {
          case 'mode':
            return [
              option(
                'Online + Offline',
                dMode == 'all',
                countWith('mode', (_) => true),
                () => dMode = 'all',
              ),
              option(
                'Online',
                dMode == 'online',
                countWith('mode', (s) => _modeOf(s) == 'online'),
                () => dMode = 'online',
                color: _blue,
              ),
              option(
                'Offline',
                dMode == 'offline',
                countWith('mode', (s) => _modeOf(s) == 'offline'),
                () => dMode = 'offline',
                color: _offline,
              ),
            ];
          case 'section':
            return [
              for (final sec in ['all', 'A', 'B', 'C', 'D', 'E'])
                option(
                  sec == 'all' ? 'All sections' : 'Section $sec',
                  dSection == sec,
                  countWith(
                    'section',
                    (s) =>
                        sec == 'all' ||
                        (_modeOf(s) == 'online' && _sectionOf(s) == sec),
                  ),
                  () => dSection = sec,
                  color: _blue,
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 6, 14, 0),
                child: Text(
                  'Sections are for online English students',
                  style: GoogleFonts.poppins(color: _secondary, fontSize: 10),
                ),
              ),
            ];
          case 'timing':
            return [
              option(
                'All timings',
                dTiming == 'all',
                countWith('timing', (_) => true),
                () => dTiming = 'all',
              ),
              for (final b in BatchSlots.all)
                option(
                  b.label,
                  dTiming == b.label,
                  countWith('timing', (s) => _timingOf(s) == b.label),
                  () => dTiming = b.label,
                  color: _green,
                  sub: b.period == 'AM' ? 'Morning' : 'Evening',
                ),
              option(
                'No timing set',
                dTiming == _noTiming,
                countWith('timing', (s) => _timingOf(s) == _noTiming),
                () => dTiming = _noTiming,
                color: _amber,
              ),
            ];
          case 'att':
            return [
              option(
                'Any attendance',
                dAtt == 'all',
                countWith('att', (_) => true),
                () => dAtt = 'all',
              ),
              option(
                'Good — 75% and more',
                dAtt == 'good',
                countWith('att', (s) => _attOf(s) == 'good'),
                () => dAtt = 'good',
                color: _green,
                sub: 'Ready to promote',
              ),
              option(
                'Okay — 50% to 74%',
                dAtt == 'mid',
                countWith('att', (s) => _attOf(s) == 'mid'),
                () => dAtt = 'mid',
                color: _amber,
              ),
              option(
                'Low — under 50%',
                dAtt == 'low',
                countWith('att', (s) => _attOf(s) == 'low'),
                () => dAtt = 'low',
                color: _red,
                sub: 'Maybe keep in this stage',
              ),
              option(
                'No classes yet',
                dAtt == 'new',
                countWith('att', (s) => _attOf(s) == 'new'),
                () => dAtt = 'new',
                color: _secondary,
              ),
            ];
          default:
            return [
              option(
                'Everyone',
                dBoth == 'all',
                countWith('both', (_) => true),
                () => dBoth = 'all',
              ),
              option(
                'Only this stage',
                dBoth == 'only',
                countWith('both', (s) => _alsoIn(s).isEmpty),
                () => dBoth = 'only',
                color: _navy,
              ),
              option(
                'Also in a higher stage',
                dBoth == 'both',
                countWith('both', (s) => _alsoIn(s).isNotEmpty),
                () => dBoth = 'both',
                color: _amber,
                sub: 'Two timings, or promoted the old way',
              ),
            ];
        }
      }

      final draftCount = [
        dMode,
        dSection,
        dTiming,
        dAtt,
        dBoth,
      ].where((e) => e != 'all').length;

      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 8, 10),
            child: Row(
              children: [
                const Icon(Icons.tune_rounded, color: _navy, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Filters',
                        style: GoogleFonts.poppins(
                          color: _text,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '$_language Stage $_stage students',
                        style: GoogleFonts.poppins(
                          color: _secondary,
                          fontSize: 10.5,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: draftCount == 0
                      ? null
                      : () => setPanel(() {
                          dMode = 'all';
                          dSection = 'all';
                          dTiming = 'all';
                          dAtt = 'all';
                          dBoth = 'all';
                        }),
                  child: Text(
                    'Clear all',
                    style: GoogleFonts.poppins(
                      color: draftCount == 0 ? _secondary : _red,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  icon: const Icon(Icons.close_rounded, color: _secondary),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: _border),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: wide ? 160 : 132,
                  color: _soft,
                  child: ListView(
                    children: [
                      for (final g in groups)
                        InkWell(
                          onTap: () =>
                              setPanel(() => active = g['key'] as String),
                          child: Container(
                            padding: const EdgeInsets.fromLTRB(12, 15, 10, 15),
                            decoration: BoxDecoration(
                              color: active == g['key']
                                  ? Colors.white
                                  : Colors.transparent,
                              border: Border(
                                left: BorderSide(
                                  color: active == g['key']
                                      ? _navy
                                      : Colors.transparent,
                                  width: 4,
                                ),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  g['icon'] as IconData,
                                  size: 16,
                                  color: active == g['key']
                                      ? _navy
                                      : _secondary,
                                ),
                                const SizedBox(width: 7),
                                Expanded(
                                  child: Text(
                                    g['title'] as String,
                                    style: GoogleFonts.poppins(
                                      color: active == g['key']
                                          ? _text
                                          : _secondary,
                                      fontSize: 12,
                                      fontWeight: active == g['key']
                                          ? FontWeight.w700
                                          : FontWeight.w600,
                                    ),
                                  ),
                                ),
                                if (isSet(g['key'] as String))
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                      color: _navy,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    children: options(),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.fromLTRB(
              16,
              12,
              16,
              12 + MediaQuery.of(ctx).padding.bottom,
            ),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: _border)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$total',
                        style: GoogleFonts.poppins(
                          color: _text,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'students found',
                        style: GoogleFonts.poppins(
                          color: _secondary,
                          fontSize: 10.5,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height: 46,
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _mode = dMode;
                        _section = dSection;
                        _timing = dTiming;
                        _att = dAtt;
                        _both = dBoth;
                      });
                      Navigator.of(ctx).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _navy,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 26),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Show $total students',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    final wide = MediaQuery.of(context).size.width >= 700;
    if (wide) {
      showGeneralDialog(
        context: context,
        barrierDismissible: true,
        barrierLabel: 'Filters',
        barrierColor: Colors.black.withOpacity(.35),
        transitionDuration: const Duration(milliseconds: 220),
        pageBuilder: (ctx, _, __) => Align(
          alignment: Alignment.centerRight,
          child: Material(
            color: Colors.white,
            elevation: 12,
            child: SizedBox(
              width: 470,
              height: double.infinity,
              child: SafeArea(
                child: StatefulBuilder(builder: (c, sp) => panel(c, sp, true)),
              ),
            ),
          ),
        ),
        transitionBuilder: (ctx, anim, _, child) => SlideTransition(
          position: Tween(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: child,
        ),
      );
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        builder: (ctx) => SizedBox(
          height: MediaQuery.of(ctx).size.height * .8,
          child: StatefulBuilder(builder: (c, sp) => panel(c, sp, false)),
        ),
      );
    }
  }

  // ------------------------------------------------------------------ UI pieces
  Widget _hero(bool wide) {
    final total = (_stageCounts[_stageKey] ?? _rows.length) as num;
    return Container(
      padding: EdgeInsets.fromLTRB(wide ? 20 : 14, 14, wide ? 20 : 14, 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_deepNavy, _navy],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _navy.withOpacity(.18),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Which stage is finished?',
                      style: GoogleFonts.poppins(
                        color: Colors.white70,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _last
                          ? '$_language Stage 7  →  Course completed'
                          : '$_language Stage $_stage  →  Stage ${_stage + 1}',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: wide ? 20 : 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      '$total student${total == 1 ? '' : 's'} in this stage now',
                      style: GoogleFonts.poppins(
                        color: _yellow,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              _langToggle(),
            ],
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [for (int i = 1; i <= 7; i++) _stagePill(i)]),
          ),
        ],
      ),
    );
  }

  Widget _langToggle() {
    Widget item(String lang) {
      final sel = _language == lang;
      return InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () {
          if (sel) return;
          setState(() {
            _language = lang;
            _section = 'all';
          });
          _load();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: sel ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            lang,
            style: GoogleFonts.poppins(
              color: sel ? _navy : Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [item('English'), item('Hindi')],
      ),
    );
  }

  Widget _stagePill(int i) {
    final sel = _stage == i;
    final count = _stageCounts['stage$i'];
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          if (sel) return;
          setState(() => _stage = i);
          _load();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 82,
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: sel ? _yellow : Colors.white.withOpacity(.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: sel ? _yellow : Colors.white.withOpacity(.18),
            ),
          ),
          child: Column(
            children: [
              Text(
                'Stage $i',
                style: GoogleFonts.poppins(
                  color: sel ? _text : Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                count == null ? '—' : '$count students',
                style: GoogleFonts.poppins(
                  color: sel ? _text.withOpacity(.75) : Colors.white60,
                  fontSize: 9.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Left to promote • Promoted • Dropped (+ progress) — one slim bar
  Widget _summaryRow(bool wide) {
    final left = ((_summary['left'] ?? _stageCounts[_stageKey] ?? 0) as num)
        .toInt();
    final promoted = ((_summary['promoted'] ?? 0) as num).toInt();
    final dropped = ((_summary['dropped'] ?? 0) as num).toInt();
    final total = left + promoted;
    final pct = total == 0 ? 0.0 : promoted / total;

    void switchTo(String v) {
      if (_view == v) return;
      setState(() => _view = v);
      _load();
    }

    Widget stat(
      String key,
      String title,
      int value,
      IconData icon,
      Color c,
      VoidCallback onTap,
    ) {
      final sel = key == _view;
      return InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: sel ? c.withOpacity(.10) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: sel ? c.withOpacity(.45) : Colors.transparent,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: c),
              const SizedBox(width: 6),
              Text(
                '$value',
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: c,
                ),
              ),
              const SizedBox(width: 5),
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: _text,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final statList = <Widget>[
      stat(
        'left',
        'Left',
        left,
        Icons.hourglass_top_rounded,
        _navy,
        () => switchTo('left'),
      ),
      stat(
        'promoted',
        _last ? 'Completed' : 'Promoted',
        promoted,
        Icons.trending_up_rounded,
        _green,
        () => switchTo('promoted'),
      ),
      stat(
        'dropped',
        'Dropped',
        dropped,
        Icons.person_off_rounded,
        _red,
        () => AdminShellNavigation.selectModule(15),
      ),
    ];

    final progress = Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 6,
              backgroundColor: _soft,
              valueColor: const AlwaysStoppedAnimation<Color>(_green),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          total == 0
              ? 'No students'
              : '$promoted / $total done · ${(pct * 100).round()}%',
          style: GoogleFonts.poppins(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            color: _secondary,
          ),
        ),
      ],
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: wide
          ? Row(
              children: [
                ...statList,
                const SizedBox(width: 16),
                Expanded(child: progress),
                const SizedBox(width: 6),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(spacing: 4, runSpacing: 4, children: statList),
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 6, 4, 4),
                  child: progress,
                ),
              ],
            ),
    );
  }

  Widget _toolbar() {
    final n = _activeFilters;
    final on = n > 0;
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 46,
            child: TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              style: GoogleFonts.poppins(fontSize: 13, color: _text),
              decoration: InputDecoration(
                hintText: 'Search name or phone',
                hintStyle: GoogleFonts.poppins(fontSize: 13, color: _secondary),
                prefixIcon: const Icon(Icons.search_rounded, color: _secondary),
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: _secondary,
                        ),
                        onPressed: () => setState(() => _search.clear()),
                      ),
                contentPadding: EdgeInsets.zero,
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(11),
                  borderSide: const BorderSide(color: _border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(11),
                  borderSide: const BorderSide(color: _border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(11),
                  borderSide: const BorderSide(color: _navy),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Material(
          color: on ? _navy : Colors.white,
          borderRadius: BorderRadius.circular(11),
          child: InkWell(
            onTap: _openFilterPanel,
            borderRadius: BorderRadius.circular(11),
            child: Container(
              height: 46,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: on ? _navy : _border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.tune_rounded,
                    size: 18,
                    color: on ? Colors.white : _navy,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Filter',
                    style: GoogleFonts.poppins(
                      color: on ? Colors.white : _text,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (on) ...[
                    const SizedBox(width: 6),
                    Container(
                      width: 20,
                      height: 20,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: _yellow,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '$n',
                        style: GoogleFonts.poppins(
                          color: _text,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),
        IconButton(
          tooltip: 'Refresh',
          onPressed: () => _load(),
          icon: const Icon(Icons.refresh_rounded, color: _navy),
        ),
      ],
    );
  }

  /// Quick timing chips (with counts) — the most used filter, always visible
  Widget _timingChips() {
    final counts = <String, int>{};
    for (final s in _rows.where((s) => _shown(s, skip: 'timing'))) {
      final t = _timingOf(s);
      counts[t] = (counts[t] ?? 0) + 1;
    }
    final keys = counts.keys.toList()
      ..sort((a, b) => _timingOrder(a).compareTo(_timingOrder(b)));
    final all = counts.values.fold<int>(0, (a, b) => a + b);

    Widget chip(
      String label,
      int count,
      bool sel,
      VoidCallback onTap, {
      Color color = _green,
    }) => Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => setState(onTap),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: sel ? color : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: sel ? color : _border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.schedule_rounded,
                size: 14,
                color: sel ? Colors.white : _secondary,
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: GoogleFonts.poppins(
                  color: sel ? Colors.white : _text,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: sel ? Colors.white.withOpacity(.25) : _soft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: GoogleFonts.poppins(
                    color: sel ? Colors.white : _navy,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          chip(
            'All timings',
            all,
            _timing == 'all',
            () => _timing = 'all',
            color: _navy,
          ),
          for (final t in keys)
            chip(
              _timingLabel(t),
              counts[t] ?? 0,
              _timing == t,
              () => _timing = t,
              color: t == _noTiming ? _amber : _green,
            ),
        ],
      ),
    );
  }

  Widget _appliedPills(int shown) {
    final pills = <Widget>[];
    void add(String label, Color c, VoidCallback onRemove) => pills.add(
      Padding(
        padding: const EdgeInsets.only(right: 6),
        child: Container(
          padding: const EdgeInsets.only(left: 11, right: 4),
          decoration: BoxDecoration(
            color: c.withOpacity(.10),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: c.withOpacity(.35)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: GoogleFonts.poppins(
                  color: c,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              InkWell(
                onTap: () => setState(onRemove),
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(Icons.close_rounded, size: 15, color: c),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (_mode != 'all')
      add(
        _mode == 'online' ? 'Online' : 'Offline',
        _mode == 'online' ? _blue : _offline,
        () => _mode = 'all',
      );
    if (_section != 'all')
      add('Section $_section', _blue, () => _section = 'all');
    if (_timing != 'all')
      add(_timingLabel(_timing), _green, () => _timing = 'all');
    if (_att != 'all') {
      add(
        {
              'good': 'Attendance 75%+',
              'mid': 'Attendance 50–74%',
              'low': 'Attendance under 50%',
              'new': 'No classes yet',
            }[_att] ??
            _att,
        _pctColor(_att == 'good' ? 80 : (_att == 'mid' ? 60 : 10)),
        () => _att = 'all',
      );
    }
    if (_both != 'all')
      add(
        _both == 'both' ? 'Also in higher stage' : 'Only this stage',
        _amber,
        () => _both = 'all',
      );

    if (pills.isEmpty) return const SizedBox.shrink();
    final countText = Text(
      _loading
          ? 'Loading…'
          : (shown == _rows.length
                ? '${_rows.length} students'
                : '$shown of ${_rows.length} students'),
      style: GoogleFonts.poppins(
        color: _secondary,
        fontSize: 11,
        fontWeight: FontWeight.w600,
      ),
    );
    return SizedBox(
      height: 32,
      child: Row(
        children: [
          Expanded(
            child: pills.isEmpty
                ? const SizedBox.shrink()
                : ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      ...pills,
                      TextButton(
                        onPressed: _clearFilters,
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          minimumSize: const Size(0, 32),
                        ),
                        child: Text(
                          'Clear all',
                          style: GoogleFonts.poppins(
                            color: _red,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
          const SizedBox(width: 8),
          countText,
        ],
      ),
    );
  }

  Widget _twoStageNote(List<Map<String, dynamic>> shown) {
    final two = shown.where((r) => _alsoIn(r).isNotEmpty).toList();
    if (two.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: _amber.withOpacity(.09),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _amber.withOpacity(.35)),
      ),
      child: Row(
        children: [
          const Icon(Icons.layers_rounded, color: _amber, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${two.length} student${two.length == 1 ? ' is' : 's are'} also in a higher stage. '
              'Studying both on purpose (two timings)? Leave them. Stage $_stage finished? Select them — only Stage $_stage closes.',
              style: GoogleFonts.poppins(
                fontSize: 11.5,
                height: 1.4,
                color: _text,
              ),
            ),
          ),
          TextButton(
            onPressed: () => setState(() => _both = 'both'),
            child: Text(
              'Show them',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w800,
                color: _amber,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _groupHeader(String timing, List<Map<String, dynamic>> list) {
    final ids = list.map(_idOf).toList();
    final allSel = ids.isNotEmpty && ids.every(_picked.contains);
    final someSel = ids.any(_picked.contains);
    final slot = BatchSlots.find(timing);
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 10, 0, 6),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: (timing == _noTiming ? _amber : _green).withOpacity(.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              timing == _noTiming
                  ? Icons.help_outline_rounded
                  : (slot != null && slot.period == 'AM'
                        ? Icons.wb_sunny_rounded
                        : Icons.nights_stay_rounded),
              size: 18,
              color: timing == _noTiming ? _amber : _green,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _timingLabel(timing),
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: _text,
                  ),
                ),
                Text(
                  '${list.length} student${list.length == 1 ? '' : 's'}',
                  style: GoogleFonts.poppins(fontSize: 10.5, color: _secondary),
                ),
              ],
            ),
          ),
          if (!_promotedView)
            OutlinedButton.icon(
              onPressed: () => setState(() {
                if (allSel) {
                  _picked.removeAll(ids);
                } else {
                  _picked.addAll(ids);
                }
              }),
              icon: Icon(
                allSel
                    ? Icons.remove_done_rounded
                    : (someSel ? Icons.done_rounded : Icons.done_all_rounded),
                size: 16,
              ),
              label: Text(
                allSel ? 'Unselect' : 'Select this timing',
                style: GoogleFonts.poppins(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: allSel ? _red : _green,
                side: BorderSide(
                  color: (allSel ? _red : _green).withOpacity(.45),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _studentTile(Map<String, dynamic> s) {
    final id = _idOf(s);
    final sel = _picked.contains(id);
    final pct = _pctOf(s);
    final classes = _classesOf(s);
    final mode = _modeOf(s);
    final sec = _sectionOf(s);
    final also = _alsoIn(s);
    final name = (s['name'] ?? '').toString();
    final initials = name.trim().isEmpty
        ? '?'
        : name
              .trim()
              .split(RegExp(r'\s+'))
              .take(2)
              .map((w) => w[0].toUpperCase())
              .join();
    final pc = classes > 0 ? _pctColor(pct) : _secondary;

    void toggle() {
      if (_promotedView) return; // promoted list is only to look at
      setState(() => sel ? _picked.remove(id) : _picked.add(id));
    }

    final nowIn = (s['nowIn'] as List? ?? [])
        .map((e) => e.toString().replaceAll('stage', 'Stage '))
        .toList();

    return Material(
      color: sel ? _green.withOpacity(.05) : Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: toggle,
        child: Container(
          padding: const EdgeInsets.fromLTRB(4, 10, 14, 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: sel ? _green.withOpacity(.55) : _border,
              width: sel ? 1.4 : 1,
            ),
          ),
          child: Row(
            children: [
              if (_promotedView)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Icon(
                    Icons.check_circle_rounded,
                    color: _green,
                    size: 22,
                  ),
                )
              else
                Checkbox(
                  value: sel,
                  activeColor: _green,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(5),
                  ),
                  onChanged: (_) => toggle(),
                ),
              CircleAvatar(
                radius: 18,
                backgroundColor: (mode == 'offline' ? _offline : _blue)
                    .withOpacity(.12),
                child: Text(
                  initials,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: mode == 'offline' ? _offline : _blue,
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
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _text,
                      ),
                    ),
                    Text(
                      (s['phone'] ?? '').toString(),
                      style: GoogleFonts.poppins(
                        fontSize: 10.5,
                        color: _secondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 5,
                      runSpacing: 4,
                      children: [
                        _tag(
                          mode == 'offline' ? 'Offline' : 'Online',
                          mode == 'offline' ? _offline : _blue,
                        ),
                        if (_language == 'English' &&
                            mode == 'online' &&
                            sec.isNotEmpty &&
                            sec != 'NONE')
                          _tag('Sec $sec', _navy),
                        for (final a in also) _tag('Also in $a', _amber),
                        if (_promotedView)
                          nowIn.isEmpty
                              ? _tag('Course completed 🎓', _green)
                              : _tag('Now in ${nowIn.join(' + ')}', _green),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 92,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      classes > 0 ? '$pct%' : '—',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: pc,
                      ),
                    ),
                    const SizedBox(height: 3),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: classes > 0 ? pct / 100 : 0,
                        minHeight: 5,
                        backgroundColor: _soft,
                        valueColor: AlwaysStoppedAnimation<Color>(pc),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      classes > 0
                          ? '${s['attended']}/$classes classes'
                          : 'no classes yet',
                      style: GoogleFonts.poppins(
                        fontSize: 9.5,
                        color: _secondary,
                      ),
                    ),
                  ],
                ),
              ),
              _moreMenu(s),
            ],
          ),
        ),
      ),
    );
  }

  /// ⋮ Open student • Mark as dropout
  Widget _moreMenu(Map<String, dynamic> s) {
    PopupMenuItem<String> item(
      String value,
      IconData icon,
      String label,
      Color c,
    ) => PopupMenuItem<String>(
      value: value,
      height: 42,
      child: Row(
        children: [
          Icon(icon, size: 18, color: c),
          const SizedBox(width: 10),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: c == _red ? _red : _text,
            ),
          ),
        ],
      ),
    );
    return PopupMenuButton<String>(
      tooltip: 'More',
      icon: const Icon(Icons.more_vert_rounded, color: _secondary),
      color: Colors.white,
      surfaceTintColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      onSelected: (v) {
        if (v == 'open') _openStudent(s);
        if (v == 'dropout') _dropout(s);
      },
      itemBuilder: (_) => [
        item('open', Icons.person_search_rounded, 'Open student', _navy),
        const PopupMenuDivider(),
        item('dropout', Icons.person_off_rounded, 'Mark as dropout', _red),
      ],
    );
  }

  Widget _tag(String t, Color c) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(
      color: c.withOpacity(.10),
      borderRadius: BorderRadius.circular(7),
    ),
    child: Text(
      t,
      style: GoogleFonts.poppins(
        fontSize: 9.5,
        fontWeight: FontWeight.w700,
        color: c,
      ),
    ),
  );

  Widget _tiles(List<Map<String, dynamic>> list, bool twoCols) {
    if (!twoCols) {
      return Column(
        children: [
          for (final s in list)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _studentTile(s),
            ),
        ],
      );
    }
    return LayoutBuilder(
      builder: (ctx, c) {
        final w = (c.maxWidth - 10) / 2;
        return Wrap(
          spacing: 10,
          runSpacing: 8,
          children: [
            for (final s in list) SizedBox(width: w, child: _studentTile(s)),
          ],
        );
      },
    );
  }

  Widget _empty(String title, String sub, IconData icon) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 50),
    child: Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: _soft,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(icon, color: _navy, size: 30),
        ),
        const SizedBox(height: 12),
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: _text,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          sub,
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(fontSize: 12, color: _secondary),
        ),
      ],
    ),
  );

  Widget _bottomBar(int shownCount) {
    final n = _picked.length;
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        decoration: BoxDecoration(
          color: Colors.white,
          border: const Border(top: BorderSide(color: _border)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.05),
              blurRadius: 12,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _green.withOpacity(.12),
                shape: BoxShape.circle,
              ),
              child: Text(
                '$n',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: _green,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'student${n == 1 ? '' : 's'} selected',
                    style: GoogleFonts.poppins(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: _text,
                    ),
                  ),
                  InkWell(
                    onTap: () => setState(() => _picked.clear()),
                    child: Text(
                      'Clear selection',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _red,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            ElevatedButton.icon(
              onPressed: _saving ? null : _promote,
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Icon(
                      _last
                          ? Icons.emoji_events_rounded
                          : Icons.trending_up_rounded,
                      size: 18,
                    ),
              label: Text(
                _last ? 'Complete course' : 'Promote to Stage ${_stage + 1}',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _green,
                foregroundColor: Colors.white,
                disabledBackgroundColor: _green.withOpacity(.5),
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------------ build
  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final wide = width >= 700;
    final twoCols = width >= 1250;

    final shown = _rows.where((s) => _shown(s)).toList();
    // group by timing (morning first, "no timing" last)
    final groups = <String, List<Map<String, dynamic>>>{};
    for (final s in shown) {
      groups.putIfAbsent(_timingOf(s), () => []).add(s);
    }
    final timingKeys = groups.keys.toList()
      ..sort((a, b) => _timingOrder(a).compareTo(_timingOrder(b)));
    for (final k in timingKeys) {
      groups[k]!.sort(
        (a, b) => (a['name'] ?? '').toString().compareTo(
          (b['name'] ?? '').toString(),
        ),
      );
    }
    final shownIds = shown.map(_idOf).toList();
    final allShownPicked =
        shownIds.isNotEmpty && shownIds.every(_picked.contains);

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: _text,
        surfaceTintColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: _text),
        actionsIconTheme: const IconThemeData(color: _text),
        automaticallyImplyLeading: !widget.embedded,
        leading:
            widget.embedded &&
                AdminShellNavigation.shouldShowMenuButton(context)
            ? IconButton(
                icon: const Icon(Icons.menu_rounded),
                onPressed: AdminShellNavigation.openDrawer,
              )
            : null,
        titleSpacing:
            widget.embedded &&
                !AdminShellNavigation.shouldShowMenuButton(context)
            ? 20.0
            : null,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Promote students',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w800,
                fontSize: 17,
                color: _text,
              ),
            ),
            Text(
              'Old stage → study material only • new stage → live class',
              style: GoogleFonts.poppins(fontSize: 10.5, color: _secondary),
            ),
          ],
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: _border),
        ),
      ),
      bottomNavigationBar: _picked.isEmpty || _promotedView
          ? null
          : _bottomBar(shown.length),
      body: RefreshIndicator(
        onRefresh: () => _load(),
        child: ListView(
          padding: EdgeInsets.fromLTRB(wide ? 22 : 14, 16, wide ? 22 : 14, 30),
          children: [
            _hero(wide),
            const SizedBox(height: 10),
            _summaryRow(wide),
            const SizedBox(height: 10),
            _toolbar(),
            const SizedBox(height: 8),
            _timingChips(),
            if (_activeFilters > 0) ...[
              const SizedBox(height: 6),
              _appliedPills(shown.length),
            ],
            if (!_promotedView) _twoStageNote(shown),
            if (_promotedView && shown.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _green.withOpacity(.07),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _green.withOpacity(.25)),
                ),
                child: Text(
                  'These students finished $_language Stage $_stage. They can read its study material only. '
                  'Timing shown = their class timing now. Made a mistake? ⋮ → Open student → tap the green Stage $_stage tile → Live again.',
                  style: GoogleFonts.poppins(
                    fontSize: 11.5,
                    height: 1.45,
                    color: _text,
                  ),
                ),
              ),
            if (shown.isNotEmpty && !_promotedView)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${shown.length == _rows.length ? '${shown.length}' : '${shown.length} of ${_rows.length}'} '
                        'student${shown.length == 1 ? '' : 's'} • ${timingKeys.length} timing${timingKeys.length == 1 ? '' : 's'}',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: _text,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => setState(() {
                        if (allShownPicked) {
                          _picked.removeAll(shownIds);
                        } else {
                          _picked.addAll(shownIds);
                        }
                      }),
                      icon: Icon(
                        allShownPicked
                            ? Icons.remove_done_rounded
                            : Icons.done_all_rounded,
                        size: 18,
                        color: _navy,
                      ),
                      label: Text(
                        allShownPicked ? 'Unselect all' : 'Select all shown',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w800,
                          color: _navy,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (_loading && _rows.isEmpty)
              const Padding(
                padding: EdgeInsets.all(50),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_rows.isEmpty)
              _promotedView
                  ? _empty(
                      'Nobody promoted from Stage $_stage yet',
                      'Promoted students show here.',
                      Icons.trending_up_rounded,
                    )
                  : (((_summary['promoted'] ?? 0) as num) > 0
                        ? _empty(
                            'Everyone is promoted 🎉',
                            'No students left in $_language Stage $_stage.',
                            Icons.celebration_rounded,
                          )
                        : _empty(
                            'No students in $_language Stage $_stage',
                            'Pick another stage on top.',
                            Icons.groups_2_outlined,
                          ))
            else if (shown.isEmpty)
              Column(
                children: [
                  _empty(
                    'No students match',
                    'Change or clear the filters.',
                    Icons.filter_alt_off_rounded,
                  ),
                  TextButton(
                    onPressed: _clearFilters,
                    child: Text(
                      'Clear filters',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w800,
                        color: _red,
                      ),
                    ),
                  ),
                ],
              )
            else
              for (final t in timingKeys) ...[
                _groupHeader(t, groups[t]!),
                _tiles(groups[t]!, twoCols),
              ],
          ],
        ),
      ),
    );
  }
}
