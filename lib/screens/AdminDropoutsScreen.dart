// =========================================================================
// 🚪 DROPOUTS — students who stopped the course in the middle
//
//   showMarkDropoutSheet(...) → from Student Control: language + stage where the
//                               student stopped + reason → live class OFF, material stays open
//   AdminDropoutsScreen       → principal's list: who dropped, which course/stage,
//                               online section, reason, fee pending, call button
//   AdminDropoutDetailScreen  → everything about the student: fees, joined date,
//                               attendance, practice, tests, call notes, Rejoin
// =========================================================================
import 'package:lets_speake_manager/Api/admin_badges.dart';
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:lets_speake_manager/Api/ApiendPoints.dart';
import 'package:lets_speake_manager/Api/api_headers.dart';
import 'package:lets_speake_manager/Api/admin_live.dart';
import 'package:lets_speake_manager/Navigation/AdminShellNavigation.dart';
import 'package:url_launcher/url_launcher.dart';

const Color _text = Color(0xFF173A52);
const Color _secondary = Color(0xFF6B8496);
const Color _border = Color(0xFFD5E5EE);
const Color _bg = Color(0xFFF5FAFD);
const Color _navy = Color(0xFF0A4A75);
const Color _blue = Color(0xFF2E86C9);
const Color _teal = Color(0xFF19B8B8);
const Color _green = Color(0xFF16A66A);
const Color _red = Color(0xFFE45757);
const Color _amber = Color(0xFFE59E1B);
const Color _offline = Color(0xFFC68B00);

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String _day(String? iso) {
  final d = DateTime.tryParse(iso ?? '')?.toLocal();
  if (d == null) return '—';
  return '${d.day} ${_months[d.month - 1]} ${d.year}';
}

String _stageLabel(String s) => s.replaceAll('stage', 'Stage ');

const _reasonTypes = [
  ('Fees', Icons.currency_rupee_rounded),
  ('Timing', Icons.schedule_rounded),
  ('Moved away', Icons.location_off_rounded),
  ('Health', Icons.healing_rounded),
  ('Job / Studies', Icons.work_outline_rounded),
  ('Not interested', Icons.thumb_down_alt_outlined),
  ('Other', Icons.more_horiz_rounded),
];

Future<({bool ok, String message, Map<String, dynamic>? data})> _call(
  String method,
  String path, {
  Map<String, dynamic>? body,
}) async {
  try {
    final uri = Uri.parse('${ApiEndpoints.baseUrl}$path');
    final res = method == 'GET'
        ? await http
              .get(uri, headers: ApiHeaders.auth())
              .timeout(const Duration(seconds: 25))
        : await http
              .post(
                uri,
                headers: ApiHeaders.json(),
                body: jsonEncode(body ?? {}),
              )
              .timeout(const Duration(seconds: 25));
    final data = jsonDecode(res.body);
    final map = data is Map
        ? Map<String, dynamic>.from(data)
        : <String, dynamic>{};
    return (
      ok: res.statusCode == 200,
      message: (map['message'] ?? '').toString(),
      data: map,
    );
  } catch (_) {
    return (
      ok: false,
      message: 'No internet / server not reachable',
      data: null,
    );
  }
}

Future<void> _phone(String phone, {bool whatsapp = false}) async {
  final digits = phone.replaceAll(RegExp(r'\D'), '');
  final ten = digits.length > 10
      ? digits.substring(digits.length - 10)
      : digits;
  final uri = whatsapp
      ? Uri.parse('https://wa.me/91$ten')
      : Uri.parse('tel:+91$ten');
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

// =========================================================================
// MARK AS DROPOUT (bottom sheet)
// =========================================================================
/// Returns true when the student was marked as dropout.
Future<bool> showMarkDropoutSheet(BuildContext context, Map user) async {
  final r = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (_) => _MarkDropoutSheet(user: user),
  );
  return r == true;
}

class _MarkDropoutSheet extends StatefulWidget {
  final Map user;
  const _MarkDropoutSheet({required this.user});

  @override
  State<_MarkDropoutSheet> createState() => _MarkDropoutSheetState();
}

