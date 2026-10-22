import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:lets_speake_manager/Api/ApiendPoints.dart';
import 'package:lets_speake_manager/Api/api_headers.dart';
import 'package:lets_speake_manager/Api/batch_slots.dart';
import 'package:lets_speake_manager/Controllers/adminController.dart';
import 'package:lets_speake_manager/Navigation/AdminShellNavigation.dart';
import 'package:lets_speake_manager/screens/AttendanceReportScreen.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

/// Student Control — mode, course access, per-stage section + timing.
/// ⚡ LIVE: when the student changes a timing in the student app (or the fee is
/// approved), this screen updates by itself — no refresh needed. If the admin
/// is in the middle of editing, their edits are kept and a banner offers
/// "Load latest".
/// Every section / timing shows how many students are already in it,
/// and the emptiest one is marked "Fewest" so new students are easy to place.
class AdminUserControlScreen extends StatefulWidget {
  final dynamic user;
  const AdminUserControlScreen({super.key, required this.user});

  @override
  State<AdminUserControlScreen> createState() => _AdminUserControlScreenState();
}

class _AdminUserControlScreenState extends State<AdminUserControlScreen> with WidgetsBindingObserver {
  // ---------------- palette ----------------
  static const Color textColor = Color(0xFF173A52);
  static const Color secondaryText = Color(0xFF6B8496);
  static const Color borderColor = Color(0xFFD5E5EE);
  static const Color bg = Color(0xFFF5FAFD);
  static const Color cardBg = Color(0xFFFFFFFF);
  static const Color subtle = Color(0xFFEAF4FA);
  static const Color navy = Color(0xFF0A4A75);
  static const Color blue = Color(0xFF2E86C9);
  static const Color green = Color(0xFF16A66A);
  static const Color red = Color(0xFFE45757);
  static const Color amber = Color(0xFFF4C542);
  static const Color amberText = Color(0xFF8B6A00);
  static const Color offlineColor = Color(0xFFC68B00);

  static const List<String> sections = ['A', 'B', 'C', 'D', 'E'];
  static const List<String> stageKeys = ['stage1', 'stage2', 'stage3', 'stage4', 'stage5', 'stage6', 'stage7'];

  // find it if the Students page already made it, otherwise make it here
  // (after logout + login this screen can open before the Students page)
  final AdminController adminController =
      Get.isRegistered<AdminController>() ? Get.find<AdminController>() : Get.put(AdminController());

  late Map<String, dynamic> englishAccess;
  late Map<String, dynamic> hindiAccess;
  late String selectedMode;
  late String selectedSection; // "A".."E" or ""
  late String selectedFeeStatus;
  late String selectedBatch; // default (signup) timing — canonical label or ""
  late Map<String, String> englishBatch; // per-stage timing, "" = use default
  late Map<String, String> hindiBatch;
  String _savedSnapshot = '';

  bool showHindi = false;
  bool isSaving = false;
  bool isLoadingAnalytics = true;
  List<dynamic> studentAttendanceLog = [];
  List<dynamic> studentTestResults = [];

  /// Students per stage / section / timing (from /admin/class-load)
  final ValueNotifier<Map<String, dynamic>?> _load = ValueNotifier(null);
  bool loadingLoad = false;

  // ---------------- live updates ----------------
  late Map<String, dynamic> _user; // latest copy of the student from the server
  IO.Socket? _socket;
  Timer? _poll; // safety net if a socket message is missed
  Timer? _liveDebounce;
  Map<String, dynamic>? _pendingRemote; // arrived while the admin was editing
  String _pendingWhat = '';
  int _panelsOpen = 0; // a sheet / dialog is open → don't change things under it
  bool _live = false; // socket connected
  bool _fetchingUser = false;

