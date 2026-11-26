// =========================================================================
// 🔁 ONLINE ↔ OFFLINE FOR SOME DAYS (admin)
//
//   showModeChangeSheet(...)  → "Change for 1 day / 2 days / 1 week / permanent"
//                               (opened from Student Control)
//   tempModeText(user)        → "Online till 8 Nov (normally offline)" or null
//   AdminModeChangesScreen    → "Converted students": who is changed right now,
//                               till when, history, "End now"
//
// The server puts the student back by itself when the time is over.
// =========================================================================
import 'package:lets_speake_manager/Api/admin_badges.dart';
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:lets_speake_manager/Api/ApiendPoints.dart';
import 'package:lets_speake_manager/Api/api_headers.dart';
import 'package:lets_speake_manager/Api/admin_live.dart';
import 'package:lets_speake_manager/Navigation/AdminShellNavigation.dart';

const Color _text = Color(0xFF173A52);
const Color _secondary = Color(0xFF6B8496);
const Color _border = Color(0xFFD5E5EE);
const Color _bg = Color(0xFFF5FAFD);
const Color _navy = Color(0xFF0A4A75);
const Color _blue = Color(0xFF2E86C9);
const Color _green = Color(0xFF16A66A);
const Color _red = Color(0xFFE45757);
const Color _offline = Color(0xFFC68B00);
const Color _amber = Color(0xFFE59E1B);

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

String _day(DateTime d) => '${d.day} ${_months[d.month - 1]}';

String _dateTime(String? iso) {
  final d = DateTime.tryParse(iso ?? '')?.toLocal();
  if (d == null) return '';
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  return '${_day(d)}, $h:${d.minute.toString().padLeft(2, '0')} ${d.hour < 12 ? 'AM' : 'PM'}';
}

Color _modeColor(String m) => m == 'online' ? _blue : _offline;
String _cap(String m) => m.isEmpty ? m : m[0].toUpperCase() + m.substring(1);

/// "Online till 8 Nov (normally offline)" — null when the student is normal
String? tempModeText(Map user) {
  final base = (user['modeBase'] ?? '').toString();
  final until = DateTime.tryParse(
    (user['modeTempUntil'] ?? '').toString(),
  )?.toLocal();
  if (base.isEmpty || until == null) return null;
  final mode = (user['mode'] ?? '').toString();
  final now = DateTime.now();
  final days = DateTime(
    until.year,
    until.month,
    until.day,
  ).difference(DateTime(now.year, now.month, now.day)).inDays;
  final when = days <= 0
      ? 'today only'
      : (days == 1 ? 'till tomorrow' : 'till ${_day(until)}');
  return '${_cap(mode)} $when (normally $base)';
}

/// What "1 day" means right now (same rule as the server: after 7 PM → tomorrow)
DateTime _previewUntil(String duration) {
  final days = {'1d': 1, '2d': 2, '1w': 7}[duration] ?? 1;
  final now = DateTime.now();
  final extra = now.hour >= 19 ? 1 : 0;
  return DateTime(
    now.year,
    now.month,
    now.day,
  ).add(Duration(days: days - 1 + extra));
}

Future<({bool ok, String message, Map<String, dynamic>? user})> _post(
  String path,
  Map body,
) async {
  try {
    final res = await http
        .post(
          Uri.parse('${ApiEndpoints.baseUrl}$path'),
          headers: ApiHeaders.json(),
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 20));
    final data = jsonDecode(res.body);
    final user = data is Map && data['user'] is Map
        ? Map<String, dynamic>.from(data['user'])
        : null;
    return (
      ok: res.statusCode == 200,
      message: (data['message'] ?? 'Error ${res.statusCode}').toString(),
      user: user,
    );
  } catch (_) {
    return (
      ok: false,
      message: 'No internet / server not reachable',
      user: null,
    );
  }
}

