// =========================================================================
// ✍️ TRAINER TESTS (admin) — trainer writes → admin approves → admin releases
//
//   Tabs: Waiting • Approved • Sent back • Live
//   Open a test → read every question (correct answer in green) →
//     "Send back" (with a note) / "Approve" / "Release to students"
//   Release = becomes the live test of that language + stage
//   (replaces the old one; old results stay saved).
// =========================================================================
import 'package:lets_speake_manager/Api/admin_badges.dart';
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:lets_speake_manager/Api/ApiendPoints.dart';
import 'package:lets_speake_manager/Api/api_headers.dart';
import 'package:lets_speake_manager/Navigation/AdminShellNavigation.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

const Color _text = Color(0xFF173A52);
const Color _secondary = Color(0xFF6B8496);
const Color _border = Color(0xFFD5E5EE);
const Color _bg = Color(0xFFF5FAFD);
const Color _navy = Color(0xFF0A4A75);
const Color _green = Color(0xFF16A66A);
const Color _red = Color(0xFFE45757);
const Color _amber = Color(0xFFE59E1B);
const Color _purple = Color(0xFF7A5AF8);

String _api(String path) => '${ApiEndpoints.baseUrl}/test$path';
String _stageLabel(String s) => s.replaceAll('stage', 'Stage ');