  // =========================================================
  // INIT
  // =========================================================
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeUserData();
    _connectSocket();
    _poll = Timer.periodic(const Duration(seconds: 30), (_) => _refreshStudent());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshStudent(); // back to the app → catch up
  }

  @override
  void didUpdateWidget(covariant AdminUserControlScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user['_id'] != widget.user['_id'] || oldWidget.user['id'] != widget.user['id']) {
      _initializeUserData();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _poll?.cancel();
    _liveDebounce?.cancel();
    try {
      _socket?.clearListeners();
      _socket?.dispose();
    } catch (_) {}
    _load.dispose();
    super.dispose();
  }

  String get _userId => (widget.user['_id'] ?? widget.user['id']).toString();
  String get _studentName => (_user['name'] ?? widget.user['name'] ?? 'Student').toString();
  String get _firstName {
    final n = _studentName.trim();
    return n.isEmpty ? 'this student' : n.split(' ').first;
  }

  void _initializeUserData() {
    _user = _copy(widget.user);
    _pendingRemote = null;
    _readFrom(_user);
    // open the Hindi tab when the student only learns Hindi
    showHindi = !_anyOn(englishAccess) && _anyOn(hindiAccess);

    _fetchStudentDeepAnalytics();
    _fetchClassLoad();
  }

  Map<String, dynamic> _copy(dynamic m) =>
      m is Map ? Map<String, dynamic>.from(jsonDecode(jsonEncode(m))) : <String, dynamic>{};

  /// Puts a server copy of the student into the editable fields.
  void _readFrom(Map<String, dynamic> u) {
    englishAccess = _readAccess(u['englishAccess']);
    hindiAccess = _readAccess(u['hindiAccess']);
    selectedMode = (u['mode'] ?? 'online').toString().toLowerCase();
    final sec = (u['onlineSection'] ?? '').toString().toUpperCase();
    selectedSection = sections.contains(sec) ? sec : '';
    selectedFeeStatus = (u['feeStatus'] ?? 'unpaid').toString().toLowerCase();
    selectedBatch = BatchSlots.labelOf(u['batchTime']);
    englishBatch = _readBatchMap(u['englishBatch']);
    hindiBatch = _readBatchMap(u['hindiBatch']);
    _savedSnapshot = _snapshot();
  }

  Map<String, dynamic> _readAccess(dynamic raw) {
    final map = raw is Map ? raw : const {};
    return {for (final k in stageKeys) k: map[k] == true};
  }

  Map<String, String> _readBatchMap(dynamic raw) {
    final map = raw is Map ? raw : const {};
    return {for (final k in stageKeys) k: BatchSlots.labelOf(map[k])};
  }

  // keys always in the same order → two equal settings give the same text
  String _snapshot() => jsonEncode({
        'e': {for (final k in stageKeys) k: englishAccess[k] == true},
        'h': {for (final k in stageKeys) k: hindiAccess[k] == true},
        'm': selectedMode,
        's': selectedSection,
        'b': selectedBatch,
        'eb': {for (final k in stageKeys) k: englishBatch[k] ?? ''},
        'hb': {for (final k in stageKeys) k: hindiBatch[k] ?? ''},
      });

  /// Same snapshot, but for a raw server copy (without touching the screen)
  String _snapshotOf(Map u) {
    final ea = _readAccess(u['englishAccess']);
    final ha = _readAccess(u['hindiAccess']);
    final eb = _readBatchMap(u['englishBatch']);
    final hb = _readBatchMap(u['hindiBatch']);
    final sec = (u['onlineSection'] ?? '').toString().toUpperCase();
    return jsonEncode({
      'e': ea,
      'h': ha,
      'm': (u['mode'] ?? 'online').toString().toLowerCase(),
      's': sections.contains(sec) ? sec : '',
      'b': BatchSlots.labelOf(u['batchTime']),
      'eb': eb,
      'hb': hb,
    });
  }

  bool get _dirty => _snapshot() != _savedSnapshot;

  // =========================================================
  // HELPERS
  // =========================================================
  bool _anyOn(Map<String, dynamic> m) => m.values.any((v) => v == true);
  bool get _isOnline => selectedMode == 'online';
  bool get _hasSection => sections.contains(selectedSection);

  /// Sections exist only for ONLINE ENGLISH classes
  bool _needsSection(bool isEnglish) => _isOnline && isEnglish;

  String _stageNo(String key) => key.replaceAll('stage', '');

  /// Effective timing of one stage: its own timing, else the default (signup) timing
  String _stageTiming(bool isEnglish, String key) {
    final own = (isEnglish ? englishBatch : hindiBatch)[key] ?? '';
    return own.isNotEmpty ? own : selectedBatch;
  }

  /// Timings already used by OTHER enabled stages → "English Stage 1"
  Map<String, String> _takenTimings({required bool isEnglish, required String key}) {
    final taken = <String, String>{};
    void scan(bool eng, Map<String, dynamic> access) {
      for (final k in stageKeys) {
        if (eng == isEnglish && k == key) continue;
        if (access[k] != true) continue;
        final t = _stageTiming(eng, k);
        if (t.isNotEmpty) taken.putIfAbsent(t, () => '${eng ? 'English' : 'Hindi'} Stage ${_stageNo(k)}');
      }
    }

    scan(true, englishAccess);
    scan(false, hindiAccess);
    return taken;
  }

  dynamic _dig(dynamic m, List<String> path) {
    dynamic cur = m;
    for (final p in path) {
      if (cur is Map && cur.containsKey(p)) {
        cur = cur[p];
      } else {
        return null;
      }
    }
    return cur;
  }

  int _num(dynamic v) => (v is num) ? v.toInt() : int.tryParse('${v ?? ''}') ?? 0;

  /// Load table for one stage in the student's current mode (other students only)
  Map? _stageLoad(bool isEnglish, String key) {
    final v = _dig(_load.value, [_isOnline ? 'online' : 'offline', isEnglish ? 'English' : 'Hindi', key]);
    return v is Map ? v : null;
  }

  int _sectionCount(Map? load, String sec) => _num(_dig(load, ['sections', sec]));
  int _timingCount(Map? load, String label) => _num(_dig(load, ['timings', label]));
  int _classCount(Map? load, String sec, String label) => _num(_dig(load, ['matrix', sec, label]));

  String? _trainerFor(bool isEnglish, String key, String sec) {
    final t = _dig(_load.value, ['trainers', isEnglish ? 'English' : 'Hindi', key]);
    if (t is! Map) return null;
    final v = t[sec] ?? t['all'];
    return v == null ? null : v.toString();
  }

  // =========================================================
  // ⚡ LIVE UPDATES
  // =========================================================
  void _connectSocket() {
    try {
      // Socket.IO connects to the server root, not ".../api"
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
      s.onReconnect((_) {
        s.emit('join_admin_room');
        _refreshStudent(); // catch anything that changed while offline
      });
      s.onDisconnect((_) {
        if (mounted) setState(() => _live = false);
      });
      s.on('student_update', _onStudentUpdate);
      s.on('fee_update', _onStudentUpdate);
      _socket = s;
    } catch (e) {
      debugPrint('Student control socket error: $e');
    }
  }

  void _onStudentUpdate(dynamic data) {
    if (!mounted || data is! Map) return;
    if ((data['userId'] ?? '').toString() != _userId) return; // another student
    if (data['deleted'] == true) {
      _snack('Student deleted', '$_firstName\'s account was deleted.', red, icon: Icons.person_off_rounded);
      return;
    }
    final u = data['user'];
    if (u is Map) {
      _applyRemote(_copy(u));
    } else {
      // the event only says "something changed" → ask the server (short wait groups quick changes)
      _liveDebounce?.cancel();
      _liveDebounce = Timer(const Duration(milliseconds: 500), _refreshStudent);
    }
  }

  /// Load this student again from the server.
  Future<void> _refreshStudent() async {
    if (!mounted || _fetchingUser || isSaving) return;
    _fetchingUser = true;
    try {
      final res = await http.get(
        Uri.parse("${ApiEndpoints.baseUrl}/admin/student/$_userId?_t=${DateTime.now().millisecondsSinceEpoch}"),
        headers: ApiHeaders.auth(),
      );
      if (!mounted) return;
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final u = body is Map && body['user'] is Map ? body['user'] : body;
        if (u is Map) _applyRemote(_copy(u));
      } else if (res.statusCode == 404) {
        // older backend without this route → use the Students list (it refreshes itself)
        final i = adminController.usersList.indexWhere((x) => (x['_id'] ?? x['id']).toString() == _userId);
        if (i != -1) _applyRemote(_copy(adminController.usersList[i]));
      }
    } catch (e) {
      debugPrint('Refresh student error: $e');
    } finally {
      _fetchingUser = false;
    }
  }

  /// A fresh server copy arrived. Update the screen — unless the admin is editing.
  void _applyRemote(Map<String, dynamic> fresh) {
    if (!mounted || isSaving) return;
    final merged = {..._user, ...fresh};

    // fee is not edited on this screen → always show the newest value
    final fee = (merged['feeStatus'] ?? 'unpaid').toString().toLowerCase();
    final feeChanged = fee != selectedFeeStatus;

    final settingsChanged = _snapshotOf(merged) != _snapshotOf(_user);
    if (!settingsChanged) {
      _user = merged;
      if (feeChanged) {
        setState(() => selectedFeeStatus = fee);
        _liveToast(fee == 'paid' ? 'Fee marked paid ✓' : 'Fee status: unpaid');
      }
      return;
    }

    final what = _describeChange(_user, merged);
    if (_dirty || _panelsOpen > 0) {
      // keep what the admin is doing; offer the new values
      setState(() {
        selectedFeeStatus = fee;
        _pendingRemote = merged;
        _pendingWhat = what;
      });
      return;
    }

    setState(() {
      _user = merged;
      _pendingRemote = null;
      _readFrom(merged);
    });
    _liveToast(what);
    _fetchClassLoad(); // class sizes changed too
  }

  /// Admin tapped "Load latest" (or closed a sheet without changing anything)
  void _loadPending() {
    final p = _pendingRemote;
    if (p == null) return;
    HapticFeedback.selectionClick();
    final what = _pendingWhat;
    setState(() {
      _user = p;
      _pendingRemote = null;
      _readFrom(p);
    });
    _liveToast(what);
    _fetchClassLoad();
  }

  void _keepMine() {
    final p = _pendingRemote;
    if (p == null) return;
    // the student's copy is now the base; the admin's edits stay as unsaved changes
    setState(() {
      _user = p;
      _pendingRemote = null;
    });
  }

  String _prettyStage(String k) => 'Stage ${_stageNo(k)}';

  /// "Changed English Stage 2 timing to 7:00 PM – 8:00 PM"
  String _describeChange(Map a, Map b) {
    final out = <String>[];
    final ba = BatchSlots.labelOf(a['batchTime']), bb = BatchSlots.labelOf(b['batchTime']);
    if (ba != bb) out.add('Default timing → ${bb.isEmpty ? 'none' : bb}');
    for (final isEnglish in [true, false]) {
      final field = isEnglish ? 'englishBatch' : 'hindiBatch';
      final ma = _readBatchMap(a[field]), mb = _readBatchMap(b[field]);
      for (final k in stageKeys) {
        if (ma[k] != mb[k]) {
          out.add('${isEnglish ? 'English' : 'Hindi'} ${_prettyStage(k)} → ${mb[k]!.isEmpty ? 'default timing' : mb[k]}');
        }
      }
      final aa = _readAccess(a[isEnglish ? 'englishAccess' : 'hindiAccess']);
      final ab = _readAccess(b[isEnglish ? 'englishAccess' : 'hindiAccess']);
      for (final k in stageKeys) {
        if (aa[k] != ab[k]) out.add('${isEnglish ? 'English' : 'Hindi'} ${_prettyStage(k)} ${ab[k] == true ? 'turned on' : 'turned off'}');
      }
    }
    final mA = (a['mode'] ?? '').toString().toLowerCase(), mB = (b['mode'] ?? '').toString().toLowerCase();
    if (mA != mB) out.add('Mode → ${mB == 'online' ? 'Online' : 'Offline'}');
    final sA = (a['onlineSection'] ?? '').toString().toUpperCase(), sB = (b['onlineSection'] ?? '').toString().toUpperCase();
    if (sA != sB) out.add(sections.contains(sB) ? 'Section → $sB' : 'Section removed');
    if (out.isEmpty) return 'Settings were updated';
    if (out.length > 2) return '${out.take(2).join(' • ')} • +${out.length - 2} more';
    return out.join(' • ');
  }

  void _liveToast(String msg) {
    if (!mounted) return;
    Get.closeCurrentSnackbar();
    Get.snackbar(
      'Updated live — $_firstName',
      msg,
      backgroundColor: navy.withOpacity(0.96),
      colorText: Colors.white,
      icon: const Icon(Icons.bolt_rounded, color: amber),
      snackPosition: SnackPosition.TOP,
      margin: const EdgeInsets.all(16),
      borderRadius: 14,
      duration: const Duration(seconds: 4),
    );
  }

  /// Banner shown when the student changed something while the admin was editing
  Widget _pendingBanner() {
    if (_pendingRemote == null) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: amber.withOpacity(.7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.bolt_rounded, color: amberText, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$_firstName just changed their settings',
                        style: GoogleFonts.poppins(color: textColor, fontSize: 12.5, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(_pendingWhat, style: GoogleFonts.poppins(color: amberText, fontSize: 11.5, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text('Your unsaved edits are kept. Load the latest to see their change.',
                        style: GoogleFonts.poppins(color: secondaryText, fontSize: 10.5)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: _keepMine,
                child: Text('Keep my edits', style: GoogleFonts.poppins(color: secondaryText, fontSize: 12, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: 6),
              ElevatedButton.icon(
                onPressed: _loadPending,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: Text('Load latest', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: navy,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // =========================================================
  // NETWORK
  // =========================================================
  Future<void> _fetchClassLoad() async {
    loadingLoad = true;
    if (mounted) setState(() {});
    try {
      final res = await http.get(
        Uri.parse("${ApiEndpoints.baseUrl}/admin/class-load?exclude=$_userId"),
        headers: ApiHeaders.auth(),
      );
      if (!mounted) return;
      if (res.statusCode == 200) {
        _load.value = Map<String, dynamic>.from(jsonDecode(res.body));
      } else {
        debugPrint("Class load failed: ${res.statusCode} ${res.body}");
      }
    } catch (e) {
      debugPrint("Class load error: $e");
    } finally {
      loadingLoad = false;
      if (mounted) setState(() {});
    }
  }

  Future<void> _fetchStudentDeepAnalytics() async {
    isLoadingAnalytics = true;
    if (mounted) setState(() {});
    try {
      final responses = await Future.wait([
        http.get(Uri.parse("${ApiEndpoints.userAttendance}?userId=$_userId"), headers: ApiHeaders.auth()),
        http.get(Uri.parse("${ApiEndpoints.userTestResults}?userId=$_userId"), headers: ApiHeaders.auth()),
      ]);
      if (responses[0].statusCode == 200) {
        studentAttendanceLog = jsonDecode(responses[0].body)['records'] ?? [];
      }
      if (responses[1].statusCode == 200) {
        studentTestResults = jsonDecode(responses[1].body)['results'] ?? [];
      }
    } catch (e) {
      debugPrint("Analytics Fetch Error: $e");
    } finally {
      isLoadingAnalytics = false;
      if (mounted) setState(() {});
    }
  }

  // ---------------- analytics getters ----------------
  int get presentSessions => studentAttendanceLog.where((r) => r['status'] == 'Present').length;
  int get partialLateSessions =>
      studentAttendanceLog.where((r) => r['status'] == 'Partial' || r['status'] == 'Late').length;
  int get totalLoggedSessions => studentAttendanceLog.length;

  double get attendanceRate {
    if (totalLoggedSessions == 0) return 0.0;
    return ((presentSessions + (partialLateSessions * 0.5)) / totalLoggedSessions) * 100;
  }

  int get totalMinutesSpent {
    int total = 0;
    for (final r in studentAttendanceLog) {
      total += (r['totalMinutesSpent'] as num? ?? 0).toInt();
    }
    return total;
  }

  double get averageTestScore {
    if (studentTestResults.isEmpty) return 0.0;
    int earned = 0, possible = 0;
    for (final t in studentTestResults) {
      earned += (t['score'] as num? ?? 0).toInt();
      possible += (t['totalQuestions'] as num? ?? 1).toInt();
    }
    return possible > 0 ? (earned / possible) * 100 : 0.0;
  }

  String get regularityStatus {
    if (totalLoggedSessions < 3) return "New student";
    if (attendanceRate >= 80) return "Regular";
    if (attendanceRate >= 50) return "Moderate";
    return "At risk";
  }

  Color get regularityColor {
    if (totalLoggedSessions < 3) return blue;
    if (attendanceRate >= 80) return green;
    if (attendanceRate >= 50) return amber;
    return red;
  }

  // =========================================================
  // ACTIONS
  // =========================================================
  void _snack(String title, String msg, Color color, {IconData icon = Icons.info_outline_rounded}) {
    Get.snackbar(
      title,
      msg,
      backgroundColor: color.withOpacity(0.95),
      colorText: Colors.white,
      icon: Icon(icon, color: Colors.white),
      snackPosition: SnackPosition.TOP,
      margin: const EdgeInsets.all(16),
      borderRadius: 14,
    );
  }

  Future<void> _goBackToStudents() async {
    if (_dirty) {
      final leave = await Get.dialog<bool>(
        AlertDialog(
          backgroundColor: cardBg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Text('Discard changes?',
              style: GoogleFonts.poppins(color: textColor, fontWeight: FontWeight.w700, fontSize: 16)),
          content: Text("You changed $_firstName's settings but didn't save them.",
              style: GoogleFonts.poppins(color: secondaryText, fontSize: 12.5)),
          actions: [
            TextButton(
              onPressed: () => Get.back(result: false),
              child: Text('Keep editing', style: GoogleFonts.poppins(color: secondaryText, fontWeight: FontWeight.w600)),
            ),
            TextButton(
              onPressed: () => Get.back(result: true),
              child: Text('Discard', style: GoogleFonts.poppins(color: red, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      );
      if (leave != true) return;
    }

    if (AdminShellNavigation.detailUser.value != null) {
      AdminShellNavigation.goHome();
      return;
    }
    if (Get.key.currentState?.canPop() ?? false) {
      Get.back();
      return;
    }
    AdminShellNavigation.openDrawer();
  }

  void _disableStage(bool isEnglish, String key) {
    HapticFeedback.selectionClick();
    setState(() {
      (isEnglish ? englishAccess : hindiAccess)[key] = false;
      (isEnglish ? englishBatch : hindiBatch)[key] = '';
      if (!_anyOn(englishAccess)) selectedSection = '';
    });
  }

  void _turnAllOff(bool isEnglish) {
    HapticFeedback.selectionClick();
    setState(() {
      for (final k in stageKeys) {
        (isEnglish ? englishAccess : hindiAccess)[k] = false;
        (isEnglish ? englishBatch : hindiBatch)[k] = '';
      }
      if (!_anyOn(englishAccess)) selectedSection = '';
    });
  }

  Future<void> _saveAllSettings() async {
    final hasEnglish = _anyOn(englishAccess);

    if (_isOnline && hasEnglish && !_hasSection) {
      _snack('Choose a section', 'Online English classes need a section (A–E).', amberText);
      return;
    }
    for (final isEnglish in [true, false]) {
      final access = isEnglish ? englishAccess : hindiAccess;
      for (final k in stageKeys) {
        if (access[k] == true && _stageTiming(isEnglish, k).isEmpty) {
          _snack('Timing missing', 'Set a timing for ${isEnglish ? 'English' : 'Hindi'} Stage ${_stageNo(k)}.',
              amberText);
          return;
        }
      }
    }

    HapticFeedback.mediumImpact();
    setState(() => isSaving = true);
    try {
      final section = _isOnline && hasEnglish ? selectedSection : 'None';
      // Access + timings in ONE request → the server checks clashes with the NEW timings.
      // If it refuses, stop here and show why (nothing half-saved).
      await adminController.updateUserAccess(
        _userId,
        englishAccess,
        hindiAccess,
        selectedMode,
        englishBatch: englishBatch,
        hindiBatch: hindiBatch,
        batchTime: selectedBatch,
        onlineSection: section,
      );

      final response = await http.put(
        Uri.parse(ApiEndpoints.updateStudentStatus),
        headers: ApiHeaders.json(),
        body: jsonEncode({
          "userId": _userId,
          "feeStatus": selectedFeeStatus,
          "onlineSection": section,
          "mode": selectedMode,
          "batchTime": selectedBatch,
          "englishBatch": englishBatch,
          "hindiBatch": hindiBatch,
        }),
      );

      if (response.statusCode == 200) {
        // keep the cached list in sync so other screens show the new values
        final idx = adminController.usersList.indexWhere((u) => (u['_id'] ?? u['id']).toString() == _userId);
        if (idx != -1) {
          final updated = Map<String, dynamic>.from(adminController.usersList[idx]);
          updated['batchTime'] = selectedBatch;
          updated['englishBatch'] = Map<String, String>.from(englishBatch);
          updated['hindiBatch'] = Map<String, String>.from(hindiBatch);
          updated['englishAccess'] = Map<String, dynamic>.from(englishAccess);
          updated['hindiAccess'] = Map<String, dynamic>.from(hindiAccess);
          updated['onlineSection'] = section;
          updated['mode'] = selectedMode;
          adminController.usersList[idx] = updated;
        }
        setState(() {
          _savedSnapshot = _snapshot();
          _pendingRemote = null; // the admin's save is now the newest
          _user = {
            ..._user,
            'batchTime': selectedBatch,
            'englishBatch': Map<String, String>.from(englishBatch),
            'hindiBatch': Map<String, String>.from(hindiBatch),
            'englishAccess': Map<String, dynamic>.from(englishAccess),
            'hindiAccess': Map<String, dynamic>.from(hindiAccess),
            'onlineSection': section,
            'mode': selectedMode,
            'feeStatus': selectedFeeStatus,
          };
        });
        _snack("Saved", "$_firstName's classes are updated.", green, icon: Icons.check_circle_rounded);
        _fetchClassLoad();
      } else {
        String msg = "Could not save changes (${response.statusCode}).";
        try {
          final body = jsonDecode(response.body);
          if (body is Map && body['message'] != null) msg = body['message'].toString();
        } catch (_) {}
        _snack("Not saved", msg, red, icon: Icons.error_outline_rounded);
      }
    } on AccessSaveException catch (e) {
      _snack("Not saved", e.message, red, icon: Icons.error_outline_rounded);
    } catch (e) {
      _snack("Not saved", "Connection error: $e", red, icon: Icons.error_outline_rounded);
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  // =========================================================
  // PANEL (bottom sheet on phones, dialog on web/tablet)
  // =========================================================
  void _showPanel(Widget Function(BuildContext ctx) builder) {
    final size = MediaQuery.of(context).size;
    _panelsOpen++;
    void closed() {
      if (_panelsOpen > 0) _panelsOpen--;
      // a live change came in while the sheet was open and the admin changed nothing → show it now
      if (mounted && _panelsOpen == 0 && _pendingRemote != null && !_dirty) _loadPending();
    }

    if (size.width >= 700) {
      Get.dialog(
        Dialog(
          backgroundColor: cardBg,
          surfaceTintColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 580, maxHeight: size.height * .88),
            child: Builder(builder: builder),
          ),
        ),
      ).whenComplete(closed);
    } else {
      Get.bottomSheet(
        Container(
          constraints: BoxConstraints(maxHeight: size.height * .92),
          decoration: const BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(top: false, child: Builder(builder: builder)),
        ),
        isScrollControlled: true,
      ).whenComplete(closed);
    }
  }

  Widget _panelHeader({required IconData icon, required String title, required String subtitle}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 10, 6),
      child: Column(
        children: [
          if (MediaQuery.of(context).size.width < 700)
            Container(
              width: 38,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(color: borderColor, borderRadius: BorderRadius.circular(4)),
            ),
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: blue.withOpacity(.10), borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: blue, size: 20),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: GoogleFonts.poppins(color: textColor, fontSize: 15.5, fontWeight: FontWeight.w700)),
                    Text(subtitle, style: GoogleFonts.poppins(color: secondaryText, fontSize: 10.5)),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Get.back(),
                icon: const Icon(Icons.close_rounded, color: secondaryText),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stepLabel(String n, String text, {Widget? trailing}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 20,
            height: 20,
            alignment: Alignment.center,
            decoration: const BoxDecoration(color: navy, shape: BoxShape.circle),
            child: Text(n, style: GoogleFonts.poppins(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: GoogleFonts.poppins(color: textColor, fontSize: 12.5, fontWeight: FontWeight.w700)),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  Widget _fewestBadge() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(color: green.withOpacity(.12), borderRadius: BorderRadius.circular(6)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.trending_down_rounded, size: 11, color: green),
            const SizedBox(width: 2),
            Text('Fewest', style: GoogleFonts.poppins(color: green, fontSize: 8.5, fontWeight: FontWeight.w800)),
          ],
        ),
      );

  // =========================================================
  // STAGE SHEET — choose section (online English) + timing
  // =========================================================
  void _openStageSheet({required bool isEnglish, required String key}) {
    final accessMap = isEnglish ? englishAccess : hindiAccess;
    final batchMap = isEnglish ? englishBatch : hindiBatch;
    final wasEnabled = accessMap[key] == true;
    final needsSection = _needsSection(isEnglish);
    final taken = _takenTimings(isEnglish: isEnglish, key: key);
    final title = '${isEnglish ? 'English' : 'Hindi'} Stage ${_stageNo(key)}';
    final otherEnglishOn = englishAccess.entries.any((e) => e.key != key && e.value == true);

    String tempSection = _hasSection ? selectedSection : '';
    String tempTiming = wasEnabled ? _stageTiming(isEnglish, key) : (batchMap[key] ?? '');
    if (tempTiming.isEmpty && !taken.containsKey(selectedBatch)) tempTiming = selectedBatch; // suggest signup timing
    if (taken.containsKey(tempTiming)) tempTiming = '';

    _showPanel((ctx) => StatefulBuilder(
          builder: (ctx, setSheet) => ValueListenableBuilder<Map<String, dynamic>?>(
            valueListenable: _load,
            builder: (ctx, data, _) {
              final load = _stageLoad(isEnglish, key);
              final hasLoad = load != null;

              // ---- sections ----
              final secCounts = {for (final s in sections) s: _sectionCount(load, s)};
              final secMin = secCounts.values.isEmpty ? 0 : secCounts.values.reduce((a, b) => a < b ? a : b);
              final secMax = secCounts.values.isEmpty ? 0 : secCounts.values.reduce((a, b) => a > b ? a : b);
              final fewestSection =
                  hasLoad && secMax > secMin ? sections.firstWhere((s) => secCounts[s] == secMin) : null;

              // ---- timings ----
              int countFor(BatchSlot b) => (needsSection && tempSection.isNotEmpty)
                  ? _classCount(load, tempSection, b.label)
                  : _timingCount(load, b.label);
              final free = BatchSlots.all.where((b) => !taken.containsKey(b.label)).toList();
              final freeCounts = free.map(countFor).toList();
              final tMin = freeCounts.isEmpty ? 0 : freeCounts.reduce((a, b) => a < b ? a : b);
              final tMax = freeCounts.isEmpty ? 0 : freeCounts.reduce((a, b) => a > b ? a : b);
              final fewestTiming =
                  hasLoad && tMax > tMin ? free.firstWhere((b) => countFor(b) == tMin).label : null;
              final allTimingMax = BatchSlots.all.map(countFor).fold<int>(0, (a, b) => a > b ? a : b);

              final canSave = tempTiming.isNotEmpty && (!needsSection || tempSection.isNotEmpty);

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _panelHeader(
                    icon: wasEnabled ? Icons.edit_calendar_rounded : Icons.lock_open_rounded,
                    title: title,
                    subtitle: '${_isOnline ? 'Online' : 'Offline'} class • $_studentName',
                  ),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(18, 6, 18, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(color: subtle, borderRadius: BorderRadius.circular(10)),
                            child: Row(
                              children: [
                                const Icon(Icons.people_alt_outlined, size: 15, color: secondaryText),
                                const SizedBox(width: 7),
                                Expanded(
                                  child: Text(
                                    hasLoad
                                        ? 'Numbers show students already in each class (${_num(load?['total'])} in this stage, not counting $_firstName).'
                                        : (loadingLoad ? 'Loading student counts…' : 'Student counts unavailable.'),
                                    style: GoogleFonts.poppins(color: secondaryText, fontSize: 10, height: 1.35),
                                  ),
                                ),
                                if (!hasLoad && loadingLoad)
                                  const SizedBox(
                                      width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: blue)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),

                          // ================= SECTION =================
                          if (needsSection) ...[
                            _stepLabel('1', 'Choose section'),
                            LayoutBuilder(builder: (ctx, c) {
                              final cols = c.maxWidth >= 480 ? 5 : 3;
                              final w = (c.maxWidth - (cols - 1) * 8) / cols;
                              return Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: sections.map((s) {
                                  final chosen = tempSection == s;
                                  final n = secCounts[s] ?? 0;
                                  final trainer = _trainerFor(isEnglish, key, s);
                                  return SizedBox(
                                    width: w,
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(13),
                                      onTap: () {
                                        HapticFeedback.selectionClick();
                                        setSheet(() => tempSection = s);
                                      },
                                      child: AnimatedContainer(
                                        duration: const Duration(milliseconds: 140),
                                        padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
                                        decoration: BoxDecoration(
                                          color: chosen ? blue.withOpacity(.09) : subtle,
                                          borderRadius: BorderRadius.circular(13),
                                          border: Border.all(color: chosen ? blue : borderColor, width: chosen ? 1.5 : 1),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Container(
                                                  width: 26,
                                                  height: 26,
                                                  alignment: Alignment.center,
                                                  decoration: BoxDecoration(
                                                    color: chosen ? blue : cardBg,
                                                    shape: BoxShape.circle,
                                                    border: Border.all(color: chosen ? blue : borderColor),
                                                  ),
                                                  child: Text(s,
                                                      style: GoogleFonts.poppins(
                                                          color: chosen ? Colors.white : textColor,
                                                          fontSize: 12,
                                                          fontWeight: FontWeight.w800)),
                                                ),
                                                const Spacer(),
                                                if (chosen)
                                                  const Icon(Icons.check_circle_rounded, color: blue, size: 16)
                                                else if (fewestSection == s)
                                                  const Icon(Icons.trending_down_rounded, color: green, size: 16),
                                              ],
                                            ),
                                            const SizedBox(height: 7),
                                            Text(hasLoad ? '$n student${n == 1 ? '' : 's'}' : '…',
                                                style: GoogleFonts.poppins(
                                                    color: textColor, fontSize: 11.5, fontWeight: FontWeight.w700)),
                                            const SizedBox(height: 4),
                                            ClipRRect(
                                              borderRadius: BorderRadius.circular(4),
                                              child: LinearProgressIndicator(
                                                value: secMax == 0 ? 0 : n / secMax,
                                                minHeight: 4,
                                                backgroundColor: cardBg,
                                                valueColor: AlwaysStoppedAnimation(fewestSection == s ? green : blue),
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              fewestSection == s ? 'Fewest' : (trainer ?? 'No trainer'),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: GoogleFonts.poppins(
                                                color: fewestSection == s
                                                    ? green
                                                    : (trainer == null ? secondaryText.withOpacity(.7) : secondaryText),
                                                fontSize: 9,
                                                fontWeight: fewestSection == s ? FontWeight.w800 : FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              );
                            }),
                            if (otherEnglishOn && _hasSection && tempSection.isNotEmpty && tempSection != selectedSection)
                              Container(
                                margin: const EdgeInsets.only(top: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                decoration: BoxDecoration(
                                    color: amber.withOpacity(.15), borderRadius: BorderRadius.circular(10)),
                                child: Row(
                                  children: [
                                    const Icon(Icons.info_outline_rounded, size: 14, color: amberText),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        'The section is the same for all English stages — $_firstName moves to Section $tempSection in every English stage.',
                                        style: GoogleFonts.poppins(color: amberText, fontSize: 9.8, height: 1.35),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            const SizedBox(height: 16),
                          ],

                          // ================= TIMING =================
                          _stepLabel(
                            needsSection ? '2' : '1',
                            'Choose timing',
                            trailing: needsSection && tempSection.isNotEmpty
                                ? Text('in Section $tempSection',
                                    style: GoogleFonts.poppins(
                                        color: secondaryText, fontSize: 10, fontWeight: FontWeight.w600))
                                : null,
                          ),
                          ...BatchSlots.all.map((b) {
                            final usedBy = taken[b.label];
                            final disabled = usedBy != null;
                            final chosen = tempTiming == b.label;
                            final n = countFor(b);
                            final total = _timingCount(load, b.label);
                            final isFewest = fewestTiming == b.label;
                            final sub = !hasLoad
                                ? '…'
                                : (needsSection && tempSection.isNotEmpty)
                                    ? '$n in Section $tempSection • $total in this stage'
                                    : '$n student${n == 1 ? '' : 's'}';
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: disabled
                                    ? null
                                    : () {
                                        HapticFeedback.selectionClick();
                                        setSheet(() => tempTiming = b.label);
                                      },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 140),
                                  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
                                  decoration: BoxDecoration(
                                    color: disabled
                                        ? const Color(0xFFF2F4F6)
                                        : chosen
                                            ? blue.withOpacity(.09)
                                            : subtle,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: chosen ? blue : borderColor, width: chosen ? 1.5 : 1),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 28,
                                        height: 28,
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color: chosen ? blue : cardBg,
                                          shape: BoxShape.circle,
                                          border: Border.all(color: chosen ? blue : borderColor),
                                        ),
                                        child: Text('${b.number}',
                                            style: GoogleFonts.poppins(
                                                color: chosen ? Colors.white : secondaryText,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w800)),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              b.shortLabel,
                                              style: GoogleFonts.poppins(
                                                color: disabled ? secondaryText.withOpacity(.6) : textColor,
                                                fontSize: 12.3,
                                                fontWeight: chosen ? FontWeight.w700 : FontWeight.w600,
                                                decoration: disabled ? TextDecoration.lineThrough : null,
                                              ),
                                            ),
                                            if (!disabled) ...[
                                              const SizedBox(height: 3),
                                              Row(
                                                children: [
                                                  SizedBox(
                                                    width: 54,
                                                    child: ClipRRect(
                                                      borderRadius: BorderRadius.circular(4),
                                                      child: LinearProgressIndicator(
                                                        value: allTimingMax == 0 ? 0 : n / allTimingMax,
                                                        minHeight: 4,
                                                        backgroundColor: cardBg,
                                                        valueColor: AlwaysStoppedAnimation(isFewest ? green : blue),
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 7),
                                                  Flexible(
                                                    child: Text(sub,
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                        style: GoogleFonts.poppins(color: secondaryText, fontSize: 9.5)),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      if (disabled)
                                        Container(
                                          constraints: const BoxConstraints(maxWidth: 120),
                                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                          decoration: BoxDecoration(
                                              color: red.withOpacity(.10), borderRadius: BorderRadius.circular(7)),
                                          child: Text('Used by $usedBy',
                                              maxLines: 2,
                                              style: GoogleFonts.poppins(
                                                  color: red, fontSize: 8.5, fontWeight: FontWeight.w700)),
                                        )
                                      else if (chosen)
                                        const Icon(Icons.check_circle_rounded, color: blue, size: 19)
                                      else if (isFewest)
                                        _fewestBadge(),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ),

                  // ================= FOOTER =================
                  Container(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                    decoration: const BoxDecoration(border: Border(top: BorderSide(color: borderColor))),
                    child: Row(
                      children: [
                        if (wasEnabled)
                          TextButton.icon(
                            onPressed: () {
                              Get.back();
                              _disableStage(isEnglish, key);
                            },
                            icon: const Icon(Icons.block_rounded, size: 15, color: red),
                            label: Text('Turn off',
                                style: GoogleFonts.poppins(color: red, fontSize: 11.5, fontWeight: FontWeight.w700)),
                          ),
                        const Spacer(),
                        TextButton(
                          onPressed: () => Get.back(),
                          child: Text('Cancel',
                              style: GoogleFonts.poppins(color: secondaryText, fontWeight: FontWeight.w600)),
                        ),
                        const SizedBox(width: 6),
                        ElevatedButton.icon(
                          onPressed: !canSave
                              ? null
                              : () {
                                  Get.back();
                                  HapticFeedback.selectionClick();
                                  setState(() {
                                    if (needsSection) selectedSection = tempSection;
                                    accessMap[key] = true;
                                    batchMap[key] = tempTiming;
                                    if (selectedBatch.isEmpty) selectedBatch = tempTiming;
                                  });
                                },
                          icon: Icon(wasEnabled ? Icons.check_rounded : Icons.lock_open_rounded, size: 16),
                          label: Text(wasEnabled ? 'Apply' : 'Enable stage',
                              style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 12)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: navy,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: borderColor,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ));
  }

  // =========================================================
  // SECTION SHEET — change the section for all English stages
  // =========================================================
  void _openSectionSheet() {
    final enabled = stageKeys.where((k) => englishAccess[k] == true).toList();
    String temp = selectedSection;

    _showPanel((ctx) => StatefulBuilder(
          builder: (ctx, setSheet) => ValueListenableBuilder<Map<String, dynamic>?>(
            valueListenable: _load,
            builder: (ctx, data, _) {
              final hasLoad = data != null;
              int totalFor(String s) =>
                  enabled.fold<int>(0, (a, k) => a + _sectionCount(_stageLoad(true, k), s));
              final totals = {for (final s in sections) s: totalFor(s)};
              final mn = totals.values.reduce((a, b) => a < b ? a : b);
              final mx = totals.values.reduce((a, b) => a > b ? a : b);
              final fewest = hasLoad && mx > mn ? sections.firstWhere((s) => totals[s] == mn) : null;

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _panelHeader(
                    icon: Icons.groups_rounded,
                    title: 'Online section',
                    subtitle: 'Used for all of $_firstName\'s English stages',
                  ),
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.fromLTRB(18, 6, 18, 12),
                      itemCount: sections.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 7),
                      itemBuilder: (ctx, i) {
                        final s = sections[i];
                        final chosen = temp == s;
                        return InkWell(
                          borderRadius: BorderRadius.circular(13),
                          onTap: () => setSheet(() => temp = s),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 140),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: chosen ? blue.withOpacity(.09) : subtle,
                              borderRadius: BorderRadius.circular(13),
                              border: Border.all(color: chosen ? blue : borderColor, width: chosen ? 1.5 : 1),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: chosen ? blue : cardBg,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: chosen ? blue : borderColor),
                                  ),
                                  child: Text(s,
                                      style: GoogleFonts.poppins(
                                          color: chosen ? Colors.white : textColor,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 13)),
                                ),
                                const SizedBox(width: 11),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Section $s',
                                          style: GoogleFonts.poppins(
                                              color: textColor, fontSize: 12.5, fontWeight: FontWeight.w700)),
                                      const SizedBox(height: 2),
                                      Text(
                                        !hasLoad
                                            ? 'Loading…'
                                            : enabled.isEmpty
                                                ? 'No English stage enabled yet'
                                                : enabled
                                                    .map((k) =>
                                                        'S${_stageNo(k)}: ${_sectionCount(_stageLoad(true, k), s)}')
                                                    .join('  •  '),
                                        maxLines: 2,
                                        style: GoogleFonts.poppins(color: secondaryText, fontSize: 9.8),
                                      ),
                                    ],
                                  ),
                                ),
                                if (fewest == s) ...[_fewestBadge(), const SizedBox(width: 6)],
                                if (chosen) const Icon(Icons.check_circle_rounded, color: blue, size: 19),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                    decoration: const BoxDecoration(border: Border(top: BorderSide(color: borderColor))),
                    child: Row(
                      children: [
                        const Spacer(),
                        TextButton(
                          onPressed: () => Get.back(),
                          child: Text('Cancel',
                              style: GoogleFonts.poppins(color: secondaryText, fontWeight: FontWeight.w600)),
                        ),
                        const SizedBox(width: 6),
                        ElevatedButton(
                          onPressed: temp.isEmpty
                              ? null
                              : () {
                                  Get.back();
                                  setState(() => selectedSection = temp);
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: navy,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text('Use Section ${temp.isEmpty ? '' : temp}',
                              style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 12)),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ));
  }

  // =========================================================
  // BUILD
  // =========================================================
  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= 1050;
    final isTablet = width >= 700 && width < 1050;
    final pad = isDesktop ? 26.0 : (isTablet ? 20.0 : 14.0);

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _goBackToStudents();
      },
      child: Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: cardBg,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          toolbarHeight: 60,
          leading: IconButton(
            tooltip: 'Back to Students',
            onPressed: _goBackToStudents,
            icon: const Icon(Icons.arrow_back_rounded, color: textColor, size: 22),
          ),
          titleSpacing: 0,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Student control',
                  style: GoogleFonts.poppins(color: textColor, fontSize: isDesktop ? 17 : 15.5, fontWeight: FontWeight.w700)),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(color: _live ? green : secondaryText.withOpacity(.5), shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 5),
                  Text(_live ? 'Live • updates by itself' : 'Mode, stages, section & timing',
                      style: GoogleFonts.poppins(
                          color: _live ? green : secondaryText, fontSize: 9.5, fontWeight: _live ? FontWeight.w600 : FontWeight.w400)),
                ],
              ),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'Attendance report',
              onPressed: () => Get.to(() => AttendanceReportScreen(userId: _userId, name: _studentName, role: 'student')),
              icon: const Icon(Icons.insights_rounded, color: navy),
            ),
            if (isDesktop)
              Padding(padding: const EdgeInsets.only(right: 18, left: 6), child: _saveButton(compact: true)),
          ],
        ),
        bottomNavigationBar: isDesktop ? null : _mobileSaveBar(),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1220),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.fromLTRB(pad, 16, pad, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _pendingBanner(),
                    _buildHero(isDesktop: isDesktop),
                    const SizedBox(height: 14),
                    if (isDesktop)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _buildCourseCard()),
                          const SizedBox(width: 16),
                          SizedBox(
                            width: 390,
                            child: Column(
                              children: [
                                _buildSettingsCard(),
                                const SizedBox(height: 14),
                                _buildAnalyticsCard(),
                              ],
                            ),
                          ),
                        ],
                      )
                    else ...[
                      _buildSettingsCard(),
                      const SizedBox(height: 14),
                      _buildCourseCard(),
                      const SizedBox(height: 14),
                      _buildAnalyticsCard(),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _mobileSaveBar() {
    final dirty = _dirty;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 9, 14, 10),
        decoration: BoxDecoration(
          color: cardBg,
          border: const Border(top: BorderSide(color: borderColor)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(.06), blurRadius: 18, offset: const Offset(0, -5))],
        ),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: dirty ? amber : green, shape: BoxShape.circle),
            ),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                dirty ? 'Unsaved changes' : 'All changes saved',
                style: GoogleFonts.poppins(
                    color: dirty ? amberText : secondaryText, fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ),
            SizedBox(width: 170, child: _saveButton(compact: false)),
          ],
        ),
      ),
    );
  }

  Widget _saveButton({required bool compact}) {
    final dirty = _dirty;
    return SizedBox(
      height: compact ? 40 : 46,
      width: compact ? 168 : double.infinity,
      child: ElevatedButton.icon(
        onPressed: isSaving ? null : _saveAllSettings,
        icon: isSaving
            ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : Icon(dirty ? Icons.save_rounded : Icons.check_rounded, size: 17),
        label: Text(
          isSaving ? 'Saving…' : (dirty ? 'Save changes' : 'Saved'),
          style: GoogleFonts.poppins(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: dirty ? navy : green,
          foregroundColor: Colors.white,
          disabledBackgroundColor: navy.withOpacity(.65),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  // =========================================================
  // HERO
  // =========================================================
  Widget _buildHero({required bool isDesktop}) {
    final initial = _studentName.trim().isNotEmpty ? _studentName.trim()[0].toUpperCase() : 'S';
    final phone = (_user['phone'] ?? widget.user['phone'] ?? 'No phone').toString();
    final isPaid = selectedFeeStatus == 'paid';
    final enCount = stageKeys.where((k) => englishAccess[k] == true).length;
    final hiCount = stageKeys.where((k) => hindiAccess[k] == true).length;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isDesktop ? 20 : 15),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0E466D), Color(0xFF155A88), Color(0xFF2C6F9F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: isDesktop ? 58 : 50,
            height: isDesktop ? 58 : 50,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(.13),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(.22)),
            ),
            alignment: Alignment.center,
            child: Text(initial,
                style: GoogleFonts.poppins(
                    color: Colors.white, fontSize: isDesktop ? 23 : 20, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(_studentName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                              color: Colors.white, fontSize: isDesktop ? 18 : 16, fontWeight: FontWeight.w700)),
                    ),
                    if (!isDesktop) ...[
                      const SizedBox(width: 8),
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(color: regularityColor, shape: BoxShape.circle),
                      ),
                    ],
                  ],
                ),
                InkWell(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: phone));
                    _snack('Copied', phone, navy, icon: Icons.copy_rounded);
                  },
                  child: Text(phone, style: GoogleFonts.poppins(color: Colors.white.withOpacity(.72), fontSize: 10.5)),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 5,
                  children: [
                    _heroChip(_isOnline ? Icons.wifi_rounded : Icons.location_on_rounded, _isOnline ? 'Online' : 'Offline'),
                    if (_isOnline && _hasSection && enCount > 0) _heroChip(Icons.groups_rounded, 'Section $selectedSection'),
                    if (enCount > 0) _heroChip(Icons.translate_rounded, 'English $enCount/7'),
                    if (hiCount > 0) _heroChip(Icons.language_rounded, 'Hindi $hiCount/7'),
                    _heroChip(isPaid ? Icons.verified_rounded : Icons.error_outline_rounded, isPaid ? 'Paid' : 'Unpaid'),
                  ],
                ),
              ],
            ),
          ),
          if (isDesktop) ...[
            const SizedBox(width: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(.10),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withOpacity(.20)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 7, height: 7, decoration: BoxDecoration(color: regularityColor, shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  Text(regularityStatus,
                      style: GoogleFonts.poppins(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _heroChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: const Color(0xFFF7DF55)),
          const SizedBox(width: 4),
          Text(label, style: GoogleFonts.poppins(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  // =========================================================
  // CARD SHELL
  // =========================================================
  Widget _card({
    required String title,
    String? subtitle,
    required IconData icon,
    Color accent = navy,
    Widget? trailing,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(color: accent.withOpacity(.09), borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: accent, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: GoogleFonts.poppins(color: textColor, fontSize: 13.5, fontWeight: FontWeight.w700)),
                    if (subtitle != null)
                      Text(subtitle, style: GoogleFonts.poppins(color: secondaryText, fontSize: 9.8, height: 1.3)),
                  ],
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  // =========================================================
  // SETTINGS (mode, section)
  // =========================================================
  Widget _buildSettingsCard() {
    final hasEnglish = _anyOn(englishAccess);
    return _card(
      title: 'Learning mode',
      subtitle: _isOnline ? 'Live audio classes in the app' : 'Classes at the centre • GPS check-in',
      icon: Icons.tune_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _segmented([
            _segItem('Online', Icons.wifi_rounded, _isOnline, blue, () {
              HapticFeedback.selectionClick();
              setState(() => selectedMode = 'online');
            }),
            _segItem('Offline', Icons.location_on_rounded, !_isOnline, offlineColor, () {
              HapticFeedback.selectionClick();
              setState(() => selectedMode = 'offline');
            }),
          ]),
          const SizedBox(height: 12),

          // ---- section (online only) ----
          if (_isOnline)
            _infoRow(
              icon: Icons.groups_rounded,
              color: hasEnglish && !_hasSection ? amberText : blue,
              title: !hasEnglish
                  ? 'Section'
                  : _hasSection
                      ? 'Section $selectedSection'
                      : 'No section yet',
              subtitle: !hasEnglish
                  ? 'Chosen when you enable an English stage'
                  : 'Same section for all English stages',
              action: hasEnglish ? (_hasSection ? 'Change' : 'Choose') : null,
              onTap: hasEnglish ? _openSectionSheet : null,
            )
          else
            _infoRow(
              icon: Icons.info_outline_rounded,
              color: offlineColor,
              title: 'No sections offline',
              subtitle: 'Offline students only need a timing per stage',
            ),
        ],
      ),
    );
  }

  Widget _infoRow({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    String? action,
    VoidCallback? onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
        decoration: BoxDecoration(
          color: color.withOpacity(.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(.18)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GoogleFonts.poppins(color: textColor, fontSize: 11.5, fontWeight: FontWeight.w700)),
                  Text(subtitle, style: GoogleFonts.poppins(color: secondaryText, fontSize: 9.5)),
                ],
              ),
            ),
            if (action != null)
              Text(action, style: GoogleFonts.poppins(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }

  Widget _segmented(List<Widget> items) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: subtle,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          for (int i = 0; i < items.length; i++) ...[
            Expanded(child: items[i]),
            if (i != items.length - 1) const SizedBox(width: 3),
          ],
        ],
      ),
    );
  }

  Widget _segItem(String title, IconData icon, bool selected, Color color, VoidCallback onTap, {String? badge}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
          decoration: BoxDecoration(
            color: selected ? color : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 15, color: selected ? Colors.white : secondaryText),
              const SizedBox(width: 6),
              Flexible(
                child: Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                        color: selected ? Colors.white : secondaryText, fontSize: 11, fontWeight: FontWeight.w700)),
              ),
              if (badge != null) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: selected ? Colors.white.withOpacity(.22) : borderColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(badge,
                      style: GoogleFonts.poppins(
                          color: selected ? Colors.white : secondaryText, fontSize: 9, fontWeight: FontWeight.w700)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // =========================================================
  // COURSE ACCESS
  // =========================================================
  Widget _buildCourseCard() {
    final isEnglish = !showHindi;
    final access = isEnglish ? englishAccess : hindiAccess;
    final enCount = stageKeys.where((k) => englishAccess[k] == true).length;
    final hiCount = stageKeys.where((k) => hindiAccess[k] == true).length;
    final anyOn = _anyOn(access);

    return _card(
      title: 'Course access',
      subtitle: _isOnline
          ? 'Tap a stage to enable it and pick its section and timing'
          : 'Tap a stage to enable it and pick its timing',
      icon: Icons.school_rounded,
      trailing: IconButton(
        tooltip: 'Refresh student counts',
        onPressed: loadingLoad ? null : _fetchClassLoad,
        icon: loadingLoad
            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: blue))
            : const Icon(Icons.refresh_rounded, color: secondaryText, size: 20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _segmented([
            _segItem('English', Icons.translate_rounded, isEnglish, navy, () => setState(() => showHindi = false),
                badge: '$enCount/7'),
            _segItem('Hindi', Icons.language_rounded, !isEnglish, blue, () => setState(() => showHindi = true),
                badge: '$hiCount/7'),
          ]),
          if (isEnglish && _isOnline && enCount > 0 && !_hasSection) ...[
            const SizedBox(height: 10),
            _infoRow(
              icon: Icons.warning_amber_rounded,
              color: amberText,
              title: 'Choose a section',
              subtitle: 'Online English classes need a section (A–E)',
              action: 'Choose',
              onTap: _openSectionSheet,
            ),
          ],
          const SizedBox(height: 12),
          LayoutBuilder(builder: (ctx, c) {
            final twoCols = c.maxWidth >= 640;
            final tiles = stageKeys.map((k) => _stageTile(isEnglish, k)).toList();
            if (!twoCols) {
              return Column(
                children: [
                  for (int i = 0; i < tiles.length; i++) ...[
                    tiles[i],
                    if (i != tiles.length - 1) const SizedBox(height: 8),
                  ],
                ],
              );
            }
            final w = (c.maxWidth - 10) / 2;
            return Wrap(
              spacing: 10,
              runSpacing: 8,
              children: tiles.map((t) => SizedBox(width: w, child: t)).toList(),
            );
          }),
          if (anyOn) ...[
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _turnAllOff(isEnglish),
                icon: const Icon(Icons.block_rounded, size: 14, color: red),
                label: Text('Turn off all ${isEnglish ? 'English' : 'Hindi'} stages',
                    style: GoogleFonts.poppins(color: red, fontSize: 10.5, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _stageTile(bool isEnglish, String key) {
    final access = isEnglish ? englishAccess : hindiAccess;
    final batchMap = isEnglish ? englishBatch : hindiBatch;
    final on = access[key] == true;
    final accent = isEnglish ? navy : blue;
    final no = _stageNo(key);

    if (!on) {
      return InkWell(
        borderRadius: BorderRadius.circular(13),
        onTap: () => _openStageSheet(isEnglish: isEnglish, key: key),
        child: Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: subtle.withOpacity(.6),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            children: [
              _stageBadge(no, false, accent),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Stage $no',
                        style: GoogleFonts.poppins(color: textColor, fontSize: 12, fontWeight: FontWeight.w700)),
                    Text('Locked', style: GoogleFonts.poppins(color: secondaryText, fontSize: 9.5)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: accent.withOpacity(.30)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_rounded, size: 14, color: accent),
                    const SizedBox(width: 3),
                    Text('Enable', style: GoogleFonts.poppins(color: accent, fontSize: 10, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    final load = _stageLoad(isEnglish, key);
    final hasLoad = load != null;
    final timing = _stageTiming(isEnglish, key);
    final ownTiming = (batchMap[key] ?? '').isNotEmpty;
    final needsSection = _needsSection(isEnglish);

    // counts INCLUDING this student
    final secN = needsSection && _hasSection ? _sectionCount(load, selectedSection) + 1 : 0;
    final classN = timing.isEmpty
        ? 0
        : (needsSection && _hasSection ? _classCount(load, selectedSection, timing) : _timingCount(load, timing)) + 1;
    final trainer = needsSection && _hasSection ? _trainerFor(isEnglish, key, selectedSection) : _trainerFor(isEnglish, key, 'all');

    return InkWell(
      borderRadius: BorderRadius.circular(13),
      onTap: () => _openStageSheet(isEnglish: isEnglish, key: key),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
        decoration: BoxDecoration(
          color: accent.withOpacity(.05),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: accent.withOpacity(.28)),
        ),
        child: Row(
          children: [
            _stageBadge(no, true, accent),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('Stage $no',
                          style: GoogleFonts.poppins(color: textColor, fontSize: 12, fontWeight: FontWeight.w700)),
                      if (trainer != null) ...[
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text('• $trainer',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(color: secondaryText, fontSize: 9.5)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 5),
                  Wrap(
                    spacing: 6,
                    runSpacing: 5,
                    children: [
                      if (needsSection)
                        _hasSection
                            ? _pill(Icons.groups_rounded, 'Section $selectedSection',
                                hasLoad ? '$secN student${secN == 1 ? '' : 's'}' : null, accent)
                            : _pill(Icons.warning_amber_rounded, 'No section', null, amberText),
                      timing.isEmpty
                          ? _pill(Icons.schedule_rounded, 'Set timing', null, amberText)
                          : _pill(
                              Icons.schedule_rounded,
                              BatchSlots.shortOf(timing) + (ownTiming ? '' : ' (signup)'),
                              hasLoad ? '$classN in class' : null,
                              ownTiming ? accent : amberText,
                            ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: secondaryText),
          ],
        ),
      ),
    );
  }

  Widget _stageBadge(String no, bool on, Color accent) => Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: on ? accent : cardBg,
          shape: BoxShape.circle,
          border: Border.all(color: on ? accent : borderColor),
        ),
        child: on
            ? const Icon(Icons.check_rounded, color: Colors.white, size: 17)
            : Text(no.padLeft(2, '0'),
                style: GoogleFonts.poppins(color: secondaryText, fontSize: 10, fontWeight: FontWeight.w700)),
      );

  Widget _pill(IconData icon, String label, String? count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(color: color.withOpacity(.10), borderRadius: BorderRadius.circular(7)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(label, style: GoogleFonts.poppins(color: color, fontSize: 9.5, fontWeight: FontWeight.w700)),
          if (count != null) ...[
            Text('  •  ', style: GoogleFonts.poppins(color: color.withOpacity(.5), fontSize: 9)),
            Text(count, style: GoogleFonts.poppins(color: color.withOpacity(.85), fontSize: 9.5, fontWeight: FontWeight.w500)),
          ],
        ],
      ),
    );
  }

  // =========================================================
  // LEARNING OVERVIEW
  // =========================================================
  Widget _buildAnalyticsCard() {
    return _card(
      title: 'Learning overview',
      subtitle: regularityStatus,
      icon: Icons.insights_rounded,
      accent: blue,
      child: Column(
        children: [
          LayoutBuilder(builder: (context, constraints) {
            final cards = [
              _statCard('Sessions', '$totalLoggedSessions', navy, Icons.event_available_rounded),
              _statCard('Learning time', '${(totalMinutesSpent / 60).toStringAsFixed(1)}h', blue, Icons.schedule_rounded),
              _statCard('Attendance', '${attendanceRate.toStringAsFixed(0)}%', green, Icons.check_circle_outline_rounded),
              _statCard('Avg. test', '${averageTestScore.toStringAsFixed(0)}%', offlineColor, Icons.assessment_rounded),
            ];
            if (constraints.maxWidth < 620) {
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: cards.map((c) => SizedBox(width: (constraints.maxWidth - 8) / 2, child: c)).toList(),
              );
            }
            return Row(
              children: [
                for (int i = 0; i < cards.length; i++) ...[
                  Expanded(child: cards[i]),
                  if (i != cards.length - 1) const SizedBox(width: 8),
                ],
              ],
            );
          }),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Text('Test performance by stage',
                    style: GoogleFonts.poppins(color: textColor, fontSize: 11.5, fontWeight: FontWeight.w700)),
              ),
              if (isLoadingAnalytics)
                const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: blue, strokeWidth: 2)),
            ],
          ),
          const SizedBox(height: 8),
          _buildPerformanceChart(),
        ],
      ),
    );
  }

  Widget _statCard(String label, String value, Color color, IconData icon) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(.16)),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(color: color.withOpacity(.10), borderRadius: BorderRadius.circular(9)),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(color: color, fontSize: 15, fontWeight: FontWeight.w700)),
                Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(color: secondaryText, fontSize: 8.8)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceChart() {
    if (isLoadingAnalytics) {
      return Container(
        height: 100,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: subtle, borderRadius: BorderRadius.circular(12)),
        child: const CircularProgressIndicator(color: blue, strokeWidth: 2),
      );
    }

    if (studentTestResults.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
        decoration: BoxDecoration(
          color: subtle,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            const Icon(Icons.bar_chart_rounded, color: blue, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text('No test results yet. Stage scores appear after a test.',
                  style: GoogleFonts.poppins(color: secondaryText, fontSize: 10)),
            ),
          ],
        ),
      );
    }

    return Container(
      height: 140,
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      decoration: BoxDecoration(
        color: subtle,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: studentTestResults.length,
        separatorBuilder: (_, __) => const SizedBox(width: 13),
        itemBuilder: (context, index) {
          final result = studentTestResults[index];
          final stage = (result['stage'] ?? 'S1').toString().toUpperCase();
          final language = (result['language'] ?? 'English').toString();
          final score = (result['score'] as num? ?? 0).toInt();
          final total = (result['totalQuestions'] as num? ?? 1).toInt();
          final pct = total > 0 ? (score / total).clamp(0.0, 1.0).toDouble() : 0.0;
          final barColor = pct >= .5 ? green : red;

          return SizedBox(
            width: 42,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text('${(pct * 100).toStringAsFixed(0)}%',
                    style: GoogleFonts.poppins(color: barColor, fontSize: 9, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Expanded(
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      width: 24,
                      height: 70,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(7),
                        border: Border.all(color: borderColor),
                      ),
                      alignment: Alignment.bottomCenter,
                      child: FractionallySizedBox(
                        widthFactor: 1,
                        heightFactor: pct.clamp(.08, 1.0).toDouble(),
                        alignment: Alignment.bottomCenter,
                        child: Container(
                          decoration: BoxDecoration(color: barColor, borderRadius: BorderRadius.circular(6)),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 5),
                Text(stage, style: GoogleFonts.poppins(color: textColor, fontSize: 8.5, fontWeight: FontWeight.w700)),
                Text(language.isNotEmpty ? language[0] : 'E',
                    style: GoogleFonts.poppins(color: secondaryText, fontSize: 7.5)),
              ],
            ),
          );
        },
      ),
    );
  }
}