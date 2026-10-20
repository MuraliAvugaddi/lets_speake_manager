import 'dart:async';
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

/// 🔀 Temporary section merge — ENGLISH ONLINE classes only
/// (Hindi and offline classes have no sections).
///
/// Example: Stage 1 Section B's trainer is absent → merge B into A.
///  • B students join Section A's class — students already in class are moved automatically.
///  • Section A's trainer sees them (tagged "Sec B") and does practice + rating.
///  • Attendance and practice stay saved under Section B.
///  • Several sections can join one: B, C, D → A.
///  • Unmerge here (or B's trainer taps "I'm back") → B students go back to B.
class AdminSectionMergeScreen extends StatefulWidget {
  const AdminSectionMergeScreen({super.key});

  @override
  State<AdminSectionMergeScreen> createState() => _AdminSectionMergeScreenState();
}

class _AdminSectionMergeScreenState extends State<AdminSectionMergeScreen> {
  // ============================================================
  // COLORS
  // ============================================================
  static const Color primaryBlue = Color(0xFF2563EB);
  static const Color lightBlue = Color(0xFFE7F2F8);
  static const Color paleBlue = Color(0xFFF5F9FF);
  static const Color background = Color(0xFFEAF4FA);
  static const Color cardColor = Colors.white;
  static const Color textPrimary = Color(0xFF173E5C);
  static const Color textSecondary = Color(0xFF6A8295);
  static const Color borderColor = Color(0xFFD7E7F0);
  static const Color successColor = Color(0xFF16A34A);
  static const Color dangerColor = Color(0xFFDC2626);
  static const Color warningColor = Color(0xFFD97706);

  static const List<String> sections = ['A', 'B', 'C', 'D', 'E'];

  // ============================================================
  // STATE
  // ============================================================
  bool isLoading = false;
  bool isSubmitting = false;
  final Set<String> _cancelling = <String>{}; // merge ids being removed
  List<Map<String, dynamic>> activeMerges = [];

  String selectedStage = 'stage1';
  String? hostSection = 'A';
  final Set<String> guestSections = <String>{};

  IO.Socket? _socket;
  Timer? _liveDebounce;
  bool _live = false;

