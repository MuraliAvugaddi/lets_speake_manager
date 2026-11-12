import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:lets_speake_manager/rtc/live_room.dart'; // 🎧 LiveKit audio classes (same names as before)
import 'package:lets_speake_manager/rtc/live_room.dart' as svf show Priority;
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:lets_speake_manager/Api/ApiendPoints.dart';
import 'package:lets_speake_manager/Api/api_headers.dart';
import 'package:lets_speake_manager/screens/AdminAssemblyReportScreen.dart';

/// 🎙 Special class — Sir speaks to EVERYONE (all languages, stages, sections, trainers).
/// Students and trainers join muted. Sir controls the mics:
///   • "Mute everyone" (locked): nobody can unmute, except people Sir allows
///   • "Let everyone talk" (open): students & trainers can unmute themselves
/// Built for 2,000–2,500 people: the screen refreshes once a second (not on every
/// audio-level change) and shows the first 150 names.
class AdminAssemblyHostScreen extends StatefulWidget {
  final String title;
  const AdminAssemblyHostScreen({super.key, this.title = 'Surendra Sir Special Class'});

  @override
  State<AdminAssemblyHostScreen> createState() => _AdminAssemblyHostScreenState();
}

enum _Phase { connecting, live, error }

class _AdminAssemblyHostScreenState extends State<AdminAssemblyHostScreen> {
  static const Color bgTop = Color(0xFF2A0F57);
  static const Color bgBottom = Color(0xFF7B2FF7);
  static const Color red = Color(0xFFE45757);
  static const Color green = Color(0xFF28C2C2);

  _Phase phase = _Phase.connecting;
  String errorText = '';
  Call? call;
  bool ending = false;

  // 🎤 mic control shared with every phone through the call's custom data
  bool micLocked = true; // start locked: with 2,000+ people only Sir talks until he opens it
  final Set<String> allowed = <String>{};
  Timer? _tick;
  Timer? _publishTimer;
  static const int maxNames = 150;

  // who is a trainer (from the server) → the list is split Trainers / Students
  Set<String> trainerIds = <String>{};
  Set<String> staffIds = <String>{};

  // ✋ raised hands + 💬 questions from students (LiveKit data messages)
  final List<_Hand> hands = <_Hand>[];
  final List<_Msg> msgs = <_Msg>[];
  int unreadMsgs = 0;
  bool _chatOpen = false;
  StreamSubscription<ClassSignal>? _sigSub;

  Map<String, dynamic> get _me {
    final raw = GetStorage().read('user');
    return raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
  }

