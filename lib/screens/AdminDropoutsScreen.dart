// =========================================================================
// 🚪 DROPOUTS — students who stopped the course in the middle
//
//   showMarkDropoutSheet(...) → from Student Control: language + stage where the
//                               student stopped + reason → all access OFF
//   AdminDropoutsScreen       → principal's list: who dropped, which course/stage,
//                               online section, reason, fee pending, call button
//   AdminDropoutDetailScreen  → everything about the student: fees, joined date,
//                               attendance, practice, tests, call notes, Rejoin
// =========================================================================
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
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

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

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

Future<({bool ok, String message, Map<String, dynamic>? data})> _call(String method, String path,
    {Map<String, dynamic>? body}) async {
  try {
    final uri = Uri.parse('${ApiEndpoints.baseUrl}$path');
    final res = method == 'GET'
        ? await http.get(uri, headers: ApiHeaders.auth()).timeout(const Duration(seconds: 25))
        : await http.post(uri, headers: ApiHeaders.json(), body: jsonEncode(body ?? {})).timeout(const Duration(seconds: 25));
    final data = jsonDecode(res.body);
    final map = data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
    return (ok: res.statusCode == 200, message: (map['message'] ?? '').toString(), data: map);
  } catch (_) {
    return (ok: false, message: 'No internet / server not reachable', data: null);
  }
}

Future<void> _phone(String phone, {bool whatsapp = false}) async {
  final digits = phone.replaceAll(RegExp(r'\D'), '');
  final ten = digits.length > 10 ? digits.substring(digits.length - 10) : digits;
  final uri = whatsapp ? Uri.parse('https://wa.me/91$ten') : Uri.parse('tel:+91$ten');
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
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
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
        ? List.generate(7, (i) => 'stage${i + 1}').where((s) => access[s] == true).toList()
        : <String>[];
    _enabled = {
      'English': on(widget.user['englishAccess']),
      'Hindi': on(widget.user['hindiAccess']),
    };
    _language = _enabled['English']!.isNotEmpty || _enabled['Hindi']!.isEmpty ? 'English' : 'Hindi';
    _pickHighestStage();
  }

  void _pickHighestStage() {
    final list = _enabled[_language]!;
    _stage = list.isNotEmpty ? list.last : 'stage1'; // usually the stage they were studying
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final text = _reason.text.trim();
    final reason = [if (_reasonType.isNotEmpty) _reasonType, if (text.isNotEmpty) text].join(' — ');
    if (reason.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose or write the reason'), backgroundColor: _red),
      );
      return;
    }
    setState(() => _saving = true);
    final r = await _call('POST', '/admin/dropout', body: {
      'userId': (widget.user['_id'] ?? widget.user['id']).toString(),
      'language': _language,
      'stage': _stage,
      'reason': reason,
      'reasonType': _reasonType,
    });
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(r.message.isEmpty ? 'Done' : r.message), backgroundColor: r.ok ? _green : _red),
    );
    if (r.ok) Navigator.pop(context, true);
  }

  Widget _chip(String label, bool sel, VoidCallback onTap, {Color color = _navy, IconData? icon}) => ChoiceChip(
        selected: sel,
        showCheckmark: false,
        avatar: icon == null ? null : Icon(icon, size: 16, color: sel ? Colors.white : color),
        label: Text(label),
        labelStyle: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.w700, color: sel ? Colors.white : _text),
        selectedColor: color,
        backgroundColor: _bg,
        side: BorderSide(color: sel ? color : _border),
        onSelected: (_) => onTap(),
      );

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 8),
        child: Text(t, style: GoogleFonts.poppins(fontWeight: FontWeight.w700, color: _text, fontSize: 13)),
      );

  @override
  Widget build(BuildContext context) {
    final name = (widget.user['name'] ?? 'Student').toString();
    final langs = _enabled.entries.where((e) => e.value.isNotEmpty).map((e) => e.key).toList();
    final stages = _enabled[_language]!.isNotEmpty ? _enabled[_language]! : List.generate(7, (i) => 'stage${i + 1}');
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
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
                  decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(4)),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(color: _red.withOpacity(.1), borderRadius: BorderRadius.circular(14)),
                    child: const Icon(Icons.person_remove_alt_1_rounded, color: _red),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Mark as dropout',
                            style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w800, color: _text)),
                        Text(name, style: GoogleFonts.poppins(fontSize: 12, color: _secondary)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: _amber.withOpacity(.08), borderRadius: BorderRadius.circular(12)),
                child: Text(
                  'All course access will be switched OFF. The principal will see this student in Dropouts with your reason. You can give access back any time with "Rejoin".',
                  style: GoogleFonts.poppins(fontSize: 11.5, color: _text, height: 1.4),
                ),
              ),
              _label('Which course did they stop?'),
              Wrap(
                spacing: 8,
                children: (langs.isEmpty ? ['English', 'Hindi'] : langs)
                    .map((l) => _chip(l, _language == l, () => setState(() {
                          _language = l;
                          _pickHighestStage();
                        }), color: l == 'Hindi' ? _teal : _blue))
                    .toList(),
              ),
              _label('Stopped at stage'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: stages.map((s) => _chip(_stageLabel(s), _stage == s, () => setState(() => _stage = s))).toList(),
              ),
              _label('Reason'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _reasonTypes
                    .map((r) => _chip(r.$1, _reasonType == r.$1, () => setState(() => _reasonType = _reasonType == r.$1 ? '' : r.$1),
                        color: _red, icon: r.$2))
                    .toList(),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _reason,
                maxLines: 3,
                maxLength: 400,
                decoration: InputDecoration(
                  hintText: 'What did the student say? e.g. "Shifting to Hyderabad for job, may come back in Jan"',
                  hintStyle: GoogleFonts.poppins(fontSize: 12, color: Colors.black38),
                  filled: true,
                  fillColor: _bg,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _border)),
                  enabledBorder:
                      OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _border)),
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
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: _saving
                      ? const SizedBox(
                          width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.person_remove_alt_1_rounded),
                  label: Text('Mark dropout — ${_language} ${_stageLabel(_stage)}',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w800, fontSize: 13.5)),
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
// =========================================================================
class AdminDropoutsScreen extends StatefulWidget {
  final bool embedded;
  const AdminDropoutsScreen({super.key, this.embedded = false});

