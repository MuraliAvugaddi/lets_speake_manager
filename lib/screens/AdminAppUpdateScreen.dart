import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:lets_speake_manager/Api/ApiendPoints.dart';
import 'package:lets_speake_manager/Api/api_headers.dart';
import 'package:lets_speake_manager/Navigation/AdminShellNavigation.dart';

/// 📲 App update message for students.
/// After you publish a new version on the Play Store / App Store, enter its
/// build number here → every student on an older version sees
/// "New update available — Update now".
class AdminAppUpdateScreen extends StatefulWidget {
  /// true = opened from the sidebar (menu button), false = pushed screen (back button)
  final bool embedded;
  const AdminAppUpdateScreen({super.key, this.embedded = false});

  @override
  State<AdminAppUpdateScreen> createState() => _AdminAppUpdateScreenState();
}

class _PlatformForm {
  final latest = TextEditingController();
  final minimum = TextEditingController();
  final version = TextEditingController();
  final notes = TextEditingController();
  final url = TextEditingController();
  bool force = false; // minimum = latest

  void fill(Map m) {
    latest.text = '${m['latestBuild'] ?? 0}';
    minimum.text = '${m['minimumBuild'] ?? 0}';
    version.text = (m['versionName'] ?? '').toString();
    notes.text = (m['notes'] ?? '').toString();
    url.text = (m['storeUrl'] ?? '').toString();
    final l = int.tryParse(latest.text) ?? 0;
    force = l > 0 && (int.tryParse(minimum.text) ?? 0) >= l;
  }

  Map<String, dynamic> toJson() {
    final l = int.tryParse(latest.text.trim()) ?? 0;
    final m = force ? l : (int.tryParse(minimum.text.trim()) ?? 0);
    return {
      'latestBuild': l,
      'minimumBuild': m > l ? l : m,
      'versionName': version.text.trim(),
      'notes': notes.text.trim(),
      'storeUrl': url.text.trim(),
    };
  }

  void dispose() {
    for (final c in [latest, minimum, version, notes, url]) {
      c.dispose();
    }
  }
}

class _AdminAppUpdateScreenState extends State<AdminAppUpdateScreen> {
  static const Color navy = Color(0xFF155A88);
  static const Color textColor = Color(0xFF173A52);
  static const Color secondaryText = Color(0xFF678196);
  static const Color borderColor = Color(0xFFD5E5EE);
  static const Color background = Color(0xFFE8F2F8);
  static const Color success = Color(0xFF16A66A);
  static const Color error = Color(0xFFE45757);
  static const Color android = Color(0xFF16A66A);
  static const Color apple = Color(0xFF173A52);

