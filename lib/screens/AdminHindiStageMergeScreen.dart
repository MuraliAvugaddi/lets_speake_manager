import 'dart:async';
import 'package:lets_speake_manager/Api/admin_badges.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:get/get.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:lets_speake_manager/Api/ApiendPoints.dart';
import 'package:lets_speake_manager/Api/api_headers.dart';
import 'package:lets_speake_manager/Navigation/AdminShellNavigation.dart';

/// 🔀 Temporary HINDI STAGE merge (Hindi has no sections → stages are merged).
///
/// Example: Hindi Stage 2's trainer is absent → merge Stage 2 into Stage 1.
///  • Stage 2 students join Stage 1's class — students already in class are moved automatically.
///  • Stage 1's trainer sees them (tagged "Stage 2") and does practice + rating.
///  • Attendance and practice stay saved under Stage 2.
///  • Many stages can join one class: Stage 2 … 7 → Stage 1 (all 7 at a time).
///  • Unmerge here (or Stage 2's trainer taps "I'm back") → students go back to Stage 2.
class AdminHindiStageMergeScreen extends StatefulWidget {
  const AdminHindiStageMergeScreen({super.key});

  @override
  State<AdminHindiStageMergeScreen> createState() => _AdminHindiStageMergeScreenState();
}

class _AdminHindiStageMergeScreenState extends State<AdminHindiStageMergeScreen> {
  // ============================================================
  // COLORS (same family as Section Merge)
  // ============================================================
  static const Color primary = Color(0xFF0F5A87);
  static const Color teal = Color(0xFF28C2C2);
  static const Color background = Color(0xFFEAF4FA);
  static const Color textPrimary = Color(0xFF173E5C);
  static const Color textSecondary = Color(0xFF6A8295);
  static const Color borderColor = Color(0xFFD7E7F0);
  static const Color successColor = Color(0xFF16A34A);
  static const Color dangerColor = Color(0xFFDC2626);
  static const Color warningColor = Color(0xFFD97706);
  static const Color guestColor = Color(0xFF7A5AF8);

  static const List<String> stages = ['stage1', 'stage2', 'stage3', 'stage4', 'stage5', 'stage6', 'stage7'];

  // ============================================================
  // STATE
  // ============================================================
  bool isLoading = false;
  bool isSubmitting = false;
  final Set<String> _cancelling = <String>{};
  List<Map<String, dynamic>> activeMerges = [];

  String? hostStage = 'stage1';
  final Set<String> guestStages = <String>{};

  IO.Socket? _socket;
  Timer? _liveDebounce;
  bool _live = false;

  @override
  void initState() {
    super.initState();
    fetchMerges();
    _connectSocket();
  }

  @override
  void dispose() {
    _liveDebounce?.cancel();
    try {
      _socket?.clearListeners();
      _socket?.dispose();
    } catch (_) {}
    super.dispose();
  }