  @override
  State<AdminDropoutsScreen> createState() => _AdminDropoutsScreenState();
}

class _AdminDropoutsScreenState extends State<AdminDropoutsScreen> with WidgetsBindingObserver {
  String _status = 'dropped';
  String _language = 'all';
  String _stage = 'all';
  String _mode = 'all';
  String _q = '';
  bool _loading = true;
  List<Map<String, dynamic>> _rows = [];
  Map<String, dynamic> _summary = {};
  Timer? _debounce;
  Timer? _poll;
  void Function()? _stopLive;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    // ⚡ marked dropout / rejoined / call note / fee paid → list updates by itself
    _stopLive = AdminLive.on(['dropout_update', 'student_update'], () => _load(quiet: true));
    _poll = Timer.periodic(const Duration(seconds: 30), (_) => _load(quiet: true)); // safety net
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _debounce?.cancel();
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
    final qs = Uri(queryParameters: {
      'status': _status,
      'language': _language,
      'stage': _stage,
      'mode': _mode,
      if (_q.isNotEmpty) 'q': _q,
      '_t': '${DateTime.now().millisecondsSinceEpoch}',
    }).query;
    final r = await _call('GET', '/admin/dropouts?$qs');
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (!r.ok && quiet) return; // keep the old list if a background refresh fails
      if (r.ok && r.data != null) {
        _rows = ((r.data!['dropouts'] ?? []) as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
        _summary = r.data!['summary'] is Map ? Map<String, dynamic>.from(r.data!['summary']) : {};
      }
    });
  }

  Widget _filter(String label, bool sel, VoidCallback onTap, {Color color = _navy}) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          selected: sel,
          showCheckmark: false,
          label: Text(label),
          labelStyle: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700, color: sel ? Colors.white : _text),
          selectedColor: color,
          backgroundColor: Colors.white,
          side: BorderSide(color: sel ? color : _border),
          onSelected: (_) => onTap(),
        ),
      );

  int _count(String language) {
    final m = _summary[language];
    if (m is! Map) return 0;
    return m.values.fold<int>(0, (a, b) => a + (b is int ? b : 0));
  }

  @override
  Widget build(BuildContext context) {
    final total = _summary['total'] ?? 0;
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
        leading: widget.embedded && AdminShellNavigation.shouldShowMenuButton(context)
            ? IconButton(icon: const Icon(Icons.menu_rounded), onPressed: AdminShellNavigation.openDrawer)
            : null,
        title: Text('Dropouts', style: GoogleFonts.poppins(fontWeight: FontWeight.w800, fontSize: 17, color: _text)),
        actions: [IconButton(onPressed: () => _load(), icon: const Icon(Icons.refresh_rounded))],
      ),
      body: RefreshIndicator(
        onRefresh: () => _load(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 30),
          children: [
            // ---- counts ----
            Row(
              children: [
                _countTile('Total dropped', '$total', _red),
                const SizedBox(width: 10),
                _countTile('English', '${_count('English')}', _blue),
                const SizedBox(width: 10),
                _countTile('Hindi', '${_count('Hindi')}', _teal),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              onChanged: (v) {
                _debounce?.cancel();
                _debounce = Timer(const Duration(milliseconds: 400), () {
                  _q = v.trim();
                  _load();
                });
              },
              decoration: InputDecoration(
                hintText: 'Search name or phone',
                prefixIcon: const Icon(Icons.search_rounded),
                isDense: true,
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _border)),
                enabledBorder:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _border)),
              ),
            ),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                _filter('Dropped', _status == 'dropped', () {
                  _status = 'dropped';
                  _load();
                }, color: _red),
                _filter('Rejoined', _status == 'rejoined', () {
                  _status = 'rejoined';
                  _load();
                }, color: _green),
                _filter('All', _status == 'all', () {
                  _status = 'all';
                  _load();
                }),
                const SizedBox(width: 6),
                _filter('Online', _mode == 'online', () {
                  _mode = _mode == 'online' ? 'all' : 'online';
                  _load();
                }, color: _blue),
                _filter('Offline', _mode == 'offline', () {
                  _mode = _mode == 'offline' ? 'all' : 'offline';
                  _load();
                }, color: _offline),
              ]),
            ),
            const SizedBox(height: 6),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                _filter('All courses', _language == 'all', () {
                  _language = 'all';
                  _load();
                }),
                _filter('English', _language == 'English', () {
                  _language = 'English';
                  _load();
                }, color: _blue),
                _filter('Hindi', _language == 'Hindi', () {
                  _language = 'Hindi';
                  _load();
                }, color: _teal),
                const SizedBox(width: 6),
                _filter('All stages', _stage == 'all', () {
                  _stage = 'all';
                  _load();
                }),
                for (var i = 1; i <= 7; i++)
                  _filter('Stage $i', _stage == 'stage$i', () {
                    _stage = 'stage$i';
                    _load();
                  }),
              ]),
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
            else if (_rows.isEmpty)
              Padding(
                padding: const EdgeInsets.all(40),
                child: Text(_status == 'dropped' ? 'No dropouts here. 🎉' : 'Nothing here.',
                    textAlign: TextAlign.center, style: GoogleFonts.poppins(color: _secondary)),
              )
            else
              ..._rows.map(_card),
          ],
        ),
      ),
    );
  }

  Widget _countTile(String title, String n, Color c) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: _border)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(n, style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w800, color: c)),
              Text(title, style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: _secondary)),
            ],
          ),
        ),
      );

  Widget _card(Map<String, dynamic> r) {
    final rejoined = r['status'] == 'rejoined';
    final fee = r['feeNow'] is Map ? Map<String, dynamic>.from(r['feeNow']) : <String, dynamic>{};
    final pending = (fee['monthsPending'] ?? r['monthsPending'] ?? 0) as num;
    final mode = (r['mode'] ?? '').toString();
    final section = (r['onlineSection'] ?? '').toString();
    final lastNote = r['lastNote'] is Map ? Map<String, dynamic>.from(r['lastNote']) : null;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: rejoined ? _green.withOpacity(.35) : _border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () async {
          final changed = await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (_) => AdminDropoutDetailScreen(id: r['_id'].toString())),
          );
          if (changed == true) _load();
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: (rejoined ? _green : _red).withOpacity(.1),
                    child: Text(
                      (r['name'] ?? '?').toString().isEmpty ? '?' : (r['name'] ?? '?').toString()[0].toUpperCase(),
                      style: GoogleFonts.poppins(color: rejoined ? _green : _red, fontWeight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text((r['name'] ?? 'Student').toString(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 14, color: _text)),
                        Text((r['phone'] ?? '').toString(), style: GoogleFonts.poppins(fontSize: 11.5, color: _secondary)),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Call',
                    onPressed: () => _phone((r['phone'] ?? '').toString()),
                    icon: const Icon(Icons.call_rounded, color: _green),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _tag('${r['language']} • ${_stageLabel((r['stage'] ?? '').toString())}',
                      r['language'] == 'Hindi' ? _teal : _blue),
                  _tag(mode == 'offline' ? 'Offline' : 'Online${section.isNotEmpty && section != 'None' ? ' • Sec $section' : ''}',
                      mode == 'offline' ? _offline : _navy),
                  if (pending > 0) _tag('Fee pending • $pending ${pending == 1 ? 'month' : 'months'}', _red),
                  if (pending == 0) _tag('Fee paid', _green),
                  if (rejoined) _tag('Rejoined ${_day(r['rejoinedAt']?.toString())}', _green),
                ],
              ),
              const SizedBox(height: 8),
              Text('Reason: ${r['reason'] ?? ''}',
                  maxLines: 2, overflow: TextOverflow.ellipsis, style: GoogleFonts.poppins(fontSize: 12, color: _text)),
              if (lastNote != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('📞 ${lastNote['text']}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(fontSize: 11.5, color: _secondary)),
                ),
              const SizedBox(height: 6),
              Text('Dropped ${_day(r['createdAt']?.toString())} • by ${(r['droppedByName'] ?? 'admin').toString().isEmpty ? 'admin' : r['droppedByName']}',
                  style: GoogleFonts.poppins(fontSize: 10.5, color: _secondary)),
            ],
          ),
        ),
      ),
    );
  }
}