  final _android = _PlatformForm();
  final _ios = _PlatformForm();
  bool _loading = true;
  bool _saving = false;
  String _updatedBy = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _android.dispose();
    _ios.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await http.get(Uri.parse('${ApiEndpoints.baseUrl}/app-version?_t=${DateTime.now().millisecondsSinceEpoch}'));
      if (res.statusCode == 200) {
        final d = jsonDecode(res.body);
        _android.fill(d['android'] ?? {});
        _ios.fill(d['ios'] ?? {});
        _updatedBy = (d['updatedByName'] ?? '').toString();
      }
    } catch (e) {
      debugPrint('App version load error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    HapticFeedback.mediumImpact();
    setState(() => _saving = true);
    try {
      final res = await http.put(
        Uri.parse('${ApiEndpoints.baseUrl}/admin/app-version'),
        headers: ApiHeaders.json(),
        body: jsonEncode({'android': _android.toJson(), 'ios': _ios.toJson()}),
      );
      final body = jsonDecode(res.body);
      if (res.statusCode == 200) {
        _snack('Saved', (body['message'] ?? 'Saved').toString(), success);
        await _load();
      } else {
        _snack('Not saved', (body['message'] ?? 'Error ${res.statusCode}').toString(), error);
      }
    } catch (e) {
      _snack('Connection error', '$e', error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String t, String m, Color c) {
    Get.closeCurrentSnackbar();
    Get.snackbar(t, m,
        backgroundColor: c, colorText: Colors.white, snackPosition: SnackPosition.TOP, margin: const EdgeInsets.all(14));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: widget.embedded
            ? (AdminShellNavigation.shouldShowMenuButton(context)
                ? IconButton(icon: const Icon(Icons.menu_rounded, color: textColor), onPressed: AdminShellNavigation.openDrawer)
                : null)
            : IconButton(icon: const Icon(Icons.arrow_back_rounded, color: textColor), onPressed: () => Get.back()),
        titleSpacing: widget.embedded && !AdminShellNavigation.shouldShowMenuButton(context) ? 20 : 0,
        title: Text('App update', style: GoogleFonts.poppins(color: textColor, fontSize: 16, fontWeight: FontWeight.w700)),
        bottom: const PreferredSize(preferredSize: Size.fromHeight(1), child: Divider(height: 1, color: borderColor)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: navy, strokeWidth: 2.5))
          : ListView(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 30),
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 760),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _howTo(),
                        const SizedBox(height: 14),
                        _platformCard('Android • Play Store', Icons.android_rounded, android, _android),
                        const SizedBox(height: 14),
                        _platformCard('iPhone • App Store', Icons.apple_rounded, apple, _ios, isIos: true),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton.icon(
                            onPressed: _saving ? null : _save,
                            icon: _saving
                                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : const Icon(Icons.campaign_rounded),
                            label: Text('Save & notify students',
                                style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: navy,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                          ),
                        ),
                        if (_updatedBy.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Center(
                            child: Text('Last changed by $_updatedBy',
                                style: GoogleFonts.poppins(color: secondaryText, fontSize: 10.5)),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _howTo() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: const Color(0xFFF4F9FC), borderRadius: BorderRadius.circular(16), border: Border.all(color: borderColor)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.lightbulb_rounded, color: Color(0xFFE3B21B), size: 18),
            const SizedBox(width: 7),
            Text('How to use', style: GoogleFonts.poppins(color: textColor, fontSize: 13, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 6),
          Text(
            '1. Publish the new version on the store (wait until it is LIVE).\n'
            '2. Enter its build number — the number after "+" in pubspec.yaml (version: 1.0.1+6 → 6).\n'
            '3. Save. Students on an older build see "New update available" when they open the app.\n'
            '4. Turn on "Force update" only for important fixes — then old versions can\'t be used until updated.',
            style: GoogleFonts.poppins(color: secondaryText, fontSize: 11, height: 1.55),
          ),
        ],
      ),
    );
  }

  Widget _platformCard(String title, IconData icon, Color color, _PlatformForm f, {bool isIos = false}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: borderColor)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(color: color.withOpacity(.10), borderRadius: BorderRadius.circular(11)),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 10),
              Text(title, style: GoogleFonts.poppins(color: textColor, fontSize: 14.5, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _field('Latest build', f.latest, hint: '6', number: true)),
              const SizedBox(width: 10),
              Expanded(child: _field('Version name', f.version, hint: '1.0.1')),
            ],
          ),
          const SizedBox(height: 10),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: f.force,
            activeColor: error,
            onChanged: (v) => setState(() => f.force = v),
            title: Text('Force update', style: GoogleFonts.poppins(color: textColor, fontSize: 12.5, fontWeight: FontWeight.w700)),
            subtitle: Text(
              f.force
                  ? 'Older versions are blocked until the student updates.'
                  : 'Students can tap "Later" (asked again after 1 day).',
              style: GoogleFonts.poppins(color: f.force ? error : secondaryText, fontSize: 10.5),
            ),
          ),
          if (!f.force) ...[
            _field('Minimum build (optional)', f.minimum,
                hint: '0', number: true, help: 'Builds below this number MUST update. 0 = nobody is forced.'),
            const SizedBox(height: 10),
          ],
          _field("What's new (shown to students)", f.notes, hint: '• New holiday calendar\n• Faster live class join', lines: 3),
          const SizedBox(height: 10),
          _field(isIos ? 'App Store link' : 'Play Store link', f.url,
              hint: isIos ? 'https://apps.apple.com/app/id1234567890' : 'https://play.google.com/store/apps/details?id=com.surendra.letsspeak',
              help: isIos ? 'Copy it from App Store Connect after the app is live.' : null),
        ],
      ),
    );
  }

  Widget _field(String label, TextEditingController c, {String? hint, bool number = false, int lines = 1, String? help}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.poppins(color: textColor, fontSize: 11, fontWeight: FontWeight.w700)),
        const SizedBox(height: 5),
        TextField(
          controller: c,
          maxLines: lines,
          keyboardType: number ? TextInputType.number : (lines > 1 ? TextInputType.multiline : TextInputType.url),
          inputFormatters: number ? [FilteringTextInputFormatter.digitsOnly] : null,
          style: GoogleFonts.poppins(fontSize: 12.5, color: textColor, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.poppins(fontSize: 11.5, color: secondaryText.withOpacity(.6)),
            isDense: true,
            filled: true,
            fillColor: const Color(0xFFF7FAFC),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: borderColor)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: borderColor)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: navy, width: 1.4)),
          ),
        ),
        if (help != null) ...[
          const SizedBox(height: 3),
          Text(help, style: GoogleFonts.poppins(color: secondaryText, fontSize: 9.5)),
        ],
      ],
    );
  }
}
