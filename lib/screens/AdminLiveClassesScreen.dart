// =========================================================================
// 👀 WATCH LIVE CLASSES — admin / principal joins any running class quietly
//
//   AdminLiveClassesScreen → every class running now (English sections,
//                            Hindi stages, offline, special class) + student count
//   _ObserveClassScreen    → listen only: hear the trainer & students,
//                            see who is in the class and who is speaking.
//                            Hidden from trainer and students, no attendance,
//                            no extra account needed.
//                            🎙 "Speak" → trainer & students HEAR you, but your
//                            name / profile is still not shown to them.
// =========================================================================
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:get_storage/get_storage.dart';
import 'package:lets_speake_manager/Api/ApiendPoints.dart';
import 'package:lets_speake_manager/Api/api_headers.dart';
import 'package:lets_speake_manager/Api/admin_live.dart';
import 'package:lets_speake_manager/Navigation/AdminShellNavigation.dart';
import 'package:lets_speake_manager/rtc/live_room.dart';

const Color _text = Color(0xFF173A52);
const Color _secondary = Color(0xFF6B8496);
const Color _border = Color(0xFFD5E5EE);
const Color _bg = Color(0xFFF5FAFD);
const Color _navy = Color(0xFF0A4A75);
const Color _blue = Color(0xFF2E86C9);
const Color _teal = Color(0xFF19B8B8);
const Color _green = Color(0xFF16A66A);
const Color _red = Color(0xFFE45757);
const Color _offline = Color(0xFFC68B00);
const Color _purple = Color(0xFF7B2FF7);

String _stageLabel(String s) => s.replaceAll('stage', 'Stage ');

String _title(Map r) {
  if (r['kind'] == 'special') return 'Surendra Sir Special Class';
  final parts = <String>[
    (r['language'] ?? '').toString(),
    _stageLabel((r['stage'] ?? '').toString()),
    if ((r['section'] ?? '').toString().isNotEmpty) 'Section ${r['section']}',
  ];
  return parts.where((e) => e.isNotEmpty).join(' • ');
}

Color _colorOf(Map r) {
  if (r['kind'] == 'special') return _purple;
  if (r['mode'] == 'offline') return _offline;
  return r['language'] == 'Hindi' ? _teal : _blue;
}

class AdminLiveClassesScreen extends StatefulWidget {
  final bool embedded;
  const AdminLiveClassesScreen({super.key, this.embedded = false});

  @override
  State<AdminLiveClassesScreen> createState() => _AdminLiveClassesScreenState();
}

class _AdminLiveClassesScreenState extends State<AdminLiveClassesScreen> with WidgetsBindingObserver {
  List<Map<String, dynamic>> _rooms = [];
  bool _loading = true;
  String? _error;
  String _filter = 'all'; // all | English | Hindi | offline
  Timer? _poll;
  void Function()? _stopLive;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    // ⚡ a trainer starts / ends a class → the list changes at once
    _stopLive = AdminLive.on(
      ['live_rooms_changed', 'class_started', 'assembly_live', 'assembly_ended'],
      () => _load(quiet: true),
      debounce: const Duration(milliseconds: 1500), // give LiveKit a moment to list the new room
    );
    // student counts + classes that end when everyone leaves
    _poll = Timer.periodic(const Duration(seconds: 10), (_) => _load(quiet: true));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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
    if (!quiet) setState(() => _loading = true);
    try {
      final res = await http
          .get(Uri.parse('${ApiEndpoints.baseUrl}/rtc/live-rooms?_t=${DateTime.now().millisecondsSinceEpoch}'),
              headers: ApiHeaders.auth())
          .timeout(const Duration(seconds: 20));
      final data = jsonDecode(res.body);
      if (res.statusCode == 200) {
        _rooms = ((data['rooms'] ?? []) as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
        _error = null;
      } else if (!quiet || _rooms.isEmpty) {
        _error = (data['error'] ?? data['message'] ?? 'Could not load classes').toString();
      }
    } catch (_) {
      if (!quiet || _rooms.isEmpty) _error = 'No internet / server not reachable';
    }
    if (mounted) setState(() => _loading = false);
  }