  // ⚡ LIVE — another admin / a trainer ("I'm back") changes a merge
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
      s.onReconnect((_) => fetchMerges(silent: true));
      s.onDisconnect((_) {
        if (mounted) setState(() => _live = false);
      });
      s.on('merge_updated', (data) {
        if (data is Map && (data['language'] ?? '').toString() != 'Hindi') return;
        _liveDebounce?.cancel();
        _liveDebounce = Timer(const Duration(milliseconds: 400), () => fetchMerges(silent: true));
      });
      _socket = s;
    } catch (e) {
      debugPrint('Hindi merge socket error: $e');
    }
  }

  // ============================================================
  // DATA
  // ============================================================
  Future<void> fetchMerges({bool silent = false}) async {
    if (!mounted) return;
    if (!silent) setState(() => isLoading = true);
    try {
      final response = await http.get(
        Uri.parse('${ApiEndpoints.hindiStageMerges}?_t=${DateTime.now().millisecondsSinceEpoch}'),
        headers: ApiHeaders.auth(),
      );
      if (!mounted) return;
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final list = (data['merges'] as List? ?? [])
            .whereType<Map>()
            .map((m) => Map<String, dynamic>.from(m))
            .toList();
        setState(() {
          activeMerges = list;
          _cleanSelection();
        });
      } else if (!silent) {
        _snack('Unable to load', _errorOf(response, 'Could not load Hindi merges.'), warningColor);
      }
    } catch (e) {
      debugPrint('Fetch Hindi merges error: $e');
      if (mounted && !silent) _snack('Connection error', 'Unable to connect to the server.', dangerColor);
    } finally {
      if (mounted && !silent) setState(() => isLoading = false);
    }
  }

  String _errorOf(http.Response r, String fallback) {
    try {
      final d = jsonDecode(r.body);
      if (d is Map && d['message'] != null) return d['message'].toString();
    } catch (_) {}
    return fallback;
  }

  String _name(String s) => s.replaceFirst('stage', 'Stage ');

  /// stage already joined to another stage → its host ("stage1")
  String? _mergedInto(String st) =>
      activeMerges.firstWhereOrNull((m) => m['guestStage']?.toString() == st)?['hostStage']?.toString();

  /// stages joined INTO this stage
  List<String> _guestsOf(String st) => activeMerges
      .where((m) => m['hostStage']?.toString() == st)
      .map((m) => m['guestStage'].toString())
      .toList();

  /// why this stage can't be the main class (null = OK)
  String? _hostBlock(String st) {
    final into = _mergedInto(st);
    return into == null ? null : 'In ${_name(into)}';
  }

  /// why this stage can't join the chosen main class (null = OK)
  String? _guestBlock(String st) {
    if (st == hostStage) return 'Main';
    final into = _mergedInto(st);
    if (into != null) return into == hostStage ? 'Joined' : 'In ${_name(into)}';
    if (_guestsOf(st).isNotEmpty) return 'Hosting';
    return null;
  }

  void _cleanSelection() {
    if (hostStage != null && _hostBlock(hostStage!) != null) hostStage = null;
    guestStages.removeWhere((g) => _guestBlock(g) != null);
  }

  List<String> get _freeGuests => stages.where((s) => _guestBlock(s) == null).toList();

  // ============================================================
  // ACTIONS
  // ============================================================
  Future<void> _submit() async {
    final host = hostStage;
    if (host == null) {
      _snack('Choose the main class', 'Pick the stage whose trainer is present.', warningColor);
      return;
    }
    if (guestStages.isEmpty) {
      _snack('Choose stages', 'Pick the stage(s) whose trainer is absent.', warningColor);
      return;
    }
    if (isSubmitting) return;
    HapticFeedback.mediumImpact();
    setState(() => isSubmitting = true);
    final guests = guestStages.toList()..sort();
    try {
      final response = await http.post(
        Uri.parse(ApiEndpoints.mergeHindiStages),
        headers: ApiHeaders.json(),
        body: jsonEncode({'hostStage': host, 'guestStages': guests}),
      );
      if (!mounted) return;
      if (response.statusCode == 200) {
        _snack(
          'Stages merged',
          '${guests.map(_name).join(', ')} ${guests.length > 1 ? 'are' : 'is'} now in ${_name(host)}\'s Hindi class. Students in class are moved automatically.',
          successColor,
        );
        setState(() => guestStages.clear());
        await fetchMerges(silent: true);
      } else {
        _snack('Merge failed', _errorOf(response, 'Failed to merge stages.'), warningColor);
      }
    } catch (e) {
      debugPrint('Hindi merge error: $e');
      _snack('Server error', 'Unable to connect to the server.', dangerColor);
    } finally {
      if (mounted) setState(() => isSubmitting = false);
    }
  }

  Future<bool> _remove(String id) async {
    setState(() => _cancelling.add(id));
    try {
      final response = await http.delete(
        Uri.parse('${ApiEndpoints.hindiStageMerges}/$id'),
        headers: ApiHeaders.auth(),
      );
      if (response.statusCode == 200) return true;
      _snack('Unable to unmerge', _errorOf(response, 'Please try again.'), dangerColor);
    } catch (e) {
      _snack('Connection error', 'Unable to connect to the server.', dangerColor);
    } finally {
      if (mounted) setState(() => _cancelling.remove(id));
    }
    return false;
  }

  Future<void> _unmerge(Map<String, dynamic> m) async {
    final guest = _name(m['guestStage'].toString());
    final host = _name(m['hostStage'].toString());
    final ok = await _confirm(
      title: 'Unmerge $guest?',
      message: '$guest students go back to their own class. Students in $host\'s class right now are moved back automatically.',
      action: 'Unmerge',
    );
    if (!ok) return;
    if (await _remove(m['_id'].toString())) {
      _snack('Unmerged', '$guest is back in its own class.', primary);
      await fetchMerges(silent: true);
    }
  }

  Future<void> _unmergeGroup(String host, List<Map<String, dynamic>> group) async {
    final ok = await _confirm(
      title: 'Unmerge all from ${_name(host)}?',
      message: '${group.map((m) => _name(m['guestStage'].toString())).join(', ')} go back to their own classes.',
      action: 'Unmerge all',
    );
    if (!ok) return;
    var done = 0;
    for (final m in group) {
      if (await _remove(m['_id'].toString())) done++;
    }
    if (done > 0) _snack('Unmerged', '$done stage${done > 1 ? 's are' : ' is'} back in their own class.', primary);
    await fetchMerges(silent: true);
  }

  Future<bool> _confirm({required String title, required String message, required String action}) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: textPrimary)),
        content: Text(message, style: GoogleFonts.poppins(fontSize: 12.5, color: textSecondary, height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text('Keep merge', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: dangerColor,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(action, style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _snack(String title, String message, Color color) {
    Get.closeCurrentSnackbar();
    Get.snackbar(
      title,
      message,
      backgroundColor: color,
      colorText: Colors.white,
      margin: const EdgeInsets.all(16),
      borderRadius: 12,
      duration: const Duration(seconds: 4),
      snackPosition: SnackPosition.TOP,
    );
  }

  // ============================================================
  // BUILD
  // ============================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      appBar: _appBar(),
      body: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth;
          final pad = w >= 1000 ? 36.0 : (w >= 600 ? 24.0 : 14.0);
          return RefreshIndicator(
            color: primary,
            onRefresh: fetchMerges,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.symmetric(horizontal: pad, vertical: 20),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Hindi Stage Merging',
                          style: GoogleFonts.poppins(fontSize: 23, fontWeight: FontWeight.w700, color: textPrimary)),
                      const SizedBox(height: 4),
                      Text(
                        'A Hindi trainer is absent? Send their stage to another stage\'s class until they are back. '
                        'You can merge many stages at once — even all 7 into one class.',
                        style: GoogleFonts.poppins(fontSize: 12.5, color: textSecondary, height: 1.45),
                      ),
                      const SizedBox(height: 18),
                      _createCard(),
                      const SizedBox(height: 26),
                      Row(
                        children: [
                          Text('Active Hindi merges',
                              style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w700, color: textPrimary)),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                            decoration: BoxDecoration(color: primary.withOpacity(.10), borderRadius: BorderRadius.circular(20)),
                            child: Text('${activeMerges.length}',
                                style: GoogleFonts.poppins(fontSize: 11.5, fontWeight: FontWeight.w700, color: primary)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _activeList(),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  PreferredSizeWidget _appBar() {
    final isMobile = MediaQuery.sizeOf(context).width < 700;
    return PreferredSize(
      preferredSize: Size.fromHeight(isMobile ? 54 : 60),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(bottom: BorderSide(color: borderColor)),
        ),
        child: SafeArea(
          bottom: false,
          child: Row(
            children: [
              SizedBox(
                width: isMobile ? 50 : 58,
                child: Center(
                  child: IconButton(
                    tooltip: 'Open menu',
                    onPressed: AdminShellNavigation.openDrawer,
                    icon: AdminMenuIcon(Icons.menu_rounded, color: textPrimary, size: 25),
                  ),
                ),
              ),
              Container(
                width: isMobile ? 34 : 38,
                height: isMobile ? 34 : 38,
                decoration: BoxDecoration(color: primary, borderRadius: BorderRadius.circular(9)),
                child: Center(
                  child: Text('अ',
                      style: GoogleFonts.poppins(color: Colors.white, fontSize: isMobile ? 16 : 18, fontWeight: FontWeight.w800)),
                ),
              ),
              SizedBox(width: isMobile ? 9 : 11),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Hindi Stage Merge',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(color: textPrimary, fontSize: isMobile ? 15 : 18, fontWeight: FontWeight.w700, height: 1.05)),
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(color: _live ? successColor : textSecondary.withOpacity(.5), shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 5),
                        Text(_live ? 'Live • Hindi online classes' : 'Hindi online classes',
                            style: GoogleFonts.poppins(
                                color: _live ? successColor : textSecondary, fontSize: 9.5, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Refresh',
                onPressed: isLoading ? null : fetchMerges,
                icon: isLoading
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: primary))
                    : const Icon(Icons.refresh_rounded, color: textPrimary, size: 23),
              ),
              const SizedBox(width: 6),
            ],
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // CREATE
  // ------------------------------------------------------------
  Widget _createCard() {
    final free = _freeGuests;
    final allPicked = free.isNotEmpty && free.every(guestStages.contains);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
        boxShadow: [BoxShadow(color: primary.withOpacity(.05), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label('1. Main class — trainer is PRESENT'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: stages.map((st) {
              final block = _hostBlock(st);
              final selected = hostStage == st;
              return _chip(
                text: _name(st),
                sub: block ?? (_guestsOf(st).isNotEmpty ? '+${_guestsOf(st).length}' : null),
                selected: selected,
                color: primary,
                enabled: block == null,
                onTap: () => setState(() {
                  hostStage = st;
                  guestStages.remove(st);
                  _cleanSelection();
                }),
              );
            }).toList(),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(child: _label('2. Join into it — trainer is ABSENT')),
              if (hostStage != null && free.isNotEmpty)
                TextButton(
                  onPressed: () => setState(() {
                    if (allPicked) {
                      guestStages.clear();
                    } else {
                      guestStages.addAll(free);
                    }
                  }),
                  child: Text(allPicked ? 'Clear' : 'Select all',
                      style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700, color: guestColor)),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: stages.map((st) {
              final block = hostStage == null ? 'Pick main' : _guestBlock(st);
              final selected = guestStages.contains(st);
              return _chip(
                text: _name(st),
                sub: block,
                selected: selected,
                color: guestColor,
                enabled: block == null,
                check: true,
                onTap: () => setState(() => selected ? guestStages.remove(st) : guestStages.add(st)),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          if (hostStage != null && guestStages.isNotEmpty)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFFF1EDFF), borderRadius: BorderRadius.circular(12)),
              child: Text(
                '${(guestStages.toList()..sort()).map(_name).join(', ')} students will join ${_name(hostStage!)}\'s Hindi class. '
                'Their attendance & practice stay in their own stage.',
                style: GoogleFonts.poppins(fontSize: 11.5, color: const Color(0xFF4A3AA8), fontWeight: FontWeight.w600, height: 1.4),
              ),
            ),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: isSubmitting ? null : _submit,
              icon: isSubmitting
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.merge_type_rounded),
              label: Text(isSubmitting ? 'Merging…' : 'Merge stages',
                  style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String t) =>
      Text(t, style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.w700, color: textPrimary));

  Widget _chip({
    required String text,
    String? sub,
    required bool selected,
    required Color color,
    required bool enabled,
    required VoidCallback onTap,
    bool check = false,
  }) {
    return Opacity(
      opacity: enabled ? 1 : .45,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: enabled ? onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: 96,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            color: selected ? color : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: selected ? color : borderColor, width: 1.3),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (check && selected) ...[
                    const Icon(Icons.check_rounded, size: 14, color: Colors.white),
                    const SizedBox(width: 3),
                  ],
                  Text(text,
                      style: GoogleFonts.poppins(
                          fontSize: 12.5, fontWeight: FontWeight.w700, color: selected ? Colors.white : textPrimary)),
                ],
              ),
              if (sub != null)
                Text(sub,
                    style: GoogleFonts.poppins(
                        fontSize: 9.5, fontWeight: FontWeight.w600, color: selected ? Colors.white70 : textSecondary)),
            ],
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // ACTIVE
  // ------------------------------------------------------------
  Widget _activeList() {
    if (isLoading && activeMerges.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(30),
        child: Center(child: CircularProgressIndicator(color: primary)),
      );
    }
    if (activeMerges.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          children: [
            const Icon(Icons.check_circle_outline_rounded, color: successColor, size: 34),
            const SizedBox(height: 8),
            Text('No Hindi stages are merged',
                style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700, color: textPrimary)),
            Text('Every Hindi stage is in its own class.', style: GoogleFonts.poppins(fontSize: 12, color: textSecondary)),
          ],
        ),
      );
    }
    final groups = <String, List<Map<String, dynamic>>>{};
    for (final m in activeMerges) {
      (groups[m['hostStage'].toString()] ??= []).add(m);
    }
    final hosts = groups.keys.toList()..sort();
    return Column(
      children: hosts.map((h) => _groupCard(h, groups[h]!)).toList(),
    );
  }

  Widget _groupCard(String host, List<Map<String, dynamic>> group) {
    final trainer = (group.first['hostTrainer'] ?? '').toString();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
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
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: primary, borderRadius: BorderRadius.circular(10)),
                child: Text(_name(host),
                    style: GoogleFonts.poppins(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  trainer.isEmpty ? 'Main Hindi class' : 'Main class • $trainer',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: textSecondary),
                ),
              ),
              if (group.length > 1)
                TextButton(
                  onPressed: () => _unmergeGroup(host, group),
                  child: Text('Unmerge all',
                      style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700, color: dangerColor)),
                ),
            ],
          ),
          const SizedBox(height: 10),
          ...group.map((m) {
            final id = m['_id'].toString();
            final busy = _cancelling.contains(id);
            final guestTrainer = (m['guestTrainer'] ?? '').toString();
            final n = (m['guestStudents'] ?? 0);
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
              decoration: BoxDecoration(color: const Color(0xFFF7F5FF), borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  const Icon(Icons.subdirectory_arrow_right_rounded, color: guestColor, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_name(m['guestStage'].toString()),
                            style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700, color: textPrimary)),
                        Text(
                          '$n student${n == 1 ? '' : 's'}${guestTrainer.isEmpty ? '' : ' • trainer $guestTrainer absent'}',
                          style: GoogleFonts.poppins(fontSize: 11, color: textSecondary),
                        ),
                      ],
                    ),
                  ),
                  busy
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                        )
                      : TextButton.icon(
                          onPressed: () => _unmerge(m),
                          icon: const Icon(Icons.call_split_rounded, size: 17, color: dangerColor),
                          label: Text('Unmerge',
                              style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700, color: dangerColor)),
                        ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
