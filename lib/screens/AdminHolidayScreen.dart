import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:lets_speake_manager/Api/ApiendPoints.dart';
import 'package:lets_speake_manager/Api/api_headers.dart';

/// 🏖 Holidays — "Tomorrow is Dasara" in one tap.
/// On a holiday nobody is marked absent, and the day is not a working day
/// (trainer salary, attendance %, best student of the month).
class AdminHolidayScreen extends StatefulWidget {
  const AdminHolidayScreen({super.key});

  @override
  State<AdminHolidayScreen> createState() => _AdminHolidayScreenState();
}

class _AdminHolidayScreenState extends State<AdminHolidayScreen> {
  static const Color navy = Color(0xFF155A88);
  static const Color purple = Color(0xFF7A5AF8);
  static const Color textColor = Color(0xFF173A52);
  static const Color secondaryText = Color(0xFF678196);
  static const Color borderColor = Color(0xFFD5E5EE);
  static const Color background = Color(0xFFE8F2F8);
  static const Color success = Color(0xFF16A66A);
  static const Color error = Color(0xFFE45757);

  static const List<String> _suggestions = [
    'Dasara',
    'Diwali',
    'Sankranti',
    'Holi',
    'Ugadi',
    'Ramzan',
    'Christmas',
    'Independence Day',
    'Republic Day',
  ];

  final TextEditingController _title = TextEditingController(text: 'Dasara');
  late DateTime _from;
  late DateTime _to;
  String _appliesTo = 'all'; // all | students | trainers
  String _quick = 'tomorrow'; // today | tomorrow | pick

  List<Map<String, dynamic>> _holidays = [];
  Map<String, dynamic>? _rules;
  bool _loading = true;
  bool _saving = false;
  bool _showPast = false;
  final Set<String> _removing = <String>{};