String _date(String? iso) {
  final d = DateTime.tryParse(iso ?? '')?.toLocal();
  if (d == null) return '';
  const m = [
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
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  return '${d.day} ${m[d.month - 1]}, $h:${d.minute.toString().padLeft(2, '0')} ${d.hour < 12 ? 'AM' : 'PM'}';
}

const _tabs = [
  ('pending', 'Waiting', _amber),
  ('approved', 'Approved', _purple),
  ('rejected', 'Sent back', _red),
  ('released', 'Live', _green),
];

class AdminTestDraftsScreen extends StatefulWidget {
  final bool embedded;
  const AdminTestDraftsScreen({super.key, this.embedded = false});

  @override
  State<AdminTestDraftsScreen> createState() => _AdminTestDraftsScreenState();
}

class _AdminTestDraftsScreenState extends State<AdminTestDraftsScreen>
    with WidgetsBindingObserver {
  String _status = 'pending';
  bool _loading = true;
  List<Map<String, dynamic>> _drafts = [];
  Map<String, dynamic> _counts = {};
  IO.Socket? _socket;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    _listenLive();
    // safety net: refresh every 30 s even if the live connection drops
    _poll = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _load(quiet: true),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _poll?.cancel();
    _socket?.clearListeners();
    _socket?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load(quiet: true);
  }

  /// ⚡ A trainer sends a test → it appears here at once (no refresh)
  void _listenLive() {
    try {
      final uri = Uri.parse(ApiEndpoints.baseUrl);
      _socket = IO.io(
        '${uri.scheme}://${uri.host}:${uri.port}',
        <String, dynamic>{
          'transports': ['websocket'],
          'autoConnect': true,
          'forceNew': true,
          'auth': {'token': ApiHeaders.token ?? ''},
        },
      );
      _socket?.onConnect((_) {
        _socket?.emit('join_admin_room');
        _load(quiet: true);
      });
      _socket?.onReconnect((_) => _socket?.emit('join_admin_room'));
      _socket?.on('test_draft_new', (data) {
        if (!mounted) return;
        _load(quiet: true);
        final who = data is Map
            ? (data['createdByName'] ?? 'A trainer').toString()
            : 'A trainer';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('📝 $who sent a test for approval'),
            backgroundColor: _purple,
            duration: const Duration(seconds: 3),
          ),
        );
      });
      _socket?.on('test_draft_updated', (_) {
        if (mounted) _load(quiet: true);
      });
    } catch (e) {
      debugPrint('Trainer tests live updates off: $e');
    }
  }

  Future<void> _load({bool quiet = false}) async {
    if (!mounted) return;
    if (!quiet) setState(() => _loading = true);
    try {
      final res = await http
          .get(
            Uri.parse(
              _api(
                '/admin/test-drafts?status=$_status&_t=${DateTime.now().millisecondsSinceEpoch}',
              ),
            ),
            headers: ApiHeaders.auth(),
          )
          .timeout(const Duration(seconds: 20));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        _drafts = ((data['drafts'] ?? []) as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        if (data['counts'] is Map)
          _counts = Map<String, dynamic>.from(data['counts']);
      }
    } catch (e) {
      debugPrint('Trainer tests load error: $e');
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _open(Map<String, dynamic> d) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AdminTestDraftDetailScreen(id: d['_id'].toString()),
      ),
    );
    if (changed == true) _load();
  }

  @override
  Widget build(BuildContext context) {
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
                icon: AdminMenuIcon(Icons.menu_rounded),
                onPressed: AdminShellNavigation.openDrawer,
              )
            : null,
        title: Text(
          'Trainer tests',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w800,
            fontSize: 17,
            color: _text,
          ),
        ),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _tabs.map((t) {
                  final sel = _status == t.$1;
                  final n = _counts[t.$1] ?? 0;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      selected: sel,
                      showCheckmark: false,
                      label: Text('${t.$2}  $n'),
                      labelStyle: GoogleFonts.poppins(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: sel ? Colors.white : _text,
                      ),
                      selectedColor: t.$3,
                      backgroundColor: _bg,
                      side: BorderSide(
                        color: sel ? Colors.transparent : _border,
                      ),
                      onSelected: (_) {
                        _status = t.$1;
                        _load();
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _drafts.isEmpty
                  ? ListView(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(50),
                          child: Text(
                            _status == 'pending'
                                ? 'No trainer tests waiting. 🎉'
                                : 'Nothing here.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(color: _secondary),
                          ),
                        ),
                      ],
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 30),
                      children: _drafts.map(_card).toList(),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _card(Map<String, dynamic> d) {
    final title = (d['title'] ?? '').toString();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: ListTile(
        onTap: () => _open(d),
        contentPadding: const EdgeInsets.fromLTRB(14, 6, 10, 6),
        title: Text(
          title.isEmpty
              ? '${d['language']} ${_stageLabel(d['stage'].toString())} test'
              : title,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w700,
            fontSize: 14,
            color: _text,
          ),
        ),
        subtitle: Text(
          '${d['language']} • ${_stageLabel(d['stage'].toString())} • ${d['questionCount'] ?? 0} questions • ${d['durationMinutes'] ?? 25} min\n'
          'By ${d['createdByName'] ?? 'trainer'} • ${_date(d['updatedAt']?.toString())}',
          style: GoogleFonts.poppins(
            fontSize: 11.5,
            color: _secondary,
            height: 1.4,
          ),
        ),
        trailing: const Icon(Icons.chevron_right_rounded, color: _secondary),
      ),
    );
  }
}

// =========================================================================
// DETAIL
// =========================================================================
class AdminTestDraftDetailScreen extends StatefulWidget {
  final String id;
  const AdminTestDraftDetailScreen({super.key, required this.id});

  @override
  State<AdminTestDraftDetailScreen> createState() =>
      _AdminTestDraftDetailScreenState();
}

