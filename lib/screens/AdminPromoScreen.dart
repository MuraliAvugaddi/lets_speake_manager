import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:lets_speake_manager/Api/ApiendPoints.dart';
import 'package:lets_speake_manager/Api/api_headers.dart';
import 'package:lets_speake_manager/Navigation/AdminShellNavigation.dart';
import 'package:url_launcher/url_launcher.dart';

/// Posters & Reels — the admin posts an image, an Instagram-style reel, or both.
/// Students see it as a popup when they open the app (with an X to close).
///   Get.to(() => const AdminPromoScreen());
class AdminPromoScreen extends StatefulWidget {
  /// true = opened from the admin sidebar (menu button instead of back)
  final bool embedded;
  const AdminPromoScreen({super.key, this.embedded = false});

  @override
  State<AdminPromoScreen> createState() => _AdminPromoScreenState();
}

class _PickedFile {
  final String name;
  final Uint8List bytes;
  const _PickedFile(this.name, this.bytes);
  int get size => bytes.length;
}

class _AdminPromoScreenState extends State<AdminPromoScreen> {
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
  static const Color pink = Color(0xFFD6336C);

  static const int imageMax = 10 * 1024 * 1024;
  static const int videoMax = 100 * 1024 * 1024;

  final titleCtrl = TextEditingController();
  final captionCtrl = TextEditingController();
  final igCtrl = TextEditingController(); // Instagram reel link

  String target = 'all'; // all | online | offline
  int endPreset = 0; // 0 = until turned off, 3/7/10 days, -1 = custom date
  DateTime? customEnd;

  _PickedFile? image;
  _PickedFile? video;
  bool picking = false;
  bool uploading = false;

  bool loading = true;
  String? loadError;
  List<Map<String, dynamic>> promos = [];
  final Set<String> busy = {};