  String get _userId => (_me['_id'] ?? _me['id'] ?? '').toString();
  String get _userName => (_me['name'] ?? 'Surendra Sir').toString();

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    _start();
  }

  @override
  void dispose() {
    _sigSub?.cancel();
    _tick?.cancel();
    _publishTimer?.cancel();
    WakelockPlus.disable();
    final c = call;
    call = null;
    if (c != null) c.leave();
    super.dispose();
  }

  Future<void> _start() async {
    setState(() {
      phase = _Phase.connecting;
      errorText = '';
    });
    try {
      if (_userId.isEmpty) throw Exception('Please log out and log in again.');

      // 1) Stream token (server gives admins the host role)
      final tokenRes = await http
          .post(Uri.parse("${ApiEndpoints.baseUrl}/rtc/token"),
              headers: ApiHeaders.json(), body: jsonEncode({"userId": _userId}))
          .timeout(const Duration(seconds: 25));
      if (tokenRes.statusCode != 200) throw Exception('Could not get class access (${tokenRes.statusCode})');
      final t = jsonDecode(tokenRes.body);
      final token = (t['token'] ?? '').toString();
      final apiKey = (t['apiKey'] ?? '').toString();
      if (token.isEmpty || apiKey.isEmpty) throw Exception('Class token missing');

      // 2) Server creates today's special class call
      final prepRes = await http
          .post(Uri.parse("${ApiEndpoints.baseUrl}/rtc/prepare-call"),
              headers: ApiHeaders.json(), body: jsonEncode({"userId": _userId, "type": "assembly"}))
          .timeout(const Duration(seconds: 25));
      final prep = jsonDecode(prepRes.body);
      if (prepRes.statusCode != 200) throw Exception(prep['error'] ?? 'Server error (${prepRes.statusCode})');
      if (prep['assembly'] == false) throw Exception('Special class is not set. Go back and tap "Set special class".');
      final callId = (prep['callId'] ?? '').toString();
      if (callId.isEmpty) throw Exception('No class id from server');

      // 3) Connect + join with the microphone ON (camera never)
      try {
        await StreamVideo.reset(disconnect: true);
      } catch (_) {}
      final client = StreamVideo(
        apiKey,
        user: User.regular(userId: _userId, name: _userName),
        userToken: token,
        options: StreamVideoOptions(logPriority: svf.Priority.warning),
      );
      final c = client.makeCall(callType: StreamCallType.defaultType(), id: callId);
      await c.getOrCreate();
      final joined = await c.join(
        connectOptions: CallConnectOptions(camera: TrackOption.disabled(), microphone: TrackOption.enabled()),
      );
      if (joined.isFailure) throw Exception('Could not connect: $joined');
      try {
        await c.setCameraEnabled(enabled: false);
        await c.setMicrophoneEnabled(enabled: true);
      } catch (e) {
        debugPrint('Mic error: $e');
      }
      call = c;
      _sigSub?.cancel();
      _sigSub = c.signals.listen(_onSignal); // ✋ 💬 from students
      _loadPeople();
      await _publishNow(); // students join locked (muted) by default
      // 1 refresh per second is enough — rebuilding on every audio-level change
      // with 2,000+ people would freeze the browser.
      _tick?.cancel();
      _tick = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
      if (mounted) setState(() => phase = _Phase.live);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        phase = _Phase.error;
        errorText = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _loadPeople() async {
    try {
      final res = await http
          .get(Uri.parse("${ApiEndpoints.baseUrl}/class-mode/assembly/people"), headers: ApiHeaders.auth())
          .timeout(const Duration(seconds: 20));
      if (res.statusCode != 200) return;
      final d = jsonDecode(res.body);
      if (!mounted) return;
      setState(() {
        trainerIds = ((d['trainers'] ?? []) as List).map((e) => e.toString()).toSet();
        staffIds = ((d['staff'] ?? []) as List).map((e) => e.toString()).toSet();
      });
    } catch (e) {
      debugPrint('Load trainers error: $e');
    }
  }

  // ---------------- mic lock for everyone ----------------
  void _schedulePublish() {
    _publishTimer?.cancel();
    _publishTimer = Timer(const Duration(milliseconds: 250), _publishNow);
  }

  Future<void> _publishNow() async {
    final c = call;
    if (c == null) return;
    try {
      // ONE json text (a null in custom data crashes Stream 1.5 joins)
      final state = jsonEncode({'micLocked': micLocked, 'allowed': allowed.toList(), 'assembly': true});
      final r = await c.update(custom: <String, Object>{'state': state, 'ts': DateTime.now().millisecondsSinceEpoch});
      if (r.isFailure) debugPrint('Publish mic state failed: $r');
    } catch (e) {
      debugPrint('Publish mic state error: $e');
    }
  }

  Future<void> _muteEveryone() async {
    final c = call;
    if (c == null) return;
    setState(() {
      micLocked = true;
      allowed.clear();
    });
    _schedulePublish();
    try {
      await c.muteOthers(track: TrackType.audio); // turns every other mic off right now
    } catch (e) {
      debugPrint('Mute others error: $e');
    }
    Get.snackbar('Everyone muted', 'Only you can talk. Students can\'t unmute until you allow.',
        backgroundColor: const Color(0xFF0E466D), colorText: Colors.white, snackPosition: SnackPosition.TOP);
  }

  void _letEveryoneTalk() {
    setState(() => micLocked = false);
    _schedulePublish();
    Get.snackbar('Mics open', 'Students and trainers can unmute themselves now.',
        backgroundColor: green, colorText: Colors.white, snackPosition: SnackPosition.TOP);
  }

  void _personSheet(CallParticipantState p) {
    final isAllowed = allowed.contains(p.userId);
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(p.name.isEmpty ? 'Guest' : p.name,
                  style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w800, color: const Color(0xFF173A52))),
              Text(p.isAudioEnabled ? 'Mic is ON' : 'Mic is off',
                  style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF6B8496))),
              const SizedBox(height: 14),
              if (micLocked)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(isAllowed ? Icons.block_rounded : Icons.record_voice_over_rounded,
                      color: isAllowed ? red : green),
                  title: Text(isAllowed ? 'Stop allowing to speak' : 'Allow to speak',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
                  subtitle: Text(isAllowed ? 'They can\'t unmute again' : 'Only this person can unmute',
                      style: GoogleFonts.poppins(fontSize: 11)),
                  onTap: () async {
                    Get.back();
                    setState(() => isAllowed ? allowed.remove(p.userId) : allowed.add(p.userId));
                    _schedulePublish();
                    if (isAllowed) await call?.muteUsers(userIds: [p.userId]);
                  },
                ),
              if (p.isAudioEnabled)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.mic_off_rounded, color: red),
                  title: Text('Mute now', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
                  onTap: () async {
                    Get.back();
                    await call?.muteUsers(userIds: [p.userId]);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _toggleMic(bool currentlyOn) async {
    final c = call;
    if (c == null) return;
    try {
      await c.setMicrophoneEnabled(enabled: !currentlyOn);
    } catch (e) {
      Get.snackbar('Microphone', 'Could not change the microphone: $e',
          backgroundColor: red, colorText: Colors.white, snackPosition: SnackPosition.TOP);
    }
  }

  // =========================================================
  // ✋ RAISE HAND + 💬 QUESTIONS
  // =========================================================
  void _onSignal(ClassSignal sig) {
    if (!mounted || sig.from.isEmpty || sig.fromStaff) return;
    if (sig.type == 'hand') {
      final up = sig.data['up'] == true;
      final i = hands.indexWhere((h) => h.id == sig.from);
      if (up && i < 0) {
        setState(() => hands.add(_Hand(sig.from, sig.fromName, DateTime.now())));
      } else if (!up && i >= 0) {
        setState(() => hands.removeAt(i));
      }
    } else if (sig.type == 'msg') {
      final text = (sig.data['text'] ?? '').toString().trim();
      if (text.isEmpty) return;
      setState(() {
        msgs.add(_Msg(sig.from, sig.fromName, text.length > 300 ? text.substring(0, 300) : text, DateTime.now(), false));
        if (msgs.length > 400) msgs.removeAt(0);
        if (!_chatOpen) unreadMsgs++;
      });
    }
  }

  /// "Allow": hand goes down + this student can unmute (even when everyone is muted)
  Future<void> _allowHand(_Hand h) async {
    setState(() {
      hands.removeWhere((e) => e.id == h.id);
      if (micLocked) allowed.add(h.id);
    });
    _schedulePublish();
    await call?.sendSignal({'t': 'hand_ok'}, to: [h.id]);
  }

  Future<void> _lowerHand(String id) async {
    setState(() => hands.removeWhere((e) => e.id == id));
    await call?.sendSignal({'t': 'hand_down'}, to: [id]);
  }

  Future<void> _lowerAllHands() async {
    final ids = hands.map((h) => h.id).toList();
    setState(hands.clear);
    if (ids.isNotEmpty) await call?.sendSignal({'t': 'hand_down'}, to: ids);
  }

  Future<bool> _sendToAll(String text) async {
    final t = text.trim();
    if (t.isEmpty || call == null) return false;
    final ok = await call!.sendSignal({'t': 'msg', 'text': t});
    if (ok && mounted) setState(() => msgs.add(_Msg(_userId, 'You → everyone', t, DateTime.now(), true)));
    return ok;
  }

  Future<bool> _replyTo(_Msg to, String text) async {
    final t = text.trim();
    if (t.isEmpty || call == null) return false;
    final ok = await call!.sendSignal({'t': 'msg', 'text': t, 'private': true}, to: [to.fromId]);
    if (ok && mounted) setState(() => msgs.add(_Msg(_userId, 'You → ${to.fromName}', t, DateTime.now(), true)));
    return ok;
  }

  void _openHandsSheet() {
    Get.bottomSheet(
      StatefulBuilder(builder: (ctx, setSheet) {
        final list = List<_Hand>.from(hands);
        Future<void> act(Future<void> Function() f) async {
          await f();
          setSheet(() {});
        }

        return Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * .75),
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
          decoration: const BoxDecoration(
            color: Colors.white,
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
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(4)),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text('✋', style: TextStyle(fontSize: 20)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('Raised hands (${list.length})',
                          style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w800, color: const Color(0xFF173A52))),
                    ),
                    if (list.isNotEmpty)
                      TextButton(
                        onPressed: () => act(_lowerAllHands),
                        child: Text('Lower all', style: GoogleFonts.poppins(color: red, fontWeight: FontWeight.w700)),
                      ),
                  ],
                ),
                Text(
                  micLocked
                      ? 'Everyone is muted. "Allow" lets only that student unmute.'
                      : 'Mics are open. "Allow" tells the student to speak now.',
                  style: GoogleFonts.poppins(fontSize: 11.5, color: const Color(0xFF6B8496)),
                ),
                const SizedBox(height: 10),
                if (list.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Text('No hands raised right now.', style: GoogleFonts.poppins(color: Colors.black45)),
                    ),
                  )
                else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: list.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final h = list[i];
                        return Container(
                          padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF7F4FD),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFE6DDF8)),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 16,
                                backgroundColor: const Color(0xFFF5C542).withOpacity(.25),
                                child: Text('${i + 1}',
                                    style: GoogleFonts.poppins(
                                        color: const Color(0xFFB7860B), fontWeight: FontWeight.w800, fontSize: 12)),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(h.name.isEmpty ? 'Student' : h.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.poppins(fontWeight: FontWeight.w700, color: const Color(0xFF173A52))),
                              ),
                              IconButton(
                                tooltip: 'Lower hand',
                                onPressed: () => act(() => _lowerHand(h.id)),
                                icon: const Icon(Icons.pan_tool_alt_outlined, color: Colors.black38, size: 20),
                              ),
                              ElevatedButton(
                                onPressed: () => act(() => _allowHand(h)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF16A66A),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                child: Text('Allow', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 12)),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      }),
      isScrollControlled: true,
    );
  }

  Future<void> _openChatSheet() async {
    setState(() {
      _chatOpen = true;
      unreadMsgs = 0;
    });
    await Get.bottomSheet(
      _HostChatSheet(
        messages: () => msgs,
        sendToAll: _sendToAll,
        replyTo: _replyTo,
      ),
      isScrollControlled: true,
    );
    if (mounted) {
      setState(() {
        _chatOpen = false;
        unreadMsgs = 0;
      });
    }
  }

  Widget _handsBanner() {
    if (hands.isEmpty) return const SizedBox.shrink();
    final first = hands.first;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Material(
        color: const Color(0xFFF5C542),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: _openHandsSheet,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
            child: Row(
              children: [
                const Text('✋', style: TextStyle(fontSize: 20)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    hands.length == 1
                        ? '${first.name} raised a hand'
                        : '${first.name} and ${hands.length - 1} more raised hands',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(color: const Color(0xFF2A0F57), fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                ),
                if (hands.length == 1)
                  ElevatedButton(
                    onPressed: () => _allowHand(first),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF16A66A),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      visualDensity: VisualDensity.compact,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text('Allow', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 12)),
                  )
                else
                  Text('View  ›',
                      style: GoogleFonts.poppins(color: const Color(0xFF2A0F57), fontWeight: FontWeight.w800, fontSize: 12)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _leave({required bool endForAll}) async {
    if (endForAll) {
      final ok = await Get.dialog<bool>(
        AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Text('End the class for everyone?', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16)),
          content: Text(
            'Everyone is disconnected. Special class mode stays on until you tap "Remove — back to normal".',
            style: GoogleFonts.poppins(fontSize: 12.5, height: 1.45),
          ),
          actions: [
            TextButton(onPressed: () => Get.back(result: false), child: const Text('Cancel')),
            TextButton(
              onPressed: () => Get.back(result: true),
              child: Text('End for all', style: GoogleFonts.poppins(color: red, fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }
    setState(() => ending = true);
    final c = call;
    call = null;
    if (c != null) {
      try {
        if (endForAll) await c.end();
        await c.leave();
      } catch (_) {}
    }
    if (mounted) Get.back();
  }

  // =========================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgTop,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [bgTop, bgBottom]),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 6, 16, 0),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: ending ? null : () => _leave(endForAll: false),
                          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                        ),
                        Expanded(
                          child: Text(widget.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                        ),
                        if (phase == _Phase.live) ...[
                          IconButton(
                            tooltip: 'Raised hands',
                            onPressed: _openHandsSheet,
                            icon: _badgeIcon(Icons.pan_tool_rounded, hands.length, const Color(0xFFF5C542)),
                          ),
                          IconButton(
                            tooltip: 'Student questions',
                            onPressed: _openChatSheet,
                            icon: _badgeIcon(Icons.chat_bubble_rounded, unreadMsgs, red),
                          ),
                        ],
                        IconButton(
                          tooltip: 'Who attended',
                          onPressed: () => Get.to(() => const AdminAssemblyReportScreen()),
                          icon: const Icon(Icons.fact_check_rounded, color: Colors.white),
                        ),
                        if (phase == _Phase.live)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                            decoration: BoxDecoration(color: red, borderRadius: BorderRadius.circular(8)),
                            child: Text('LIVE',
                                style: GoogleFonts.poppins(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
                          ),
                      ],
                    ),
                  ),
                  Expanded(child: _body()),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _body() {
    if (phase == _Phase.connecting) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: Colors.white),
            const SizedBox(height: 14),
            Text('Starting the special class…', style: GoogleFonts.poppins(color: Colors.white, fontSize: 14)),
            const SizedBox(height: 4),
            Text('Allow the microphone if the browser asks.',
                style: GoogleFonts.poppins(color: Colors.white70, fontSize: 11.5)),
          ],
        ),
      );
    }
    if (phase == _Phase.error) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.white, size: 46),
              const SizedBox(height: 12),
              Text('Could not start', style: GoogleFonts.poppins(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text(errorText,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12, height: 1.4)),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _start,
                icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                label: Text('Try again', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w700)),
                style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.white54)),
              ),
            ],
          ),
        ),
      );
    }

    final c = call;
    if (c == null) return const SizedBox.shrink();
    final state = c.state.value;
    final all = state.callParticipants;
    final me = all.where((p) => p.isLocal).toList();
    final micOn = me.isNotEmpty && me.first.isAudioEnabled;
    final speakingMe = me.isNotEmpty && me.first.isSpeaking;
    // one entry per person (a user may be connected twice)
    final seen = <String>{};
    final others = all.where((p) => !p.isLocal && seen.add(p.userId)).toList();
    // people talking / with mic on / allowed first, then A–Z
    int rank(CallParticipantState p) =>
        p.isSpeaking ? 0 : (p.isAudioEnabled ? 1 : (allowed.contains(p.userId) ? 2 : 3));
    others.sort((a, b) {
      final r = rank(a).compareTo(rank(b));
      return r != 0 ? r : a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    final micOnCount = others.where((p) => p.isAudioEnabled).length;
    // ✋ a student who left the class → hand goes down
    final hereIds = others.map((p) => p.userId).toSet();
    hands.removeWhere((h) => !hereIds.contains(h.id));
    // 👨‍🏫 trainers (and other staff) on top, 🎓 students below
    final trainers = others.where((p) => trainerIds.contains(p.userId) || staffIds.contains(p.userId)).toList();
    final students = others.where((p) => !trainerIds.contains(p.userId) && !staffIds.contains(p.userId)).toList();
    final shownStudents = students.take(maxNames).toList();

    return Column(
      children: [
        const SizedBox(height: 10),
        GestureDetector(
          onTap: () => _toggleMic(micOn),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 118,
            height: 118,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: micOn ? Colors.white : Colors.white.withOpacity(.12),
              border: Border.all(color: speakingMe ? green : Colors.white38, width: speakingMe ? 6 : 2),
            ),
            child: Icon(micOn ? Icons.mic_rounded : Icons.mic_off_rounded, color: micOn ? bgBottom : Colors.white, size: 50),
          ),
        ),
        const SizedBox(height: 8),
        Text(micOn ? 'Your microphone is ON — everyone hears you' : 'Microphone OFF — tap to speak',
            style: GoogleFonts.poppins(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        _handsBanner(), // ✋ yellow bar when students raise hands

        // ---- mic control for everyone ----
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: Colors.white.withOpacity(.10), borderRadius: BorderRadius.circular(14)),
            child: Row(
              children: [
                Expanded(
                  child: _segButton(
                    icon: Icons.mic_off_rounded,
                    text: 'Mute everyone',
                    selected: micLocked,
                    onTap: _muteEveryone,
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: _segButton(
                    icon: Icons.record_voice_over_rounded,
                    text: 'Let everyone talk',
                    selected: !micLocked,
                    onTap: _letEveryoneTalk,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          micLocked
              ? 'Locked: students can\'t unmute${allowed.isNotEmpty ? ' (except ${allowed.length} you allowed)' : ''}. Tap a name to allow.'
              : 'Open: students & trainers can unmute themselves.',
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(color: Colors.white70, fontSize: 10.5),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            _pill(Icons.groups_rounded, '${others.length} in class'),
            _pill(Icons.co_present_rounded, '${trainers.length} trainers'),
            _pill(Icons.school_rounded, '${students.length} students'),
            _pill(Icons.mic_rounded, '$micOnCount with mic on'),
          ],
        ),
        const SizedBox(height: 10),
        Expanded(
          child: Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white.withOpacity(.08), borderRadius: BorderRadius.circular(18)),
            child: others.isEmpty
                ? Center(
                    child: Text('Waiting for students and trainers to join…',
                        style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12)),
                  )
                : SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _sectionTitle('👨‍🏫 Trainers', trainers.length),
                        trainers.isEmpty
                            ? _emptyLine('No trainers in the class yet')
                            : _nameWrap(trainers),
                        const SizedBox(height: 14),
                        _sectionTitle('🎓 Students', students.length),
                        students.isEmpty ? _emptyLine('No students in the class yet') : _nameWrap(shownStudents),
                        if (students.length > shownStudents.length)
                          Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: Text('+ ${students.length - shownStudents.length} more students listening',
                                style: GoogleFonts.poppins(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600)),
                          ),
                      ],
                    ),
                  ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 50,
                  child: OutlinedButton.icon(
                    onPressed: ending ? null : () => _leave(endForAll: false),
                    icon: const Icon(Icons.logout_rounded, color: Colors.white),
                    label: Text('Leave', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w700)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white54),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: ending ? null : () => _leave(endForAll: true),
                    icon: const Icon(Icons.call_end_rounded),
                    label: Text('End for everyone', style: GoogleFonts.poppins(fontWeight: FontWeight.w800)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: red,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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

  Widget _sectionTitle(String text, int count) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Text(text, style: GoogleFonts.poppins(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w800)),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
              decoration: BoxDecoration(color: Colors.white.withOpacity(.18), borderRadius: BorderRadius.circular(10)),
              child: Text('$count',
                  style: GoogleFonts.poppins(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 8),
            Expanded(child: Container(height: 1, color: Colors.white.withOpacity(.12))),
          ],
        ),
      );

  Widget _emptyLine(String text) => Padding(
        padding: const EdgeInsets.only(left: 2, bottom: 2),
        child: Text(text, style: GoogleFonts.poppins(color: Colors.white54, fontSize: 11)),
      );

  Widget _nameWrap(List<CallParticipantState> list) => Wrap(
        spacing: 6,
        runSpacing: 6,
        children: list.map((p) {
          final isAllowed = allowed.contains(p.userId);
          return InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => _personSheet(p),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: p.isSpeaking
                    ? green.withOpacity(.40)
                    : (isAllowed ? Colors.amber.withOpacity(.30) : Colors.white.withOpacity(.10)),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(p.isAudioEnabled ? Icons.mic_rounded : Icons.mic_off_rounded,
                      color: p.isAudioEnabled ? Colors.white : Colors.white54, size: 12),
                  const SizedBox(width: 4),
                  Text(p.name.isEmpty ? 'Guest' : p.name,
                      style: GoogleFonts.poppins(color: Colors.white, fontSize: 10.5)),
                ],
              ),
            ),
          );
        }).toList(),
      );

  Widget _segButton({required IconData icon, required String text, required bool selected, required VoidCallback onTap}) {
    return InkWell(
      borderRadius: BorderRadius.circular(11),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(11),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: selected ? bgBottom : Colors.white),
            const SizedBox(width: 6),
            Flexible(
              child: Text(text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                      color: selected ? bgBottom : Colors.white, fontSize: 11.5, fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pill(IconData icon, String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(color: Colors.white.withOpacity(.14), borderRadius: BorderRadius.circular(20)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 15),
            const SizedBox(width: 5),
            Text(text, style: GoogleFonts.poppins(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
          ],
        ),
      );

  Widget _badgeIcon(IconData icon, int n, Color badge) => Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(icon, color: Colors.white, size: 22),
          if (n > 0)
            Positioned(
              right: -8,
              top: -6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(color: badge, borderRadius: BorderRadius.circular(8)),
                child: Text(n > 99 ? '99+' : '$n',
                    style: GoogleFonts.poppins(
                        color: badge == red ? Colors.white : const Color(0xFF2A0F57), fontSize: 9, fontWeight: FontWeight.w800)),
              ),
            ),
        ],
      );
}

