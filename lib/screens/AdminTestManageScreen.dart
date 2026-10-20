import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:lets_speake_manager/Api/ApiendPoints.dart';
import 'package:lets_speake_manager/Api/api_headers.dart';
import 'package:lets_speake_manager/Navigation/AdminShellNavigation.dart';



class AdminTestManageScreen extends StatefulWidget {
  const AdminTestManageScreen({super.key});

  @override
  State<AdminTestManageScreen> createState() => _AdminTestManageScreenState();
}

class _AdminTestManageScreenState extends State<AdminTestManageScreen> {
  // Let's Speak logo palette — LIGHT ADMIN UI ONLY.
  static const Color navy = Color(0xFF155A88);
  static const Color deepNavy = Color(0xFF0E466D);
  static const Color blue = Color(0xFF2C6F9F);
  static const Color teal = Color(0xFF28C2C2);
  static const Color yellow = Color(0xFFF7DF55);

  static const Color background = Color(0xFFE8F2F8);
  static const Color surface = Colors.white;
  static const Color soft = Color(0xFFF4F9FC);
  static const Color border = Color(0xFFD5E5EE);
  static const Color text = Color(0xFF173A52);
  static const Color secondary = Color(0xFF678196);
  static const Color success = Color(0xFF16A66A);
  static const Color error = Color(0xFFE45757);
  static const Color warning = Color(0xFFF2B84B);

  late String selectedLanguage;
  late String selectedStage;

  int selectedTab = 0;
  int? correctOption;
  bool isUploading = false;
  bool isFetchingResults = false;

  final questionController = TextEditingController();
  final opt1Controller = TextEditingController();
  final opt2Controller = TextEditingController();
  final opt3Controller = TextEditingController();
  final opt4Controller = TextEditingController();

  final List<String> allStages = const [
    'stage1',
    'stage2',
    'stage3',
    'stage4',
    'stage5',
    'stage6',
    'stage7',
  ];

  List<Map<String, dynamic>> questionsList = [];
  List<dynamic> resultsList = [];

  // The test students see right now for the selected language + stage
  Map<String, dynamic>? liveTest; // null = loading
  bool togglingActive = false;
  int durationMinutes = 25;

  @override
  void initState() {
    super.initState();
    selectedLanguage = 'English';
    selectedStage = 'stage1';
    fetchResults();
    fetchLiveTest();
  }

  // ---------------------------------------------------------------
  // LIVE TEST (what students see now)
  // ---------------------------------------------------------------
  Future<void> fetchLiveTest() async {
    if (mounted) setState(() => liveTest = null);
    try {
      final res = await http.get(
        Uri.parse('${ApiEndpoints.baseUrl}/test/admin/get-test?language=$selectedLanguage&stage=$selectedStage'),
        headers: ApiHeaders.auth(),
      );
      if (!mounted) return;
      if (res.statusCode == 200) {
        final data = Map<String, dynamic>.from(jsonDecode(res.body));
        setState(() {
          liveTest = data;
          if (data['exists'] == true) {
            durationMinutes = int.tryParse('${data['durationMinutes'] ?? 25}') ?? 25;
          }
        });
      } else {
        setState(() => liveTest = {'exists': false, 'error': true});
      }
    } catch (e) {
      debugPrint('fetchLiveTest error: $e');
      if (mounted) setState(() => liveTest = {'exists': false, 'error': true});
    }
  }

  Future<void> toggleActive(bool active) async {
    setState(() => togglingActive = true);
    try {
      final res = await http.post(
        Uri.parse('${ApiEndpoints.baseUrl}/test/admin/test-active'),
        headers: ApiHeaders.json(),
        body: jsonEncode({'language': selectedLanguage, 'stage': selectedStage, 'isActive': active}),
      );
      if (res.statusCode == 200) {
        _showMessage(active ? 'Test is live' : 'Test paused',
            active ? 'Students can take it now.' : 'Students can\'t start it until you resume. Results are kept.',
            color: active ? success : warning);
        await fetchLiveTest();
      } else {
        _showMessage('Could not change', 'Server error (${res.statusCode}).', color: error);
      }
    } catch (_) {
      _showMessage('Connection error', 'Please try again.', color: error);
    } finally {
      if (mounted) setState(() => togglingActive = false);
    }
  }