/// Go back to the normal mode now. Returns the updated mode fields or null.
Future<Map<String, dynamic>?> endTempModeNow(
  BuildContext context,
  String userId,
  String name,
) async {
  final sure = await showDialog<bool>(
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
              color: _red.withOpacity(.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.undo_rounded, color: _red, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'End now?',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: _text,
              ),
            ),
          ),
        ],
      ),
      content: Text(
        '$name goes back to the normal mode right now.',
        style: GoogleFonts.poppins(
          fontSize: 13,
          color: _secondary,
          height: 1.45,
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
            backgroundColor: _red,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Text(
            'End now',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    ),
  );
  if (sure != true) return null;
  final r = await _post('/admin/change-mode/end', {'userId': userId});
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(r.message), backgroundColor: r.ok ? _green : _red),
    );
  }
  return r.ok ? r.user : null;
}

/// Bottom sheet: pick online/offline + how long. Returns the updated mode fields or null.
Future<Map<String, dynamic>?> showModeChangeSheet(
  BuildContext context,
  Map user,
) {
  return showModalBottomSheet<Map<String, dynamic>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (_) => _ModeChangeSheet(user: user),
  );
}

class _ModeChangeSheet extends StatefulWidget {
  final Map user;
  const _ModeChangeSheet({required this.user});

  @override
  State<_ModeChangeSheet> createState() => _ModeChangeSheetState();
}

class _ModeChangeSheetState extends State<_ModeChangeSheet> {
  late String _normal; // the student's real mode
  late String _to;
  String _duration = '1d';
  bool _saving = false;
  final _reason = TextEditingController();

