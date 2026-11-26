import 'dart:convert';
import 'package:lets_speake_manager/Api/admin_badges.dart';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:lets_speake_manager/Api/ApiendPoints.dart';
import 'package:lets_speake_manager/Api/api_headers.dart';
import 'package:lets_speake_manager/Navigation/AdminShellNavigation.dart';

/// 📚 STUDY MATERIAL — upload one PDF per stage day (English + Hindi, Stage 1–7)
///
///  • The PDF is compressed on the server and stored on Cloudinary.
///  • Every student phone downloads it ONCE and keeps it offline.
///  • Upload the same day again = update → phones replace their copy.
///  • A day uploaded here is shown instead of the same day inside the app.
class AdminMaterialScreen extends StatefulWidget {
  const AdminMaterialScreen({super.key});

  @override
  State<AdminMaterialScreen> createState() => _AdminMaterialScreenState();
}

class _PickedPdf {
  final String name;
  final Uint8List bytes;
  const _PickedPdf(this.name, this.bytes);
}

class _AdminMaterialScreenState extends State<AdminMaterialScreen> {
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

  static const int pdfMax = 40 * 1024 * 1024;

  String language = 'English';
  String stage = 'stage1';

  bool loading = false;
  bool uploading = false;
  final Set<String> deleting = <String>{};
  List<Map<String, dynamic>> all = [];

  final dayCtrl = TextEditingController();
  final titleCtrl = TextEditingController();
  final subtitleCtrl = TextEditingController();
  _PickedPdf? picked;