Widget _tag(String t, Color c) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: c.withOpacity(.1), borderRadius: BorderRadius.circular(20)),
      child: Text(t, style: GoogleFonts.poppins(fontSize: 10.5, fontWeight: FontWeight.w700, color: c)),
    );

// =========================================================================
// DETAIL (principal opens one student)
// =========================================================================
class AdminDropoutDetailScreen extends StatefulWidget {
  final String id;
  const AdminDropoutDetailScreen({super.key, required this.id});

  @override
  State<AdminDropoutDetailScreen> createState() => _AdminDropoutDetailScreenState();
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
    final r = await _call('POST', '/admin/dropout/note', body: {'id': widget.id, 'text': t});
    if (!mounted) return;
    setState(() => _busy = false);
    if (r.ok) {
      _note.clear();
      _changed = true;
      _load();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(r.message), backgroundColor: _red));
    }
  }

  Future<void> _rejoin() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Rejoin this student?', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        content: Text('All the access they had before dropping will be switched ON again.',
            style: GoogleFonts.poppins(fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: _green, foregroundColor: Colors.white, elevation: 0),
            child: const Text('Rejoin'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    final r = await _call('POST', '/admin/dropout/rejoin', body: {'id': widget.id});
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(r.message), backgroundColor: r.ok ? _green : _red));
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
          title: Text('Dropout details', style: GoogleFonts.poppins(fontWeight: FontWeight.w800, fontSize: 17, color: _text)),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _d == null
                ? Center(child: Text('Could not load', style: GoogleFonts.poppins(color: _secondary)))
                : _content(),
      ),
    );
  }

  Widget _section(String title, IconData icon, Color color, List<Widget> children) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: _border)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, color: color, size: 19),
              const SizedBox(width: 8),
              Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.w800, fontSize: 14, color: _text)),
            ]),
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
            SizedBox(width: 120, child: Text(k, style: GoogleFonts.poppins(fontSize: 12, color: _secondary))),
            Expanded(
              child: Text(v, style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.w600, color: color ?? _text)),
            ),
          ],
        ),
      );

  Widget _content() {
    final d = _d!;
    final drop = Map<String, dynamic>.from(d['dropout'] ?? {});
    final fee = Map<String, dynamic>.from(d['fee'] ?? {});
    final attendance = ((d['attendance'] ?? []) as List).whereType<Map>().toList();
    final practice = ((d['practice'] ?? []) as List).whereType<Map>().toList();
    final practiceNotes = ((d['practiceNotes'] ?? []) as List).whereType<Map>().toList();
    final tests = ((d['tests'] ?? []) as List).whereType<Map>().toList();
    final notes = ((drop['notes'] ?? []) as List).whereType<Map>().toList().reversed.toList();
    final last = d['lastAttended'] is Map ? Map<String, dynamic>.from(d['lastAttended']) : null;
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
            gradient: LinearGradient(colors: rejoined ? [_green, const Color(0xFF0E8A57)] : [_red, const Color(0xFFB83B3B)]),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text((drop['name'] ?? '').toString(),
                  style: GoogleFonts.poppins(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w800)),
              Text(phone, style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12.5)),
              const SizedBox(height: 8),
              Text(
                rejoined
                    ? 'Rejoined on ${_day(drop['rejoinedAt']?.toString())}'
                    : 'Dropped ${drop['language']} ${_stageLabel((drop['stage'] ?? '').toString())} on ${_day(drop['createdAt']?.toString())}',
                style: GoogleFonts.poppins(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600),
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
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.call_rounded, size: 18),
                      label: Text('Call', style: GoogleFonts.poppins(fontWeight: FontWeight.w800)),
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
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.chat_rounded, size: 18),
                      label: Text('WhatsApp', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        _section('Why they stopped', Icons.info_outline_rounded, _red, [
          Text((drop['reason'] ?? '').toString(), style: GoogleFonts.poppins(fontSize: 13, color: _text, height: 1.45)),
          const SizedBox(height: 6),
          Text('Marked by ${(drop['droppedByName'] ?? 'admin').toString().isEmpty ? 'admin' : drop['droppedByName']}',
              style: GoogleFonts.poppins(fontSize: 11, color: _secondary)),
        ]),

        _section('Student', Icons.person_rounded, _navy, [
          _row('Joined', '${_day(d['joinedAt']?.toString())}  (${d['daysWithUs'] ?? 0} days with us)'),
          _row('Class', (drop['mode'] ?? '') == 'offline'
              ? 'Offline'
              : 'Online${section.isNotEmpty && section != 'None' ? ' • Section $section' : ''}'),
          if ((drop['batchTime'] ?? '').toString().isNotEmpty) _row('Timing', drop['batchTime'].toString()),
          _row('Stopped at', '${drop['language']} ${_stageLabel((drop['stage'] ?? '').toString())}'),
          _row('Last attended',
              last == null ? 'Never' : '${last['date']} • ${last['language']} ${_stageLabel((last['stage'] ?? '').toString())}'),
        ]),

        _section('Fees', Icons.currency_rupee_rounded, pending > 0 ? _red : _green, [
          _row('This month', (fee['feeStatus'] ?? 'unpaid') == 'paid' ? 'Paid ✅' : 'Not paid',
              color: (fee['feeStatus'] ?? 'unpaid') == 'paid' ? _green : _red),
          _row('Pending', pending > 0 ? '$pending ${pending == 1 ? 'month' : 'months'}' : 'Nothing pending',
              color: pending > 0 ? _red : _green),
          _row('Last paid', _day(fee['lastFeePaymentDate']?.toString())),
        ]),

        _section('Attendance', Icons.fact_check_rounded, _blue, [
          if (attendance.isEmpty)
            Text('No attendance records.', style: GoogleFonts.poppins(fontSize: 12, color: _secondary))
          else
            ...attendance.map((a) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Expanded(
                          child: Text('${a['language']} ${_stageLabel((a['stage'] ?? '').toString())}',
                              style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 12.5, color: _text)),
                        ),
                        Text('${a['percent']}%',
                            style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w800,
                                color: (a['percent'] ?? 0) >= 75 ? _green : ((a['percent'] ?? 0) >= 50 ? _amber : _red))),
                      ]),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          minHeight: 6,
                          value: ((a['percent'] ?? 0) as num) / 100,
                          backgroundColor: _border,
                          valueColor: AlwaysStoppedAnimation(
                              (a['percent'] ?? 0) >= 75 ? _green : ((a['percent'] ?? 0) >= 50 ? _amber : _red)),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text('Present ${a['Present']} • Late ${a['Late']} • Absent ${a['Absent']} • of ${a['total']} classes',
                          style: GoogleFonts.poppins(fontSize: 11, color: _secondary)),
                    ],
                  ),
                )),
        ]),

        _section('Speaking practice', Icons.record_voice_over_rounded, _teal, [
          if (practice.isEmpty)
            Text('No practice records.', style: GoogleFonts.poppins(fontSize: 12, color: _secondary))
          else
            ...practice.map((p) => _row('${p['language']} ${_stageLabel((p['stage'] ?? '').toString())}',
                '${p['count']} times${(p['avgRating'] ?? 0) > 0 ? ' • ⭐ ${p['avgRating']}' : ''}')),
          if (practiceNotes.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('Trainer notes', style: GoogleFonts.poppins(fontSize: 11.5, fontWeight: FontWeight.w700, color: _secondary)),
            ...practiceNotes.map((n) => Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '• ${n['date']} ${n['trainerName'] ?? ''}${(n['rating'] ?? 0) > 0 ? ' ⭐${n['rating']}' : ''}${(n['note'] ?? '').toString().isNotEmpty ? ' — ${n['note']}' : ''}',
                    style: GoogleFonts.poppins(fontSize: 11.5, color: _text),
                  ),
                )),
          ],
        ]),

        _section('Tests', Icons.assignment_rounded, _navy, [
          if (tests.isEmpty)
            Text('No tests taken.', style: GoogleFonts.poppins(fontSize: 12, color: _secondary))
          else
            ...tests.map((t) => _row(
                '${t['language']} ${_stageLabel((t['stage'] ?? '').toString())}',
                'Best ${t['best']}% • Last ${t['last']?['percent'] ?? 0}% • ${t['attempts']} ${t['attempts'] == 1 ? 'try' : 'tries'}')),
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
                    hintStyle: GoogleFonts.poppins(fontSize: 12, color: Colors.black38),
                    isDense: true,
                    filled: true,
                    fillColor: _bg,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _border)),
                    enabledBorder:
                        OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _border)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                style: IconButton.styleFrom(backgroundColor: _navy),
                onPressed: _busy ? null : _saveNote,
                icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (notes.isEmpty)
            Text('No calls yet.', style: GoogleFonts.poppins(fontSize: 12, color: _secondary))
          else
            ...notes.map((n) => Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: _bg, borderRadius: BorderRadius.circular(12)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(n['text'].toString(), style: GoogleFonts.poppins(fontSize: 12.5, color: _text)),
                      const SizedBox(height: 2),
                      Text('${(n['byName'] ?? '').toString()} • ${_day(n['at']?.toString())}',
                          style: GoogleFonts.poppins(fontSize: 10.5, color: _secondary)),
                    ],
                  ),
                )),
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: Text('Rejoin — give access back', style: GoogleFonts.poppins(fontWeight: FontWeight.w800)),
            ),
          ),
      ],
    );
  }
}