  @override
  void initState() {
    super.initState();
    final mode = (widget.user['mode'] ?? 'online').toString().toLowerCase();
    final base = (widget.user['modeBase'] ?? '').toString().toLowerCase();
    _normal = base.isNotEmpty ? base : mode;
    _to = _normal == 'online' ? 'offline' : 'online';
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final r = await _post('/admin/change-mode', {
      'userId': (widget.user['_id'] ?? widget.user['id']).toString(),
      'mode': _to,
      'duration': _duration,
      'reason': _reason.text.trim(),
    });
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(r.message), backgroundColor: r.ok ? _green : _red),
    );
    if (r.ok) Navigator.pop(context, r.user ?? {'mode': _to});
  }

  @override
  Widget build(BuildContext context) {
    final name = (widget.user['name'] ?? 'Student').toString();
    final temp = _duration != 'permanent';
    // a temporary change to the normal mode makes no sense
    final sameAsNormal = temp && _to == _normal;
    final until = temp ? _previewUntil(_duration) : null;

    Widget durationChip(String key, String label) {
      final sel = _duration == key;
      return ChoiceChip(
        selected: sel,
        label: Text(label),
        labelStyle: GoogleFonts.poppins(
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          color: sel ? Colors.white : _text,
        ),
        selectedColor: key == 'permanent' ? _navy : _amber,
        backgroundColor: _bg,
        side: BorderSide(color: sel ? Colors.transparent : _border),
        showCheckmark: false,
        onSelected: (_) => setState(() => _duration = key),
      );
    }

    Widget modeButton(String m, IconData icon) {
      final sel = _to == m;
      final c = _modeColor(m);
      return Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => setState(() => _to = m),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: sel ? c : c.withOpacity(.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: sel ? c : c.withOpacity(.25)),
            ),
            child: Column(
              children: [
                Icon(icon, color: sel ? Colors.white : c),
                const SizedBox(height: 4),
                Text(
                  _cap(m),
                  style: GoogleFonts.poppins(
                    color: sel ? Colors.white : c,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 16),
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
              Text(
                'Change class mode',
                style: GoogleFonts.poppins(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: _text,
                ),
              ),
              Text(
                '$name is normally ${_normal.toUpperCase()}',
                style: GoogleFonts.poppins(fontSize: 12, color: _secondary),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  modeButton('online', Icons.wifi_rounded),
                  const SizedBox(width: 10),
                  modeButton('offline', Icons.location_on_rounded),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'For how long?',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w700,
                  color: _text,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  durationChip('1d', '1 day'),
                  durationChip('2d', '2 days'),
                  durationChip('1w', '1 week'),
                  durationChip('permanent', 'Permanent'),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: (sameAsNormal ? _red : (temp ? _amber : _navy))
                      .withOpacity(.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  sameAsNormal
                      ? '$name is already $_normal normally. Choose ${_normal == 'online' ? 'Offline' : 'Online'}, or Permanent.'
                      : temp
                      ? '${_cap(_to)} until ${_day(until!)} night. Then back to $_normal automatically.\n'
                            'The ${_to} trainer sees $name in the class list with a badge.'
                      : '$name becomes ${_to.toUpperCase()} for good.',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: _text,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _reason,
                maxLength: 200,
                decoration: InputDecoration(
                  hintText: 'Reason (optional) e.g. out of town, exam week',
                  hintStyle: GoogleFonts.poppins(fontSize: 12.5),
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
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: (_saving || sameAsNormal) ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _modeColor(_to),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          temp
                              ? 'Make ${_cap(_to)} till ${_day(until!)}'
                              : 'Make ${_cap(_to)} permanently',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
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
// 📋 CONVERTED STUDENTS
// =========================================================================
class AdminModeChangesScreen extends StatefulWidget {
  final bool embedded; // inside the admin shell (sidebar / drawer)
  const AdminModeChangesScreen({super.key, this.embedded = false});

  @override
  State<AdminModeChangesScreen> createState() => _AdminModeChangesScreenState();
}

class _AdminModeChangesScreenState extends State<AdminModeChangesScreen>
    with WidgetsBindingObserver {
  String _status = 'active'; // active | all
  String _to = 'all'; // all | online | offline
  String _q = '';
  bool _loading = true;
  List<Map<String, dynamic>> _rows = [];
  Map<String, dynamic> _active = {'online': 0, 'offline': 0};
  Timer? _debounce;
  Timer? _poll;
  void Function()? _stopLive;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    // ⚡ changed from Student Control / "End now" / time over → list updates by itself
    _stopLive = AdminLive.on([
      'mode_change_update',
      'student_update',
    ], () => _load(quiet: true));
    // safety net + the "till 8 Nov" / time-over status changes by itself on the server
    _poll = Timer.periodic(
      const Duration(seconds: 60),
      (_) => _load(quiet: true),
    );
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
    try {
      final uri = Uri.parse('${ApiEndpoints.baseUrl}/admin/mode-changes')
          .replace(
            queryParameters: {
              'status': _status,
              'mode': _to,
              if (_q.isNotEmpty) 'q': _q,
              '_t': '${DateTime.now().millisecondsSinceEpoch}',
            },
          );
      final res = await http
          .get(uri, headers: ApiHeaders.auth())
          .timeout(const Duration(seconds: 20));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        _rows = ((data['changes'] ?? []) as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        if (data['active'] is Map)
          _active = Map<String, dynamic>.from(data['active']);
      }
    } catch (e) {
      debugPrint('Mode changes load error: $e');
    }
    if (mounted) setState(() => _loading = false);
  }

  Widget _filterChip(
    String label,
    bool sel,
    VoidCallback onTap, {
    Color color = _navy,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        selected: sel,
        label: Text(label),
        showCheckmark: false,
        labelStyle: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: sel ? Colors.white : _text,
        ),
        selectedColor: color,
        backgroundColor: Colors.white,
        side: BorderSide(color: sel ? Colors.transparent : _border),
        onSelected: (_) => onTap(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final online = _active['online'] ?? 0;
    final offline = _active['offline'] ?? 0;
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
        title: Text(
          'Converted students',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w800,
            fontSize: 17,
            color: _text,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () => _load(),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _load(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 30),
          children: [
            Row(
              children: [
                _countTile(
                  'Online for now',
                  '$online',
                  'normally offline',
                  _blue,
                ),
                const SizedBox(width: 10),
                _countTile(
                  'Offline for now',
                  '$offline',
                  'normally online',
                  _offline,
                ),
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
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: _border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: _border),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _filterChip('Running now', _status == 'active', () {
                    _status = 'active';
                    _load();
                  }),
                  _filterChip('All history', _status == 'all', () {
                    _status = 'all';
                    _load();
                  }),
                  const SizedBox(width: 8),
                  _filterChip('All', _to == 'all', () {
                    _to = 'all';
                    _load();
                  }, color: _text),
                  _filterChip('→ Online', _to == 'online', () {
                    _to = 'online';
                    _load();
                  }, color: _blue),
                  _filterChip('→ Offline', _to == 'offline', () {
                    _to = 'offline';
                    _load();
                  }, color: _offline),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_rows.isEmpty)
              Padding(
                padding: const EdgeInsets.all(40),
                child: Text(
                  _status == 'active'
                      ? 'No student is changed right now.'
                      : 'No changes yet.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(color: _secondary),
                ),
              )
            else
              ..._rows.map(_row),
          ],
        ),
      ),
    );
  }

  Widget _countTile(String title, String n, String sub, Color c) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            n,
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: c,
            ),
          ),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: _text,
            ),
          ),
          Text(
            sub,
            style: GoogleFonts.poppins(fontSize: 10.5, color: _secondary),
          ),
        ],
      ),
    ),
  );

  Widget _row(Map<String, dynamic> r) {
    final from = (r['from'] ?? '').toString();
    final to = (r['to'] ?? '').toString();
    final status = (r['status'] ?? '').toString();
    final duration = (r['duration'] ?? '').toString();
    final until = DateTime.tryParse((r['until'] ?? '').toString())?.toLocal();
    final durLabel =
        {
          '1d': '1 day',
          '2d': '2 days',
          '1w': '1 week',
          'permanent': 'Permanent',
        }[duration] ??
        duration;
    final statusLook =
        {
          'active': (
            'Running • till ${until == null ? '' : _day(until)}',
            _amber,
          ),
          'ended': ('Finished • back to $from', _secondary),
          'cancelled': ('Ended early / changed again', _secondary),
          'permanent': ('Permanent change', _navy),
        }[status] ??
        (status, _secondary);
    final reason = (r['reason'] ?? '').toString();
    final english = r['englishAccess'] is Map
        ? (r['englishAccess'] as Map).entries
              .where((e) => e.value == true)
              .map((e) => e.key.toString().replaceAll('stage', 'S'))
              .join(' ')
        : '';
    final hindi = r['hindiAccess'] is Map
        ? (r['hindiAccess'] as Map).entries
              .where((e) => e.value == true)
              .map((e) => e.key.toString().replaceAll('stage', 'S'))
              .join(' ')
        : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
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
                child: Text(
                  (r['name'] ?? 'Student').toString(),
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: _text,
                  ),
                ),
              ),
              _pill(_cap(from), _modeColor(from)),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Icon(
                  Icons.arrow_forward_rounded,
                  size: 15,
                  color: _secondary,
                ),
              ),
              _pill(_cap(to), _modeColor(to)),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            [
              (r['phone'] ?? '').toString(),
              if (english.isNotEmpty) 'English $english',
              if (hindi.isNotEmpty) 'Hindi $hindi',
              if ((r['onlineSection'] ?? '').toString().isNotEmpty &&
                  r['onlineSection'] != 'None')
                'Sec ${r['onlineSection']}',
            ].where((e) => e.isNotEmpty).join(' • '),
            style: GoogleFonts.poppins(fontSize: 11, color: _secondary),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _pill(durLabel, _navy),
              const SizedBox(width: 6),
              Flexible(child: _pill(statusLook.$1, statusLook.$2)),
            ],
          ),
          if (reason.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Reason: $reason',
              style: GoogleFonts.poppins(fontSize: 11.5, color: _text),
            ),
          ],
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(
                  'By ${(r['changedByName'] ?? 'admin').toString().isEmpty ? 'admin' : r['changedByName']} • ${_dateTime(r['createdAt']?.toString())}',
                  style: GoogleFonts.poppins(fontSize: 10.5, color: _secondary),
                ),
              ),
              if (status == 'active')
                TextButton(
                  onPressed: () async {
                    final u = await endTempModeNow(
                      context,
                      r['userId'].toString(),
                      (r['name'] ?? '').toString(),
                    );
                    if (u != null) _load();
                  },
                  child: Text(
                    'End now',
                    style: GoogleFonts.poppins(
                      color: _red,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pill(String t, Color c) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: c.withOpacity(.1),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      t,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: GoogleFonts.poppins(
        fontSize: 10.5,
        fontWeight: FontWeight.w700,
        color: c,
      ),
    ),
  );
}
