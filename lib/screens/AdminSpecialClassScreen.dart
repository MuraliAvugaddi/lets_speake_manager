import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:lets_speake_manager/Api/ApiendPoints.dart';
import 'package:lets_speake_manager/Api/api_headers.dart';
import 'package:lets_speake_manager/Navigation/AdminShellNavigation.dart';
import 'package:lets_speake_manager/screens/AdminAssemblyHostScreen.dart';
import 'package:lets_speake_manager/screens/AdminAssemblyReportScreen.dart';

/// Special class days:
///   🌐 Online day     → all OFFLINE trainers + students have class ONLINE (rain, festival, any reason)
///   🎙 Special class  → everyone (all languages, stages, sections, trainers) joins ONE class
/// Both stay on until the admin taps "Back to normal".
///   Get.to(() => const AdminSpecialClassScreen());
class AdminSpecialClassScreen extends StatefulWidget {
  /// true = opened from the admin sidebar (menu button instead of back)
  final bool embedded;
  const AdminSpecialClassScreen({super.key, this.embedded = false});

  @override
  State<AdminSpecialClassScreen> createState() => _AdminSpecialClassScreenState();
}

class _AdminSpecialClassScreenState extends State<AdminSpecialClassScreen> {
  static const Color textColor = Color(0xFF173A52);
  static const Color secondaryText = Color(0xFF6B8496);
  static const Color borderColor = Color(0xFFD5E5EE);
  static const Color bg = Color(0xFFF5FAFD);
  static const Color cardBg = Color(0xFFFFFFFF);
  static const Color navy = Color(0xFF0A4A75);
  static const Color blue = Color(0xFF2E86C9);
  static const Color green = Color(0xFF16A66A);
  static const Color red = Color(0xFFE45757);
  static const Color purple = Color(0xFF7B2FF7);
  static const Color pink = Color(0xFFD6336C);

  bool loading = true;
  bool savingRain = false;
  bool savingAssembly = false;
  Map<String, dynamic>? rain;
  Map<String, dynamic>? assembly;

  final titleCtrl = TextEditingController(text: 'Surendra Sir Special Class');

  // Why offline classes go online today (shown to trainers and students)
  static const List<String> reasons = ['🌧 Heavy rain', '🎉 Festival / holiday', '⚡ Power cut', '🚌 Transport problem'];
  String pickedReason = reasons.first;
  final reasonCtrl = TextEditingController();
  bool customReason = false;
  String get _reason => customReason ? reasonCtrl.text.trim() : pickedReason;
  TimeOfDay pickedTime = const TimeOfDay(hour: 11, minute: 0);