  Color get langColor => language == 'Hindi' ? hindiColor : primary;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    dayCtrl.dispose();
    titleCtrl.dispose();
    subtitleCtrl.dispose();
    super.dispose();
  }

  // ============================================================
  // DATA
  // ============================================================
  List<Map<String, dynamic>> get current =>
      all
          .where((m) => m['language'] == language && m['stage'] == stage)
          .toList()
        ..sort((a, b) => (a['day'] as num).compareTo(b['day'] as num));

  int get _nextDay {
    final days = current.map((m) => (m['day'] as num).toInt()).toSet();
    var d = 1;
    while (days.contains(d)) {
      d++;
    }
    return d;
  }

  Map<String, dynamic>? _existing(int day) {
    for (final m in current) {
      if ((m['day'] as num).toInt() == day) return m;
    }
    return null;
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() => loading = true);
    try {
      final res = await http.get(
        Uri.parse(
          '${ApiEndpoints.materials}?_t=${DateTime.now().millisecondsSinceEpoch}',
        ),
        headers: ApiHeaders.auth(),
      );
      if (!mounted) return;
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          all = (data['materials'] as List? ?? [])
              .whereType<Map>()
              .map((m) => Map<String, dynamic>.from(m))
              .toList();
          if (dayCtrl.text.isEmpty) dayCtrl.text = '$_nextDay';
        });
      } else if (!silent) {
        _snack(
          'Unable to load',
          _msgOf(res, 'Could not load material.'),
          warningColor,
        );
      }
    } catch (e) {
      if (mounted && !silent)
        _snack(
          'Connection error',
          'Unable to connect to the server.',
          dangerColor,
        );
    } finally {
      if (mounted && !silent) setState(() => loading = false);
    }
  }

  String _msgOf(http.Response r, String fallback) {
    try {
      final d = jsonDecode(r.body);
      if (d is Map && d['message'] != null) return d['message'].toString();
    } catch (_) {}
    return fallback;
  }

  String _size(num bytes) {
    if (bytes >= 1024 * 1024)
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / 1024).toStringAsFixed(0)} KB';
  }

  // ============================================================
  // ACTIONS
  // ============================================================
  Future<void> _pick() async {
    if (uploading) return;
    try {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: const ['pdf'],
        dialogTitle: 'Choose the PDF',
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (bytes.length > pdfMax) {
        _snack('Too large', 'PDF must be under 40 MB.', dangerColor);
        return;
      }
      if (bytes.length < 5 ||
          String.fromCharCodes(bytes.sublist(0, 5)) != '%PDF-') {
        _snack('Not a PDF', 'Please choose a PDF file.', dangerColor);
        return;
      }
      setState(() {
        picked = _PickedPdf(file.name, bytes);
        // file name like "Day-6_ST-5_Eng (Habits).pdf" → fill day + title
        final name = file.name.replaceAll(
          RegExp(r'\.pdf$', caseSensitive: false),
          '',
        );
        final dm = RegExp(
          r'day[\s_-]*(\d{1,2})',
          caseSensitive: false,
        ).firstMatch(name);
        if (dm != null && dayCtrl.text.trim().isEmpty)
          dayCtrl.text = dm.group(1)!;
        final tm = RegExp(r'\(([^)]+)\)').firstMatch(name);
        if (titleCtrl.text.trim().isEmpty)
          titleCtrl.text = (tm?.group(1) ?? '').trim();
      });
    } catch (e) {
      _snack('Could not open file', '$e', dangerColor);
    }
  }

  Future<void> _upload() async {
    final day = int.tryParse(dayCtrl.text.trim()) ?? 0;
    if (day < 1 || day > 60) {
      _snack('Day number', 'Enter the day number (1 to 60).', warningColor);
      return;
    }
    final file = picked;
    if (file == null) {
      _snack('Choose a PDF', 'Tap "Choose PDF" first.', warningColor);
      return;
    }
    final old = _existing(day);
    if (old != null) {
      final ok = await _confirm(
        'Replace Day $day?',
        'Day $day "${old['title']}" is already uploaded. Students will get the new PDF and their old copy is removed.',
        'Replace',
      );
      if (!ok) return;
    }
    HapticFeedback.mediumImpact();
    setState(() => uploading = true);
    try {
      final req = http.MultipartRequest(
        'POST',
        Uri.parse(ApiEndpoints.materials),
      );
      req.headers.addAll(ApiHeaders.auth());
      req.fields['language'] = language;
      req.fields['stage'] = stage;
      req.fields['day'] = '$day';
      req.fields['title'] = titleCtrl.text.trim();
      req.fields['subtitle'] = subtitleCtrl.text.trim();
      req.files.add(
        http.MultipartFile.fromBytes('pdf', file.bytes, filename: file.name),
      );
      final res = await http.Response.fromStream(await req.send());
      if (!mounted) return;
      if (res.statusCode == 200) {
        _snack(
          'Uploaded',
          _msgOf(res, 'Students get it automatically.'),
          successColor,
        );
        setState(() {
          picked = null;
          titleCtrl.clear();
          subtitleCtrl.clear();
          dayCtrl.clear();
        });
        await _load(silent: true);
        if (mounted) setState(() => dayCtrl.text = '$_nextDay');
      } else {
        _snack('Upload failed', _msgOf(res, 'Please try again.'), dangerColor);
      }
    } catch (e) {
      _snack(
        'Upload failed',
        'Connection error. Please try again.',
        dangerColor,
      );
    } finally {
      if (mounted) setState(() => uploading = false);
    }
  }

  Future<void> _delete(Map<String, dynamic> m) async {
    final ok = await _confirm(
      'Delete Day ${m['day']}?',
      'The PDF is removed from students\' phones. If the app has its own copy of this day, students see that again.',
      'Delete',
    );
    if (!ok) return;
    final id = m['id'].toString();
    setState(() => deleting.add(id));
    try {
      final res = await http.delete(
        Uri.parse('${ApiEndpoints.materials}/$id'),
        headers: ApiHeaders.auth(),
      );
      if (res.statusCode == 200) {
        _snack('Deleted', 'Day ${m['day']} removed.', primary);
        await _load(silent: true);
      } else {
        _snack(
          'Could not delete',
          _msgOf(res, 'Please try again.'),
          dangerColor,
        );
      }
    } catch (_) {
      _snack(
        'Connection error',
        'Unable to connect to the server.',
        dangerColor,
      );
    } finally {
      if (mounted) setState(() => deleting.remove(id));
    }
  }

  void _replace(Map<String, dynamic> m) {
    setState(() {
      dayCtrl.text = '${m['day']}';
      titleCtrl.text = '${m['title'] ?? ''}';
      subtitleCtrl.text = '${m['subtitle'] ?? ''}';
      picked = null;
    });
    _pick();
  }

  /// ✏️ change the title / short line without uploading the PDF again
  Future<void> _edit(Map<String, dynamic> m) async {
    final t = TextEditingController(text: '${m['title'] ?? ''}');
    final st = TextEditingController(text: '${m['subtitle'] ?? ''}');
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Edit Day ${m['day']}',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: textPrimary,
          ),
        ),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: t,
                maxLength: 120,
                decoration: _input('Title').copyWith(counterText: ''),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: st,
                maxLength: 160,
                decoration: _input(
                  'Short line (optional)',
                ).copyWith(counterText: ''),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                color: textSecondary,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(c, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: primary,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            child: Text(
              'Save',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
    final title = t.text.trim();
    final subtitle = st.text.trim();
    t.dispose();
    st.dispose();
    if (ok != true) return;
    if (title.isEmpty) {
      _snack('Title needed', 'Please type a title.', warningColor);
      return;
    }
    try {
      final res = await http.patch(
        Uri.parse('${ApiEndpoints.materials}/${m['id']}'),
        headers: ApiHeaders.json(),
        body: jsonEncode({'title': title, 'subtitle': subtitle}),
      );
      if (res.statusCode == 200) {
        _snack(
          'Saved',
          'Day ${m['day']} updated on students\' phones.',
          successColor,
        );
        await _load(silent: true);
      } else {
        _snack('Could not save', _msgOf(res, 'Please try again.'), dangerColor);
      }
    } catch (_) {
      _snack(
        'Connection error',
        'Unable to connect to the server.',
        dangerColor,
      );
    }
  }

  Future<bool> _confirm(String title, String message, String action) async {
    final r = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: textPrimary,
          ),
        ),
        content: Text(
          message,
          style: GoogleFonts.poppins(
            fontSize: 12.5,
            color: textSecondary,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                color: textSecondary,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(c, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: action == 'Delete' ? dangerColor : primary,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            child: Text(
              action,
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
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
                        'Study Material',
                        style: GoogleFonts.poppins(
                          fontSize: 23,
                          fontWeight: FontWeight.w700,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Upload a PDF for any stage day. Students\' phones download it once and keep it offline. '
                        'Upload the same day again to update it.',
                        style: GoogleFonts.poppins(
                          fontSize: 12.5,
                          color: textSecondary,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _picker(),
                      const SizedBox(height: 16),
                      _uploadCard(),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Text(
                            '$language • Stage ${stage.replaceAll('stage', '')}',
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
                              color: langColor.withOpacity(.10),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${current.length} days',
                              style: GoogleFonts.poppins(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: langColor,
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
                  Icons.picture_as_pdf_rounded,
                  color: Colors.white,
                  size: isMobile ? 18 : 20,
                ),
              ),
              SizedBox(width: isMobile ? 9 : 11),
              Expanded(
                child: Text(
                  'Study Material',
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

  Widget _picker() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: ['English', 'Hindi'].map((l) {
              final sel = language == l;
              final color = l == 'Hindi' ? hindiColor : primary;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(l == 'Hindi' ? 'Hindi • हिंदी' : 'English'),
                  selected: sel,
                  showCheckmark: false,
                  selectedColor: color,
                  backgroundColor: Colors.white,
                  side: BorderSide(color: sel ? color : borderColor),
                  labelStyle: GoogleFonts.poppins(
                    fontWeight: FontWeight.w700,
                    color: sel ? Colors.white : textPrimary,
                  ),
                  onSelected: (_) => setState(() {
                    language = l;
                    picked = null;
                    titleCtrl.clear();
                    dayCtrl.text = '$_nextDay';
                  }),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(7, (i) {
              final st = 'stage${i + 1}';
              final sel = stage == st;
              final n = all
                  .where((m) => m['language'] == language && m['stage'] == st)
                  .length;
              return ChoiceChip(
                label: Text(n > 0 ? 'Stage ${i + 1} • $n' : 'Stage ${i + 1}'),
                selected: sel,
                showCheckmark: false,
                selectedColor: langColor,
                backgroundColor: Colors.white,
                side: BorderSide(color: sel ? langColor : borderColor),
                labelStyle: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: sel ? Colors.white : textPrimary,
                ),
                onSelected: (_) => setState(() {
                  stage = st;
                  picked = null;
                  titleCtrl.clear();
                  dayCtrl.text = '$_nextDay';
                }),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _uploadCard() {
    final day = int.tryParse(dayCtrl.text.trim()) ?? 0;
    final replacing = day > 0 && _existing(day) != null;
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Upload a day',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 92,
                child: TextField(
                  controller: dayCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(2),
                  ],
                  onChanged: (_) => setState(() {}),
                  decoration: _input('Day'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: titleCtrl,
                  maxLength: 120,
                  decoration: _input(
                    'Title (e.g. Past Habit)',
                  ).copyWith(counterText: ''),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: subtitleCtrl,
            maxLength: 160,
            decoration: _input(
              'Short line under the title (optional, e.g. Past habit sentences & practice)',
            ).copyWith(counterText: ''),
          ),
          if (replacing)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Day $day is already uploaded → this will UPDATE it.',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: warningColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          const SizedBox(height: 12),
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: uploading ? null : _pick,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: picked != null ? teal.withOpacity(.08) : background,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: picked != null ? teal : borderColor),
              ),
              child: Row(
                children: [
                  Icon(
                    picked != null
                        ? Icons.picture_as_pdf_rounded
                        : Icons.upload_file_rounded,
                    color: picked != null ? teal : textSecondary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      picked != null
                          ? '${picked!.name}  •  ${_size(picked!.bytes.length)}'
                          : 'Choose PDF (max 40 MB)',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: picked != null ? textPrimary : textSecondary,
                      ),
                    ),
                  ),
                  if (picked != null)
                    IconButton(
                      onPressed: uploading
                          ? null
                          : () => setState(() => picked = null),
                      icon: const Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: textSecondary,
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'The server makes big PDFs smaller automatically, so students download faster.',
            style: GoogleFonts.poppins(fontSize: 10.5, color: textSecondary),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: uploading ? null : _upload,
              icon: uploading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Icon(
                      replacing
                          ? Icons.sync_rounded
                          : Icons.cloud_upload_rounded,
                    ),
              label: Text(
                uploading
                    ? 'Uploading… please wait'
                    : (replacing ? 'Update Day $day' : 'Upload'),
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: langColor,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _input(String label) => InputDecoration(
    labelText: label,
    labelStyle: GoogleFonts.poppins(fontSize: 12.5, color: textSecondary),
    filled: true,
    fillColor: Colors.white,
    isDense: true,
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
      borderSide: BorderSide(color: langColor),
    ),
  );

  Widget _list() {
    if (loading && all.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(30),
        child: Center(child: CircularProgressIndicator(color: primary)),
      );
    }
    final list = current;
    if (list.isEmpty) {
      return _card(
        child: Column(
          children: [
            const Icon(
              Icons.folder_open_rounded,
              color: textSecondary,
              size: 32,
            ),
            const SizedBox(height: 6),
            Text(
              'Nothing uploaded for this stage yet',
              style: GoogleFonts.poppins(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: textPrimary,
              ),
            ),
            Text(
              'Students see the material inside the app (if any).',
              style: GoogleFonts.poppins(fontSize: 11.5, color: textSecondary),
            ),
          ],
        ),
      );
    }
    return Column(
      children: list.map((m) {
        final id = m['id'].toString();
        final busy = deleting.contains(id);
        final v = (m['version'] ?? 1) as num;
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: langColor.withOpacity(.10),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'DAY',
                      style: GoogleFonts.poppins(
                        fontSize: 7.5,
                        fontWeight: FontWeight.w700,
                        color: langColor,
                      ),
                    ),
                    Text(
                      '${m['day']}',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: langColor,
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${m['title'] ?? ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: textPrimary,
                      ),
                    ),
                    if ('${m['subtitle'] ?? ''}'.isNotEmpty)
                      Text(
                        '${m['subtitle']}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: textSecondary,
                        ),
                      ),
                    Text(
                      '${_size((m['bytes'] ?? 0) as num)}${v > 1 ? '  •  updated ${v.toInt() - 1}×' : ''}',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        color: textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (busy)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else ...[
                IconButton(
                  tooltip: 'Edit title',
                  onPressed: () => _edit(m),
                  icon: const Icon(Icons.edit_outlined, color: textSecondary),
                ),
                IconButton(
                  tooltip: 'Update (upload a new PDF for this day)',
                  onPressed: uploading ? null : () => _replace(m),
                  icon: const Icon(Icons.sync_rounded, color: primary),
                ),
                IconButton(
                  tooltip: 'Delete',
                  onPressed: () => _delete(m),
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    color: dangerColor,
                  ),
                ),
              ],
            ],
          ),
        );
      }).toList(),
    );
  }
}