  List<Map<String, dynamic>> get _shown => _rooms.where((r) {
        switch (_filter) {
          case 'English':
            return r['language'] == 'English' && r['mode'] != 'offline';
          case 'Hindi':
            return r['language'] == 'Hindi' && r['mode'] != 'offline';
          case 'offline':
            return r['mode'] == 'offline';
          default:
            return true;
        }
      }).toList();

  Widget _chip(String label, String key, Color color) {
    final sel = _filter == key;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        selected: sel,
        showCheckmark: false,
        label: Text(label),
        labelStyle: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700, color: sel ? Colors.white : _text),
        selectedColor: color,
        backgroundColor: Colors.white,
        side: BorderSide(color: sel ? color : _border),
        onSelected: (_) => setState(() => _filter = key),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final list = _shown;
    final students = _rooms.fold<int>(0, (a, r) => a + ((r['participants'] ?? 0) as num).toInt());
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
        title: Text('Watch live classes', style: GoogleFonts.poppins(fontWeight: FontWeight.w800, fontSize: 17, color: _text)),
        actions: [IconButton(onPressed: () => _load(), icon: const Icon(Icons.refresh_rounded))],
      ),
      body: RefreshIndicator(
        onRefresh: () => _load(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 30),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [_navy, Color(0xFF0E6BA8)]),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(color: Colors.white.withOpacity(.15), borderRadius: BorderRadius.circular(14)),
                    child: const Icon(Icons.headphones_rounded, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${_rooms.length} ${_rooms.length == 1 ? 'class' : 'classes'} live now',
                            style: GoogleFonts.poppins(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
                        Text('$students people inside • you join hidden, mic off',
                            style: GoogleFonts.poppins(color: Colors.white70, fontSize: 11.5)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                _chip('All', 'all', _navy),
                _chip('English', 'English', _blue),
                _chip('Hindi', 'Hindi', _teal),
                _chip('Offline', 'offline', _offline),
              ]),
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
            else if (_error != null)
              Padding(
                padding: const EdgeInsets.all(30),
                child: Text(_error!, textAlign: TextAlign.center, style: GoogleFonts.poppins(color: _red)),
              )
            else if (list.isEmpty)
              Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  children: [
                    const Icon(Icons.nights_stay_outlined, size: 44, color: Colors.black26),
                    const SizedBox(height: 8),
                    Text('No class is running right now.\nThis list updates by itself.',
                        textAlign: TextAlign.center, style: GoogleFonts.poppins(color: _secondary)),
                  ],
                ),
              )
            else
              ...list.map(_card),
          ],
        ),
      ),
    );
  }

  Widget _card(Map<String, dynamic> r) {
    final c = _colorOf(r);
    final n = ((r['participants'] ?? 0) as num).toInt();
    final started = DateTime.tryParse((r['startedAt'] ?? '').toString())?.toLocal();
    final mins = started == null ? null : DateTime.now().difference(started).inMinutes;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(color: c.withOpacity(.12), borderRadius: BorderRadius.circular(14)),
            child: Icon(r['kind'] == 'special' ? Icons.campaign_rounded : Icons.record_voice_over_rounded, color: c),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_title(r),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 14, color: _text)),
                const SizedBox(height: 2),
                Row(children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(color: _red, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 5),
                  Text('LIVE', style: GoogleFonts.poppins(fontSize: 10.5, fontWeight: FontWeight.w800, color: _red)),
                  Text('  •  $n inside${mins != null ? '  •  ${mins}m' : ''}${r['mode'] == 'offline' ? '  •  Offline' : ''}',
                      style: GoogleFonts.poppins(fontSize: 11, color: _secondary)),
                ]),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => _ObserveClassScreen(room: r['name'].toString(), title: _title(r), color: c)),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: c,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.headphones_rounded, size: 18),
            label: Text('Listen', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

// =========================================================================
// LISTEN TO ONE CLASS
// =========================================================================
class _ObserveClassScreen extends StatefulWidget {
  final String room;
  final String title;
  final Color color;
  const _ObserveClassScreen({required this.room, required this.title, required this.color});

  @override
  State<_ObserveClassScreen> createState() => _ObserveClassScreenState();
}

class _ObserveClassScreenState extends State<_ObserveClassScreen> {
  Call? _call;
  StreamSubscription<CallState>? _sub;
  CallState? _state;
  String? _error;
  bool _connecting = true;
  bool _ended = false;
  bool _soundOn = true; // class sound on this phone
  bool _speaking = false; // 🎙 visible + mic allowed
  bool _micOn = false; // my mic right now (while speaking)
  bool _micBusy = false;

  @override
  void initState() {
    super.initState();
    _join();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _call?.leave(); // leaving = gone for everyone (mic off too)
    super.dispose();
  }

  void _toast(String t, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(t),
      backgroundColor: error ? _red : _green,
      behavior: SnackBarBehavior.floating,
    ));
  }

  /// 🎙 First tap: ask → become visible + mic ON. Then: mic on / off. "Stop" → hidden again.
  Future<void> _startSpeaking() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Speak in this class?', style: GoogleFonts.poppins(fontWeight: FontWeight.w800, fontSize: 17)),
        content: Text(
          'The trainer and students will HEAR your voice.\n\nYour name and profile stay hidden — you are not shown in their list.',
          style: GoogleFonts.poppins(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: _green, foregroundColor: Colors.white, elevation: 0),
            icon: const Icon(Icons.mic_rounded, size: 18),
            label: const Text('Speak'),
          ),
        ],
      ),
    );
    if (ok != true || _call == null) return;
    setState(() => _micBusy = true);
    final err = await _call!.setObserverSpeaking(true);
    if (!mounted) return;
    setState(() {
      _micBusy = false;
      if (err == null) {
        _speaking = true;
        _micOn = true;
      }
    });
    err == null ? _toast('🎙 Mic on — they hear you, your name stays hidden') : _toast(err, error: true);
  }

  Future<void> _stopSpeaking() async {
    if (_call == null) return;
    setState(() => _micBusy = true);
    final err = await _call!.setObserverSpeaking(false);
    if (!mounted) return;
    setState(() {
      _micBusy = false;
      if (err == null) {
        _speaking = false;
        _micOn = false;
      }
    });
    err == null ? _toast('Mic off • listening quietly') : _toast(err, error: true);
  }

  /// 🔍 "Check": what the server sees (is my voice really going out?)
  Future<void> _check() async {
    final c = _call;
    if (c == null) return;
    try {
      final people = await c.roomCheck();
      if (!mounted) return;
      final me = people.where((p) => (p['identity'] ?? '').toString().startsWith('observer_')).toList();
      final mine = me.isEmpty ? null : me.first;
      final sending = mine != null && ((mine['audio'] as List?) ?? []).any((a) => a is Map && a['muted'] != true);
      final others = people.where((p) => !(p['identity'] ?? '').toString().startsWith('observer_')).length;
      final h = c.micHealth;
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Mic check', style: GoogleFonts.poppins(fontWeight: FontWeight.w800)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _checkRow('Server allows your mic', mine?['canPublish'] == true),
              _checkRow('This app has mic permission + is sending', h.sending && !h.muted),
              _checkRow('Server receives your voice', sending),
              _checkRow('Hidden from trainer & students list', true),
              const SizedBox(height: 8),
              Text('$others other people in the class',
                  style: GoogleFonts.poppins(fontSize: 12, color: _secondary)),
              if (!sending) ...[
                const SizedBox(height: 10),
                Text(
                  mine?['canPublish'] != true
                      ? 'Fix: update the BACKEND files and restart npm start.'
                      : 'Fix: allow the microphone for this app / browser, then tap Stop and Speak again.',
                  style: GoogleFonts.poppins(fontSize: 12, color: _red, fontWeight: FontWeight.w600),
                ),
              ],
            ],
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
        ),
      );
    } catch (e) {
      _toast('Check failed: $e', error: true);
    }
  }

  Widget _checkRow(String t, bool ok) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(children: [
          Icon(ok ? Icons.check_circle_rounded : Icons.cancel_rounded, color: ok ? _green : _red, size: 19),
          const SizedBox(width: 8),
          Expanded(child: Text(t, style: GoogleFonts.poppins(fontSize: 12.5, color: _text))),
        ]),
      );

  /// 🎤 pick the right microphone (Windows often picks a silent one)
  Future<void> _pickMic() async {
    final c = _call;
    if (c == null) return;
    final mics = await c.micDevices();
    if (!mounted) return;
    if (mics.isEmpty) {
      _toast('No microphone found. Plug in / allow the mic and try again.', error: true);
      return;
    }
    final pick = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 4),
              child: Text('Choose microphone',
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w800, fontSize: 16, color: _text)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
              child: Text('Talk after choosing — the green "They hear you" light must turn on.',
                  style: GoogleFonts.poppins(fontSize: 11.5, color: _secondary)),
            ),
            for (final m in mics)
              ListTile(
                leading: Icon(Icons.mic_rounded, color: m.id == c.usedMicId ? _green : _secondary),
                title: Text(m.label, style: GoogleFonts.poppins(fontSize: 13, color: _text)),
                trailing: m.id == c.usedMicId ? const Icon(Icons.check_rounded, color: _green) : null,
                onTap: () => Navigator.pop(ctx, m.id),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (pick == null) return;
    await c.useMic(pick);
    _toast('Microphone changed — say something');
  }

  Future<void> _toggleMic() async {
    if (_call == null) return;
    final on = !_micOn;
    setState(() => _micOn = on);
    await _call!.setMyMic(on);
  }

  Future<void> _join() async {
    setState(() {
      _connecting = true;
      _error = null;
    });
    try {
      final box = GetStorage();
      final u = box.read('user');
      final id = (u is Map ? (u['_id'] ?? u['id']) : null)?.toString() ?? 'admin';
      final name = (u is Map ? u['name'] : null)?.toString() ?? 'Admin';
      final client = StreamVideo('livekit', user: User.regular(userId: id, name: name));
      final c = client.makeCall(callType: StreamCallType.defaultType(), id: widget.room)..observer = true;
      final r = await c.join(connectOptions: CallConnectOptions(camera: TrackOption.disabled(), microphone: TrackOption.disabled()));
      if (r.isFailure) throw Exception('$r');
      _call = c;
      _sub = c.state.asStream().listen((s) {
        if (!mounted) return;
        setState(() {
          _state = s;
          if (s.status == CallStatus.disconnected) _ended = true;
        });
      });
      setState(() {
        _state = c.state.value;
        _connecting = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _connecting = false;
          _error = 'Could not open this class. It may have ended.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final people = (_state?.callParticipants ?? const <CallParticipantState>[]).where((p) => !p.isLocal).toList();
    final trainers = people.where((p) => p.roles.contains('admin')).toList();
    final students = people.where((p) => !p.roles.contains('admin')).toList()
      ..sort((a, b) {
        if (a.isSpeaking != b.isSpeaking) return a.isSpeaking ? -1 : 1;
        if (a.isAudioEnabled != b.isAudioEnabled) return a.isAudioEnabled ? -1 : 1;
        return a.name.compareTo(b.name);
      });
    final talking = people.where((p) => p.isAudioEnabled).length;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: widget.color,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title, style: GoogleFonts.poppins(fontWeight: FontWeight.w800, fontSize: 15)),
            Text(
                _speaking
                    ? (_micOn ? '🎙 Speaking • they hear you, nobody sees you' : 'Mic paused • nobody sees you')
                    : (_soundOn ? 'Listening quietly • nobody can see you' : 'Sound off • nobody can see you'),
                style: GoogleFonts.poppins(fontSize: 10.5, color: Colors.white70)),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 🎤 live light: is the SERVER hearing my voice? (silent = wrong mic)
              if (_speaking && _micOn && _call != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
                    decoration: BoxDecoration(
                      color: (_call!.iAmHeard ? _green : _secondary).withOpacity(.10),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: (_call!.iAmHeard ? _green : _border)),
                    ),
                    child: Row(
                      children: [
                        Icon(_call!.iAmHeard ? Icons.graphic_eq_rounded : Icons.mic_none_rounded,
                            color: _call!.iAmHeard ? _green : _secondary, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _call!.iAmHeard
                                ? 'They hear you ✅'
                                : 'Say something… (no light while talking = wrong mic → Change mic)',
                            style: GoogleFonts.poppins(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: _call!.iAmHeard ? _green : _secondary),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _pickMic,
                          icon: const Icon(Icons.settings_voice_rounded, size: 17),
                          label: Text('Change mic', style: GoogleFonts.poppins(fontSize: 11.5, fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                  ),
                ),
              // 🎙 TALK TO THE CLASS
              if (_call != null && !_ended)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: !_speaking
                      ? SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton.icon(
                            onPressed: _micBusy ? null : _startSpeaking,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _green,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            icon: _micBusy
                                ? const SizedBox(
                                    width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.mic_rounded),
                            label: Text('Speak to the class', style: GoogleFonts.poppins(fontWeight: FontWeight.w800)),
                          ),
                        )
                      : Row(
                          children: [
                            Expanded(
                              child: SizedBox(
                                height: 50,
                                child: ElevatedButton.icon(
                                  onPressed: _micBusy ? null : _toggleMic,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _micOn ? _green : Colors.white,
                                    foregroundColor: _micOn ? Colors.white : _green,
                                    elevation: 0,
                                    side: const BorderSide(color: _green, width: 1.3),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  ),
                                  icon: Icon(_micOn ? Icons.mic_rounded : Icons.mic_off_rounded),
                                  label: Text(_micOn ? 'Mic ON' : 'Mic OFF',
                                      style: GoogleFonts.poppins(fontWeight: FontWeight.w800)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: SizedBox(
                                height: 50,
                                child: OutlinedButton.icon(
                                  onPressed: _micBusy ? null : _stopSpeaking,
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: _text,
                                    side: const BorderSide(color: _border, width: 1.3),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  ),
                                  icon: const Icon(Icons.visibility_off_rounded, size: 19),
                                  label: Text('Stop speaking', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              height: 50,
                              width: 50,
                              child: IconButton.outlined(
                                tooltip: 'Mic check',
                                onPressed: _check,
                                icon: const Icon(Icons.troubleshoot_rounded, color: _navy),
                              ),
                            ),
                          ],
                        ),
                ),
              Row(
            children: [
              // 🔇 one button: class sound ON / OFF — only on this phone, the trainer is never told
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _call == null || _ended
                        ? null
                        : () async {
                            final on = !_soundOn;
                            setState(() => _soundOn = on);
                            await _call!.setSoundOn(on);
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _soundOn ? Colors.white : _navy,
                      foregroundColor: _soundOn ? _navy : Colors.white,
                      elevation: 0,
                      side: const BorderSide(color: _navy, width: 1.3),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: Icon(_soundOn ? Icons.volume_up_rounded : Icons.volume_off_rounded),
                    label: Text(_soundOn ? 'Sound off' : 'Sound on', style: GoogleFonts.poppins(fontWeight: FontWeight.w800)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _red,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: const Icon(Icons.logout_rounded),
                    label: Text('Leave', style: GoogleFonts.poppins(fontWeight: FontWeight.w800)),
                  ),
                ),
              ),
            ],
          ),
            ],
          ),
        ),
      ),
      body: _connecting
          ? const Center(child: CircularProgressIndicator())
          : _error != null || _ended
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(30),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_ended ? Icons.check_circle_outline_rounded : Icons.error_outline_rounded,
                            size: 48, color: _ended ? _green : _red),
                        const SizedBox(height: 10),
                        Text(_ended ? 'The class has ended.' : _error!,
                            textAlign: TextAlign.center, style: GoogleFonts.poppins(color: _text, fontSize: 14)),
                        if (!_ended) ...[
                          const SizedBox(height: 12),
                          OutlinedButton(onPressed: _join, child: const Text('Try again')),
                        ],
                      ],
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
                  children: [
                    // 🌐 Chrome blocked the class sound → one tap starts it
                    if (_call?.soundBlocked == true)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            await _call?.unlockSound();
                            if (mounted) setState(() {});
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _red,
                            foregroundColor: Colors.white,
                            minimumSize: const Size.fromHeight(48),
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          icon: const Icon(Icons.volume_up_rounded),
                          label: Text('Tap to hear the class', style: GoogleFonts.poppins(fontWeight: FontWeight.w800)),
                        ),
                      ),
                    Row(children: [
                      _stat('${people.length}', 'In class', Icons.groups_rounded, _navy),
                      const SizedBox(width: 10),
                      _stat('${students.length}', 'Students', Icons.school_rounded, _blue),
                      const SizedBox(width: 10),
                      _stat('$talking', 'Mic on', Icons.mic_rounded, _green),
                    ]),
                    const SizedBox(height: 14),
                    _head('Trainer', trainers.length),
                    if (trainers.isEmpty)
                      _empty('The trainer is not in the class right now')
                    else
                      ...trainers.map((p) => _person(p, trainer: true)),
                    const SizedBox(height: 14),
                    _head('Students', students.length),
                    if (students.isEmpty)
                      _empty('No students yet')
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: students.map(_studentChip).toList(),
                      ),
                  ],
                ),
    );
  }

  Widget _stat(String n, String label, IconData icon, Color c) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: _border)),
          child: Row(
            children: [
              Icon(icon, color: c, size: 20),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(n, style: GoogleFonts.poppins(fontWeight: FontWeight.w800, fontSize: 17, color: _text)),
                  Text(label, style: GoogleFonts.poppins(fontSize: 10.5, color: _secondary)),
                ],
              ),
            ],
          ),
        ),
      );

  Widget _head(String t, int n) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text('$t ($n)', style: GoogleFonts.poppins(fontWeight: FontWeight.w800, fontSize: 14, color: _text)),
      );

  Widget _empty(String t) => Text(t, style: GoogleFonts.poppins(fontSize: 12, color: _secondary));

  Widget _person(CallParticipantState p, {bool trainer = false}) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: p.isSpeaking ? _green : _border, width: p.isSpeaking ? 2 : 1),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: _navy.withOpacity(.1),
              child: Text(p.name.isEmpty ? '?' : p.name[0].toUpperCase(),
                  style: GoogleFonts.poppins(color: _navy, fontWeight: FontWeight.w800)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.name, style: GoogleFonts.poppins(fontWeight: FontWeight.w700, color: _text)),
                  Text(p.isSpeaking ? 'Speaking now…' : (trainer ? 'Trainer' : 'Student'),
                      style: GoogleFonts.poppins(fontSize: 11, color: p.isSpeaking ? _green : _secondary)),
                ],
              ),
            ),
            Icon(p.isAudioEnabled ? Icons.mic_rounded : Icons.mic_off_rounded,
                color: p.isAudioEnabled ? _green : Colors.black26),
          ],
        ),
      );

  Widget _studentChip(CallParticipantState p) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: p.isSpeaking ? _green.withOpacity(.12) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: p.isSpeaking ? _green : _border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(p.isAudioEnabled ? Icons.mic_rounded : Icons.mic_off_rounded,
                size: 14, color: p.isAudioEnabled ? _green : Colors.black26),
            const SizedBox(width: 5),
            Text(p.name, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: _text)),
          ],
        ),
      );
}