  @override
  void initState() {
    super.initState();
    fetchActiveMerges();
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

  // ============================================================
  // ⚡ LIVE — another admin / a trainer ("I'm back") changes a merge
  // ============================================================
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
      s.onReconnect((_) => fetchActiveMerges(silent: true));
      s.onDisconnect((_) {
        if (mounted) setState(() => _live = false);
      });
      s.on('merge_updated', (_) {
        _liveDebounce?.cancel();
        _liveDebounce = Timer(const Duration(milliseconds: 400), () => fetchActiveMerges(silent: true));
      });
      _socket = s;
    } catch (e) {
      debugPrint('Merge socket error: $e');
    }
  }

  // ============================================================
  // DATA
  // ============================================================
  Future<void> fetchActiveMerges({bool silent = false}) async {
    if (!mounted) return;
    if (!silent) setState(() => isLoading = true);
    try {
      final response = await http.get(
        Uri.parse('${ApiEndpoints.sectionMerges}?_t=${DateTime.now().millisecondsSinceEpoch}'),
        headers: ApiHeaders.auth(),
      );
      if (!mounted) return;
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final list = (data['merges'] as List? ?? [])
            .whereType<Map>()
            .map((m) => Map<String, dynamic>.from(m))
            .where((m) => (m['language'] ?? 'English').toString() == 'English')
            .toList();
        setState(() {
          activeMerges = list;
          _cleanSelection();
        });
      } else if (!silent) {
        _showSnackbar(title: 'Unable to load', message: _errorOf(response, 'Could not load active merges.'), color: warningColor);
      }
    } catch (e) {
      debugPrint('Fetch merges error: $e');
      if (mounted && !silent) {
        _showSnackbar(title: 'Connection error', message: 'Unable to connect to the server.', color: dangerColor);
      }
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

  // merges of the stage being edited
  List<Map<String, dynamic>> get _stageMerges =>
      activeMerges.where((m) => m['stage']?.toString() == selectedStage).toList();

  /// Section already joined to another section in this stage → its host ("A")
  String? _mergedInto(String sec) {
    final m = _stageMerges.firstWhereOrNull((m) => m['guestSection']?.toString() == sec);
    return m?['hostSection']?.toString();
  }

  /// Sections joined INTO this section in this stage
  List<String> _guestsOf(String sec) => _stageMerges
      .where((m) => m['hostSection']?.toString() == sec)
      .map((m) => m['guestSection'].toString())
      .toList();

  /// Why this section can't be picked as host (null = OK)
  String? _hostBlock(String sec) {
    final into = _mergedInto(sec);
    if (into != null) return 'In $into';
    return null;
  }

  /// Why this section can't join the chosen host (null = OK)
  String? _guestBlock(String sec) {
    if (sec == hostSection) return 'Host';
    final into = _mergedInto(sec);
    if (into != null) return into == hostSection ? 'Joined' : 'In $into';
    if (_guestsOf(sec).isNotEmpty) return 'Hosting';
    return null;
  }

  void _cleanSelection() {
    if (hostSection != null && _hostBlock(hostSection!) != null) hostSection = null;
    guestSections.removeWhere((g) => _guestBlock(g) != null);
  }

  // ============================================================
  // ACTIONS
  // ============================================================
  Future<void> _submitMerge() async {
    final host = hostSection;
    if (host == null) {
      _showSnackbar(title: 'Choose a host', message: 'Pick the section whose trainer is present.', color: warningColor);
      return;
    }
    if (guestSections.isEmpty) {
      _showSnackbar(title: 'Choose sections', message: 'Pick the section(s) whose trainer is absent.', color: warningColor);
      return;
    }
    if (isSubmitting) return;
    HapticFeedback.mediumImpact();
    setState(() => isSubmitting = true);
    final guests = guestSections.toList()..sort();
    try {
      final response = await http.post(
        Uri.parse(ApiEndpoints.mergeSections),
        headers: ApiHeaders.json(),
        body: jsonEncode({
          'language': 'English',
          'stage': selectedStage,
          'hostSection': host,
          'guestSections': guests,
        }),
      );
      if (!mounted) return;
      if (response.statusCode == 200) {
        _showSnackbar(
          title: 'Sections merged',
          message: 'Section ${guests.join(', ')} ${guests.length > 1 ? 'are' : 'is'} now in Section $host\'s class. Students in class are moved automatically.',
          color: successColor,
        );
        setState(() => guestSections.clear());
        await fetchActiveMerges(silent: true);
      } else {
        _showSnackbar(title: 'Merge failed', message: _errorOf(response, 'Failed to merge sections.'), color: warningColor);
      }
    } catch (e) {
      debugPrint('Submit merge error: $e');
      _showSnackbar(title: 'Server error', message: 'Unable to connect to the server.', color: dangerColor);
    } finally {
      if (mounted) setState(() => isSubmitting = false);
    }
  }

  Future<bool> _removeMerge(String mergeId) async {
    setState(() => _cancelling.add(mergeId));
    try {
      final response = await http.delete(
        Uri.parse('${ApiEndpoints.baseUrl}/admin/section-merges/$mergeId'),
        headers: ApiHeaders.auth(),
      );
      if (response.statusCode == 200) return true;
      _showSnackbar(title: 'Unable to unmerge', message: _errorOf(response, 'Please try again.'), color: dangerColor);
    } catch (e) {
      debugPrint('Cancel merge error: $e');
      _showSnackbar(title: 'Connection error', message: 'Unable to connect to the server.', color: dangerColor);
    } finally {
      if (mounted) setState(() => _cancelling.remove(mergeId));
    }
    return false;
  }

  Future<void> _unmerge(Map<String, dynamic> merge) async {
    final guest = merge['guestSection'].toString();
    final host = merge['hostSection'].toString();
    final ok = await _confirm(
      title: 'Unmerge Section $guest?',
      message: 'Section $guest students go back to their own class. Students in Section $host\'s class right now are moved back automatically.',
      action: 'Unmerge',
    );
    if (!ok) return;
    if (await _removeMerge(merge['_id'].toString())) {
      _showSnackbar(title: 'Unmerged', message: 'Section $guest is back in its own class.', color: primaryBlue);
      await fetchActiveMerges(silent: true);
    }
  }

  Future<void> _unmergeAll(String stage, String host, List<Map<String, dynamic>> group) async {
    final ok = await _confirm(
      title: 'Unmerge all from Section $host?',
      message: '${group.map((m) => 'Section ${m['guestSection']}').join(', ')} go back to their own classes.',
      action: 'Unmerge all',
    );
    if (!ok) return;
    var done = 0;
    for (final m in group) {
      if (await _removeMerge(m['_id'].toString())) done++;
    }
    if (done > 0) {
      _showSnackbar(title: 'Unmerged', message: '$done section${done > 1 ? 's are' : ' is'} back in their own class.', color: primaryBlue);
    }
    await fetchActiveMerges(silent: true);
  }

  Future<bool> _confirm({required String title, required String message, required String action}) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(color: const Color(0xFFFFF1F2), borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.call_split_rounded, color: dangerColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(title, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: textPrimary)),
            ),
          ],
        ),
        content: Text(message, style: GoogleFonts.poppins(fontSize: 12.5, color: textSecondary, height: 1.5)),
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
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
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(action, style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _showSnackbar({required String title, required String message, required Color color}) {
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

  String _stageLabel(String s) => s.replaceFirst('stage', 'Stage ');

  // ============================================================
  // BUILD
  // ============================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      appBar: _buildAppBar(),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final isDesktop = w >= 1000;
          final isTablet = w >= 600 && w < 1000;
          return RefreshIndicator(
            color: primaryBlue,
            backgroundColor: Colors.white,
            onRefresh: fetchActiveMerges,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.symmetric(horizontal: isDesktop ? 36 : (isTablet ? 24 : 14), vertical: 20),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1250),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildPageHeader(),
                      const SizedBox(height: 18),
                      if (isDesktop)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 5, child: _buildCreateMergeCard()),
                            const SizedBox(width: 22),
                            Expanded(flex: 4, child: _buildInformationCard()),
                          ],
                        )
                      else ...[
                        _buildCreateMergeCard(),
                        const SizedBox(height: 16),
                        _buildInformationCard(),
                      ],
                      const SizedBox(height: 28),
                      _buildActiveMergeHeader(),
                      const SizedBox(height: 12),
                      _buildActiveMerges(),
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

  PreferredSizeWidget _buildAppBar() {
    final isMobile = MediaQuery.sizeOf(context).width < 700;
    return PreferredSize(
      preferredSize: Size.fromHeight(isMobile ? 54 : 60),
      child: Container(
        width: double.infinity,
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
                    icon: const Icon(Icons.menu_rounded, color: textPrimary, size: 25),
                  ),
                ),
              ),
              Container(
                width: isMobile ? 34 : 38,
                height: isMobile ? 34 : 38,
                decoration: BoxDecoration(color: const Color(0xFF0F5A87), borderRadius: BorderRadius.circular(9)),
                child: Icon(Icons.merge_type_rounded, color: Colors.white, size: isMobile ? 18 : 20),
              ),
              SizedBox(width: isMobile ? 9 : 11),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Section Merge',
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
                        Flexible(
                          child: Text(
                            _live ? 'Live • English online classes' : 'English online classes',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                                color: _live ? successColor : textSecondary, fontSize: 9.5, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.only(right: isMobile ? 5 : 9),
                child: IconButton(
                  tooltip: 'Refresh',
                  onPressed: isLoading ? null : fetchActiveMerges,
                  icon: isLoading
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: primaryBlue))
                      : const Icon(Icons.refresh_rounded, color: textPrimary, size: 23),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPageHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Temporary Section Merging',
            style: GoogleFonts.poppins(fontSize: 23, fontWeight: FontWeight.w700, color: textPrimary)),
        const SizedBox(height: 4),
        Text('A trainer is absent? Send their section to another section\'s class until they are back.',
            style: GoogleFonts.poppins(fontSize: 12.5, color: textSecondary)),
      ],
    );
  }

  // ------------------------------------------------------------
  // CREATE
  // ------------------------------------------------------------
  Widget _buildCreateMergeCard() {
    final guests = guestSections.toList()..sort();
    final canSubmit = hostSection != null && guests.isNotEmpty && !isSubmitting;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.035), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _iconContainer(Icons.merge_type_rounded, lightBlue, primaryBlue),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Create merge', style: GoogleFonts.poppins(fontSize: 16.5, fontWeight: FontWeight.w700, color: textPrimary)),
                    Text('English • Online classes', style: GoogleFonts.poppins(fontSize: 11, color: textSecondary)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          _buildLabel('1. Stage'),
          const SizedBox(height: 8),
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: 7,
              separatorBuilder: (_, __) => const SizedBox(width: 7),
              itemBuilder: (_, i) {
                final s = 'stage${i + 1}';
                final on = s == selectedStage;
                final count = activeMerges.where((m) => m['stage']?.toString() == s).length;
                return InkWell(
                  borderRadius: BorderRadius.circular(11),
                  onTap: () => setState(() {
                    selectedStage = s;
                    guestSections.clear();
                    _cleanSelection();
                    hostSection ??= sections.firstWhereOrNull((x) => _hostBlock(x) == null);
                  }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    padding: const EdgeInsets.symmetric(horizontal: 13),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: on ? primaryBlue : const Color(0xFFFAFBFD),
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(color: on ? primaryBlue : borderColor),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Stage ${i + 1}',
                            style: GoogleFonts.poppins(
                                fontSize: 11.5, fontWeight: FontWeight.w700, color: on ? Colors.white : textPrimary)),
                        if (count > 0) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: on ? Colors.white.withOpacity(.22) : warningColor.withOpacity(.14),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text('$count',
                                style: GoogleFonts.poppins(
                                    fontSize: 9.5, fontWeight: FontWeight.w800, color: on ? Colors.white : warningColor)),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 18),
          _buildLabel('2. Section with trainer present (host)'),
          const SizedBox(height: 8),
          _chipRow(
            selected: (s) => s == hostSection,
            blocked: _hostBlock,
            color: successColor,
            icon: Icons.person_rounded,
            onTap: (s) => setState(() {
              hostSection = s;
              guestSections.remove(s);
              guestSections.removeWhere((g) => _guestBlock(g) != null);
            }),
          ),

          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildLabel('3. Sections joining (trainer absent)')),
              Text('pick one or more', style: GoogleFonts.poppins(fontSize: 10, color: textSecondary)),
            ],
          ),
          const SizedBox(height: 8),
          _chipRow(
            selected: (s) => guestSections.contains(s),
            blocked: hostSection == null ? (_) => 'Pick host' : _guestBlock,
            color: warningColor,
            icon: Icons.person_off_rounded,
            onTap: (s) => setState(() {
              HapticFeedback.selectionClick();
              guestSections.contains(s) ? guestSections.remove(s) : guestSections.add(s);
            }),
          ),

          const SizedBox(height: 16),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Container(
              key: ValueKey('${hostSection}_${guests.join()}'),
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: guests.isEmpty ? paleBlue : const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: guests.isEmpty ? const Color(0xFFDCEBFF) : warningColor.withOpacity(.35)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(guests.isEmpty ? Icons.info_outline_rounded : Icons.merge_type_rounded,
                      size: 18, color: guests.isEmpty ? primaryBlue : warningColor),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      guests.isEmpty || hostSection == null
                          ? 'Pick the section(s) whose trainer is absent today.'
                          : 'Section ${guests.join(', ')} students will join Section $hostSection\'s ${_stageLabel(selectedStage)} class. '
                              'Section $hostSection\'s trainer does their practice & rating. '
                              'Attendance and practice stay saved in Section ${guests.join(' / ')}.',
                      style: GoogleFonts.poppins(fontSize: 11.5, color: const Color(0xFF36516E), height: 1.5),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: canSubmit ? _submitMerge : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryBlue,
                disabledBackgroundColor: primaryBlue.withOpacity(0.35),
                foregroundColor: Colors.white,
                disabledForegroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: isSubmitting
                  ? const SizedBox(width: 21, height: 21, child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white))
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.merge_type_rounded, size: 20),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            guests.isEmpty || hostSection == null
                                ? 'Merge sections'
                                : 'Merge ${guests.join(', ')} into $hostSection',
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(fontSize: 13.5, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chipRow({
    required bool Function(String) selected,
    required String? Function(String) blocked,
    required Color color,
    required IconData icon,
    required void Function(String) onTap,
  }) {
    return LayoutBuilder(builder: (context, c) {
      const gap = 8.0;
      final w = ((c.maxWidth - gap * 4) / 5).clamp(48.0, 120.0);
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: sections.map((s) {
          final on = selected(s);
          final block = blocked(s);
          final disabled = block != null && !on;
          return Opacity(
            opacity: disabled ? .45 : 1,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: disabled ? null : () => onTap(s),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: w,
                height: 58,
                decoration: BoxDecoration(
                  color: on ? color.withOpacity(.12) : const Color(0xFFFAFBFD),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: on ? color : borderColor, width: on ? 1.6 : 1),
                ),
                child: Stack(
                  children: [
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(s,
                              style: GoogleFonts.poppins(
                                  fontSize: 17, fontWeight: FontWeight.w800, color: on ? color : textPrimary, height: 1.1)),
                          Text(
                            block ?? 'Section',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(fontSize: 8.5, fontWeight: FontWeight.w600, color: textSecondary),
                          ),
                        ],
                      ),
                    ),
                    if (on)
                      Positioned(
                        top: 4,
                        right: 4,
                        child: Icon(Icons.check_circle_rounded, size: 14, color: color),
                      ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      );
    });
  }

  Widget _buildInformationCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: lightBlue,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFD9E9FF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _iconContainer(Icons.help_outline_rounded, Colors.white, primaryBlue),
              const SizedBox(width: 12),
              Text('How it works', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: textPrimary)),
            ],
          ),
          const SizedBox(height: 18),
          _buildInfoStep(
            number: '01',
            title: 'Merge',
            description: 'Section B\'s trainer is absent → merge B into A. You can merge several (B, C, D → A).',
          ),
          _buildInfoStep(
            number: '02',
            title: 'Students move by themselves',
            description: 'B students join A\'s class. Students already in class are moved automatically — no refresh.',
          ),
          _buildInfoStep(
            number: '03',
            title: 'Records stay in their section',
            description: 'A\'s trainer sees them tagged "Sec B" and does practice + rating. Attendance & practice are saved in Section B.',
          ),
          _buildInfoStep(
            number: '04',
            title: 'Unmerge',
            description: 'Unmerge here, or B\'s trainer taps "I\'m back" in their app. Students go back to Section B.',
            isLast: true,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoStep({required String number, required String title, required String description, bool isLast = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(9)),
            child: Text(number, style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w700, color: primaryBlue)),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.poppins(fontSize: 12.5, fontWeight: FontWeight.w700, color: textPrimary)),
                const SizedBox(height: 2),
                Text(description, style: GoogleFonts.poppins(fontSize: 11, color: textSecondary, height: 1.45)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // ACTIVE MERGES (grouped: stage → host section)
  // ------------------------------------------------------------
  Widget _buildActiveMergeHeader() {
    final hosts = <String>{for (final m in activeMerges) '${m['stage']}|${m['hostSection']}'}.length;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Active merges', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700, color: textPrimary)),
              Text('Stays on until you unmerge (or the absent trainer taps "I\'m back").',
                  style: GoogleFonts.poppins(fontSize: 11, color: textSecondary)),
            ],
          ),
        ),
        if (!isLoading)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
            decoration: BoxDecoration(color: lightBlue, borderRadius: BorderRadius.circular(20)),
            child: Text('${activeMerges.length} section${activeMerges.length == 1 ? '' : 's'} • $hosts class${hosts == 1 ? '' : 'es'}',
                style: GoogleFonts.poppins(fontSize: 10.5, fontWeight: FontWeight.w700, color: primaryBlue)),
          ),
      ],
    );
  }

  Widget _buildActiveMerges() {
    if (isLoading && activeMerges.isEmpty) return _buildLoadingState();
    if (activeMerges.isEmpty) return _buildEmptyState();

    // group by stage + host
    final groups = <String, List<Map<String, dynamic>>>{};
    for (final m in activeMerges) {
      groups.putIfAbsent('${m['stage']}|${m['hostSection']}', () => []).add(m);
    }
    final keys = groups.keys.toList()..sort();

    return LayoutBuilder(builder: (context, c) {
      final cols = c.maxWidth >= 650 ? 2 : 1;
      final cardW = cols == 2 ? (c.maxWidth - 16) / 2 : c.maxWidth;
      return Wrap(
        spacing: 16,
        runSpacing: 14,
        children: keys.map((k) {
          final parts = k.split('|');
          return SizedBox(width: cardW, child: _buildGroupCard(parts[0], parts[1], groups[k]!));
        }).toList(),
      );
    });
  }

  Widget _buildGroupCard(String stage, String host, List<Map<String, dynamic>> group) {
    group.sort((a, b) => a['guestSection'].toString().compareTo(b['guestSection'].toString()));
    final hostTrainer = (group.first['hostTrainer'] ?? '').toString();
    final total = group.fold<int>(0, (t, m) => t + (int.tryParse('${m['guestStudents'] ?? 0}') ?? 0));
    final busyAll = group.every((m) => _cancelling.contains(m['_id'].toString()));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.025), blurRadius: 14, offset: const Offset(0, 5))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // host header
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: const Color(0xFFECFDF3), borderRadius: BorderRadius.circular(13)),
                child: Text(host, style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w800, color: successColor)),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${_stageLabel(stage)} • Section $host class',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700, color: textPrimary)),
                    Text(
                      '${hostTrainer.isNotEmpty ? 'Trainer: $hostTrainer' : 'English online'} • +$total student${total == 1 ? '' : 's'} joining',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(fontSize: 10.5, color: textSecondary),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(color: const Color(0xFFECFDF3), borderRadius: BorderRadius.circular(20)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(width: 6, height: 6, decoration: const BoxDecoration(color: successColor, shape: BoxShape.circle)),
                    const SizedBox(width: 5),
                    Text('Active', style: GoogleFonts.poppins(fontSize: 9.5, fontWeight: FontWeight.w700, color: successColor)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // guests
          ...group.map((m) => _guestRow(m, host)),
          if (group.length > 1) ...[
            const SizedBox(height: 4),
            SizedBox(
              width: double.infinity,
              height: 38,
              child: TextButton.icon(
                onPressed: busyAll ? null : () => _unmergeAll(stage, host, group),
                icon: const Icon(Icons.call_split_rounded, size: 16, color: dangerColor),
                label: Text('Unmerge all', style: GoogleFonts.poppins(fontSize: 11.5, fontWeight: FontWeight.w700, color: dangerColor)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _guestRow(Map<String, dynamic> m, String host) {
    final guest = m['guestSection'].toString();
    final id = m['_id'].toString();
    final trainer = (m['guestTrainer'] ?? '').toString();
    final students = int.tryParse('${m['guestStudents'] ?? 0}') ?? 0;
    final busy = _cancelling.contains(id);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(10, 9, 8, 9),
      decoration: BoxDecoration(color: const Color(0xFFFFF7ED), borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(9)),
            child: Text(guest, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w800, color: warningColor)),
          ),
          const SizedBox(width: 6),
          const Icon(Icons.arrow_forward_rounded, size: 15, color: textSecondary),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Section $guest → Section $host',
                    style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700, color: textPrimary)),
                Text(
                  '${trainer.isNotEmpty ? '$trainer absent' : 'Trainer absent'} • $students student${students == 1 ? '' : 's'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(fontSize: 10, color: textSecondary),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 34,
            child: OutlinedButton(
              onPressed: busy ? null : () => _unmerge(m),
              style: OutlinedButton.styleFrom(
                foregroundColor: dangerColor,
                side: BorderSide(color: dangerColor.withOpacity(.3)),
                backgroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
              ),
              child: busy
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: dangerColor))
                  : Text('Unmerge', style: GoogleFonts.poppins(fontSize: 10.5, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(String text) =>
      Text(text, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w700, color: textPrimary));

  Widget _iconContainer(IconData icon, Color bg, Color fg, {double size = 44}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Icon(icon, color: fg, size: size * 0.48),
    );
  }

  Widget _buildLoadingState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 46),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: borderColor)),
      child: Column(
        children: [
          const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 2.5, color: primaryBlue)),
          const SizedBox(height: 14),
          Text('Loading active merges…', style: GoogleFonts.poppins(fontSize: 12, color: textSecondary)),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: borderColor)),
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(color: lightBlue, borderRadius: BorderRadius.circular(18)),
            child: const Icon(Icons.merge_type_rounded, size: 30, color: primaryBlue),
          ),
          const SizedBox(height: 14),
          Text('No active merges', style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700, color: textPrimary)),
          const SizedBox(height: 4),
          Text('Every section is in its own class today.',
              textAlign: TextAlign.center, style: GoogleFonts.poppins(fontSize: 11.5, color: textSecondary)),
        ],
      ),
    );
  }
}