class _AdminTestDraftDetailScreenState
    extends State<AdminTestDraftDetailScreen> {
  Map<String, dynamic>? _d;
  bool _loading = true;
  bool _busy = false;
  final Set<int> _removed = {}; // admin can drop bad questions before approving

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await http
          .get(
            Uri.parse(_api('/admin/test-draft?id=${widget.id}')),
            headers: ApiHeaders.auth(),
          )
          .timeout(const Duration(seconds: 20));
      if (res.statusCode == 200) {
        _d = Map<String, dynamic>.from(jsonDecode(res.body)['draft']);
      }
    } catch (e) {
      debugPrint('Draft load error: $e');
    }
    if (mounted) setState(() => _loading = false);
  }

  List get _questions => (_d?['questions'] as List?) ?? const [];

  Future<void> _act(String action) async {
    final d = _d!;
    String note = '';
    if (action == 'reject') {
      final ctrl = TextEditingController();
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => _lightDialog(
          ctx,
          icon: Icons.undo_rounded,
          color: _red,
          title: 'Send back to trainer',
          message:
              'The trainer sees your note, fixes the test and sends it again.',
          confirm: 'Send back',
          extra: TextField(
            controller: ctrl,
            maxLines: 3,
            maxLength: 500,
            autofocus: true,
            style: GoogleFonts.poppins(fontSize: 13, color: _text),
            cursorColor: _red,
            decoration: InputDecoration(
              hintText:
                  'What should the trainer fix? e.g. "Q3 has two correct answers"',
              hintStyle: GoogleFonts.poppins(fontSize: 12, color: _secondary),
              filled: true,
              fillColor: _bg,
              contentPadding: const EdgeInsets.all(12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _red),
              ),
            ),
          ),
        ),
      );
      note = ctrl.text.trim();
      ctrl.dispose();
      if (ok != true) return;
    } else if (action == 'release') {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => _lightDialog(
          ctx,
          icon: Icons.rocket_launch_rounded,
          color: _green,
          title: 'Release to students?',
          message:
              'This becomes the LIVE test for ${d['language']} ${_stageLabel(d['stage'].toString())}.',
          confirm: 'Release',
          extra: Column(
            children: [
              _point(
                Icons.swap_horiz_rounded,
                'It replaces the current test of that stage.',
              ),
              _point(Icons.history_rounded, 'Old results stay saved.'),
              _point(
                Icons.notifications_active_rounded,
                'Students of that stage can take it now.',
              ),
            ],
          ),
        ),
      );
      if (ok != true) return;
    }

    final keep = <dynamic>[];
    for (var i = 0; i < _questions.length; i++) {
      if (!_removed.contains(i)) keep.add(_questions[i]);
    }
    if (keep.isEmpty) {
      _snack('Keep at least one question', false);
      return;
    }

    setState(() => _busy = true);
    try {
      final res = await http
          .post(
            Uri.parse(_api('/admin/test-draft/review')),
            headers: ApiHeaders.json(),
            body: jsonEncode({
              'id': widget.id,
              'action': action,
              'note': note,
              if (_removed.isNotEmpty) 'questions': keep,
            }),
          )
          .timeout(const Duration(seconds: 25));
      final msg = (jsonDecode(res.body)['message'] ?? '').toString();
      if (!mounted) return;
      _snack(msg.isEmpty ? 'Done' : msg, res.statusCode == 200);
      if (res.statusCode == 200) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) _snack('No internet / server not reachable', false);
    }
    if (mounted) setState(() => _busy = false);
  }

  void _snack(String m, bool ok) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(m), backgroundColor: ok ? _green : _red),
  );

  /// ☀️ Light dialog (always white, even when the app theme is dark)
  Widget _lightDialog(
    BuildContext ctx, {
    required IconData icon,
    required Color color,
    required String title,
    required String message,
    required String confirm,
    Widget? extra,
  }) {
    return AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titlePadding: const EdgeInsets.fromLTRB(22, 22, 22, 6),
      contentPadding: const EdgeInsets.fromLTRB(22, 6, 22, 4),
      actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      title: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withOpacity(.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: _text,
              ),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: _secondary,
                height: 1.45,
              ),
            ),
            if (extra != null) ...[const SizedBox(height: 12), extra],
          ],
        ),
      ),
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
            backgroundColor: color,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Text(
            confirm,
            style: GoogleFonts.poppins(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }

  Widget _point(IconData icon, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      children: [
        Icon(icon, size: 16, color: _green),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.poppins(fontSize: 12.5, color: _text),
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final d = _d;
    final status = (d?['status'] ?? '').toString();
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: _text,
        surfaceTintColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: _text),
        title: Text(
          'Check test',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w800,
            fontSize: 17,
            color: _text,
          ),
        ),
      ),
      bottomNavigationBar: d == null || status == 'released'
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _busy ? null : () => _act('reject'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          side: const BorderSide(color: _red),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Send back',
                          style: GoogleFonts.poppins(
                            color: _red,
                            fontWeight: FontWeight.w700,
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (status != 'approved') ...[
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _busy ? null : () => _act('approve'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                            side: const BorderSide(color: _purple),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'Approve',
                            style: GoogleFonts.poppins(
                              color: _purple,
                              fontWeight: FontWeight.w700,
                              fontSize: 12.5,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: _busy ? null : () => _act('release'),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          backgroundColor: _green,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _busy
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                status == 'approved'
                                    ? 'Release to students'
                                    : 'Approve & release',
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12.5,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : d == null
          ? Center(
              child: Text(
                'Could not load this test',
                style: GoogleFonts.poppins(color: _secondary),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 30),
              children: [
                Container(
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
                        (d['title'] ?? '').toString().isEmpty
                            ? '${d['language']} ${_stageLabel(d['stage'].toString())} test'
                            : d['title'].toString(),
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: _text,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${d['language']} • ${_stageLabel(d['stage'].toString())} • ${_questions.length} questions • ${d['durationMinutes']} min',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: _secondary,
                        ),
                      ),
                      Text(
                        'Written by ${d['createdByName'] ?? 'trainer'} • ${_date(d['updatedAt']?.toString())}',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: _secondary,
                        ),
                      ),
                      if ((d['reviewNote'] ?? '').toString().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            'Last note: ${d['reviewNote']}',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: _text,
                            ),
                          ),
                        ),
                      if (status != 'released')
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            'Tip: tap 🗑 on a bad question to leave it out.',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: _secondary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                for (var i = 0; i < _questions.length; i++)
                  _question(i, status != 'released'),
              ],
            ),
    );
  }

  Widget _question(int i, bool editable) {
    final q = _questions[i] as Map;
    final opts = (q['options'] as List?) ?? const [];
    final correct = int.tryParse('${q['correctOptionIndex'] ?? 0}') ?? 0;
    final removed = _removed.contains(i);
    const letters = ['A', 'B', 'C', 'D', 'E', 'F'];
    return Opacity(
      opacity: removed ? .4 : 1,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.fromLTRB(14, 10, 6, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: removed ? _red : _border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      '${i + 1}. ${q['questionText']}',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                        color: _text,
                      ),
                    ),
                  ),
                ),
                if (editable)
                  IconButton(
                    tooltip: removed ? 'Keep' : 'Leave out',
                    onPressed: () => setState(
                      () => removed ? _removed.remove(i) : _removed.add(i),
                    ),
                    icon: Icon(
                      removed
                          ? Icons.undo_rounded
                          : Icons.delete_outline_rounded,
                      color: removed ? _navy : Colors.black38,
                      size: 20,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            for (var k = 0; k < opts.length; k++)
              Container(
                margin: const EdgeInsets.only(top: 5, right: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: k == correct ? _green.withOpacity(.1) : _bg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: k == correct ? _green : Colors.transparent,
                  ),
                ),
                child: Row(
                  children: [
                    Text(
                      '${k < letters.length ? letters[k] : k + 1}. ',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w700,
                        color: k == correct ? _green : _secondary,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        opts[k].toString(),
                        style: GoogleFonts.poppins(
                          fontSize: 12.5,
                          color: _text,
                        ),
                      ),
                    ),
                    if (k == correct)
                      const Icon(
                        Icons.check_circle_rounded,
                        color: _green,
                        size: 18,
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