  IO.Socket? _socket;
  bool _live = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    _from = today.add(const Duration(days: 1));
    _to = _from;
    _load();
    _loadRules();
    _connectSocket();
  }

  @override
  void dispose() {
    _title.dispose();
    try {
      _socket?.clearListeners();
      _socket?.dispose();
    } catch (_) {}
    super.dispose();
  }

  // ---------------------------------------------------------------
  // DATA
  // ---------------------------------------------------------------
  void _connectSocket() {
    try {
      final uri = Uri.parse(ApiEndpoints.baseUrl);
      final host = "${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}";
      final s = IO.io(
        host,
        IO.OptionBuilder()
            .setTransports(['websocket'])
            .setAuth({'token': ApiHeaders.token ?? ''})
            .enableForceNew()
            .enableAutoConnect()
            .build(),
      );
      s.onConnect((_) {
        s.emit('join_admin_room');
        if (mounted) setState(() => _live = true);
      });
      s.onDisconnect((_) {
        if (mounted) setState(() => _live = false);
      });
      s.on('holiday_updated', (_) => _load(silent: true));
      _socket = s;
    } catch (e) {
      debugPrint('Holiday socket error: $e');
    }
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent && mounted) setState(() => _loading = true);
    try {
      final res = await http.get(
        Uri.parse('${ApiEndpoints.baseUrl}/admin/holidays?_t=${DateTime.now().millisecondsSinceEpoch}'),
        headers: ApiHeaders.auth(),
      );
      if (res.statusCode == 200 && mounted) {
        final data = jsonDecode(res.body);
        setState(() {
          _holidays = (data['holidays'] as List? ?? []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
        });
      }
    } catch (e) {
      debugPrint('Holiday load error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadRules() async {
    try {
      final res = await http.get(Uri.parse('${ApiEndpoints.baseUrl}/attendance-rules'));
      if (res.statusCode == 200 && mounted) setState(() => _rules = Map<String, dynamic>.from(jsonDecode(res.body)));
    } catch (_) {}
  }

  String _key(DateTime d) => DateFormat('dd-MM-yyyy').format(d);

  DateTime? _parseKey(String key) {
    try {
      return DateFormat('dd-MM-yyyy').parseStrict(key);
    } catch (_) {
      return null;
    }
  }

  int get _days => _to.difference(_from).inDays + 1;

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      _snack('Add a name', 'For example: Dasara', error);
      return;
    }
    if (_saving) return;
    HapticFeedback.mediumImpact();
    setState(() => _saving = true);
    try {
      final res = await http.post(
        Uri.parse('${ApiEndpoints.baseUrl}/admin/holidays'),
        headers: ApiHeaders.json(),
        body: jsonEncode({'from': _key(_from), 'to': _key(_to), 'title': title, 'appliesTo': _appliesTo}),
      );
      final body = jsonDecode(res.body);
      if (res.statusCode == 200) {
        _snack('Holiday saved', (body['message'] ?? 'Saved').toString(), success);
        await _load(silent: true);
      } else {
        _snack('Not saved', (body['message'] ?? 'Error ${res.statusCode}').toString(), error);
      }
    } catch (e) {
      _snack('Connection error', '$e', error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _remove(Map<String, dynamic> h) async {
    final ok = await Get.dialog<bool>(
      AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('Remove holiday?', style: GoogleFonts.poppins(color: textColor, fontWeight: FontWeight.w700, fontSize: 16)),
        content: Text(
          '${_pretty(h['date'])} (${h['title']}) becomes a working day again. Anyone who did not come that day will count as absent.',
          style: GoogleFonts.poppins(color: secondaryText, fontSize: 12.5, height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: Text('Keep', style: GoogleFonts.poppins(color: secondaryText, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () => Get.back(result: true),
            style: ElevatedButton.styleFrom(backgroundColor: error, foregroundColor: Colors.white, elevation: 0),
            child: Text('Remove', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final id = h['_id'].toString();
    setState(() => _removing.add(id));
    try {
      final res = await http.delete(Uri.parse('${ApiEndpoints.baseUrl}/admin/holidays/$id'), headers: ApiHeaders.auth());
      if (res.statusCode == 200) {
        setState(() => _holidays.removeWhere((x) => x['_id'].toString() == id));
      } else {
        _snack('Not removed', 'Error ${res.statusCode}', error);
      }
    } catch (e) {
      _snack('Connection error', '$e', error);
    } finally {
      if (mounted) setState(() => _removing.remove(id));
    }
  }

  void _snack(String title, String msg, Color color) {
    Get.closeCurrentSnackbar();
    Get.snackbar(title, msg,
        backgroundColor: color,
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
        margin: const EdgeInsets.all(14),
        borderRadius: 12,
        duration: const Duration(seconds: 4));
  }

  String _pretty(dynamic key) {
    final d = _parseKey(key.toString());
    return d == null ? key.toString() : DateFormat('EEE, d MMM yyyy').format(d);
  }

  void _setQuick(String q) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (q == 'today') {
      setState(() {
        _quick = q;
        _from = today;
        _to = today;
      });
    } else if (q == 'tomorrow') {
      setState(() {
        _quick = q;
        _from = today.add(const Duration(days: 1));
        _to = _from;
      });
    } else {
      final picked = await showDateRangePicker(
        context: context,
        firstDate: today.subtract(const Duration(days: 60)),
        lastDate: today.add(const Duration(days: 400)),
        initialDateRange: DateTimeRange(start: _from, end: _to),
        helpText: 'Holiday dates (one day or a range)',
        builder: (context, child) => Theme(
          data: ThemeData.light().copyWith(colorScheme: const ColorScheme.light(primary: purple, onPrimary: Colors.white)),
          child: child!,
        ),
      );
      if (picked != null) {
        setState(() {
          _quick = 'pick';
          _from = DateTime(picked.start.year, picked.start.month, picked.start.day);
          _to = DateTime(picked.end.year, picked.end.month, picked.end.day);
        });
      }
    }
  }

  // ---------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final upcoming = _holidays.where((h) => h['past'] != true).toList();
    final past = _holidays.where((h) => h['past'] == true).toList().reversed.toList();

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_rounded, color: textColor), onPressed: () => Get.back()),
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Holidays', style: GoogleFonts.poppins(color: textColor, fontSize: 16, fontWeight: FontWeight.w700)),
            Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(color: _live ? success : secondaryText.withOpacity(.5), shape: BoxShape.circle),
                ),
                const SizedBox(width: 5),
                Text(_live ? 'Live' : 'No one is marked absent on a holiday',
                    style: GoogleFonts.poppins(color: _live ? success : secondaryText, fontSize: 9.5, fontWeight: FontWeight.w600)),
              ],
            ),
          ],
        ),
        bottom: const PreferredSize(preferredSize: Size.fromHeight(1), child: Divider(height: 1, color: borderColor)),
      ),
      body: RefreshIndicator(
        color: purple,
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 30),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _createCard(),
                    const SizedBox(height: 18),
                    _sectionTitle('Upcoming', upcoming.length),
                    const SizedBox(height: 8),
                    if (_loading)
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: CircularProgressIndicator(color: purple, strokeWidth: 2.5)),
                      )
                    else if (upcoming.isEmpty)
                      _empty('No upcoming holidays.')
                    else
                      ..._grouped(upcoming),
                    if (past.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      TextButton.icon(
                        onPressed: () => setState(() => _showPast = !_showPast),
                        icon: Icon(_showPast ? Icons.expand_less_rounded : Icons.expand_more_rounded, color: secondaryText),
                        label: Text('${_showPast ? 'Hide' : 'Show'} past holidays (${past.length})',
                            style: GoogleFonts.poppins(color: secondaryText, fontWeight: FontWeight.w600, fontSize: 12)),
                      ),
                      if (_showPast) ..._grouped(past),
                    ],
                    const SizedBox(height: 18),
                    _rulesCard(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _createCard() {
    final days = _days;
    final rangeText = days == 1
        ? DateFormat('EEEE, d MMM yyyy').format(_from)
        : '${DateFormat('d MMM').format(_from)} – ${DateFormat('d MMM yyyy').format(_to)} ($days days)';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: purple.withOpacity(.12), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.beach_access_rounded, color: purple),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text('Mark a holiday', style: GoogleFonts.poppins(color: textColor, fontSize: 15, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _label('When'),
          const SizedBox(height: 6),
          Row(
            children: [
              _choice('Today', _quick == 'today', () => _setQuick('today')),
              const SizedBox(width: 7),
              _choice('Tomorrow', _quick == 'tomorrow', () => _setQuick('tomorrow')),
              const SizedBox(width: 7),
              _choice('Pick dates', _quick == 'pick', () => _setQuick('pick'), icon: Icons.date_range_rounded),
            ],
          ),
          const SizedBox(height: 6),
          Text(rangeText, style: GoogleFonts.poppins(color: purple, fontSize: 12, fontWeight: FontWeight.w700)),
          const SizedBox(height: 14),
          _label('Name'),
          const SizedBox(height: 6),
          TextField(
            controller: _title,
            textCapitalization: TextCapitalization.words,
            style: GoogleFonts.poppins(fontSize: 13, color: textColor, fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              hintText: 'e.g. Dasara',
              isDense: true,
              filled: true,
              fillColor: const Color(0xFFF7FAFC),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(11), borderSide: const BorderSide(color: borderColor)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(11), borderSide: const BorderSide(color: borderColor)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(11), borderSide: const BorderSide(color: purple, width: 1.4)),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _suggestions.map((t) {
              final on = _title.text.trim() == t;
              return InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => setState(() => _title.text = t),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: on ? purple.withOpacity(.12) : const Color(0xFFF4F7FA),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: on ? purple : borderColor),
                  ),
                  child: Text(t, style: GoogleFonts.poppins(fontSize: 10.5, color: on ? purple : secondaryText, fontWeight: FontWeight.w600)),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),
          _label('For'),
          const SizedBox(height: 6),
          Row(
            children: [
              _choice('Everyone', _appliesTo == 'all', () => setState(() => _appliesTo = 'all')),
              const SizedBox(width: 7),
              _choice('Students', _appliesTo == 'students', () => setState(() => _appliesTo = 'students')),
              const SizedBox(width: 7),
              _choice('Trainers', _appliesTo == 'trainers', () => setState(() => _appliesTo = 'trainers')),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.beach_access_rounded, size: 19),
              label: Text(
                days == 1 ? 'Mark as holiday' : 'Mark $days days as holiday',
                style: GoogleFonts.poppins(fontSize: 13.5, fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: purple,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'On a holiday nobody is marked absent, and the day is not counted as a working day — trainer salary, attendance % and best student stay correct. Anyone who still joins a class is counted normally.',
            style: GoogleFonts.poppins(color: secondaryText, fontSize: 10.5, height: 1.45),
          ),
        ],
      ),
    );
  }

  List<Widget> _grouped(List<Map<String, dynamic>> list) => list.map(_holidayRow).toList();

  Widget _holidayRow(Map<String, dynamic> h) {
    final id = h['_id'].toString();
    final d = _parseKey(h['date'].toString());
    final isToday = h['today'] == true;
    final who = (h['appliesTo'] ?? 'all').toString();
    final busy = _removing.contains(id);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(10, 10, 6, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isToday ? purple : borderColor, width: isToday ? 1.5 : 1),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            padding: const EdgeInsets.symmetric(vertical: 5),
            decoration: BoxDecoration(color: purple.withOpacity(.10), borderRadius: BorderRadius.circular(10)),
            child: Column(
              children: [
                Text(d == null ? '' : DateFormat('MMM').format(d).toUpperCase(),
                    style: GoogleFonts.poppins(color: purple, fontSize: 8.5, fontWeight: FontWeight.w700)),
                Text(d == null ? '?' : '${d.day}',
                    style: GoogleFonts.poppins(color: purple, fontSize: 17, fontWeight: FontWeight.w800, height: 1.05)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text((h['title'] ?? 'Holiday').toString(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(color: textColor, fontSize: 13, fontWeight: FontWeight.w700)),
                    ),
                    if (isToday) ...[
                      const SizedBox(width: 6),
                      _tag('TODAY', purple),
                    ],
                  ],
                ),
                Text(
                  '${d == null ? h['date'] : DateFormat('EEEE').format(d)} • ${who == 'all' ? 'Everyone' : who == 'students' ? 'Students only' : 'Trainers only'}',
                  style: GoogleFonts.poppins(color: secondaryText, fontSize: 10.5),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Remove',
            onPressed: busy ? null : () => _remove(h),
            icon: busy
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: error))
                : const Icon(Icons.delete_outline_rounded, color: error, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _rulesCard() {
    final r = _rules;
    final grace = r?['studentGraceMinutes'] ?? 7;
    final shifts = (r?['trainerShifts'] as List?) ?? const [];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: const Color(0xFFF4F9FC), borderRadius: BorderRadius.circular(16), border: Border.all(color: borderColor)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.schedule_rounded, color: navy, size: 18),
              const SizedBox(width: 7),
              Text('Attendance time rules', style: GoogleFonts.poppins(color: textColor, fontSize: 13, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 8),
          _ruleLine('Students', 'On time = join within $grace min of the class start (05:30 class → by 05:${(30 + (int.tryParse('$grace') ?? 7)).toString().padLeft(2, '0')} AM). Later = Late, with minutes late.'),
          for (final s in shifts.whereType<Map>())
            _ruleLine('Trainer • ${(s['label'] ?? '').toString().replaceAll(' shift', '')}',
                'Class ${s['start']} → join ${s['window']} = Present. After that = Late.'),
          _ruleLine('Online', 'Minutes in class and every join / leave are recorded (tap a student to see them).'),
          _ruleLine('Offline', 'GPS check-in time decides on time / late. Minutes are not counted.'),
        ],
      ),
    );
  }

  Widget _ruleLine(String head, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 110,
              child: Text(head, style: GoogleFonts.poppins(color: navy, fontSize: 10.5, fontWeight: FontWeight.w700)),
            ),
            Expanded(child: Text(text, style: GoogleFonts.poppins(color: secondaryText, fontSize: 10.5, height: 1.4))),
          ],
        ),
      );

  Widget _label(String t) => Text(t, style: GoogleFonts.poppins(color: textColor, fontSize: 11.5, fontWeight: FontWeight.w700));

  Widget _choice(String text, bool on, VoidCallback onTap, {IconData? icon}) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(11),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: on ? purple : const Color(0xFFF7FAFC),
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: on ? purple : borderColor),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 15, color: on ? Colors.white : secondaryText),
                const SizedBox(width: 4),
              ],
              Flexible(
                child: Text(text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(color: on ? Colors.white : textColor, fontSize: 11.5, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tag(String t, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(color: c.withOpacity(.12), borderRadius: BorderRadius.circular(6)),
        child: Text(t, style: GoogleFonts.poppins(color: c, fontSize: 8.5, fontWeight: FontWeight.w800)),
      );

  Widget _sectionTitle(String t, int n) => Row(
        children: [
          Text(t, style: GoogleFonts.poppins(color: textColor, fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(width: 8),
          _tag('$n', purple),
        ],
      );

  Widget _empty(String t) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: borderColor)),
        child: Text(t, textAlign: TextAlign.center, style: GoogleFonts.poppins(color: secondaryText, fontSize: 12)),
      );
}
