import 'dart:convert';

import 'package:lets_speake_manager/Api/admin_badges.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:lets_speake_manager/Api/ApiendPoints.dart';
import 'package:lets_speake_manager/Api/api_headers.dart';
import 'package:lets_speake_manager/Navigation/AdminShellNavigation.dart';

/// 📨 STAGE MESSAGES — send a message to ONE group of students
///
///  • Choose English / Hindi / both, Stage 1–7 (one, many or all) and
///    Online / Offline / both.
///  • Only those students see it (Messages page in the app) and get a phone
///    notification. Example: English • Stage 2 • Online → only them.
///  • Delete removes it from their apps.
class AdminStageMessageScreen extends StatefulWidget {
  const AdminStageMessageScreen({super.key});

  @override
  State<AdminStageMessageScreen> createState() =>
      _AdminStageMessageScreenState();
}

class _AdminStageMessageScreenState extends State<AdminStageMessageScreen> {
  static const Color primary = Color(0xFF0F5A87);
  static const Color teal = Color(0xFF28C2C2);
  static const Color hindiColor = Color(0xFF7A5AF8);
  static const Color background = Color(0xFFEAF4FA);
  static const Color textPrimary = Color(0xFF173E5C);
  static const Color textSecondary = Color(0xFF6A8295);
  static const Color borderColor = Color(0xFFD7E7F0);
  static const Color successColor = Color(0xFF16A34A);
  static const Color dangerColor = Color(0xFFDC2626);
  static const Color warningColor = Color(0xFFD97706);

  String language = 'English'; // English / Hindi / All
  final Set<int> stages = <int>{}; // empty = all stages
  String mode = 'all'; // all / online / offline

  final titleCtrl = TextEditingController();
  final msgCtrl = TextEditingController();

  bool loading = false;
  bool sending = false;
  final Set<String> deleting = <String>{};
  List<Map<String, dynamic>> sent = [];