  String get _api => "${ApiEndpoints.baseUrl}/promo";

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    titleCtrl.dispose();
    captionCtrl.dispose();
    igCtrl.dispose();
    super.dispose();
  }

  // =========================================================
  // HELPERS
  // =========================================================
  void _snack(String title, String msg, Color color, {IconData icon = Icons.info_outline_rounded}) {
    Get.snackbar(
      title,
      msg,
      backgroundColor: color.withOpacity(.95),
      colorText: Colors.white,
      icon: Icon(icon, color: Colors.white),
      snackPosition: SnackPosition.TOP,
      margin: const EdgeInsets.all(16),
      borderRadius: 14,
    );
  }

  String _size(int bytes) {
    if (bytes >= 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / 1024).toStringAsFixed(0)} KB';
  }

  String _msgOf(http.Response res, String fallback) {
    try {
      final b = jsonDecode(res.body);
      if (b is Map && b['message'] != null) return b['message'].toString();
    } catch (_) {}
    return '$fallback (${res.statusCode})';
  }

  DateTime? get _endsAt {
    if (endPreset == 0) return null;
    if (endPreset == -1) return customEnd;
    final now = DateTime.now();
    // end of the last day
    final d = DateTime(now.year, now.month, now.day).add(Duration(days: endPreset));
    return DateTime(d.year, d.month, d.day, 23, 59);
  }

  // =========================================================
  // NETWORK
  // =========================================================
  Future<void> _load() async {
    setState(() {
      loading = true;
      loadError = null;
    });
    try {
      final res = await http.get(Uri.parse(_api), headers: ApiHeaders.auth());
      if (!mounted) return;
      if (res.statusCode == 200) {
        final list = (jsonDecode(res.body)['promos'] as List? ?? []);
        setState(() {
          promos = list.map((e) => Map<String, dynamic>.from(e)).toList();
          loading = false;
        });
      } else {
        setState(() {
          loadError = _msgOf(res, 'Could not load posts');
          loading = false;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        loadError = 'Connection error. Check the server.';
        loading = false;
      });
    }
  }

  Future<void> _pick({required bool isVideo}) async {
    if (picking || uploading) return;
    setState(() => picking = true);
    try {
      final file = await FilePicker.pickFile(
        type: isVideo ? FileType.video : FileType.image,
        dialogTitle: isVideo ? 'Choose reel video' : 'Choose poster image',
      );
      if (file == null) return; // cancelled
      final bytes = await file.readAsBytes();
      final max = isVideo ? videoMax : imageMax;
      if (bytes.length > max) {
        _snack('Too large', isVideo ? 'Reel must be under 100 MB.' : 'Image must be under 10 MB.', red);
        return;
      }
      setState(() {
        if (isVideo) {
          video = _PickedFile(file.name, bytes);
        } else {
          image = _PickedFile(file.name, bytes);
        }
      });
    } catch (e) {
      _snack('Could not open file', '$e', red);
    } finally {
      if (mounted) setState(() => picking = false);
    }
  }

  Future<void> _publish() async {
    final ig = igCtrl.text.trim();
    if (ig.isNotEmpty && !_looksLikeInstagram(ig)) {
      _snack('Check the link', 'Paste an Instagram reel link (Instagram → Share → Copy link).', amberText);
      return;
    }
    if (image == null && video == null && ig.isEmpty) {
      _snack('Nothing to post', 'Add a poster, a reel video or an Instagram reel link.', amberText);
      return;
    }
    if (endPreset == -1 && customEnd == null) {
      _snack('Pick a date', 'Choose until when students should see it.', amberText);
      return;
    }
    setState(() => uploading = true);
    try {
      final req = http.MultipartRequest('POST', Uri.parse(_api));
      req.headers.addAll(ApiHeaders.auth());
      req.fields['title'] = titleCtrl.text.trim();
      req.fields['caption'] = captionCtrl.text.trim();
      req.fields['targetMode'] = target;
      req.fields['endsAt'] = _endsAt?.toUtc().toIso8601String() ?? '';
      if (ig.isNotEmpty) req.fields['instagramUrl'] = ig;
      if (image != null) {
        req.files.add(http.MultipartFile.fromBytes('image', image!.bytes, filename: image!.name));
      }
      if (video != null) {
        req.files.add(http.MultipartFile.fromBytes('video', video!.bytes, filename: video!.name));
      }

      final res = await http.Response.fromStream(await req.send());
      if (!mounted) return;
      if (res.statusCode == 201 || res.statusCode == 200) {
        _snack('Posted', 'Students on the home screen see it right now.', green, icon: Icons.check_circle_rounded);
        setState(() {
          image = null;
          video = null;
          igCtrl.clear();
          titleCtrl.clear();
          captionCtrl.clear();
          endPreset = 0;
          customEnd = null;
        });
        _load();
      } else {
        _snack('Upload failed', _msgOf(res, 'Could not post'), red, icon: Icons.error_outline_rounded);
      }
    } catch (e) {
      _snack('Upload failed', 'Connection error: $e', red, icon: Icons.error_outline_rounded);
    } finally {
      if (mounted) setState(() => uploading = false);
    }
  }

  bool _looksLikeInstagram(String v) =>
      RegExp(r'instagram\.com/(?:[A-Za-z0-9_.]+/)?(reels?|p|tv)/[A-Za-z0-9_-]{5,}', caseSensitive: false).hasMatch(v);

  /// Instagram link box (paste a reel link instead of uploading a video)
  Widget _instagramField() {
    final text = igCtrl.text.trim();
    final ok = text.isNotEmpty && _looksLikeInstagram(text);
    final bad = text.isNotEmpty && !ok;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ok ? pink.withOpacity(.6) : (bad ? red.withOpacity(.6) : borderColor)),
        gradient: LinearGradient(colors: [const Color(0xFF833AB4).withOpacity(.05), const Color(0xFFF08C00).withOpacity(.05)]),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF833AB4), Color(0xFFD6336C), Color(0xFFF08C00)]),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: igCtrl,
              onChanged: (_) => setState(() {}),
              style: GoogleFonts.poppins(color: textColor, fontSize: 12),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                labelText: 'Instagram reel link (optional)',
                labelStyle: GoogleFonts.poppins(color: secondaryText, fontSize: 11),
                hintText: 'https://www.instagram.com/reel/…',
                hintStyle: GoogleFonts.poppins(color: secondaryText.withOpacity(.6), fontSize: 11),
                helperText: bad
                    ? 'Not an Instagram reel link'
                    : (ok ? 'Plays inside the app for students' : 'Instagram → Share → Copy link'),
                helperStyle: GoogleFonts.poppins(color: bad ? red : (ok ? green : secondaryText), fontSize: 9.5),
              ),
            ),
          ),
          if (text.isNotEmpty)
            IconButton(
              tooltip: 'Clear',
              onPressed: () => setState(igCtrl.clear),
              icon: const Icon(Icons.close_rounded, size: 18, color: secondaryText),
            ),
        ],
      ),
    );
  }

  Future<void> _toggle(Map<String, dynamic> p, bool active) async {
    final id = (p['_id'] ?? '').toString();
    setState(() => busy.add(id));
    try {
      final res = await http.patch(
        Uri.parse('$_api/$id'),
        headers: ApiHeaders.json(),
        body: jsonEncode({'active': active}),
      );
      if (res.statusCode == 200) {
        await _load();
      } else {
        _snack('Not updated', _msgOf(res, 'Could not update'), red);
      }
    } catch (_) {
      _snack('Not updated', 'Connection error', red);
    } finally {
      if (mounted) setState(() => busy.remove(id));
    }
  }

  Future<void> _delete(Map<String, dynamic> p) async {
    final id = (p['_id'] ?? '').toString();
    final ok = await Get.dialog<bool>(
      AlertDialog(
        backgroundColor: cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('Delete this post?',
            style: GoogleFonts.poppins(color: textColor, fontWeight: FontWeight.w700, fontSize: 16)),
        content: Text('The image and reel are removed from students and from Cloudinary.',
            style: GoogleFonts.poppins(color: secondaryText, fontSize: 12.5)),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: Text('Cancel', style: GoogleFonts.poppins(color: secondaryText, fontWeight: FontWeight.w600)),
          ),
          TextButton(
            onPressed: () => Get.back(result: true),
            child: Text('Delete', style: GoogleFonts.poppins(color: red, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => busy.add(id));
    try {
      final res = await http.delete(Uri.parse('$_api/$id'), headers: ApiHeaders.auth());
      if (res.statusCode == 200) {
        _snack('Deleted', 'Post removed.', navy, icon: Icons.delete_outline_rounded);
        await _load();
      } else {
        _snack('Not deleted', _msgOf(res, 'Could not delete'), red);
      }
    } catch (_) {
      _snack('Not deleted', 'Connection error', red);
    } finally {
      if (mounted) setState(() => busy.remove(id));
    }
  }

  Future<void> _openUrl(String url) async {
    if (url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  // =========================================================
  // BUILD
  // =========================================================
  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final wide = width >= 1000;
    final pad = wide ? 24.0 : 14.0;

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
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [pink, Color(0xFFF08C00)]),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.perm_media_rounded, color: Colors.white, size: 19),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Posters & Reels',
                    style: GoogleFonts.poppins(color: textColor, fontSize: 16, fontWeight: FontWeight.w700)),
                Text('Shown as a popup when students open the app',
                    style: GoogleFonts.poppins(color: secondaryText, fontSize: 9.5)),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded, color: textColor),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: wide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 440,
                        child: SingleChildScrollView(
                          padding: EdgeInsets.fromLTRB(pad, 16, 8, 24),
                          child: _buildForm(),
                        ),
                      ),
                      Expanded(
                        child: RefreshIndicator(
                          onRefresh: _load,
                          color: navy,
                          child: ListView(
                            padding: EdgeInsets.fromLTRB(8, 16, pad, 24),
                            children: _buildList(),
                          ),
                        ),
                      ),
                    ],
                  )
                : RefreshIndicator(
                    onRefresh: _load,
                    color: navy,
                    child: ListView(
                      padding: EdgeInsets.fromLTRB(pad, 14, pad, 24),
                      children: [
                        _buildForm(),
                        const SizedBox(height: 18),
                        ..._buildList(),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  // =========================================================
  // NEW POST FORM
  // =========================================================
  Widget _buildForm() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('New post', style: GoogleFonts.poppins(color: textColor, fontSize: 14, fontWeight: FontWeight.w700)),
          Text('Add a poster, a reel video, an Instagram reel link — or a mix',
              style: GoogleFonts.poppins(color: secondaryText, fontSize: 10)),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _imageBox()),
              const SizedBox(width: 10),
              Expanded(child: _videoBox()),
            ],
          ),
          const SizedBox(height: 10),
          _instagramField(),
          const SizedBox(height: 14),
          _field(titleCtrl, 'Title', 'Dussehra — 10 days to go!', maxLength: 120),
          const SizedBox(height: 10),
          _field(captionCtrl, 'Caption (optional)', 'Special speaking session on Saturday. Don\'t miss it!',
              maxLines: 3, maxLength: 500),
          const SizedBox(height: 14),
          _label('Show to'),
          const SizedBox(height: 6),
          _segmented([
            _seg('All students', Icons.groups_rounded, target == 'all', () => setState(() => target = 'all')),
            _seg('Online', Icons.wifi_rounded, target == 'online', () => setState(() => target = 'online')),
            _seg('Offline', Icons.location_on_rounded, target == 'offline', () => setState(() => target = 'offline')),
          ]),
          const SizedBox(height: 14),
          _label('Show until'),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _chip('I turn it off', endPreset == 0, () => setState(() => endPreset = 0)),
              _chip('3 days', endPreset == 3, () => setState(() => endPreset = 3)),
              _chip('7 days', endPreset == 7, () => setState(() => endPreset = 7)),
              _chip('10 days', endPreset == 10, () => setState(() => endPreset = 10)),
              _chip(
                endPreset == -1 && customEnd != null ? DateFormat('d MMM').format(customEnd!) : 'Pick date',
                endPreset == -1,
                _pickEndDate,
                icon: Icons.event_rounded,
              ),
            ],
          ),
          if (_endsAt != null) ...[
            const SizedBox(height: 6),
            Text('Hides automatically on ${DateFormat('d MMM yyyy, h:mm a').format(_endsAt!)}',
                style: GoogleFonts.poppins(color: secondaryText, fontSize: 9.8)),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: uploading ? null : _publish,
              icon: uploading
                  ? const SizedBox(
                      width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.send_rounded, size: 17),
              label: Text(
                uploading ? (video != null ? 'Uploading reel… please wait' : 'Uploading…') : 'Publish to students',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 12.5),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: navy,
                foregroundColor: Colors.white,
                disabledBackgroundColor: navy.withOpacity(.65),
                disabledForegroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
              ),
            ),
          ),
          if (uploading && video != null) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: const LinearProgressIndicator(minHeight: 3, color: navy, backgroundColor: subtle),
            ),
            const SizedBox(height: 4),
            Text('Big reels can take a minute. Keep this screen open.',
                style: GoogleFonts.poppins(color: secondaryText, fontSize: 9.5)),
          ],
        ],
      ),
    );
  }

  Future<void> _pickEndDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: customEnd ?? now.add(const Duration(days: 10)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (d == null) return;
    setState(() {
      endPreset = -1;
      customEnd = DateTime(d.year, d.month, d.day, 23, 59);
    });
  }

  Widget _label(String t) =>
      Text(t, style: GoogleFonts.poppins(color: textColor, fontSize: 11.5, fontWeight: FontWeight.w700));

  Widget _field(TextEditingController c, String label, String hint, {int maxLines = 1, int? maxLength}) {
    return TextField(
      controller: c,
      maxLines: maxLines,
      maxLength: maxLength,
      style: GoogleFonts.poppins(color: textColor, fontSize: 12.5),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        counterText: '',
        labelStyle: GoogleFonts.poppins(color: secondaryText, fontSize: 11.5),
        hintStyle: GoogleFonts.poppins(color: secondaryText.withOpacity(.6), fontSize: 11.5),
        filled: true,
        fillColor: bg,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: borderColor)),
        enabledBorder:
            OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: borderColor)),
        focusedBorder:
            OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: blue, width: 1.4)),
      ),
    );
  }

  Widget _segmented(List<Widget> items) => Container(
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

  Widget _seg(String t, IconData icon, bool selected, VoidCallback onTap) => InkWell(
        borderRadius: BorderRadius.circular(9),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
          decoration: BoxDecoration(
            color: selected ? navy : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: selected ? Colors.white : secondaryText),
              const SizedBox(width: 4),
              Flexible(
                child: Text(t,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                        color: selected ? Colors.white : secondaryText, fontSize: 10.5, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
      );

  Widget _chip(String t, bool selected, VoidCallback onTap, {IconData? icon}) => InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
          decoration: BoxDecoration(
            color: selected ? navy : cardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: selected ? navy : borderColor),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 13, color: selected ? Colors.white : secondaryText),
                const SizedBox(width: 4),
              ],
              Text(t,
                  style: GoogleFonts.poppins(
                      color: selected ? Colors.white : textColor, fontSize: 10.5, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      );

  // ---------------- media boxes ----------------
  Widget _emptyBox({
    required IconData icon,
    required String title,
    required String hint,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        height: 180,
        decoration: BoxDecoration(
          color: color.withOpacity(.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(.35), width: 1.3),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: color.withOpacity(.12), shape: BoxShape.circle),
              child: picking
                  ? Padding(
                      padding: const EdgeInsets.all(12),
                      child: CircularProgressIndicator(strokeWidth: 2, color: color),
                    )
                  : Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 8),
            Text(title, style: GoogleFonts.poppins(color: textColor, fontSize: 12, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(hint,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(color: secondaryText, fontSize: 9, height: 1.3)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _removeButton(VoidCallback onTap) => Positioned(
        top: 6,
        right: 6,
        child: Material(
          color: Colors.black.withOpacity(.55),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: uploading ? null : onTap,
            child: const Padding(
              padding: EdgeInsets.all(5),
              child: Icon(Icons.close_rounded, color: Colors.white, size: 16),
            ),
          ),
        ),
      );

  Widget _fileTag(String text) => Positioned(
        left: 6,
        right: 6,
        bottom: 6,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(color: Colors.black.withOpacity(.55), borderRadius: BorderRadius.circular(7)),
          child: Text(text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w600)),
        ),
      );

  Widget _imageBox() {
    if (image == null) {
      return _emptyBox(
        icon: Icons.add_photo_alternate_rounded,
        title: 'Add poster',
        hint: 'JPG / PNG • max 10 MB',
        color: blue,
        onTap: () => _pick(isVideo: false),
      );
    }
    return SizedBox(
      height: 180,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.memory(image!.bytes, fit: BoxFit.cover),
          ),
          _removeButton(() => setState(() => image = null)),
          _fileTag('🖼  ${_size(image!.size)}'),
        ],
      ),
    );
  }

  Widget _videoBox() {
    if (video == null) {
      return _emptyBox(
        icon: Icons.video_library_rounded,
        title: 'Add reel',
        hint: 'MP4 / MOV • max 100 MB\nVertical 9:16 works best',
        color: pink,
        onTap: () => _pick(isVideo: true),
      );
    }
    return SizedBox(
      height: 180,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF833AB4), pink, Color(0xFFF08C00)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 44),
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text(video!.name,
                      maxLines: 2,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
          _removeButton(() => setState(() => video = null)),
          _fileTag('🎬  ${_size(video!.size)}'),
        ],
      ),
    );
  }

  // =========================================================
  // POSTS LIST
  // =========================================================
  List<Widget> _buildList() {
    final live = promos.where((p) => p['live'] == true).length;
    return [
      Row(
        children: [
          Expanded(
            child: Text('Posts',
                style: GoogleFonts.poppins(color: textColor, fontSize: 14, fontWeight: FontWeight.w700)),
          ),
          if (!loading && promos.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(color: green.withOpacity(.10), borderRadius: BorderRadius.circular(8)),
              child: Text('$live live now',
                  style: GoogleFonts.poppins(color: green, fontSize: 10, fontWeight: FontWeight.w700)),
            ),
        ],
      ),
      const SizedBox(height: 8),
      if (loading)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 50),
          child: Center(child: CircularProgressIndicator(color: navy, strokeWidth: 2.2)),
        )
      else if (loadError != null)
        _message(Icons.error_outline_rounded, loadError!, red)
      else if (promos.isEmpty)
        _message(Icons.perm_media_outlined, 'No posts yet.\nAdd a poster or reel to show students a popup.', secondaryText)
      else
        ...promos.map(_postCard),
    ];
  }

  Widget _message(IconData icon, String text, Color color) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 30),
            const SizedBox(height: 8),
            Text(text,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(color: textColor, fontSize: 12, height: 1.45)),
          ],
        ),
      );

  Widget _postCard(Map<String, dynamic> p) {
    final id = (p['_id'] ?? '').toString();
    final img = p['image'] is Map ? Map<String, dynamic>.from(p['image']) : <String, dynamic>{};
    final vid = p['video'] is Map ? Map<String, dynamic>.from(p['video']) : <String, dynamic>{};
    final hasImg = (img['url'] ?? '').toString().isNotEmpty;
    final hasVid = (vid['url'] ?? '').toString().isNotEmpty;
    final ig = p['instagram'] is Map ? Map<String, dynamic>.from(p['instagram']) : <String, dynamic>{};
    final hasIg = (ig['code'] ?? '').toString().isNotEmpty;
    final active = p['active'] == true;
    final ended = p['ended'] == true;
    final live = p['live'] == true;
    final title = (p['title'] ?? '').toString().trim();
    final caption = (p['caption'] ?? '').toString().trim();
    final targetMode = (p['targetMode'] ?? 'all').toString();
    final created = DateTime.tryParse((p['createdAt'] ?? '').toString())?.toLocal();
    final endsAt = DateTime.tryParse((p['endsAt'] ?? '').toString())?.toLocal();
    final isBusy = busy.contains(id);

    final status = live ? 'Live' : (ended ? 'Ended' : (active ? 'Not live' : 'Hidden'));
    final statusColor = live ? green : (ended ? secondaryText : amberText);

    Widget thumb(String url, {bool video = false, required String openUrl}) => InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => _openUrl(openUrl),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 62,
              height: 86,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    url,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: video ? pink.withOpacity(.15) : subtle,
                      child: Icon(video ? Icons.movie_rounded : Icons.image_rounded,
                          color: video ? pink : secondaryText),
                    ),
                  ),
                  if (video)
                    const Center(child: Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 26)),
                ],
              ),
            ),
          ),
        );

    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Opacity(
        opacity: live ? 1 : .75,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: live ? green.withOpacity(.35) : borderColor),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (hasImg) thumb(img['url'].toString(), openUrl: (img['originalUrl'] ?? img['url']).toString()),
              if (hasImg && hasVid) const SizedBox(width: 6),
              if (hasVid)
                thumb((vid['thumbUrl'] ?? '').toString(),
                    video: true, openUrl: (vid['originalUrl'] ?? vid['url']).toString()),
              if ((hasImg || hasVid) && hasIg) const SizedBox(width: 6),
              if (hasIg)
                InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => _openUrl((ig['url'] ?? '').toString()),
                  child: Container(
                    width: 62,
                    height: 86,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF833AB4), Color(0xFFD6336C), Color(0xFFF08C00)],
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.camera_alt_rounded, color: Colors.white, size: 22),
                        SizedBox(height: 4),
                        Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 20),
                      ],
                    ),
                  ),
                ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title.isEmpty ? '(No title)' : title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(color: textColor, fontSize: 12.5, fontWeight: FontWeight.w700)),
                    if (caption.isNotEmpty)
                      Text(caption,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(color: secondaryText, fontSize: 10)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 5,
                      runSpacing: 5,
                      children: [
                        _tag(status, statusColor),
                        _tag(
                            targetMode == 'all'
                                ? 'All students'
                                : targetMode == 'online'
                                    ? 'Online'
                                    : 'Offline',
                            blue),
                        if (hasImg) _tag('Poster', navy),
                        if (hasIg) _tag('Instagram reel', const Color(0xFFD6336C)),
                        if (hasVid)
                          _tag(
                              'Reel${(vid['duration'] ?? 0) is num && (vid['duration'] as num) > 0 ? ' • ${vid['duration']}s' : ''}',
                              pink),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      [
                        if (created != null) 'Posted ${DateFormat('d MMM, h:mm a').format(created)}',
                        if (endsAt != null) '${ended ? 'Ended' : 'Until'} ${DateFormat('d MMM').format(endsAt)}',
                      ].join('  •  '),
                      style: GoogleFonts.poppins(color: secondaryText, fontSize: 9),
                    ),
                  ],
                ),
              ),
              Column(
                children: [
                  isBusy
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                              width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: navy)),
                        )
                      : Switch(
                          value: active,
                          activeColor: green,
                          onChanged: (v) => _toggle(p, v),
                        ),
                  IconButton(
                    tooltip: 'Delete',
                    onPressed: isBusy ? null : () => _delete(p),
                    icon: const Icon(Icons.delete_outline_rounded, color: red, size: 20),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tag(String t, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(color: c.withOpacity(.10), borderRadius: BorderRadius.circular(6)),
        child: Text(t, style: GoogleFonts.poppins(color: c, fontSize: 9, fontWeight: FontWeight.w700)),
      );
}