  bool get rainOn => rain?['active'] == true;
  bool get assemblyOn => assembly?['active'] == true;
  String get _api => "${ApiEndpoints.baseUrl}/class-mode";

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    titleCtrl.dispose();
    reasonCtrl.dispose();
    super.dispose();
  }

  void _snack(String title, String msg, Color color) {
    Get.snackbar(title, msg,
        backgroundColor: color.withOpacity(.95),
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
        margin: const EdgeInsets.all(16),
        borderRadius: 14);
  }

  String _msg(http.Response r, String fallback) {
    try {
      final b = jsonDecode(r.body);
      if (b is Map && b['message'] != null) return b['message'].toString();
    } catch (_) {}
    return '$fallback (${r.statusCode})';
  }

  String _timeLabel(TimeOfDay t) {
    final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    return '${h.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')} ${t.period == DayPeriod.am ? 'AM' : 'PM'}';
  }

  Future<void> _load() async {
    setState(() => loading = true);
    try {
      final res = await http.get(Uri.parse(_api), headers: ApiHeaders.auth());
      if (res.statusCode == 200 && mounted) {
        final data = jsonDecode(res.body);
        setState(() {
          rain = data['rain'] is Map ? Map<String, dynamic>.from(data['rain']) : null;
          assembly = data['assembly'] is Map ? Map<String, dynamic>.from(data['assembly']) : null;
        });
      }
    } catch (_) {
      _snack('Connection error', 'Check the server.', red);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<bool> _confirm(String title, String body, String action, Color color) async {
    final ok = await Get.dialog<bool>(
      AlertDialog(
        backgroundColor: cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(title, style: GoogleFonts.poppins(color: textColor, fontWeight: FontWeight.w700, fontSize: 16)),
        content: Text(body, style: GoogleFonts.poppins(color: secondaryText, fontSize: 12.5, height: 1.45)),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: Text('Cancel', style: GoogleFonts.poppins(color: secondaryText, fontWeight: FontWeight.w600)),
          ),
          TextButton(
            onPressed: () => Get.back(result: true),
            child: Text(action, style: GoogleFonts.poppins(color: color, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _setRain(bool active) async {
    if (active && _reason.isEmpty) {
      _snack('Reason needed', 'Pick or type why classes are online today.', red);
      return;
    }
    final ok = await _confirm(
      active ? 'Move offline classes online?' : 'Back to normal?',
      active
          ? 'Reason: $_reason\n\nAll OFFLINE trainers will see "Start live audio class" instead of institute check-in, and offline students will see "Join online class". Attendance is taken online until you remove this.'
          : 'Offline trainers and students go back to institute (GPS) attendance.',
      active ? 'Move online' : 'Back to normal',
      active ? blue : green,
    );
    if (!ok) return;
    setState(() => savingRain = true);
    try {
      final res = await http.post(Uri.parse('$_api/rain'),
          headers: ApiHeaders.json(), body: jsonEncode({'active': active, 'reason': _reason}));
      if (res.statusCode == 200) {
        _snack(active ? '🌐 Offline classes are online' : 'Back to normal', _msg(res, ''), active ? blue : green);
        await _load();
      } else {
        _snack('Not changed', _msg(res, 'Could not update'), red);
      }
    } catch (_) {
      _snack('Connection error', 'Try again.', red);
    } finally {
      if (mounted) setState(() => savingRain = false);
    }
  }

  Future<void> _setAssembly(bool active) async {
    final time = _timeLabel(pickedTime);
    final ok = await _confirm(
      active ? 'Start special class mode?' : 'End special class?',
      active
          ? 'Everyone — English and Hindi, all stages and sections, online and offline, and all trainers — joins ONE class at $time. Normal classes are paused until you remove this. Each student\'s attendance counts for all their stages.'
          : 'Normal classes and attendance come back.',
      active ? 'Start' : 'End & back to normal',
      active ? purple : green,
    );
    if (!ok) return;
    setState(() => savingAssembly = true);
    try {
      final res = await http.post(Uri.parse('$_api/assembly'),
          headers: ApiHeaders.json(),
          body: jsonEncode({'active': active, 'title': titleCtrl.text.trim(), 'startTime': time}));
      if (res.statusCode == 200) {
        _snack(active ? '🎙 Special class set' : 'Back to normal', _msg(res, ''), active ? purple : green);
        await _load();
      } else {
        _snack('Not changed', _msg(res, 'Could not update'), red);
      }
    } catch (_) {
      _snack('Connection error', 'Try again.', red);
    } finally {
      if (mounted) setState(() => savingAssembly = false);
    }
  }

  // =========================================================
  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >= 900;
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: cardBg,
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Special classes', style: GoogleFonts.poppins(color: textColor, fontSize: 16, fontWeight: FontWeight.w700)),
            Text('Offline classes online • Special class for everyone',
                style: GoogleFonts.poppins(color: secondaryText, fontSize: 9.5)),
          ],
        ),
        actions: [
          IconButton(onPressed: loading ? null : _load, icon: const Icon(Icons.refresh_rounded, color: textColor)),
          const SizedBox(width: 6),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator(color: navy, strokeWidth: 2.2))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: EdgeInsets.fromLTRB(wide ? 24 : 14, 16, wide ? 24 : 14, 28),
                children: [
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1100),
                      child: wide
                          ? Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(child: _rainCard()),
                                const SizedBox(width: 16),
                                Expanded(child: _assemblyCard()),
                              ],
                            )
                          : Column(children: [_rainCard(), const SizedBox(height: 14), _assemblyCard()]),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _statusPill(bool on, String onText) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: (on ? green : secondaryText).withOpacity(.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 7, height: 7, decoration: BoxDecoration(color: on ? green : secondaryText, shape: BoxShape.circle)),
            const SizedBox(width: 5),
            Text(on ? onText : 'Off',
                style: GoogleFonts.poppins(color: on ? green : secondaryText, fontSize: 10, fontWeight: FontWeight.w800)),
          ],
        ),
      );

  Widget _card({required Widget child, required Color accent, required bool on}) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: on ? accent.withOpacity(.45) : borderColor, width: on ? 1.5 : 1),
        ),
        child: child,
      );

  Widget _header(String emoji, String title, String subtitle, Color accent, bool on, String onText) => Row(
        children: [
          Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: accent.withOpacity(.10), borderRadius: BorderRadius.circular(14)),
            child: Text(emoji, style: const TextStyle(fontSize: 22)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.poppins(color: textColor, fontSize: 14.5, fontWeight: FontWeight.w800)),
                Text(subtitle, style: GoogleFonts.poppins(color: secondaryText, fontSize: 10.5)),
              ],
            ),
          ),
          _statusPill(on, onText),
        ],
      );

  Widget _point(IconData icon, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 15, color: secondaryText),
            const SizedBox(width: 7),
            Expanded(child: Text(text, style: GoogleFonts.poppins(color: textColor, fontSize: 11, height: 1.4))),
          ],
        ),
      );

  String _since(Map<String, dynamic>? m) {
    final at = DateTime.tryParse((m?['startedAt'] ?? '').toString())?.toLocal();
    if (at == null) return '';
    final by = (m?['startedByName'] ?? '').toString();
    final h = at.hour % 12 == 0 ? 12 : at.hour % 12;
    final when = '${at.day}/${at.month} $h:${at.minute.toString().padLeft(2, '0')} ${at.hour >= 12 ? 'PM' : 'AM'}';
    return 'On since $when${by.isNotEmpty ? ' • by $by' : ''}';
  }

  Widget _bigButton({
    required String text,
    required IconData icon,
    required Color color,
    required VoidCallback? onTap,
    bool busy = false,
    bool outlined = false,
  }) {
    final child = busy
        ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: outlined ? color : Colors.white))
        : Icon(icon, size: 18);
    final label = Text(text, style: GoogleFonts.poppins(fontWeight: FontWeight.w800, fontSize: 12.5));
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: outlined
          ? OutlinedButton.icon(
              onPressed: busy ? null : onTap,
              icon: child,
              label: label,
              style: OutlinedButton.styleFrom(
                foregroundColor: color,
                side: BorderSide(color: color.withOpacity(.5)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
              ),
            )
          : ElevatedButton.icon(
              onPressed: busy ? null : onTap,
              icon: child,
              label: label,
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                disabledBackgroundColor: color.withOpacity(.6),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
              ),
            ),
    );
  }

  // ---------------- 🌧 RAIN DAY ----------------
  Widget _rainCard() {
    return _card(
      accent: blue,
      on: rainOn,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header('🌐', 'Offline classes online', 'Rain, festival, power cut — any reason', blue, rainOn, 'Online now'),
          const SizedBox(height: 14),
          if (!rainOn) ...[
            Text('Reason (students & trainers see this)',
                style: GoogleFonts.poppins(color: textColor, fontSize: 11.5, fontWeight: FontWeight.w700)),
            const SizedBox(height: 7),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final r in reasons)
                  ChoiceChip(
                    label: Text(r, style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600)),
                    selected: !customReason && pickedReason == r,
                    selectedColor: blue.withOpacity(.18),
                    onSelected: (_) => setState(() {
                      customReason = false;
                      pickedReason = r;
                    }),
                  ),
                ChoiceChip(
                  label: Text('✏️ Other', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600)),
                  selected: customReason,
                  selectedColor: blue.withOpacity(.18),
                  onSelected: (_) => setState(() => customReason = true),
                ),
              ],
            ),
            if (customReason) ...[
              const SizedBox(height: 8),
              TextField(
                controller: reasonCtrl,
                maxLength: 120,
                onChanged: (_) => setState(() {}),
                style: GoogleFonts.poppins(color: textColor, fontSize: 12.5),
                decoration: InputDecoration(
                  hintText: 'e.g. Institute maintenance work',
                  counterText: '',
                  hintStyle: GoogleFonts.poppins(color: secondaryText, fontSize: 11.5),
                  filled: true,
                  fillColor: bg,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: borderColor)),
                  enabledBorder:
                      OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: borderColor)),
                ),
              ),
            ],
            const SizedBox(height: 12),
          ],
          _point(Icons.school_rounded, 'Offline trainers: "Mark institute attendance" becomes "Start live audio class".'),
          _point(Icons.groups_rounded, 'Offline students: "Join online class" appears in their app (their own trainer, own stage).'),
          _point(Icons.fact_check_rounded, 'Attendance is taken online for both, shown as 🌧 online in reports.'),
          _point(Icons.wifi_rounded, 'Online students are not affected.'),
          if (rainOn) ...[
            const SizedBox(height: 4),
            if ((rain?['note'] ?? '').toString().isNotEmpty)
              Text('Reason: ${rain?['note']}',
                  style: GoogleFonts.poppins(color: textColor, fontSize: 12, fontWeight: FontWeight.w700)),
            Text(_since(rain), style: GoogleFonts.poppins(color: blue, fontSize: 10.5, fontWeight: FontWeight.w600)),
          ],
          const SizedBox(height: 14),
          rainOn
              ? _bigButton(
                  text: 'Remove — back to institute classes',
                  icon: Icons.undo_rounded,
                  color: green,
                  outlined: true,
                  busy: savingRain,
                  onTap: () => _setRain(false),
                )
              : _bigButton(
                  text: 'Move all offline classes online',
                  icon: Icons.cloud_rounded,
                  color: blue,
                  busy: savingRain,
                  onTap: () => _setRain(true),
                ),
        ],
      ),
    );
  }

  // ---------------- 🎙 PRINCIPAL CLASS ----------------
  Widget _assemblyCard() {
    return _card(
      accent: purple,
      on: assemblyOn,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header('🎙', 'Special class — everyone together', 'All languages, stages, sections & trainers', purple,
              assemblyOn, 'On'),
          const SizedBox(height: 14),
          if (!assemblyOn) ...[
            TextField(
              controller: titleCtrl,
              maxLength: 120,
              style: GoogleFonts.poppins(color: textColor, fontSize: 12.5),
              decoration: InputDecoration(
                labelText: 'Title students see',
                counterText: '',
                labelStyle: GoogleFonts.poppins(color: secondaryText, fontSize: 11.5),
                filled: true,
                fillColor: bg,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: borderColor)),
                enabledBorder:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: borderColor)),
              ),
            ),
            const SizedBox(height: 10),
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () async {
                final t = await showTimePicker(context: context, initialTime: pickedTime);
                if (t != null) setState(() => pickedTime = t);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.schedule_rounded, color: purple, size: 19),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text('Start time: ${_timeLabel(pickedTime)}',
                          style: GoogleFonts.poppins(color: textColor, fontSize: 12.5, fontWeight: FontWeight.w700)),
                    ),
                    Text('Change', style: GoogleFonts.poppins(color: purple, fontSize: 11, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            _point(Icons.pause_circle_outline_rounded, 'Normal classes are paused until you remove it.'),
            _point(Icons.fact_check_rounded, 'One join = attendance for every stage the student has. Trainers too.'),
            _point(Icons.mic_rounded, 'You speak from this app. Students join muted; you can let everyone talk or allow one person.'),
            const SizedBox(height: 10),
            _bigButton(
              text: 'Set special class',
              icon: Icons.campaign_rounded,
              color: purple,
              busy: savingAssembly,
              onTap: () => _setAssembly(true),
            ),
          ] else ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [purple, pink]),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text((assembly?['title'] ?? 'Surendra Sir Special Class').toString(),
                      style: GoogleFonts.poppins(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
                  Text('Today at ${(assembly?['startTime'] ?? '').toString()} • students see a "Join" card',
                      style: GoogleFonts.poppins(color: Colors.white.withOpacity(.85), fontSize: 11)),
                  const SizedBox(height: 4),
                  Text(_since(assembly), style: GoogleFonts.poppins(color: Colors.white70, fontSize: 10)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _bigButton(
              text: 'Go live now — speak to everyone',
              icon: Icons.mic_rounded,
              color: purple,
              onTap: () => Get.to(() => AdminAssemblyHostScreen(
                    title: (assembly?['title'] ?? 'Surendra Sir Special Class').toString(),
                  )),
            ),
            const SizedBox(height: 8),
            _bigButton(
              text: 'Remove — back to normal classes',
              icon: Icons.undo_rounded,
              color: green,
              outlined: true,
              busy: savingAssembly,
              onTap: () => _setAssembly(false),
            ),
          ],
          // 📋 always available (also for past days)
          const SizedBox(height: 8),
          _bigButton(
            text: 'Attendance — who came / who was absent',
            icon: Icons.fact_check_rounded,
            color: purple,
            outlined: true,
            onTap: () => Get.to(() => const AdminAssemblyReportScreen()),
          ),
        ],
      ),
    );
  }
}