class _MarkDropoutSheetState extends State<_MarkDropoutSheet> {
  late final Map<String, List<String>> _enabled; // language → enabled stages
  String _language = 'English';
  String _stage = 'stage1';
  String _reasonType = '';
  final _reason = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    List<String> on(dynamic access) => access is Map
        ? List.generate(
            7,
            (i) => 'stage${i + 1}',
          ).where((s) => access[s] == true).toList()
        : <String>[];
    _enabled = {
      'English': on(widget.user['englishAccess']),
      'Hindi': on(widget.user['hindiAccess']),
    };
    _language = _enabled['English']!.isNotEmpty || _enabled['Hindi']!.isEmpty
        ? 'English'
        : 'Hindi';
    _pickHighestStage();
  }

  void _pickHighestStage() {
    final list = _enabled[_language]!;
    _stage = list.isNotEmpty
        ? list.last
        : 'stage1'; // usually the stage they were studying
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final text = _reason.text.trim();
    final reason = [
      if (_reasonType.isNotEmpty) _reasonType,
      if (text.isNotEmpty) text,
    ].join(' — ');
    if (reason.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Choose or write the reason'),
          backgroundColor: _red,
        ),
      );
      return;
    }
    setState(() => _saving = true);
    final r = await _call(
      'POST',
      '/admin/dropout',
      body: {
        'userId': (widget.user['_id'] ?? widget.user['id']).toString(),
        'language': _language,
        'stage': _stage,
        'reason': reason,
        'reasonType': _reasonType,
      },
    );
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(r.message.isEmpty ? 'Done' : r.message),
        backgroundColor: r.ok ? _green : _red,
      ),
    );
    if (r.ok) Navigator.pop(context, true);
  }

  Widget _chip(
    String label,
    bool sel,
    VoidCallback onTap, {
    Color color = _navy,
    IconData? icon,
  }) => ChoiceChip(
    selected: sel,
    showCheckmark: false,
    avatar: icon == null
        ? null
        : Icon(icon, size: 16, color: sel ? Colors.white : color),
    label: Text(label),
    labelStyle: GoogleFonts.poppins(
      fontSize: 12.5,
      fontWeight: FontWeight.w700,
      color: sel ? Colors.white : _text,
    ),
    selectedColor: color,
    backgroundColor: _bg,
    side: BorderSide(color: sel ? color : _border),
    onSelected: (_) => onTap(),
  );

  Widget _label(String t) => Padding(
    padding: const EdgeInsets.only(top: 16, bottom: 8),
    child: Text(
      t,
      style: GoogleFonts.poppins(
        fontWeight: FontWeight.w700,
        color: _text,
        fontSize: 13,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final name = (widget.user['name'] ?? 'Student').toString();
    final langs = _enabled.entries
        .where((e) => e.value.isNotEmpty)
        .map((e) => e.key)
        .toList();
    final stages = _enabled[_language]!.isNotEmpty
        ? _enabled[_language]!
        : List.generate(7, (i) => 'stage${i + 1}');
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.black12,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _red.withOpacity(.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.person_remove_alt_1_rounded,
                      color: _red,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Mark as dropout',
                          style: GoogleFonts.poppins(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: _text,
                          ),
                        ),
                        Text(
                          name,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: _secondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _amber.withOpacity(.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Live class, attendance, weekly tests, fees and notifications will be switched OFF. Study material of every stage the student had stays open. The principal will see this student in Dropouts with your reason. Give everything back any time with "Rejoin".',
                  style: GoogleFonts.poppins(
                    fontSize: 11.5,
                    color: _text,
                    height: 1.4,
                  ),
                ),
              ),
              _label('Which course did they stop?'),
              Wrap(
                spacing: 8,
                children: (langs.isEmpty ? ['English', 'Hindi'] : langs)
                    .map(
                      (l) => _chip(
                        l,
                        _language == l,
                        () => setState(() {
                          _language = l;
                          _pickHighestStage();
                        }),
                        color: l == 'Hindi' ? _teal : _blue,
                      ),
                    )
                    .toList(),
              ),
              _label('Stopped at stage'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: stages
                    .map(
                      (s) => _chip(
                        _stageLabel(s),
                        _stage == s,
                        () => setState(() => _stage = s),
                      ),
                    )
                    .toList(),
              ),
              _label('Reason'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _reasonTypes
                    .map(
                      (r) => _chip(
                        r.$1,
                        _reasonType == r.$1,
                        () => setState(
                          () => _reasonType = _reasonType == r.$1 ? '' : r.$1,
                        ),
                        color: _red,
                        icon: r.$2,
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _reason,
                maxLines: 3,
                maxLength: 400,
                decoration: InputDecoration(
                  hintText:
                      'What did the student say? e.g. "Shifting to Hyderabad for job, may come back in Jan"',
                  hintStyle: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.black38,
                  ),
                  filled: true,
                  fillColor: _bg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _border),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _red,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.person_remove_alt_1_rounded),
                  label: Text(
                    'Mark dropout — ${_language} ${_stageLabel(_stage)}',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w800,
                      fontSize: 13.5,
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
}

// =========================================================================
// DROPOUTS LIST (principal)
//   top bar  : Dropped • Rejoined • English • Hindi  (tap to filter)
//   search + Filter (side panel like Fees/Promote): Status • Online/Offline •
//            Course • Stage • Fee • Reason • When  — all with live counts
//   cards    : call / WhatsApp right on the card, tap → full details + Rejoin
// =========================================================================
class AdminDropoutsScreen extends StatefulWidget {
  final bool embedded;
  const AdminDropoutsScreen({super.key, this.embedded = false});

  @override
  State<AdminDropoutsScreen> createState() => _AdminDropoutsScreenState();
}

class _AdminDropoutsScreenState extends State<AdminDropoutsScreen>
    with WidgetsBindingObserver {
  // filters (all on this screen — one load, instant filtering)
  String _status = 'dropped'; // dropped | rejoined | all
  String _mode = 'all'; // all | online | offline
  String _language = 'all'; // all | English | Hindi
  String _stage = 'all'; // all | stage1..7
  String _fee = 'all'; // all | pending | paid
  String _reason = 'all'; // all | Fees | Timing | ...
  String _when =
      'all'; // all | 7 (days) | m1 m3 m6 m12 (this month / last 3, 6, 12 months)
  String _tab = 'list'; // list | report
  String _period = 'm3'; // report period: d1 (today) • 7 (days) • m1 m3 m6 m12
  String _chartBy = 'month'; // day | month (for 3 / 6 / 12 months)
  bool _allDays = false; // daily log: show every day
  final TextEditingController _search = TextEditingController();

  bool _loading = true;
  List<Map<String, dynamic>> _rows = []; // every dropout (dropped + rejoined)
  Timer? _poll;
  void Function()? _stopLive;

  static const _soft = Color(0xFFEAF4FA);
  static const _yellow = Color(0xFFF7DF55);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    // ⚡ marked dropout / rejoined / call note / fee paid → list updates by itself
    _stopLive = AdminLive.on([
      'dropout_update',
      'student_update',
    ], () => _load(quiet: true));
    _poll = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _load(quiet: true),
    ); // safety net
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _search.dispose();
    _poll?.cancel();
    _stopLive?.call();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load(quiet: true);
  }

  Future<void> _load({bool quiet = false}) async {
    if (!mounted) return;
    if (!quiet || _rows.isEmpty) setState(() => _loading = true);
    final qs = Uri(
      queryParameters: {
        'status': 'all',
        '_t': '${DateTime.now().millisecondsSinceEpoch}',
      },
    ).query;
    final r = await _call('GET', '/admin/dropouts?$qs');
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (!r.ok && quiet)
        return; // keep the old list if a background refresh fails
      if (r.ok && r.data != null) {
        _rows = ((r.data!['dropouts'] ?? []) as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      } else if (!r.ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(r.message.isEmpty ? 'Could not load' : r.message),
            backgroundColor: _red,
          ),
        );
      }
    });
  }

  // ------------------------------------------------------------------ helpers
  String _statusOf(Map r) => r['status'] == 'rejoined' ? 'rejoined' : 'dropped';
  String _modeOf(Map r) =>
      (r['mode'] ?? '').toString() == 'offline' ? 'offline' : 'online';
  String _langOf(Map r) =>
      (r['language'] ?? '').toString() == 'Hindi' ? 'Hindi' : 'English';
  String _stageOf(Map r) => (r['stage'] ?? '').toString();
  num _pendingOf(Map r) {
    final fee = r['feeNow'] is Map ? r['feeNow'] as Map : const {};
    final v = fee['monthsPending'] ?? r['monthsPending'] ?? 0;
    return v is num ? v : 0;
  }

  String _reasonOf(Map r) {
    final t = (r['reasonType'] ?? '').toString();
    if (t.isNotEmpty) return t;
    final text = (r['reason'] ?? '').toString();
    for (final k in _reasonTypes) {
      if (text.startsWith(k.$1)) return k.$1;
    }
    return 'Other';
  }

  int _daysAgo(Map r) {
    final d = DateTime.tryParse((r['createdAt'] ?? '').toString());
    if (d == null) return 99999;
    return DateTime.now().difference(d.toLocal()).inDays;
  }

  bool _passes(
    Map r, {
    required String status,
    required String mode,
    required String language,
    required String stage,
    required String fee,
    required String reason,
    required String when,
    String skip = '',
  }) {
    if (skip != 'status' && status != 'all' && _statusOf(r) != status)
      return false;
    if (skip != 'mode' && mode != 'all' && _modeOf(r) != mode) return false;
    if (skip != 'language' && language != 'all' && _langOf(r) != language)
      return false;
    if (skip != 'stage' && stage != 'all' && _stageOf(r) != stage) return false;
    if (skip != 'fee' && fee != 'all') {
      final p = _pendingOf(r) > 0;
      if (fee == 'pending' && !p) return false;
      if (fee == 'paid' && p) return false;
    }
    if (skip != 'reason' && reason != 'all' && _reasonOf(r) != reason)
      return false;
    if (skip != 'when' && when != 'all' && !_inWhen(r, when)) return false;
    final q = _search.text.trim().toLowerCase();
    if (q.isNotEmpty) {
      final name = (r['name'] ?? '').toString().toLowerCase();
      final phone = (r['phone'] ?? '').toString();
      if (!name.contains(q) && !phone.contains(q)) return false;
    }
    return true;
  }

  bool _shown(Map r, {String skip = ''}) => _passes(
    r,
    status: _status,
    mode: _mode,
    language: _language,
    stage: _stage,
    fee: _fee,
    reason: _reason,
    when: _when,
    skip: skip,
  );

  // the status filter is shown as the top bar → not counted as an "extra" filter
  int get _activeFilters => [
    _mode,
    _language,
    _stage,
    _fee,
    _reason,
    _when,
  ].where((e) => e != 'all').length;

  void _clearFilters() => setState(() {
    _mode = 'all';
    _language = 'all';
    _stage = 'all';
    _fee = 'all';
    _reason = 'all';
    _when = 'all';
    _search.clear();
  });

  String _whenLabel(String w) =>
      {
        'd1': 'Today',
        '7': 'Last 7 days',
        'm1': 'This month',
        'm3': 'Last 3 months',
        'm6': 'Last 6 months',
        'm12': 'Last 1 year',
      }[w] ??
      (w.startsWith('day:')
          ? _dayName(DateTime.parse(w.substring(4)))
          : 'Any time');

  static const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  String _dayName(DateTime d) =>
      '${_weekdays[d.weekday - 1]}, ${d.day} ${_months[d.month - 1]} ${d.year}';
  String _dayKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  DateTime? _droppedOn(Map r) =>
      DateTime.tryParse((r['createdAt'] ?? '').toString())?.toLocal();

  /// first day of the period: m3 = 1st of the month 2 months ago (3 calendar months incl. this one)
  DateTime _periodStart(String w) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (w == 'd1') return today;
    if (w == '7')
      return today.subtract(const Duration(days: 6)); // today + 6 days before
    final n = int.tryParse(w.replaceAll('m', '')) ?? 1;
    return DateTime(now.year, now.month - (n - 1), 1);
  }

  bool _inWhen(Map r, String w) {
    if (w == 'all') return true;
    final d = _droppedOn(r);
    if (d == null) return false;
    if (w.startsWith('day:'))
      return _dayKey(d) == w.substring(4); // one exact day (from the daily log)
    return !d.isBefore(_periodStart(w));
  }

  // ------------------------------------------------------------------ filter panel
  void _openFilterPanel() {
    String dStatus = _status,
        dMode = _mode,
        dLang = _language,
        dStage = _stage,
        dFee = _fee,
        dReason = _reason,
        dWhen = _when;
    String active = 'status';

    final groups = <Map<String, dynamic>>[
      {'key': 'status', 'title': 'Status', 'icon': Icons.flag_rounded},
      {'key': 'mode', 'title': 'Online / Offline', 'icon': Icons.wifi_rounded},
      {'key': 'language', 'title': 'Course', 'icon': Icons.translate_rounded},
      {'key': 'stage', 'title': 'Stage', 'icon': Icons.layers_rounded},
      {'key': 'fee', 'title': 'Fee', 'icon': Icons.currency_rupee_rounded},
      {'key': 'reason', 'title': 'Reason', 'icon': Icons.help_outline_rounded},
      {'key': 'when', 'title': 'When', 'icon': Icons.event_rounded},
    ];

    Widget panel(BuildContext ctx, StateSetter setPanel, bool wide) {
      bool pass(Map r, {String skip = ''}) => _passes(
        r,
        status: dStatus,
        mode: dMode,
        language: dLang,
        stage: dStage,
        fee: dFee,
        reason: dReason,
        when: dWhen,
        skip: skip,
      );
      int countWith(String skip, bool Function(Map r) test) =>
          _rows.where((r) => pass(r, skip: skip) && test(r)).length;
      final total = _rows.where((r) => pass(r)).length;

      bool isSet(String key) =>
          {
            'status': dStatus == 'dropped' ? 'all' : dStatus,
            'mode': dMode,
            'language': dLang,
            'stage': dStage,
            'fee': dFee,
            'reason': dReason,
            'when': dWhen,
          }[key] !=
          'all';

      Widget option(
        String label,
        bool selected,
        int count,
        VoidCallback onTap, {
        Color color = _navy,
        IconData? icon,
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
              if (icon != null) ...[
                Icon(icon, size: 16, color: _secondary),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.poppins(
                    color: _text,
                    fontSize: 12.5,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
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
          case 'status':
            return [
              option(
                'Dropped (now)',
                dStatus == 'dropped',
                countWith('status', (r) => _statusOf(r) == 'dropped'),
                () => dStatus = 'dropped',
                color: _red,
              ),
              option(
                'Rejoined',
                dStatus == 'rejoined',
                countWith('status', (r) => _statusOf(r) == 'rejoined'),
                () => dStatus = 'rejoined',
                color: _green,
              ),
              option(
                'All',
                dStatus == 'all',
                countWith('status', (_) => true),
                () => dStatus = 'all',
              ),
            ];
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
                countWith('mode', (r) => _modeOf(r) == 'online'),
                () => dMode = 'online',
                color: _blue,
              ),
              option(
                'Offline',
                dMode == 'offline',
                countWith('mode', (r) => _modeOf(r) == 'offline'),
                () => dMode = 'offline',
                color: _offline,
              ),
            ];
          case 'language':
            return [
              option(
                'All courses',
                dLang == 'all',
                countWith('language', (_) => true),
                () => dLang = 'all',
              ),
              option(
                'English',
                dLang == 'English',
                countWith('language', (r) => _langOf(r) == 'English'),
                () => dLang = 'English',
                color: _blue,
              ),
              option(
                'Hindi',
                dLang == 'Hindi',
                countWith('language', (r) => _langOf(r) == 'Hindi'),
                () => dLang = 'Hindi',
                color: _teal,
              ),
            ];
          case 'stage':
            return [
              option(
                'All stages',
                dStage == 'all',
                countWith('stage', (_) => true),
                () => dStage = 'all',
              ),
              for (var i = 1; i <= 7; i++)
                option(
                  'Stage $i',
                  dStage == 'stage$i',
                  countWith('stage', (r) => _stageOf(r) == 'stage$i'),
                  () => dStage = 'stage$i',
                  color: _green,
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 6, 14, 0),
                child: Text(
                  'The stage where the student stopped',
                  style: GoogleFonts.poppins(color: _secondary, fontSize: 10),
                ),
              ),
            ];
          case 'fee':
            return [
              option(
                'Any',
                dFee == 'all',
                countWith('fee', (_) => true),
                () => dFee = 'all',
              ),
              option(
                'Fee pending',
                dFee == 'pending',
                countWith('fee', (r) => _pendingOf(r) > 0),
                () => dFee = 'pending',
                color: _red,
              ),
              option(
                'Nothing pending',
                dFee == 'paid',
                countWith('fee', (r) => _pendingOf(r) == 0),
                () => dFee = 'paid',
                color: _green,
              ),
            ];
          case 'reason':
            return [
              option(
                'All reasons',
                dReason == 'all',
                countWith('reason', (_) => true),
                () => dReason = 'all',
              ),
              for (final t in _reasonTypes)
                option(
                  t.$1,
                  dReason == t.$1,
                  countWith('reason', (r) => _reasonOf(r) == t.$1),
                  () => dReason = t.$1,
                  color: _red,
                  icon: t.$2,
                ),
            ];
          default:
            return [
              option(
                'Any time',
                dWhen == 'all',
                countWith('when', (_) => true),
                () => dWhen = 'all',
              ),
              for (final w in ['d1', '7', 'm1', 'm3', 'm6', 'm12'])
                option(
                  _whenLabel(w),
                  dWhen == w,
                  countWith('when', (r) => _inWhen(r, w)),
                  () => dWhen = w,
                  color: _navy,
                ),
            ];
        }
      }

      final draftCount =
          [
            dMode,
            dLang,
            dStage,
            dFee,
            dReason,
            dWhen,
          ].where((e) => e != 'all').length +
          (dStatus == 'dropped' ? 0 : 1);

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
                        'Dropouts',
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
                          dStatus = 'dropped';
                          dMode = 'all';
                          dLang = 'all';
                          dStage = 'all';
                          dFee = 'all';
                          dReason = 'all';
                          dWhen = 'all';
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
                        _status = dStatus;
                        _mode = dMode;
                        _language = dLang;
                        _stage = dStage;
                        _fee = dFee;
                        _reason = dReason;
                        _when = dWhen;
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
  /// Dropped • Rejoined • English • Hindi — one slim bar (tap = filter)
  Widget _summaryBar(bool wide) {
    final dropped = _rows.where((r) => _statusOf(r) == 'dropped').toList();
    final rejoined = _rows.length - dropped.length;
    final en = dropped.where((r) => _langOf(r) == 'English').length;
    final hi = dropped.length - en;
    final feePending = dropped.where((r) => _pendingOf(r) > 0).length;

    Widget stat(
      String title,
      int value,
      IconData icon,
      Color c,
      bool sel,
      VoidCallback onTap,
    ) => InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => setState(onTap),
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

    final items = <Widget>[
      stat(
        'Dropped',
        dropped.length,
        Icons.person_off_rounded,
        _red,
        _status == 'dropped' && _language == 'all',
        () {
          _status = 'dropped';
          _language = 'all';
        },
      ),
      stat(
        'Rejoined',
        rejoined,
        Icons.person_add_alt_1_rounded,
        _green,
        _status == 'rejoined',
        () {
          _status = 'rejoined';
          _language = 'all';
        },
      ),
      if (wide)
        Container(
          width: 1,
          height: 22,
          color: _border,
          margin: const EdgeInsets.symmetric(horizontal: 6),
        ),
      stat(
        'English',
        en,
        Icons.translate_rounded,
        _blue,
        _status == 'dropped' && _language == 'English',
        () {
          _status = 'dropped';
          _language = _language == 'English' ? 'all' : 'English';
        },
      ),
      stat(
        'Hindi',
        hi,
        Icons.translate_rounded,
        _teal,
        _status == 'dropped' && _language == 'Hindi',
        () {
          _status = 'dropped';
          _language = _language == 'Hindi' ? 'all' : 'Hindi';
        },
      ),
    ];

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
                ...items,
                const Spacer(),
                if (feePending > 0)
                  InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => setState(() {
                      _status = 'dropped';
                      _fee = 'pending';
                    }),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      child: Text(
                        '₹ $feePending with fee pending',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _red,
                        ),
                      ),
                    ),
                  ),
              ],
            )
          : Wrap(spacing: 2, runSpacing: 2, children: items),
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
      ],
    );
  }

  Widget _appliedPills() {
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
    if (_language != 'all')
      add(
        _language,
        _language == 'Hindi' ? _teal : _blue,
        () => _language = 'all',
      );
    if (_stage != 'all') add(_stageLabel(_stage), _green, () => _stage = 'all');
    if (_fee != 'all')
      add(
        _fee == 'pending' ? 'Fee pending' : 'Nothing pending',
        _fee == 'pending' ? _red : _green,
        () => _fee = 'all',
      );
    if (_reason != 'all') add('Reason: $_reason', _red, () => _reason = 'all');
    if (_when != 'all') add(_whenLabel(_when), _navy, () => _when = 'all');
    if (pills.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 32,
      child: ListView(
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

  // ------------------------------------------------------------------ build
  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final wide = width >= 700;
    final twoCols = width >= 1250;
    final shown = _rows.where((r) => _shown(r)).toList();
    final statusTitle = {
      'dropped': 'Dropped students',
      'rejoined': 'Rejoined students',
      'all': 'All dropouts',
    }[_status]!;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: _text,
        surfaceTintColor: Colors.white,
        elevation: 0,
        // the app theme makes AppBar icons + title WHITE → force dark here (☰ menu, refresh, title)
        iconTheme: const IconThemeData(color: _text),
        actionsIconTheme: const IconThemeData(color: _text),
        automaticallyImplyLeading: !widget.embedded,
        leading:
            widget.embedded &&
                AdminShellNavigation.shouldShowMenuButton(context)
            ? IconButton(
                icon: AdminMenuIcon(Icons.menu_rounded),
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
              'Dropouts',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w800,
                fontSize: 17,
                color: _text,
              ),
            ),
            Text(
              'Students who stopped • call them • rejoin any time',
              style: GoogleFonts.poppins(fontSize: 10.5, color: _secondary),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => _load(),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: _border),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => _load(),
        child: ListView(
          padding: EdgeInsets.fromLTRB(wide ? 22 : 14, 14, wide ? 22 : 14, 30),
          children: [
            _summaryBar(wide),
            const SizedBox(height: 10),
            _tabs(),
            const SizedBox(height: 10),
            if (_tab == 'report')
              _report(wide)
            else ...[
              _toolbar(),
              if (_activeFilters > 0) ...[
                const SizedBox(height: 8),
                _appliedPills(),
              ],
              const SizedBox(height: 12),
              if (!_loading || _rows.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    '$statusTitle • ${shown.length}',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: _text,
                    ),
                  ),
                ),
              if (_loading && _rows.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(50),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_rows.isEmpty)
                _empty(
                  'No dropouts 🎉',
                  'Nobody has stopped the course.',
                  Icons.sentiment_satisfied_alt_rounded,
                )
              else if (shown.isEmpty)
                Column(
                  children: [
                    _empty(
                      _status == 'dropped' && _activeFilters == 0
                          ? 'No dropouts right now 🎉'
                          : 'No students match',
                      _activeFilters == 0
                          ? 'Everyone is studying.'
                          : 'Change or clear the filters.',
                      Icons.filter_alt_off_rounded,
                    ),
                    if (_activeFilters > 0)
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
              else if (twoCols)
                LayoutBuilder(
                  builder: (ctx, c) {
                    final w = (c.maxWidth - 12) / 2;
                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        for (final r in shown)
                          SizedBox(width: w, child: _card(r)),
                      ],
                    );
                  },
                )
              else
                for (final r in shown)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _card(r),
                  ),
            ],
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------------ 📊 REPORT
  Widget _tabs() {
    Widget tab(String key, String label, IconData icon) {
      final sel = _tab == key;
      return Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => setState(() => _tab = key),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(vertical: 9),
            decoration: BoxDecoration(
              color: sel ? _navy : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 17, color: sel ? Colors.white : _secondary),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: sel ? Colors.white : _secondary,
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          tab('list', 'Students', Icons.view_list_rounded),
          tab('report', 'Report', Icons.bar_chart_rounded),
        ],
      ),
    );
  }

  /// Report → tap a number → the Students tab with exactly those students
  void _showInList({
    String? stage,
    String? language,
    String? reason,
    String? mode,
    String? when,
  }) {
    setState(() {
      _tab = 'list';
      _status = 'all';
      _when = when ?? _period;
      _stage = stage ?? 'all';
      _language = language ?? 'all';
      _reason = reason ?? 'all';
      _mode = mode ?? 'all';
      _fee = 'all';
      _search.clear();
    });
  }

  Widget _box({
    required String title,
    String? sub,
    required Widget child,
    Widget? trailing,
  }) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: _border),
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
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: _text,
                    ),
                  ),
                  if (sub != null)
                    Text(
                      sub,
                      style: GoogleFonts.poppins(
                        fontSize: 10.5,
                        color: _secondary,
                      ),
                    ),
                ],
              ),
            ),
            if (trailing != null) trailing,
          ],
        ),
        const SizedBox(height: 12),
        child,
      ],
    ),
  );

  Widget _kpi(String label, String value, Color c, IconData icon) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: _border),
    ),
    child: Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: c.withOpacity(.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: c),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: c,
                ),
              ),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: _secondary,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  /// one horizontal bar row: label • bar • number (tap → list)
  Widget _hBar(
    String label,
    int value,
    int max,
    Color c,
    VoidCallback? onTap, {
    String? extra,
  }) => InkWell(
    borderRadius: BorderRadius.circular(8),
    onTap: value == 0 ? null : onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(
            width: 112,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _text,
              ),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: max == 0 ? 0 : value / max,
                minHeight: 10,
                backgroundColor: _soft,
                valueColor: AlwaysStoppedAnimation<Color>(c),
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: extra == null ? 30 : 74,
            child: Text(
              extra == null ? '$value' : '$value  $extra',
              textAlign: TextAlign.right,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: value == 0 ? _secondary : c,
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _report(bool wide) {
    const monthsShort = _months;
    final start = _periodStart(_period);
    final inPeriod = _rows.where((r) => _inWhen(r, _period)).toList();
    final total = inPeriod.length;
    final rejoined = inPeriod.where((r) => _statusOf(r) == 'rejoined').length;
    final stillOut = total - rejoined;

    // ---- bars: day-wise (Today / 7 days / This month, or when "Day-wise" is chosen) or month-wise ----
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final byDay =
        _period == 'd1' ||
        _period == '7' ||
        _period == 'm1' ||
        _chartBy == 'day';
    final perDay = <String, int>{};
    for (final r in inPeriod) {
      final k = _dayKey(_droppedOn(r)!);
      perDay[k] = (perDay[k] ?? 0) + 1;
    }
    final buckets = <(String, int)>[];
    final bucketKeys =
        <String>[]; // day key for each bar (day-wise) → tap = those students
    if (byDay) {
      for (
        var d = start;
        !d.isAfter(today);
        d = DateTime(d.year, d.month, d.day + 1)
      ) {
        final k = _dayKey(d);
        final label = _period == 'd1'
            ? 'Today'
            : (_period == '7'
                  ? _weekdays[d.weekday - 1]
                  : '${d.day} ${monthsShort[d.month - 1]}');
        buckets.add((label, perDay[k] ?? 0));
        bucketKeys.add(k);
      }
    } else {
      final n = int.parse(_period.replaceAll('m', ''));
      for (var i = 0; i < n; i++) {
        final m = DateTime(start.year, start.month + i, 1);
        final c = inPeriod.where((r) {
          final d = _droppedOn(r)!;
          return d.year == m.year && d.month == m.month;
        }).length;
        buckets.add((
          n > 6
              ? monthsShort[m.month - 1]
              : '${monthsShort[m.month - 1]} ${'${m.year}'.substring(2)}',
          c,
        ));
        bucketKeys.add('');
      }
    }
    final maxBucket = buckets.fold<int>(0, (a, b) => b.$2 > a ? b.$2 : a);
    final worst = buckets.isEmpty || maxBucket == 0
        ? null
        : buckets.firstWhere((b) => b.$2 == maxBucket);

    // ---- stage × course ----
    int count({
      String? stage,
      String? language,
      String? reason,
      String? mode,
    }) => inPeriod
        .where(
          (r) =>
              (stage == null || _stageOf(r) == stage) &&
              (language == null || _langOf(r) == language) &&
              (reason == null || _reasonOf(r) == reason) &&
              (mode == null || _modeOf(r) == mode),
        )
        .length;
    final stageTotals = [for (var i = 1; i <= 7; i++) count(stage: 'stage$i')];
    final maxStage = stageTotals.fold<int>(0, (a, b) => b > a ? b : a);
    final worstStageIdx = maxStage == 0 ? -1 : stageTotals.indexOf(maxStage);

    // ---- reasons ----
    final reasons = [
      for (final t in _reasonTypes) (t.$1, t.$2, count(reason: t.$1)),
    ]..sort((a, b) => b.$3.compareTo(a.$3));
    final maxReason = reasons.isEmpty ? 0 : reasons.first.$3;
    final topReason = maxReason == 0 ? '—' : reasons.first.$1;

    final online = count(mode: 'online');
    final offline = count(mode: 'offline');
    final en = count(language: 'English');
    final hi = count(language: 'Hindi');

    Widget periodChip(String key) {
      final sel = _period == key;
      final label = {
        'd1': 'Today',
        '7': '7 days',
        'm1': 'This month',
        'm3': '3 months',
        'm6': '6 months',
        'm12': '1 year',
      }[key]!;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => setState(() => _period = key),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: sel ? _red : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: sel ? _red : _border),
            ),
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: sel ? Colors.white : _text,
              ),
            ),
          ),
        ),
      );
    }

    final kpis = [
      _kpi('Dropouts', '$total', _red, Icons.person_off_rounded),
      _kpi('Came back', '$rejoined', _green, Icons.person_add_alt_1_rounded),
      _kpi('Still out', '$stillOut', _amber, Icons.hourglass_bottom_rounded),
      _kpi('Top reason', topReason, _navy, Icons.help_outline_rounded),
    ];

    // bar chart — many bars (day-wise 3/6/12 months) → fixed width, scroll sideways (latest on the right)
    final many = buckets.length > 16;
    Widget bar(int i) {
      final b = buckets[i];
      final key = bucketKeys[i];
      final col = Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            b.$2 == 0 && many ? '' : '${b.$2}',
            style: GoogleFonts.poppins(
              fontSize: many ? 9.5 : 11.5,
              fontWeight: FontWeight.w800,
              color: b.$2 == 0 ? _secondary : _red,
            ),
          ),
          const SizedBox(height: 4),
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: maxBucket == 0 ? 3 : 3 + 110 * (b.$2 / maxBucket),
            decoration: BoxDecoration(
              color: b.$2 == 0
                  ? _soft
                  : (b.$2 == maxBucket ? _red : _red.withOpacity(.45)),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(5),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            b.$1,
            maxLines: 1,
            overflow: TextOverflow.clip,
            style: GoogleFonts.poppins(
              fontSize: many ? 8.5 : 10,
              fontWeight: FontWeight.w600,
              color: _secondary,
            ),
          ),
        ],
      );
      return Tooltip(
        message: '${b.$1}: ${b.$2} dropout${b.$2 == 1 ? '' : 's'}',
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: b.$2 == 0 || key.isEmpty
              ? null
              : () => _showInList(when: 'day:$key'),
          child: col,
        ),
      );
    }

    final chart = SizedBox(
      height: 170,
      child: many
          ? ListView.builder(
              scrollDirection: Axis.horizontal,
              reverse: true, // newest day on the right, already in view
              itemCount: buckets.length,
              itemBuilder: (_, j) {
                final i = buckets.length - 1 - j;
                return SizedBox(
                  width: 34,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: bar(i),
                  ),
                );
              },
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < buckets.length; i++)
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: buckets.length > 8 ? 3 : 8,
                      ),
                      child: bar(i),
                    ),
                  ),
              ],
            ),
    );

    // day-wise / month-wise switch (only for 3 / 6 / 12 months)
    Widget? chartSwitch;
    if (_period == 'm3' || _period == 'm6' || _period == 'm12') {
      Widget opt(String key, String label) {
        final sel = _chartBy == key;
        return InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => setState(() => _chartBy = key),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: sel ? _navy : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: sel ? Colors.white : _secondary,
              ),
            ),
          ),
        );
      }

      chartSwitch = Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: _bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [opt('day', 'Day-wise'), opt('month', 'Month-wise')],
        ),
      );
    }

    // 📅 daily log: every day with dropouts (newest first) + what dropped that day
    final days = perDay.keys.toList()..sort((a, b) => b.compareTo(a));
    final shownDays = _allDays ? days : days.take(10).toList();
    final dailyLog = Column(
      children: [
        if (days.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'No dropouts in this period 🎉',
              style: GoogleFonts.poppins(fontSize: 12, color: _secondary),
            ),
          ),
        for (final k in shownDays)
          () {
            final d = DateTime.parse(k);
            final list = inPeriod
                .where((r) => _dayKey(_droppedOn(r)!) == k)
                .toList();
            final parts = <String, int>{};
            for (final r in list) {
              final t =
                  '${_langOf(r) == 'Hindi' ? 'Hi' : 'En'} ${_stageLabel(_stageOf(r)).replaceAll('Stage ', 'S')}';
              parts[t] = (parts[t] ?? 0) + 1;
            }
            final isToday = k == _dayKey(today);
            return InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => _showInList(when: 'day:$k'),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 6),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: _bg)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        color: isToday ? _red : _red.withOpacity(.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        children: [
                          Text(
                            '${d.day}',
                            style: GoogleFonts.poppins(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: isToday ? Colors.white : _red,
                              height: 1.1,
                            ),
                          ),
                          Text(
                            monthsShort[d.month - 1],
                            style: GoogleFonts.poppins(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              color: isToday ? Colors.white : _red,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isToday
                                ? 'Today • ${_weekdays[d.weekday - 1]}'
                                : _dayName(d),
                            style: GoogleFonts.poppins(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: _text,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Wrap(
                            spacing: 5,
                            runSpacing: 4,
                            children: [
                              for (final e in parts.entries)
                                _tag(
                                  e.value > 1 ? '${e.key} ×${e.value}' : e.key,
                                  e.key.startsWith('Hi') ? _teal : _blue,
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _red.withOpacity(.10),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${list.length}',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: _red,
                        ),
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded, color: _secondary),
                  ],
                ),
              ),
            );
          }(),
        if (days.length > 10)
          TextButton(
            onPressed: () => setState(() => _allDays = !_allDays),
            child: Text(
              _allDays ? 'Show less' : 'Show all ${days.length} days',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w800,
                color: _navy,
                fontSize: 12,
              ),
            ),
          ),
      ],
    );

    // stage table: Stage | English | Hindi | Total bar
    Widget cell(
      String t, {
      Color c = _text,
      FontWeight w = FontWeight.w700,
      VoidCallback? onTap,
    }) => Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Text(
            t,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(fontSize: 12, fontWeight: w, color: c),
          ),
        ),
      ),
    );
    final stageTable = Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          decoration: BoxDecoration(
            color: _bg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 70,
                child: Text(
                  'Stage',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _secondary,
                  ),
                ),
              ),
              cell('English', c: _blue, w: FontWeight.w700),
              cell('Hindi', c: _teal, w: FontWeight.w700),
              Expanded(
                flex: 3,
                child: Text(
                  'Total',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _secondary,
                  ),
                ),
              ),
            ],
          ),
        ),
        for (var i = 1; i <= 7; i++)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            decoration: BoxDecoration(
              color: i - 1 == worstStageIdx
                  ? _red.withOpacity(.05)
                  : Colors.transparent,
              border: const Border(bottom: BorderSide(color: _bg)),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 70,
                  child: Text(
                    'Stage $i',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: i - 1 == worstStageIdx
                          ? FontWeight.w800
                          : FontWeight.w600,
                      color: _text,
                    ),
                  ),
                ),
                () {
                  final n = count(stage: 'stage$i', language: 'English');
                  return cell(
                    n == 0 ? '–' : '$n',
                    c: n == 0 ? _secondary : _blue,
                    onTap: n == 0
                        ? null
                        : () => _showInList(
                            stage: 'stage$i',
                            language: 'English',
                          ),
                  );
                }(),
                () {
                  final n = count(stage: 'stage$i', language: 'Hindi');
                  return cell(
                    n == 0 ? '–' : '$n',
                    c: n == 0 ? _secondary : _teal,
                    onTap: n == 0
                        ? null
                        : () =>
                              _showInList(stage: 'stage$i', language: 'Hindi'),
                  );
                }(),
                Expanded(
                  flex: 3,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(6),
                    onTap: stageTotals[i - 1] == 0
                        ? null
                        : () => _showInList(stage: 'stage$i'),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: LinearProgressIndicator(
                                value: maxStage == 0
                                    ? 0
                                    : stageTotals[i - 1] / maxStage,
                                minHeight: 10,
                                backgroundColor: _soft,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  i - 1 == worstStageIdx
                                      ? _red
                                      : _red.withOpacity(.55),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 26,
                            child: Text(
                              '${stageTotals[i - 1]}',
                              textAlign: TextAlign.right,
                              style: GoogleFonts.poppins(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                                color: stageTotals[i - 1] == 0
                                    ? _secondary
                                    : _red,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );

    final activeDays = perDay.length;
    final monthsBox = _box(
      title: byDay ? 'Dropouts per day' : 'Dropouts per month',
      sub: worst == null
          ? 'No dropouts in this period 🎉'
          : 'Highest: ${worst.$1} — ${worst.$2} student${worst.$2 == 1 ? '' : 's'}'
                '${byDay ? ' • tap a bar to see the students' : ''}',
      trailing: chartSwitch,
      child: chart,
    );
    final dailyBox = _box(
      title: 'Daily log',
      sub: activeDays == 0
          ? 'Days with dropouts'
          : '$activeDays day${activeDays == 1 ? '' : 's'} with dropouts • avg ${(total / activeDays).toStringAsFixed(1)} per day • tap a day',
      child: dailyLog,
    );
    final stagesBox = _box(
      title: 'Stage-wise dropouts',
      sub: worstStageIdx < 0
          ? 'Tap a number to see the students'
          : 'Most dropouts: Stage ${worstStageIdx + 1} (${stageTotals[worstStageIdx]}) • tap a number to see the students',
      child: stageTable,
    );
    final reasonsBox = _box(
      title: 'Why they stopped',
      sub: 'Tap a reason to see the students',
      child: Column(
        children: [
          for (final rr in reasons)
            _hBar(
              rr.$1,
              rr.$3,
              maxReason,
              _red,
              () => _showInList(reason: rr.$1),
              extra: total == 0 ? null : '${(rr.$3 * 100 / total).round()}%',
            ),
        ],
      ),
    );
    final splitBox = _box(
      title: 'Course & class type',
      child: Column(
        children: [
          _hBar(
            'English',
            en,
            total,
            _blue,
            () => _showInList(language: 'English'),
          ),
          _hBar(
            'Hindi',
            hi,
            total,
            _teal,
            () => _showInList(language: 'Hindi'),
          ),
          const Divider(height: 18, color: _bg),
          _hBar(
            'Online',
            online,
            total,
            _navy,
            () => _showInList(mode: 'online'),
          ),
          _hBar(
            'Offline',
            offline,
            total,
            _offline,
            () => _showInList(mode: 'offline'),
          ),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final k in ['d1', '7', 'm1', 'm3', 'm6', 'm12'])
                      periodChip(k),
                  ],
                ),
              ),
            ),
            if (wide)
              Text(
                '${_day(start.toIso8601String())} – today',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _secondary,
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (wide)
          Row(
            children: [
              for (var i = 0; i < kpis.length; i++) ...[
                if (i > 0) const SizedBox(width: 10),
                Expanded(child: kpis[i]),
              ],
            ],
          )
        else
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 2.4,
            children: kpis,
          ),
        const SizedBox(height: 12),
        if (wide)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: Column(children: [monthsBox, stagesBox]),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: Column(children: [dailyBox, reasonsBox, splitBox]),
              ),
            ],
          )
        else ...[
          monthsBox,
          dailyBox,
          stagesBox,
          reasonsBox,
          splitBox,
        ],
        if (_rows.length >= 500)
          Text(
            'Report uses the latest 500 dropouts.',
            style: GoogleFonts.poppins(fontSize: 10.5, color: _secondary),
          ),
      ],
    );
  }

  Future<void> _openDetail(Map<String, dynamic> r) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AdminDropoutDetailScreen(id: r['_id'].toString()),
      ),
    );
    if (changed == true) _load();
  }

  Widget _card(Map<String, dynamic> r) {
    final rejoined = _statusOf(r) == 'rejoined';
    final pending = _pendingOf(r);
    final mode = _modeOf(r);
    final section = (r['onlineSection'] ?? '').toString();
    final lastNote = r['lastNote'] is Map
        ? Map<String, dynamic>.from(r['lastNote'])
        : null;
    final name = (r['name'] ?? 'Student').toString();
    final phone = (r['phone'] ?? '').toString();
    final accent = rejoined ? _green : _red;
    final reasonType = _reasonOf(r);
    final reasonIcon = _reasonTypes
        .firstWhere((t) => t.$1 == reasonType, orElse: () => _reasonTypes.last)
        .$2;
    final days = _daysAgo(r);
    final ago = days == 0
        ? 'today'
        : (days == 1 ? 'yesterday' : (days < 99999 ? '$days days ago' : ''));

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _openDetail(r),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: rejoined ? _green.withOpacity(.35) : _border,
            ),
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // colour strip: red = dropped, green = rejoined
                Container(
                  width: 4,
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(16),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 6, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 19,
                              backgroundColor: accent.withOpacity(.1),
                              child: Text(
                                name.trim().isEmpty
                                    ? '?'
                                    : name.trim()[0].toUpperCase(),
                                style: GoogleFonts.poppins(
                                  color: accent,
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
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                      color: _text,
                                    ),
                                  ),
                                  Text(
                                    phone,
                                    style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      color: _secondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: 'Call',
                              visualDensity: VisualDensity.compact,
                              onPressed: phone.isEmpty
                                  ? null
                                  : () => _phone(phone),
                              icon: const Icon(
                                Icons.call_rounded,
                                color: _green,
                                size: 20,
                              ),
                            ),
                            IconButton(
                              tooltip: 'WhatsApp',
                              visualDensity: VisualDensity.compact,
                              onPressed: phone.isEmpty
                                  ? null
                                  : () => _phone(phone, whatsapp: true),
                              icon: const Icon(
                                Icons.chat_rounded,
                                color: _teal,
                                size: 19,
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right_rounded,
                              color: _secondary,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            _tag(
                              '${_langOf(r)} • ${_stageLabel(_stageOf(r))}',
                              _langOf(r) == 'Hindi' ? _teal : _blue,
                            ),
                            _tag(
                              mode == 'offline'
                                  ? 'Offline'
                                  : 'Online${section.isNotEmpty && section != 'None' ? ' • Sec $section' : ''}',
                              mode == 'offline' ? _offline : _navy,
                            ),
                            if (pending > 0)
                              _tag(
                                'Fee pending • $pending ${pending == 1 ? 'month' : 'months'}',
                                _red,
                              ),
                            if (pending == 0) _tag('Fee clear', _green),
                            if (rejoined)
                              _tag(
                                'Rejoined ${_day(r['rejoinedAt']?.toString())}',
                                _green,
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: _bg,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(reasonIcon, size: 15, color: _red),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  (r['reason'] ?? '').toString(),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: _text,
                                    height: 1.35,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (lastNote != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.phone_in_talk_rounded,
                                  size: 14,
                                  color: _amber,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    (lastNote['text'] ?? '').toString(),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.poppins(
                                      fontSize: 11.5,
                                      color: _secondary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 6),
                        Text(
                          'Dropped ${_day(r['createdAt']?.toString())}${ago.isEmpty ? '' : ' ($ago)'} • by '
                          '${(r['droppedByName'] ?? '').toString().isEmpty ? 'admin' : r['droppedByName']}',
                          style: GoogleFonts.poppins(
                            fontSize: 10.5,
                            color: _secondary,
                          ),
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

Widget _tag(String t, Color c) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
  decoration: BoxDecoration(
    color: c.withOpacity(.1),
    borderRadius: BorderRadius.circular(20),
  ),
  child: Text(
    t,
    style: GoogleFonts.poppins(
      fontSize: 10.5,
      fontWeight: FontWeight.w700,
      color: c,
    ),
  ),
);

// =========================================================================
// DETAIL (principal opens one student)
// =========================================================================
class AdminDropoutDetailScreen extends StatefulWidget {
  final String id;
  const AdminDropoutDetailScreen({super.key, required this.id});

  @override
  State<AdminDropoutDetailScreen> createState() =>
      _AdminDropoutDetailScreenState();
}

class _AdminDropoutDetailScreenState extends State<AdminDropoutDetailScreen> {
  Map<String, dynamic>? _d;
  bool _loading = true;
  bool _busy = false;
  bool _changed = false;
  final _note = TextEditingController();
  void Function()? _stopLive;

  @override
  void initState() {
    super.initState();
    _load();
    // another admin added a call note / rejoined / fee paid → shows at once
    _stopLive = AdminLive.on(['dropout_update', 'student_update'], _load);
  }

  @override
  void dispose() {
    _stopLive?.call();
    _note.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final r = await _call('GET', '/admin/dropout?id=${widget.id}');
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (r.ok) _d = r.data;
    });
  }

  Future<void> _saveNote() async {
    final t = _note.text.trim();
    if (t.isEmpty) return;
    setState(() => _busy = true);
    final r = await _call(
      'POST',
      '/admin/dropout/note',
      body: {'id': widget.id, 'text': t},
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (r.ok) {
      _note.clear();
      _changed = true;
      _load();
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(r.message), backgroundColor: _red));
    }
  }

  Future<void> _rejoin() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        // ☀️ always light (the app's dark theme made it dark grey)
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
              child: const Icon(Icons.person_add_alt_1_rounded, color: _green, size: 21),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Rejoin this student?',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w800, fontSize: 16, color: _text),
              ),
            ),
          ],
        ),
        content: Text(
          'Live class, tests, fees and notifications come back exactly as before the dropout.',
          style: GoogleFonts.poppins(fontSize: 13, color: _secondary, height: 1.45),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: GoogleFonts.poppins(color: _secondary, fontWeight: FontWeight.w700)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _green,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Rejoin', style: GoogleFonts.poppins(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    final r = await _call(
      'POST',
      '/admin/dropout/rejoin',
      body: {'id': widget.id},
    );
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(r.message), backgroundColor: r.ok ? _green : _red),
    );
    if (r.ok) {
      _changed = true;
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _changed);
      },
      child: Scaffold(
        backgroundColor: _bg,
        appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: _text,
          surfaceTintColor: Colors.white,
          elevation: 0,
          iconTheme: const IconThemeData(color: _text),
          title: Text(
            'Dropout details',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w800,
              fontSize: 17,
              color: _text,
            ),
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _d == null
            ? Center(
                child: Text(
                  'Could not load',
                  style: GoogleFonts.poppins(color: _secondary),
                ),
              )
            : _content(),
      ),
    );
  }

  Widget _section(
    String title,
    IconData icon,
    Color color,
    List<Widget> children,
  ) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: _border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 19),
            const SizedBox(width: 8),
            Text(
              title,
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w800,
                fontSize: 14,
                color: _text,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ...children,
      ],
    ),
  );

  Widget _row(String k, String v, {Color? color}) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            k,
            style: GoogleFonts.poppins(fontSize: 12, color: _secondary),
          ),
        ),
        Expanded(
          child: Text(
            v,
            style: GoogleFonts.poppins(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: color ?? _text,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _content() {
    final d = _d!;
    final drop = Map<String, dynamic>.from(d['dropout'] ?? {});
    final fee = Map<String, dynamic>.from(d['fee'] ?? {});
    final attendance = ((d['attendance'] ?? []) as List)
        .whereType<Map>()
        .toList();
    final practice = ((d['practice'] ?? []) as List).whereType<Map>().toList();
    final practiceNotes = ((d['practiceNotes'] ?? []) as List)
        .whereType<Map>()
        .toList();
    final tests = ((d['tests'] ?? []) as List).whereType<Map>().toList();
    final notes = ((drop['notes'] ?? []) as List)
        .whereType<Map>()
        .toList()
        .reversed
        .toList();
    final last = d['lastAttended'] is Map
        ? Map<String, dynamic>.from(d['lastAttended'])
        : null;
    final rejoined = drop['status'] == 'rejoined';
    final pending = (fee['monthsPending'] ?? 0) as num;
    final phone = (drop['phone'] ?? '').toString();
    final section = (drop['onlineSection'] ?? '').toString();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 30),
      children: [
        // ---- header ----
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: rejoined
                  ? [_green, const Color(0xFF0E8A57)]
                  : [_red, const Color(0xFFB83B3B)],
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                (drop['name'] ?? '').toString(),
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                phone,
                style: GoogleFonts.poppins(
                  color: Colors.white70,
                  fontSize: 12.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                rejoined
                    ? 'Rejoined on ${_day(drop['rejoinedAt']?.toString())}'
                    : 'Dropped ${drop['language']} ${_stageLabel((drop['stage'] ?? '').toString())} on ${_day(drop['createdAt']?.toString())}',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _phone(phone),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: _green,
                        elevation: 0,
                        minimumSize: const Size.fromHeight(44),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.call_rounded, size: 18),
                      label: Text(
                        'Call',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _phone(phone, whatsapp: true),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white70),
                        minimumSize: const Size.fromHeight(44),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.chat_rounded, size: 18),
                      label: Text(
                        'WhatsApp',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        _section('Why they stopped', Icons.info_outline_rounded, _red, [
          Text(
            (drop['reason'] ?? '').toString(),
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: _text,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Marked by ${(drop['droppedByName'] ?? 'admin').toString().isEmpty ? 'admin' : drop['droppedByName']}',
            style: GoogleFonts.poppins(fontSize: 11, color: _secondary),
          ),
        ]),

        _section('Student', Icons.person_rounded, _navy, [
          _row(
            'Joined',
            '${_day(d['joinedAt']?.toString())}  (${d['daysWithUs'] ?? 0} days with us)',
          ),
          _row(
            'Class',
            (drop['mode'] ?? '') == 'offline'
                ? 'Offline'
                : 'Online${section.isNotEmpty && section != 'None' ? ' • Section $section' : ''}',
          ),
          if ((drop['batchTime'] ?? '').toString().isNotEmpty)
            _row('Timing', drop['batchTime'].toString()),
          _row(
            'Stopped at',
            '${drop['language']} ${_stageLabel((drop['stage'] ?? '').toString())}',
          ),
          _row(
            'Last attended',
            last == null
                ? 'Never'
                : '${last['date']} • ${last['language']} ${_stageLabel((last['stage'] ?? '').toString())}',
          ),
        ]),

        _section(
          'Fees',
          Icons.currency_rupee_rounded,
          pending > 0 ? _red : _green,
          [
            _row(
              'This month',
              (fee['feeStatus'] ?? 'unpaid') == 'paid' ? 'Paid ✅' : 'Not paid',
              color: (fee['feeStatus'] ?? 'unpaid') == 'paid' ? _green : _red,
            ),
            _row(
              'Pending',
              pending > 0
                  ? '$pending ${pending == 1 ? 'month' : 'months'}'
                  : 'Nothing pending',
              color: pending > 0 ? _red : _green,
            ),
            _row('Last paid', _day(fee['lastFeePaymentDate']?.toString())),
          ],
        ),

        _section('Attendance', Icons.fact_check_rounded, _blue, [
          if (attendance.isEmpty)
            Text(
              'No attendance records.',
              style: GoogleFonts.poppins(fontSize: 12, color: _secondary),
            )
          else
            ...attendance.map(
              (a) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${a['language']} ${_stageLabel((a['stage'] ?? '').toString())}',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w700,
                              fontSize: 12.5,
                              color: _text,
                            ),
                          ),
                        ),
                        Text(
                          '${a['percent']}%',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w800,
                            color: (a['percent'] ?? 0) >= 75
                                ? _green
                                : ((a['percent'] ?? 0) >= 50 ? _amber : _red),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        minHeight: 6,
                        value: ((a['percent'] ?? 0) as num) / 100,
                        backgroundColor: _border,
                        valueColor: AlwaysStoppedAnimation(
                          (a['percent'] ?? 0) >= 75
                              ? _green
                              : ((a['percent'] ?? 0) >= 50 ? _amber : _red),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Present ${a['Present']} • Late ${a['Late']} • Absent ${a['Absent']} • of ${a['total']} classes',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: _secondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ]),

        _section('Speaking practice', Icons.record_voice_over_rounded, _teal, [
          if (practice.isEmpty)
            Text(
              'No practice records.',
              style: GoogleFonts.poppins(fontSize: 12, color: _secondary),
            )
          else
            ...practice.map(
              (p) => _row(
                '${p['language']} ${_stageLabel((p['stage'] ?? '').toString())}',
                '${p['count']} times${(p['avgRating'] ?? 0) > 0 ? ' • ⭐ ${p['avgRating']}' : ''}',
              ),
            ),
          if (practiceNotes.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Trainer notes',
              style: GoogleFonts.poppins(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: _secondary,
              ),
            ),
            ...practiceNotes.map(
              (n) => Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '• ${n['date']} ${n['trainerName'] ?? ''}${(n['rating'] ?? 0) > 0 ? ' ⭐${n['rating']}' : ''}${(n['note'] ?? '').toString().isNotEmpty ? ' — ${n['note']}' : ''}',
                  style: GoogleFonts.poppins(fontSize: 11.5, color: _text),
                ),
              ),
            ),
          ],
        ]),

        _section('Tests', Icons.assignment_rounded, _navy, [
          if (tests.isEmpty)
            Text(
              'No tests taken.',
              style: GoogleFonts.poppins(fontSize: 12, color: _secondary),
            )
          else
            ...tests.map(
              (t) => _row(
                '${t['language']} ${_stageLabel((t['stage'] ?? '').toString())}',
                'Best ${t['best']}% • Last ${t['last']?['percent'] ?? 0}% • ${t['attempts']} ${t['attempts'] == 1 ? 'try' : 'tries'}',
              ),
            ),
        ]),

        _section('Call notes', Icons.phone_in_talk_rounded, _amber, [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _note,
                  minLines: 1,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'e.g. Called — will rejoin from December',
                    hintStyle: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.black38,
                    ),
                    isDense: true,
                    filled: true,
                    fillColor: _bg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: _border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: _border),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                style: IconButton.styleFrom(backgroundColor: _navy),
                onPressed: _busy ? null : _saveNote,
                icon: const Icon(
                  Icons.send_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (notes.isEmpty)
            Text(
              'No calls yet.',
              style: GoogleFonts.poppins(fontSize: 12, color: _secondary),
            )
          else
            ...notes.map(
              (n) => Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _bg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      n['text'].toString(),
                      style: GoogleFonts.poppins(fontSize: 12.5, color: _text),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${(n['byName'] ?? '').toString()} • ${_day(n['at']?.toString())}',
                      style: GoogleFonts.poppins(
                        fontSize: 10.5,
                        color: _secondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ]),

        if (!rejoined)
          SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _busy ? null : _rejoin,
              style: ElevatedButton.styleFrom(
                backgroundColor: _green,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: Text(
                'Rejoin — give access back',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w800),
              ),
            ),
          ),
      ],
    );
  }
}