  void showLiveQuestions() {
    final qs = List<dynamic>.from(liveTest?['questions'] ?? const []);
    Get.bottomSheet(
      Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        decoration: const BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: border, borderRadius: BorderRadius.circular(4)),
              ),
            ),
            const SizedBox(height: 12),
            Text('$selectedLanguage • ${_stageLabel(selectedStage)} — ${qs.length} questions',
                style: GoogleFonts.poppins(color: text, fontSize: 15, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: qs.length,
                itemBuilder: (_, i) {
                  final q = Map<String, dynamic>.from(qs[i] as Map);
                  return _queueItemReadOnly(i, q);
                },
              ),
            ),
          ],
        ),
      ),
      isScrollControlled: true,
    );
  }

  Widget _queueItemReadOnly(int index, Map<String, dynamic> question) {
    final options = List<dynamic>.from(question['options'] ?? const []);
    final correct = _asInt(question['correctOptionIndex']);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(color: soft, borderRadius: BorderRadius.circular(12), border: Border.all(color: border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${index + 1}. ${question['questionText'] ?? ''}',
              style: GoogleFonts.poppins(color: text, fontSize: 11.5, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          ...List.generate(options.length, (o) {
            final ok = o == correct;
            return Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Row(
                children: [
                  Icon(ok ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                      size: 14, color: ok ? success : secondary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text('${options[o]}',
                        style: GoogleFonts.poppins(
                            color: ok ? success : text, fontSize: 10.5, fontWeight: ok ? FontWeight.w700 : FontWeight.w500)),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  String _shortDate(dynamic iso) {
    final d = DateTime.tryParse('${iso ?? ''}')?.toLocal();
    if (d == null) return '';
    const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    return '${d.day} ${m[d.month - 1]}, $h:${d.minute.toString().padLeft(2, '0')} ${d.hour >= 12 ? 'PM' : 'AM'}';
  }

  /// "What students see now" card: live / paused / none + actions
  Widget _buildLiveTestCard() {
    final t = liveTest;
    if (t == null) {
      return _card(
        padding: const EdgeInsets.symmetric(vertical: 22),
        child: const Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: navy))),
      );
    }
    final exists = t['exists'] == true;
    final active = t['isActive'] == true;
    final qCount = (t['questions'] as List?)?.length ?? 0;
    final submissions = _asInt(t['submissions']);
    final kept = _asInt(t['totalResults']);
    final Color c = !exists ? secondary : (active ? success : warning);

    return _card(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(color: c.withAlpha(30), borderRadius: BorderRadius.circular(11)),
                child: Icon(!exists ? Icons.inbox_rounded : (active ? Icons.wifi_tethering_rounded : Icons.pause_circle_rounded),
                    color: c, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      !exists
                          ? 'No test for ${_stageLabel(selectedStage)} yet'
                          : active
                              ? 'Live for students'
                              : 'Paused — students can\'t start it',
                      style: GoogleFonts.poppins(color: text, fontSize: 13, fontWeight: FontWeight.w800),
                    ),
                    Text(
                      !exists
                          ? (kept > 0 ? '$kept old results are saved. Publish a test below.' : 'Add questions below and publish.')
                          : '$qCount questions • $durationMinutes min • published ${_shortDate(t['publishedAt'])}',
                      style: GoogleFonts.poppins(color: secondary, fontSize: 10, height: 1.35),
                    ),
                  ],
                ),
              ),
              if (exists)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(color: soft, borderRadius: BorderRadius.circular(20)),
                  child: Text('$submissions done',
                      style: GoogleFonts.poppins(color: navy, fontSize: 10, fontWeight: FontWeight.w800)),
                ),
            ],
          ),
          if (exists) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _smallAction(Icons.visibility_rounded, 'View questions', navy, showLiveQuestions),
                _smallAction(
                  active ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  togglingActive ? 'Saving…' : (active ? 'Pause' : 'Resume'),
                  active ? warning : success,
                  togglingActive ? null : () => toggleActive(!active),
                ),
                _smallAction(Icons.delete_outline_rounded, 'Delete test', error, deleteTest),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _smallAction(IconData icon, String label, Color color, VoidCallback? onTap) => OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 16),
        label: Text(label, style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w700)),
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color.withAlpha(90)),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );

  @override
  void dispose() {
    questionController.dispose();
    opt1Controller.dispose();
    opt2Controller.dispose();
    opt3Controller.dispose();
    opt4Controller.dispose();
    super.dispose();
  }

  void _openAdminDrawerOrBack() {
    final scaffold = AdminShellNavigation.scaffoldKey.currentState;
    if (scaffold != null) {
      AdminShellNavigation.openDrawer();
    } else if (Navigator.of(context).canPop()) {
      Get.back();
    }
  }

  String _stageLabel(String value) => value.replaceFirst('stage', 'Stage ');

  void _showMessage(
    String title,
    String message, {
    Color color = navy,
    Duration duration = const Duration(seconds: 3),
  }) {
    Get.snackbar(
      title,
      message,
      backgroundColor: color,
      colorText: Colors.white,
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.all(14),
      borderRadius: 12,
      duration: duration,
      snackStyle: SnackStyle.FLOATING,
    );
  }

  Future<void> uploadTest() async {
    if (questionsList.isEmpty) {
      _showMessage(
        'Nothing to publish',
        'Add at least one question to the queue first.',
        color: warning,
      );
      return;
    }

    // Replacing a live test → confirm first
    if (liveTest?['exists'] == true) {
      final ok = await Get.dialog<bool>(
        AlertDialog(
          backgroundColor: surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Text('Replace the current test?',
              style: GoogleFonts.poppins(color: text, fontSize: 16, fontWeight: FontWeight.w700)),
          content: Text(
            'The ${(liveTest?['questions'] as List?)?.length ?? 0}-question test will be replaced by these ${questionsList.length} questions.\n\n'
            '• All students can take the new test\n• Old results stay saved',
            style: GoogleFonts.poppins(color: secondary, fontSize: 12, height: 1.5),
          ),
          actions: [
            TextButton(onPressed: () => Get.back(result: false), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () => Get.back(result: true),
              style: ElevatedButton.styleFrom(backgroundColor: navy, foregroundColor: Colors.white, elevation: 0),
              child: const Text('Replace & publish'),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }

    setState(() => isUploading = true);

    try {
      final response = await http.post(
        Uri.parse(ApiEndpoints.updateTest),
        headers: ApiHeaders.json(),
        body: jsonEncode({
          'language': selectedLanguage,
          'stage': selectedStage,
          'isActive': true,
          'durationMinutes': durationMinutes,
          'questions': questionsList,
        }),
      );

      if (response.statusCode == 200) {
        if (!mounted) return;
        setState(() => questionsList.clear());
        _showMessage(
          'Test published',
          '$selectedLanguage ${_stageLabel(selectedStage)} is now live for students.',
          color: success,
        );
        fetchLiveTest();
      } else {
        String message = 'Upload failed.';
        try {
          final decoded = jsonDecode(response.body);
          if (decoded is Map && decoded['message'] != null) {
            message = decoded['message'].toString();
          }
        } catch (_) {}
        _showMessage('Publish failed', message, color: error);
      }
    } catch (e) {
      debugPrint('uploadTest error: $e');
      _showMessage(
        'Connection error',
        'Could not connect to the server. Please try again.',
        color: error,
      );
    } finally {
      if (mounted) setState(() => isUploading = false);
    }
  }

  Future<void> deleteTest() async {
    Get.defaultDialog(
      title: 'Delete this test?',
      middleText:
          'The $selectedLanguage ${_stageLabel(selectedStage)} test will be removed for students.\n\nStudent results are NOT deleted — they stay saved.',
      textConfirm: 'Delete test',
      textCancel: 'Cancel',
      confirmTextColor: Colors.white,
      buttonColor: error,
      backgroundColor: surface,
      titleStyle: GoogleFonts.poppins(
        color: text,
        fontSize: 17,
        fontWeight: FontWeight.w700,
      ),
      middleTextStyle: GoogleFonts.poppins(
        color: secondary,
        fontSize: 12,
        height: 1.5,
      ),
      onConfirm: () async {
        Get.back();

        try {
          final request = http.Request(
            'DELETE',
            Uri.parse(ApiEndpoints.deleteTest),
          );
          request.headers.addAll(ApiHeaders.json());
          request.body = jsonEncode({
            'language': selectedLanguage,
            'stage': selectedStage,
          });

          final streamed = await request.send();
          final response = await http.Response.fromStream(streamed);

          if (response.statusCode == 200) {
            String kept = '';
            try {
              final d = jsonDecode(response.body);
              if (d is Map && d['resultsKept'] != null) kept = ' ${d['resultsKept']} results kept.';
            } catch (_) {}
            _showMessage(
              'Test deleted',
              'Students no longer see this test.$kept',
              color: success,
            );
            await fetchLiveTest();
            await fetchResults();
          } else {
            _showMessage(
              'Delete failed',
              'The server could not remove this test.',
              color: error,
            );
          }
        } catch (e) {
          debugPrint('deleteTest error: $e');
          _showMessage(
            'Connection error',
            'Could not delete the test. Please try again.',
            color: error,
          );
        }
      },
    );
  }

  Future<void> fetchResults() async {
    if (mounted) setState(() => isFetchingResults = true);

    try {
      final response = await http.get(
        Uri.parse(
          '${ApiEndpoints.testResults}?language=$selectedLanguage&stage=$selectedStage',
        ),
        headers: ApiHeaders.auth(),
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        List<dynamic> normalized = [];

        if (decoded is List) {
          normalized = decoded;
        } else if (decoded is Map) {
          final possible = [
            decoded['results'],
            decoded['data'],
            decoded['testResults'],
            decoded['submissions'],
          ];
          for (final value in possible) {
            if (value is List) {
              normalized = value;
              break;
            }
          }
        }

        if (mounted) {
          setState(() => resultsList = normalized);
        }
      } else if (mounted) {
        setState(() => resultsList = []);
      }
    } catch (e) {
      debugPrint('fetchResults error: $e');
      if (mounted) setState(() => resultsList = []);
    } finally {
      if (mounted) setState(() => isFetchingResults = false);
    }
  }

  void addQuestion() {
    final question = questionController.text.trim();
    final options = [
      opt1Controller.text.trim(),
      opt2Controller.text.trim(),
      opt3Controller.text.trim(),
      opt4Controller.text.trim(),
    ];

    if (question.isEmpty || options.any((value) => value.isEmpty)) {
      _showMessage(
        'Complete the question',
        'Enter the question and all four answer options.',
        color: error,
      );
      return;
    }

    if (correctOption == null) {
      _showMessage(
        'Choose the answer',
        'Select which option is correct before adding the question.',
        color: warning,
      );
      return;
    }

    setState(() {
      questionsList.add({
        'questionText': question,
        'options': options,
        'correctOptionIndex': correctOption,
      });

      questionController.clear();
      opt1Controller.clear();
      opt2Controller.clear();
      opt3Controller.clear();
      opt4Controller.clear();
      correctOption = null;
    });

    _showMessage(
      'Question added',
      '${questionsList.length} question${questionsList.length == 1 ? '' : 's'} in the queue.',
      color: navy,
      duration: const Duration(seconds: 2),
    );
  }

  List<dynamic> _getFilteredResults(String requestedType) {
    final wanted = requestedType.toLowerCase();

    return resultsList.where((item) {
      if (item is! Map) return false;

      String value(dynamic v) => v?.toString().trim().toLowerCase() ?? '';

      final values = <String>[
        value(item['type']),
        value(item['mode']),
        value(item['userType']),
        value(item['studentType']),
        value(item['userMode']),
        value(item['attendanceType']),
        value(item['learningMode']),
        value(item['channel']),
      ];

      final user = item['user'];
      if (user is Map) {
        values.addAll([
          value(user['type']),
          value(user['mode']),
          value(user['userType']),
          value(user['studentType']),
          value(user['userMode']),
          value(user['learningMode']),
          value(user['channel']),
        ]);
      }

      return values.any((v) {
        if (v == wanted) return true;
        if (wanted == 'online') {
          return v.contains('online');
        }
        if (wanted == 'offline') {
          return v.contains('offline');
        }
        return false;
      });
    }).toList();
  }

  void _changeLanguage(String value) {
    if (selectedLanguage == value) return;
    setState(() => selectedLanguage = value);
    fetchLiveTest();
    if (selectedTab == 1) fetchResults();
  }

  void _changeStage(String value) {
    if (selectedStage == value) return;
    setState(() => selectedStage = value);
    fetchLiveTest();
    if (selectedTab == 1) fetchResults();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = width >= 1050;
    final isTablet = width >= 700 && width < 1050;

    return Scaffold(
      backgroundColor: background,
      appBar: _buildAppBar(isDesktop),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1320),
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    isDesktop
                        ? 28
                        : isTablet
                        ? 20
                        : 12,
                    12,
                    isDesktop
                        ? 28
                        : isTablet
                        ? 20
                        : 12,
                    0,
                  ),
                  child: _buildTabs(),
                ),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    // Keep the selected page pinned to the top.
                    // The default AnimatedSwitcher layout can center a
                    // short child vertically, creating a large blank gap
                    // below the Create & Publish / Student Results tabs.
                    layoutBuilder: (currentChild, previousChildren) {
                      return Stack(
                        alignment: Alignment.topCenter,
                        children: <Widget>[
                          ...previousChildren,
                          if (currentChild != null) currentChild,
                        ],
                      );
                    },
                    child: selectedTab == 0
                        ? _buildCreatePage(
                            isDesktop: isDesktop,
                            isTablet: isTablet,
                          )
                        : _buildResultsPage(
                            isDesktop: isDesktop,
                            isTablet: isTablet,
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(bool isDesktop) {
    return AppBar(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      toolbarHeight: isDesktop ? 70 : 58,
      leading: IconButton(
        tooltip: 'Open menu',
        onPressed: _openAdminDrawerOrBack,
        icon: const Icon(Icons.menu_rounded, color: text),
      ),
      titleSpacing: 0,
      title: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [deepNavy, blue]),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.quiz_rounded,
              color: Colors.white,
              size: 19,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'Test Management',
            style: GoogleFonts.poppins(
              color: text,
              fontSize: isDesktop ? 18 : 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
      actions: [
        if (questionsList.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: _queueBadge(),
          ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: border),
      ),
    );
  }

  Widget _buildTabs() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 800;

        return Container(
          height: isDesktop ? 56 : 52,
          padding: EdgeInsets.all(isDesktop ? 4 : 4),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(isDesktop ? 14 : 13),
            border: Border.all(color: border),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0A155A88),
                blurRadius: 12,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: _tabButton(
                  index: 0,
                  icon: Icons.edit_note_rounded,
                  label: 'Create & Publish',
                  isDesktop: isDesktop,
                ),
              ),
              SizedBox(width: isDesktop ? 4 : 3),
              Expanded(
                child: _tabButton(
                  index: 1,
                  icon: Icons.bar_chart_rounded,
                  label: 'Student Results',
                  isDesktop: isDesktop,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _tabButton({
    required int index,
    required IconData icon,
    required String label,
    required bool isDesktop,
  }) {
    final selected = selectedTab == index;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(isDesktop ? 11 : 10),
        onTap: () {
          setState(() => selectedTab = index);
          if (index == 1) fetchResults();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          height: double.infinity,
          padding: EdgeInsets.symmetric(horizontal: isDesktop ? 14 : 9),
          decoration: BoxDecoration(
            color: selected ? navy : const Color(0xFFF4F9FC),
            borderRadius: BorderRadius.circular(isDesktop ? 11 : 10),
            border: Border.all(
              color: selected ? navy : border,
              width: selected ? 1 : 0.8,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: isDesktop ? 18 : 16,
                color: selected ? Colors.white : navy,
              ),
              SizedBox(width: isDesktop ? 7 : 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    color: selected ? Colors.white : text,
                    fontSize: isDesktop ? 12.5 : 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCreatePage({required bool isDesktop, required bool isTablet}) {
    return SingleChildScrollView(
      key: const ValueKey('create-page'),
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        isDesktop
            ? 28
            : isTablet
            ? 20
            : 12,
        12,
        isDesktop
            ? 28
            : isTablet
            ? 20
            : 12,
        24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildContextCard(),
          const SizedBox(height: 12),
          _buildLiveTestCard(),
          const SizedBox(height: 12),
          if (isDesktop)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildComposer()),
                const SizedBox(width: 12),
                Expanded(child: _buildQueue()),
              ],
            )
          else ...[
            _buildComposer(),
            const SizedBox(height: 12),
            _buildQueue(),
          ],
        ],
      ),
    );
  }

  Widget _buildContextCard() {
    return _card(
      padding: const EdgeInsets.all(14),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 560;

          final selectors = Row(
            children: [
              Expanded(
                child: _dropdown(
                  label: 'Language',
                  value: selectedLanguage,
                  icon: Icons.translate_rounded,
                  items: const ['English', 'Hindi'],
                  onChanged: _changeLanguage,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: _dropdown(
                  label: 'Stage',
                  value: selectedStage,
                  icon: Icons.layers_rounded,
                  items: allStages,
                  display: _stageLabel,
                  onChanged: _changeStage,
                ),
              ),
            ],
          );

          final target = Row(
            children: [
              const Icon(Icons.public_rounded, color: teal, size: 17),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  '$selectedLanguage • ${_stageLabel(selectedStage)}',
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    color: text,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Icon(Icons.timer_outlined, color: navy, size: 16),
              const SizedBox(width: 4),
              DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: const [10, 15, 20, 25, 30, 40, 45, 60].contains(durationMinutes) ? durationMinutes : 25,
                  isDense: true,
                  dropdownColor: surface,
                  style: GoogleFonts.poppins(color: text, fontSize: 11, fontWeight: FontWeight.w700),
                  items: const [10, 15, 20, 25, 30, 40, 45, 60]
                      .map((m) => DropdownMenuItem<int>(value: m, child: Text('$m min')))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => durationMinutes = v);
                  },
                ),
              ),
            ],
          );

          if (compact) {
            return Column(
              children: [selectors, const SizedBox(height: 9), target],
            );
          }

          return Row(
            children: [
              Expanded(flex: 5, child: selectors),
              const SizedBox(width: 12),
              Expanded(flex: 4, child: target),
            ],
          );
        },
      ),
    );
  }

  Widget _dropdown({
    required String label,
    required String value,
    required IconData icon,
    required List<String> items,
    required ValueChanged<String> onChanged,
    String Function(String value)? display,
  }) {
    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: soft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: const Color(0xFFE4F0F7),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, color: navy, size: 16),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: value,
                isExpanded: true,
                dropdownColor: surface,
                icon: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: secondary,
                ),
                style: GoogleFonts.poppins(
                  color: text,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
                items: items
                    .map(
                      (item) => DropdownMenuItem<String>(
                        value: item,
                        child: Text(display?.call(item) ?? item),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) onChanged(value);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComposer() {
    return _card(
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader(
            icon: Icons.add_task_rounded,
            title: 'Add a question',
            subtitle:
                'Write the question, add four answers and choose the correct one.',
          ),
          const SizedBox(height: 14),
          _label('Question'),
          const SizedBox(height: 6),
          _input(
            controller: questionController,
            hint: 'Type the question here...',
            icon: Icons.help_outline_rounded,
            maxLines: 3,
          ),
          const SizedBox(height: 13),
          _label('Answer options'),
          const SizedBox(height: 7),
          _optionInput(1, opt1Controller),
          const SizedBox(height: 7),
          _optionInput(2, opt2Controller),
          const SizedBox(height: 7),
          _optionInput(3, opt3Controller),
          const SizedBox(height: 7),
          _optionInput(4, opt4Controller),
          const SizedBox(height: 13),
          _label('Correct answer'),
          const SizedBox(height: 6),
          _correctAnswerDropdown(),
          const SizedBox(height: 13),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: addQuestion,
              icon: const Icon(Icons.add_rounded, size: 19),
              label: Text(
                'Add to question queue',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: navy,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _correctAnswerDropdown() {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: soft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: correctOption == null ? border : success,
          width: correctOption == null ? 1 : 1.2,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: correctOption,
          isExpanded: true,
          hint: Text(
            'Choose the correct option',
            style: GoogleFonts.poppins(color: secondary, fontSize: 11),
          ),
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: secondary),
          dropdownColor: surface,
          items: List.generate(
            4,
            (index) => DropdownMenuItem<int>(
              value: index,
              child: Text(
                'Option ${index + 1} is correct',
                style: GoogleFonts.poppins(
                  color: text,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          onChanged: (value) => setState(() => correctOption = value),
        ),
      ),
    );
  }

  Widget _optionInput(int number, TextEditingController controller) {
    return _input(
      controller: controller,
      hint: 'Option $number',
      icon: Icons.radio_button_unchecked_rounded,
    );
  }

  Widget _input({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: GoogleFonts.poppins(
        color: text,
        fontSize: 11,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.poppins(color: secondary, fontSize: 10.5),
        prefixIcon: Icon(icon, color: navy, size: 17),
        filled: true,
        fillColor: soft,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: const BorderSide(color: navy, width: 1.3),
        ),
      ),
    );
  }

  Widget _buildQueue() {
    return _card(
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _sectionHeader(
                  icon: Icons.playlist_add_check_rounded,
                  title: 'Question queue',
                  subtitle: questionsList.isEmpty
                      ? 'Questions you add will appear here before publishing.'
                      : '${questionsList.length} question${questionsList.length == 1 ? '' : 's'} ready to publish.',
                ),
              ),
              if (questionsList.isNotEmpty) _queueNumber(),
            ],
          ),
          const SizedBox(height: 13),
          if (questionsList.isEmpty)
            _emptyQueue()
          else
            ...List.generate(
              questionsList.length,
              (index) => _queueItem(index, questionsList[index]),
            ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: isUploading ? null : uploadTest,
              icon: isUploading
                  ? const SizedBox(
                      width: 17,
                      height: 17,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.cloud_upload_rounded, size: 18),
              label: Text(
                isUploading ? 'Publishing test...' : 'Publish test',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: deepNavy,
                foregroundColor: Colors.white,
                disabledBackgroundColor: const Color(0xFF9AB4C4),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _queueItem(int index, Map<String, dynamic> question) {
    final options = List<dynamic>.from(question['options'] ?? const []);
    final rawCorrect = question['correctOptionIndex'];
    final correctIndex = rawCorrect is num
        ? rawCorrect.toInt()
        : int.tryParse(rawCorrect?.toString() ?? '') ?? 0;
    final answer = correctIndex >= 0 && correctIndex < options.length
        ? options[correctIndex].toString()
        : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: soft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFDCECF6),
              shape: BoxShape.circle,
            ),
            child: Text(
              '${index + 1}',
              style: GoogleFonts.poppins(
                color: navy,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (question['questionText'] ?? '').toString(),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    color: text,
                    fontSize: 10.5,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (answer.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      const Icon(
                        Icons.check_circle_rounded,
                        color: success,
                        size: 13,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          answer,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            color: success,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            tooltip: 'Remove question',
            onPressed: () => setState(() => questionsList.removeAt(index)),
            icon: const Icon(
              Icons.delete_outline_rounded,
              color: error,
              size: 18,
            ),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }


  Widget _buildResultsPage({
    required bool isDesktop,
    required bool isTablet,
  }) {
    final online = _getFilteredResults('online');
    final offline = _getFilteredResults('offline');
    final total = online.length + offline.length;

    return RefreshIndicator(
      color: navy,
      backgroundColor: surface,
      onRefresh: fetchResults,
      child: SingleChildScrollView(
        key: const ValueKey('results-page'),
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: EdgeInsets.fromLTRB(
          isDesktop
              ? 28
              : isTablet
                  ? 20
                  : 12,
          6,
          isDesktop
              ? 28
              : isTablet
                  ? 20
                  : 12,
          24,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildResultsOverview(
              total: total,
              online: online.length,
              offline: offline.length,
              isDesktop: isDesktop,
            ),
            const SizedBox(height: 10),
            _buildResultsToolbar(),
            const SizedBox(height: 14),
            if (isFetchingResults)
              _loadingResults()
            else ...[
              _resultsSection(
                title: 'Online students',
                count: online.length,
                accent: teal,
                list: online,
                columns: isDesktop
                    ? 3
                    : isTablet
                        ? 2
                        : 1,
              ),
              const SizedBox(height: 20),
              _resultsSection(
                title: 'Offline students',
                count: offline.length,
                accent: blue,
                list: offline,
                columns: isDesktop
                    ? 3
                    : isTablet
                        ? 2
                        : 1,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildResultsOverview({
    required int total,
    required int online,
    required int offline,
    required bool isDesktop,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isDesktop ? 20 : 15),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D155A88),
            blurRadius: 16,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [deepNavy, blue],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.bar_chart_rounded,
                  color: Colors.white,
                  size: 21,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Student test results',
                      style: GoogleFonts.poppins(
                        color: text,
                        fontSize: isDesktop ? 15 : 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$selectedLanguage • ${_stageLabel(selectedStage)}',
                      style: GoogleFonts.poppins(
                        color: secondary,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              if (isDesktop)
                Text(
                  'Submission overview',
                  style: GoogleFonts.poppins(
                    color: secondary,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 560;

              final cards = [
                _summaryMetric(
                  icon: Icons.groups_rounded,
                  label: 'Total submissions',
                  value: '$total',
                  accent: navy,
                ),
                _summaryMetric(
                  icon: Icons.wifi_rounded,
                  label: 'Online',
                  value: '$online',
                  accent: teal,
                ),
                _summaryMetric(
                  icon: Icons.location_on_rounded,
                  label: 'Offline',
                  value: '$offline',
                  accent: blue,
                ),
              ];

              if (compact) {
                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: cards[0]),
                        const SizedBox(width: 8),
                        Expanded(child: cards[1]),
                      ],
                    ),
                    const SizedBox(height: 8),
                    cards[2],
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: cards[0]),
                  const SizedBox(width: 9),
                  Expanded(child: cards[1]),
                  const SizedBox(width: 9),
                  Expanded(child: cards[2]),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _summaryMetric({
    required IconData icon,
    required String label,
    required String value,
    required Color accent,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: soft,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: accent.withAlpha(24),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, color: accent, size: 16),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    color: secondary,
                    fontSize: 8.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  value,
                  style: GoogleFonts.poppins(
                    color: text,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsToolbar() {
    return _card(
      padding: const EdgeInsets.all(13),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 700;

          final selectors = Row(
            children: [
              Expanded(
                child: _dropdown(
                  label: 'Language',
                  value: selectedLanguage,
                  icon: Icons.translate_rounded,
                  items: const ['English', 'Hindi'],
                  onChanged: _changeLanguage,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: _dropdown(
                  label: 'Stage',
                  value: selectedStage,
                  icon: Icons.layers_rounded,
                  items: allStages,
                  display: _stageLabel,
                  onChanged: _changeStage,
                ),
              ),
            ],
          );

          final title = Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: const Color(0xFFE4F0F7),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.tune_rounded,
                  color: navy,
                  size: 17,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Result filters',
                      style: GoogleFonts.poppins(
                        color: text,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      'Choose a language and stage',
                      style: GoogleFonts.poppins(
                        color: secondary,
                        fontSize: 8.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Material(
                color: soft,
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: isFetchingResults ? null : fetchResults,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Icon(
                      Icons.refresh_rounded,
                      size: 18,
                      color: isFetchingResults ? secondary : navy,
                    ),
                  ),
                ),
              ),
            ],
          );

          if (compact) {
            return Column(
              children: [
                title,
                const SizedBox(height: 11),
                selectors,
              ],
            );
          }

          return Row(
            children: [
              Expanded(flex: 5, child: title),
              const SizedBox(width: 18),
              SizedBox(width: 390, child: selectors),
            ],
          );
        },
      ),
    );
  }

  Widget _resultsSection({
    required String title,
    required int count,
    required Color accent,
    required List<dynamic> list,
    required int columns,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                color: accent,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: GoogleFonts.poppins(
                color: text,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 7),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 3,
              ),
              decoration: BoxDecoration(
                color: accent.withAlpha(25),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$count',
                style: GoogleFonts.poppins(
                  color: accent,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 9),
        if (list.isEmpty)
          _emptyResults(title)
        else if (columns == 1)
          Column(
            children: List.generate(
              list.length,
              (index) => Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: _resultCard(list[index], accent),
              ),
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: list.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              mainAxisExtent: 112,
            ),
            itemBuilder: (context, index) =>
                _resultCard(list[index], accent),
          ),
      ],
    );
  }

  Widget _resultCard(dynamic result, Color accent) {
    final map = result is Map ? result : <dynamic, dynamic>{};
    final name = (map['userName'] ?? map['name'] ?? 'Unknown').toString();
    final phone = (map['userPhone'] ?? map['phone'] ?? 'No phone').toString();
    final score = _asInt(map['score']);
    final total = _asInt(map['totalQuestions']);
    final percentage = total > 0
        ? ((score / total) * 100).clamp(0, 100).toDouble()
        : 0.0;
    final resultColor = percentage >= 50 ? success : error;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A155A88),
            blurRadius: 12,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: accent.withAlpha(24),
              shape: BoxShape.circle,
              border: Border.all(
                color: accent.withAlpha(45),
              ),
            ),
            child: Text(
              name.trim().isNotEmpty
                  ? name.trim()[0].toUpperCase()
                  : 'U',
              style: GoogleFonts.poppins(
                color: accent,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    color: text,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.phone_outlined,
                      color: secondary,
                      size: 11,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        phone,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          color: secondary,
                          fontSize: 9,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: soft,
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: Text(
                          '$score of $total correct',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            color: secondary,
                            fontSize: 8,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 66,
            padding: const EdgeInsets.symmetric(
              horizontal: 6,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              color: resultColor.withAlpha(18),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: resultColor.withAlpha(35),
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$score/$total',
                  style: GoogleFonts.poppins(
                    color: text,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  '${percentage.toStringAsFixed(0)}%',
                  style: GoogleFonts.poppins(
                    color: resultColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  percentage >= 50 ? 'Passed' : 'Below 50%',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    color: resultColor,
                    fontSize: 7,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _loadingResults() {
    return _card(
      padding: const EdgeInsets.symmetric(vertical: 55),
      child: const Center(
        child: CircularProgressIndicator(color: navy, strokeWidth: 2.5),
      ),
    );
  }

  Widget _emptyQueue() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 30),
      decoration: BoxDecoration(
        color: soft,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Column(
        children: [
          const Icon(Icons.playlist_add_rounded, color: secondary, size: 34),
          const SizedBox(height: 8),
          Text(
            'Your queue is empty',
            style: GoogleFonts.poppins(
              color: text,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            'Add questions from the form and review them here.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(color: secondary, fontSize: 9.5),
          ),
        ],
      ),
    );
  }

  Widget _emptyResults(String title) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: soft,
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(Icons.inbox_rounded, color: secondary, size: 19),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'No $title submissions yet',
                  style: GoogleFonts.poppins(
                    color: text,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Students who complete this test will appear here.',
                  style: GoogleFonts.poppins(color: secondary, fontSize: 9),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: const Color(0xFFE4F0F7),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: navy, size: 18),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.poppins(
                  color: text,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  color: secondary,
                  fontSize: 9.5,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _label(String value) {
    return Text(
      value,
      style: GoogleFonts.poppins(
        color: text,
        fontSize: 10.5,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Widget _card({required Widget child, EdgeInsetsGeometry? padding}) {
    return Container(
      padding: padding ?? const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D155A88),
            blurRadius: 14,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _queueBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F4F8),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const Icon(Icons.playlist_add_check_rounded, color: navy, size: 15),
          const SizedBox(width: 5),
          Text(
            '${questionsList.length} queued',
            style: GoogleFonts.poppins(
              color: navy,
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _queueNumber() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFE5F7F6),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '${questionsList.length}',
        style: GoogleFonts.poppins(
          color: navy,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  int _asInt(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}