  Color get langColor => language == 'Hindi'
      ? hindiColor
      : language == 'All'
      ? teal
      : primary;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    titleCtrl.dispose();
    msgCtrl.dispose();
    super.dispose();
  }

  // ============================================================
  // DATA
  // ============================================================
  Future<void> _load() async {
    setState(() => loading = true);
    try {
      final res = await http
          .get(
            Uri.parse(
              '${ApiEndpoints.stageMessages}?_t=${DateTime.now().millisecondsSinceEpoch}',
            ),
            headers: ApiHeaders.auth(),
          )
          .timeout(const Duration(seconds: 20));
      if (!mounted) return;
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          sent = (data['messages'] as List? ?? [])
              .whereType<Map>()
              .map((m) => Map<String, dynamic>.from(m))
              .toList();
        });
      } else {
        _snack(
          'Unable to load',
          _msgOf(res, 'Could not load messages.'),
          warningColor,
        );
      }
    } catch (_) {
      if (mounted) {
        _snack(
          'Connection error',
          'Unable to connect to the server.',
          dangerColor,
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  String _msgOf(http.Response r, String fallback) {
    try {
      final d = jsonDecode(r.body);
      if (d is Map && d['message'] != null) return '${d['message']}';
    } catch (_) {}
    return fallback;
  }

  String get _groupText {
    final lang = language == 'All' ? 'English & Hindi' : language;
    final st = stages.isEmpty
        ? 'All stages'
        : 'Stage ${(stages.toList()..sort()).join(', ')}';
    final md = mode == 'all'
        ? 'Online & Offline'
        : (mode == 'online' ? 'Online' : 'Offline');
    return '$lang • $st • $md';
  }

  Future<void> _send() async {
    final msg = msgCtrl.text.trim();
    if (msg.isEmpty) {
      _snack('Message', 'Write the message first.', warningColor);
      return;
    }
    final ok = await _confirm(
      'Send message?',
      'Students of  $_groupText  will get this message and a phone notification.',
      'Send',
      primary,
    );
    if (!ok) return;

    setState(() => sending = true);
    try {
      final res = await http
          .post(
            Uri.parse(ApiEndpoints.stageMessages),
            headers: ApiHeaders.json(),
            body: jsonEncode({
              'title': titleCtrl.text.trim(),
              'message': msg,
              'language': language,
              'stages': (stages.toList()..sort())
                  .map((n) => 'stage$n')
                  .toList(),
              'mode': mode,
            }),
          )
          .timeout(const Duration(seconds: 30));
      if (!mounted) return;
      if (res.statusCode == 201 || res.statusCode == 200) {
        titleCtrl.clear();
        msgCtrl.clear();
        _snack('Sent ✅', _msgOf(res, 'Message sent.'), successColor);
        await _load();
      } else {
        _snack('Not sent', _msgOf(res, 'Could not send.'), dangerColor);
      }
    } catch (_) {
      if (mounted) {
        _snack(
          'Connection error',
          'Unable to connect to the server.',
          dangerColor,
        );
      }
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  Future<void> _delete(Map<String, dynamic> m) async {
    final id = '${m['id']}';
    final ok = await _confirm(
      'Delete message?',
      'It will be removed from the students\' apps.',
      'Delete',
      dangerColor,
    );
    if (!ok) return;
    setState(() => deleting.add(id));
    try {
      final res = await http
          .delete(
            Uri.parse('${ApiEndpoints.stageMessages}/$id'),
            headers: ApiHeaders.auth(),
          )
          .timeout(const Duration(seconds: 20));
      if (!mounted) return;
      if (res.statusCode == 200 || res.statusCode == 404) {
        setState(() => sent.removeWhere((x) => '${x['id']}' == id));
        _snack('Deleted', 'Message removed.', successColor);
      } else {
        _snack('Not deleted', _msgOf(res, 'Could not delete.'), dangerColor);
      }
    } catch (_) {
      if (mounted) {
        _snack(
          'Connection error',
          'Unable to connect to the server.',
          dangerColor,
        );
      }
    } finally {
      if (mounted) setState(() => deleting.remove(id));
    }
  }

  Future<bool> _confirm(
    String title,
    String body,
    String action,
    Color color,
  ) async {
    final r = await Get.dialog<bool>(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          title,
          style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
        ),
        content: Text(body, style: GoogleFonts.poppins(fontSize: 13.5)),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Get.back(result: true),
            child: Text(action),
          ),
        ],
      ),
    );
    return r ?? false;
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
          final pad = c.maxWidth >= 1000
              ? 36.0
              : (c.maxWidth >= 600 ? 24.0 : 14.0);
          return RefreshIndicator(
            color: primary,
            onRefresh: _load,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.symmetric(horizontal: pad, vertical: 20),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Stage Messages',
                        style: GoogleFonts.poppins(
                          fontSize: 23,
                          fontWeight: FontWeight.w700,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Send a message only to the students you choose — for example English • Stage 2 • Online. '
                        'They see it in the app (🔔 Messages) and get a phone notification.',
                        style: GoogleFonts.poppins(
                          fontSize: 12.5,
                          color: textSecondary,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _composeCard(),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Text(
                            'Sent messages',
                            style: GoogleFonts.poppins(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: textPrimary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: primary.withOpacity(.10),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${sent.length}',
                              style: GoogleFonts.poppins(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _list(),
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
                    icon: AdminMenuIcon(Icons.menu_rounded,
                      color: textPrimary,
                      size: 25,
                    ),
                  ),
                ),
              ),
              Container(
                width: isMobile ? 34 : 38,
                height: isMobile ? 34 : 38,
                decoration: BoxDecoration(
                  color: primary,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(
                  Icons.campaign_rounded,
                  color: Colors.white,
                  size: isMobile ? 18 : 20,
                ),
              ),
              SizedBox(width: isMobile ? 9 : 11),
              Expanded(
                child: Text(
                  'Stage Messages',
                  style: GoogleFonts.poppins(
                    color: textPrimary,
                    fontSize: isMobile ? 15 : 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Refresh',
                onPressed: loading ? null : _load,
                icon: loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: primary,
                        ),
                      )
                    : const Icon(
                        Icons.refresh_rounded,
                        color: textPrimary,
                        size: 23,
                      ),
              ),
              const SizedBox(width: 6),
            ],
          ),
        ),
      ),
    );
  }

  Widget _card({required Widget child}) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: borderColor),
      boxShadow: [
        BoxShadow(
          color: primary.withOpacity(.05),
          blurRadius: 16,
          offset: const Offset(0, 6),
        ),
      ],
    ),
    child: child,
  );

  Widget _label(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      t,
      style: GoogleFonts.poppins(
        fontSize: 12.5,
        fontWeight: FontWeight.w700,
        color: textPrimary,
      ),
    ),
  );

  Widget _chip({
    required String text,
    required bool selected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ChoiceChip(
      label: Text(text),
      selected: selected,
      showCheckmark: false,
      selectedColor: color,
      backgroundColor: Colors.white,
      side: BorderSide(color: selected ? color : borderColor),
      labelStyle: GoogleFonts.poppins(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: selected ? Colors.white : textPrimary,
      ),
      onSelected: (_) => onTap(),
    );
  }

  InputDecoration _input(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: GoogleFonts.poppins(fontSize: 13, color: textSecondary),
    filled: true,
    fillColor: const Color(0xFFF7FBFD),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: borderColor),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: borderColor),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: langColor, width: 1.4),
    ),
  );

  Widget _composeCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1) course
          _label('1. Course'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _chip(
                text: 'English',
                selected: language == 'English',
                color: primary,
                onTap: () => setState(() => language = 'English'),
              ),
              _chip(
                text: 'Hindi • हिंदी',
                selected: language == 'Hindi',
                color: hindiColor,
                onTap: () => setState(() => language = 'Hindi'),
              ),
              _chip(
                text: 'Both',
                selected: language == 'All',
                color: teal,
                onTap: () => setState(() => language = 'All'),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 2) stages
          _label('2. Stages (tap one or more)'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _chip(
                text: 'All stages',
                selected: stages.isEmpty,
                color: langColor,
                onTap: () => setState(stages.clear),
              ),
              for (var n = 1; n <= 7; n++)
                _chip(
                  text: 'Stage $n',
                  selected: stages.contains(n),
                  color: langColor,
                  onTap: () => setState(() {
                    if (!stages.remove(n)) stages.add(n);
                  }),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // 3) online / offline
          _label('3. Students'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _chip(
                text: 'Online & Offline',
                selected: mode == 'all',
                color: primary,
                onTap: () => setState(() => mode = 'all'),
              ),
              _chip(
                text: '🌐 Online only',
                selected: mode == 'online',
                color: teal,
                onTap: () => setState(() => mode = 'online'),
              ),
              _chip(
                text: '🏫 Offline only',
                selected: mode == 'offline',
                color: warningColor,
                onTap: () => setState(() => mode = 'offline'),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 4) message
          _label('4. Message'),
          TextField(
            controller: titleCtrl,
            maxLength: 120,
            style: GoogleFonts.poppins(fontSize: 13.5),
            decoration: _input('Title (optional) — e.g. Class time changed'),
          ),
          const SizedBox(height: 4),
          TextField(
            controller: msgCtrl,
            minLines: 4,
            maxLines: 10,
            maxLength: 2000,
            keyboardType: TextInputType.multiline,
            style: GoogleFonts.poppins(fontSize: 13.5, height: 1.45),
            decoration: _input('Write the message for these students…'),
          ),
          const SizedBox(height: 10),

          // who gets it
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: langColor.withOpacity(.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: langColor.withOpacity(.25)),
            ),
            child: Row(
              children: [
                Icon(Icons.groups_rounded, color: langColor, size: 20),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    'Goes to:  $_groupText',
                    style: GoogleFonts.poppins(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: sending ? null : _send,
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send_rounded, size: 19),
              label: Text(
                sending ? 'Sending…' : 'Send message',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _when(dynamic v) {
    final t = DateTime.tryParse('${v ?? ''}')?.toLocal();
    if (t == null) return '';
    return DateFormat('d MMM yyyy, h:mm a').format(t);
  }

  Widget _list() {
    if (loading && sent.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(30),
        child: Center(child: CircularProgressIndicator(color: primary)),
      );
    }
    if (sent.isEmpty) {
      return _card(
        child: Text(
          'No messages sent yet.',
          style: GoogleFonts.poppins(color: textSecondary, fontSize: 13),
        ),
      );
    }
    return Column(
      children: sent.map((m) {
        final id = '${m['id']}';
        final lang = '${m['language']}';
        final c = lang == 'Hindi'
            ? hindiColor
            : lang == 'All'
            ? teal
            : primary;
        final title = '${m['title'] ?? ''}'.trim();
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _card(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: c.withOpacity(.10),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(Icons.campaign_rounded, color: c, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: c.withOpacity(.10),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${m['group'] ?? ''}',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: c,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      if (title.isNotEmpty)
                        Text(
                          title,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: textPrimary,
                          ),
                        ),
                      SelectableText(
                        '${m['message'] ?? ''}',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: textPrimary,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${_when(m['createdAt'])} • sent to ${m['sentTo'] ?? 0} students'
                        '${'${m['sentByName'] ?? ''}'.isNotEmpty ? ' • by ${m['sentByName']}' : ''}',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                IconButton(
                  tooltip: 'Delete',
                  onPressed: deleting.contains(id) ? null : () => _delete(m),
                  icon: deleting.contains(id)
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: dangerColor,
                          ),
                        )
                      : const Icon(
                          Icons.delete_outline_rounded,
                          color: dangerColor,
                        ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