class _Hand {
  final String id;
  final String name;
  final DateTime at;
  const _Hand(this.id, this.name, this.at);
}

class _Msg {
  final String fromId;
  final String fromName;
  final String text;
  final DateTime at;
  final bool mine;
  const _Msg(this.fromId, this.fromName, this.text, this.at, this.mine);
}

/// 💬 Questions from students + Sir's messages (to everyone or to one student)
class _HostChatSheet extends StatefulWidget {
  final List<_Msg> Function() messages;
  final Future<bool> Function(String text) sendToAll;
  final Future<bool> Function(_Msg to, String text) replyTo;
  const _HostChatSheet({required this.messages, required this.sendToAll, required this.replyTo});

  @override
  State<_HostChatSheet> createState() => _HostChatSheetState();
}

class _HostChatSheetState extends State<_HostChatSheet> {
  final _text = TextEditingController();
  final _scroll = ScrollController();
  _Msg? _reply;
  bool _sending = false;
  Timer? _refresh;

  @override
  void initState() {
    super.initState();
    // new questions arrive while the sheet is open → redraw every second
    _refresh = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _toBottom());
  }

  @override
  void dispose() {
    _refresh?.cancel();
    _text.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _toBottom() {
    if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
  }

  String _clock(DateTime t) {
    final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
    return '$h:${t.minute.toString().padLeft(2, '0')} ${t.hour < 12 ? 'AM' : 'PM'}';
  }

  Future<void> _send() async {
    final t = _text.text.trim();
    if (t.isEmpty || _sending) return;
    setState(() => _sending = true);
    final ok = _reply == null ? await widget.sendToAll(t) : await widget.replyTo(_reply!, t);
    if (!mounted) return;
    setState(() {
      _sending = false;
      if (ok) {
        _text.clear();
        _reply = null;
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _toBottom());
    if (!ok) {
      Get.snackbar('Not sent', 'Check your internet and try again.',
          backgroundColor: const Color(0xFFE45757), colorText: Colors.white);
    }
  }

  @override
  Widget build(BuildContext context) {
    const purple = Color(0xFF7B2FF7);
    const ink = Color(0xFF173A52);
    final list = widget.messages();
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        height: MediaQuery.of(context).size.height * .75,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(4)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
                child: Row(
                  children: [
                    const Icon(Icons.chat_bubble_rounded, color: purple, size: 20),
                    const SizedBox(width: 8),
                    Text('Student questions',
                        style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w800, color: ink)),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: list.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(28),
                          child: Text(
                            'Questions from students appear here.\nTap a question to reply only to that student.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(color: Colors.black45, fontSize: 12.5),
                          ),
                        ),
                      )
                    : ListView.builder(
                        controller: _scroll,
                        padding: const EdgeInsets.all(12),
                        itemCount: list.length,
                        itemBuilder: (_, i) {
                          final m = list[i];
                          return Align(
                            alignment: m.mine ? Alignment.centerRight : Alignment.centerLeft,
                            child: GestureDetector(
                              onTap: m.mine ? null : () => setState(() => _reply = m),
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                constraints: const BoxConstraints(maxWidth: 480),
                                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                                decoration: BoxDecoration(
                                  color: m.mine ? purple : const Color(0xFFF3EEFD),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('${m.fromName} • ${_clock(m.at)}',
                                        style: GoogleFonts.poppins(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            color: m.mine ? Colors.white70 : purple)),
                                    const SizedBox(height: 2),
                                    Text(m.text,
                                        style: GoogleFonts.poppins(fontSize: 13, color: m.mine ? Colors.white : ink)),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
              if (_reply != null)
                Container(
                  color: const Color(0xFFF3EEFD),
                  padding: const EdgeInsets.fromLTRB(14, 4, 4, 4),
                  child: Row(
                    children: [
                      const Icon(Icons.reply_rounded, size: 16, color: purple),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text('Reply only to ${_reply!.fromName}',
                            style: GoogleFonts.poppins(fontSize: 12, color: purple, fontWeight: FontWeight.w600)),
                      ),
                      IconButton(
                        onPressed: () => setState(() => _reply = null),
                        icon: const Icon(Icons.close_rounded, size: 18),
                      ),
                    ],
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 8, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _text,
                        maxLength: 300,
                        minLines: 1,
                        maxLines: 3,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _send(),
                        decoration: InputDecoration(
                          counterText: '',
                          hintText: _reply == null ? 'Message to everyone…' : 'Your reply…',
                          hintStyle: GoogleFonts.poppins(fontSize: 13),
                          filled: true,
                          fillColor: const Color(0xFFF5F3FA),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide.none),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    IconButton.filled(
                      style: IconButton.styleFrom(backgroundColor: purple),
                      onPressed: _sending ? null : _send,
                      icon: _sending
                          ? const SizedBox(
                              width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.send_rounded, color: Colors.white),
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
}
