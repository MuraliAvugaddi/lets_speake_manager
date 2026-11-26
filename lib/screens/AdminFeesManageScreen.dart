import 'dart:convert';
import 'package:lets_speake_manager/Api/admin_badges.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:get_storage/get_storage.dart';
import 'package:lets_speake_manager/Api/ApiendPoints.dart';
import 'package:lets_speake_manager/Api/api_headers.dart';
import 'package:lets_speake_manager/Api/admin_live.dart';
import 'package:lets_speake_manager/Navigation/AdminShellNavigation.dart';
import 'package:url_launcher/url_launcher.dart';

class AdminFeesManageScreen extends StatefulWidget {
  const AdminFeesManageScreen({super.key});

  @override
  State<AdminFeesManageScreen> createState() => _AdminFeesManageScreenState();
}

class _AdminFeesManageScreenState extends State<AdminFeesManageScreen>
    with WidgetsBindingObserver {
  static const Color navy = Color(0xFF155A88);
  static const Color deepNavy = Color(0xFF0E466D);
  static const Color blue = Color(0xFF2C6F9F);
  static const Color teal = Color(0xFF28C2C2);

  static const Color textColor = Color(0xFF173A52);
  static const Color secondaryText = Color(0xFF678196);
  static const Color borderColor = Color(0xFFD5E5EE);
  static const Color softSurface = Color(0xFFF4F9FC);
  static const Color pageBackground = Color(0xFFE8F2F8);
  static const Color cardColor = Color(0xFFFFFFFF);

  static const Color successGreen = Color(0xFF16A66A);
  static const Color alertRed = Color(0xFFE45757);

  void _openAdminDrawerOrBack() {
    if (AdminShellNavigation.scaffoldKey.currentState != null) {
      AdminShellNavigation.openDrawer();
    } else {
      Get.back();
    }
  }

  final box = GetStorage();
  final TextEditingController searchController = TextEditingController();

  bool isLoading = true;
  List<dynamic> allStudents = [];
  List<dynamic> monthlyHistory = []; // 🚀 Monthly collection breakdown records

  String selectedChannel = "all";
  String selectedLanguage = "all"; // all | English | Hindi
  String selectedStage = "all";
  String selectedSection = "all";
  String selectedFeeFilter = "all";

  final List<String> stageKeys = [
    'all',
    'stage1',
    'stage2',
    'stage3',
    'stage4',
    'stage5',
    'stage6',
    'stage7',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    fetchData();
    // ⚡ fee marked paid / verified anywhere → this list updates by itself
    _stopLive = AdminLive.on(['student_update', 'fee_update', 'payment_update'], () => fetchData(silent: true));
  }

  void Function()? _stopLive;

  @override
  void dispose() {
    _stopLive?.call();
    WidgetsBinding.instance.removeObserver(this);
    searchController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      fetchData(silent: true);
    }
  }

  Future<void> fetchData({bool silent = false}) async {
    if (!silent) setState(() => isLoading = true);
    try {
      final responses = await Future.wait([
        http.get(Uri.parse("${ApiEndpoints.baseUrl}/admin/all-students?mode=all&language=all&stage=all"), headers: ApiHeaders.auth()),
        http.get(Uri.parse(ApiEndpoints.feeHistory), headers: ApiHeaders.auth()),
      ]);

      if (responses[0].statusCode == 200) {
        final data = jsonDecode(responses[0].body);
        allStudents = data['students'] ?? [];
      }

      if (responses[1].statusCode == 200) {
        final historyData = jsonDecode(responses[1].body);
        monthlyHistory = historyData['history'] ?? [];
      }

      if (mounted) setState(() => isLoading = false);
    } catch (e) {
      debugPrint("Fee Directory Fetch Error: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _toggleStudentFeeStatus(String userId, String currentStatus) async {
    HapticFeedback.selectionClick();
    final String newStatus = currentStatus.toLowerCase() == 'paid' ? 'unpaid' : 'paid';
    final token = box.read('token');

    try {
      final response = await http.put(
        Uri.parse(ApiEndpoints.updateStudentStatus),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: jsonEncode({"userId": userId, "feeStatus": newStatus}),
      );

      if (response.statusCode == 200) {
        setState(() {
          final index = allStudents.indexWhere((s) => (s['_id'] ?? s['id']) == userId);
          if (index != -1) {
            allStudents[index]['feeStatus'] = newStatus;
          }
        });
      }
    } catch (e) {
      Get.snackbar("Error", "Could not update status: $e", backgroundColor: alertRed, colorText: Colors.white);
    }
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    await launchUrl(launchUri);
  }

  Future<void> _sendWhatsAppReminder(String phoneNumber, String name) async {
    final String cleanPhone = phoneNumber.replaceAll(RegExp(r'\D'), '');
    final String msg = "Hello $name, this is a reminder from Let's Talk Institute regarding your pending monthly tuition fee. Kindly complete your payment. Thank you!";
    final Uri whatsappUri = Uri.parse("https://wa.me/91$cleanPhone?text=${Uri.encodeComponent(msg)}");
    await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
  }

  // ---------------------------------------------------------------------
  // 🧰 FILTER LOGIC (all on the list already loaded → instant)
  // ---------------------------------------------------------------------
  bool _hasLang(dynamic s, String lang) {
    final acc = lang == 'English' ? s['englishAccess'] : s['hindiAccess'];
    return acc is Map && acc.values.any((v) => v == true);
  }

  bool _hasStage(dynamic s, String lang, String stage) {
    bool inLang(String l) {
      final acc = l == 'English' ? s['englishAccess'] : s['hindiAccess'];
      return acc is Map && acc[stage] == true;
    }

    return lang == 'all' ? (inLang('English') || inLang('Hindi')) : inLang(lang);
  }

  String _modeOf(dynamic s) => (s['mode'] ?? 'online').toString().toLowerCase();
  String _sectionOf(dynamic s) => (s['onlineSection'] ?? 'A').toString().toUpperCase();
  bool _isPaid(dynamic s) => (s['feeStatus'] ?? 'unpaid').toString().toLowerCase() == 'paid';

  /// [skip] = ignore one group (used to show "how many if I pick this")
  bool _passes(dynamic s,
      {required String channel,
      required String language,
      required String stage,
      required String section,
      required String fee,
      String skip = ''}) {
    if (skip != 'channel' && channel != 'all' && _modeOf(s) != channel) return false;
    if (skip != 'language' && language != 'all' && !_hasLang(s, language)) return false;
    if (skip != 'stage' && stage != 'all' && !_hasStage(s, language, stage)) return false;
    if (skip != 'section' && section != 'all' && !(_modeOf(s) == 'online' && _sectionOf(s) == section)) return false;
    if (skip != 'fee' && fee == 'paid' && !_isPaid(s)) return false;
    if (skip != 'fee' && fee == 'unpaid' && _isPaid(s)) return false;
    return true;
  }

  List<dynamic> get filteredStudents {
    final query = searchController.text.trim().toLowerCase();
    return allStudents.where((s) {
      if (!_passes(s,
          channel: selectedChannel,
          language: selectedLanguage,
          stage: selectedStage,
          section: selectedSection,
          fee: selectedFeeFilter)) return false;
      if (query.isEmpty) return true;
      final name = (s['name'] ?? '').toString().toLowerCase();
      final phone = (s['phone'] ?? '').toString().toLowerCase();
      return name.contains(query) || phone.contains(query);
    }).toList();
  }

  int get _activeFilters =>
      (selectedChannel != 'all' ? 1 : 0) +
      (selectedLanguage != 'all' ? 1 : 0) +
      (selectedStage != 'all' ? 1 : 0) +
      (selectedSection != 'all' ? 1 : 0) +
      (selectedFeeFilter != 'all' ? 1 : 0);

  void _clearAllFilters() => setState(() {
        selectedChannel = 'all';
        selectedLanguage = 'all';
        selectedStage = 'all';
        selectedSection = 'all';
        selectedFeeFilter = 'all';
      });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isWeb = width >= 950;

    final totalCount = allStudents.length;
    final totalPaid = allStudents.where((s) => (s['feeStatus'] ?? 'unpaid') == 'paid').length;
    final totalUnpaid = totalCount - totalPaid;

    return Scaffold(
      backgroundColor: pageBackground,
      appBar: AppBar(
        backgroundColor: cardColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: isWeb ? 72 : 62,
        leading: IconButton(
          tooltip: 'Menu',
          onPressed: _openAdminDrawerOrBack,
          icon: AdminMenuIcon(Icons.menu_rounded, color: textColor, size: 23),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            Container(
              width: isWeb ? 40 : 36,
              height: isWeb ? 40 : 36,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [deepNavy, navy]),
                borderRadius: BorderRadius.circular(11),
              ),
              child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 11),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Fee Management',
                  style: GoogleFonts.poppins(color: textColor, fontSize: isWeb ? 18 : 16, fontWeight: FontWeight.w700),
                ),
                if (isWeb)
                  Text(
                    'View historical payment logs',
                    style: GoogleFonts.poppins(color: secondaryText, fontSize: 10.5, fontWeight: FontWeight.w500),
                  ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh fees',
            onPressed: isLoading ? null : fetchData,
            icon: const Icon(Icons.refresh_rounded, color: textColor, size: 22),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1250),
            child: Column(
              children: [
                _buildSummary(totalCount: totalCount, totalPaid: totalPaid, totalUnpaid: totalUnpaid, isWeb: isWeb),
                _buildMonthlyHistoryDropdown(isWeb: isWeb),
                _buildControls(isWeb: isWeb),
                Expanded(
                  child: isLoading
                      ? const Center(child: CircularProgressIndicator(color: navy, strokeWidth: 2.5))
                      : filteredStudents.isEmpty
                          ? _buildEmptyState()
                          : RefreshIndicator(
                              color: navy,
                              backgroundColor: cardColor,
                              onRefresh: fetchData,
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  final twoColumns = constraints.maxWidth >= 1050;
                                  final padding = EdgeInsets.fromLTRB(isWeb ? 24 : 14, 2, isWeb ? 24 : 14, 24);

                                  if (!twoColumns) {
                                    return ListView.separated(
                                      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                                      padding: padding,
                                      itemCount: filteredStudents.length,
                                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                                      itemBuilder: (context, index) {
                                        return _buildStudentCard(filteredStudents[index], compact: false);
                                      },
                                    );
                                  }

                                  return GridView.builder(
                                    physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                                    padding: padding,
                                    itemCount: filteredStudents.length,
                                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 2,
                                      crossAxisSpacing: 10,
                                      mainAxisSpacing: 10,
                                      mainAxisExtent: 92,
                                    ),
                                    itemBuilder: (context, index) {
                                      return _buildStudentCard(filteredStudents[index], compact: true);
                                    },
                                  );
                                },
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

  Widget _buildSummary({required int totalCount, required int totalPaid, required int totalUnpaid, required bool isWeb}) {
    return Padding(
      padding: EdgeInsets.fromLTRB(isWeb ? 24 : 14, 10, isWeb ? 24 : 14, 6),
      child: Row(
        children: [
          Expanded(child: _summaryCard(label: 'Total Students', value: '$totalCount', icon: Icons.groups_rounded, color: navy, filter: 'all')),
          const SizedBox(width: 8),
          Expanded(child: _summaryCard(label: 'Paid This Month', value: '$totalPaid', icon: Icons.check_circle_rounded, color: successGreen, filter: 'paid')),
          const SizedBox(width: 8),
          Expanded(child: _summaryCard(label: 'Due This Month', value: '$totalUnpaid', icon: Icons.pending_actions_rounded, color: alertRed, filter: 'unpaid')),
        ],
      ),
    );
  }

  Widget _summaryCard({required String label, required String value, required IconData icon, required Color color, required String filter}) {
    final selected = selectedFeeFilter == filter;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => setState(() => selectedFeeFilter = filter),
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            color: selected ? color.withOpacity(.10) : cardColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: selected ? color.withOpacity(.55) : borderColor),
          ),
          child: Row(
            children: [
              Container(
                width: 33,
                height: 33,
                decoration: BoxDecoration(color: color.withOpacity(.10), borderRadius: BorderRadius.circular(9)),
                child: Icon(icon, color: color, size: 17),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(value, style: GoogleFonts.poppins(color: color, fontSize: 16, fontWeight: FontWeight.w800)),
                    Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.poppins(color: secondaryText, fontSize: 8, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 🚀 MONTHLY ARCHIVE SUMMARY DROPDOWN
  Widget _buildMonthlyHistoryDropdown({required bool isWeb}) {
    if (monthlyHistory.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.fromLTRB(isWeb ? 24 : 14, 0, isWeb ? 24 : 14, 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: softSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            const Icon(Icons.history_rounded, color: navy, size: 18),
            const SizedBox(width: 8),
            Text("Monthly Archive Logs:", style: GoogleFonts.poppins(color: textColor, fontSize: 11, fontWeight: FontWeight.w700)),
            const SizedBox(width: 10),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: monthlyHistory.map((h) {
                    final monthYear = h['monthYear']?.toString() ?? '';
                    final paid = h['totalPaid'] ?? 0;
                    final total = h['totalStudents'] ?? 0;
                    final isCurrent = h['isCurrentMonth'] == true;

                    return Container(
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: isCurrent ? navy : Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: isCurrent ? navy : borderColor),
                      ),
                      child: Text(
                        isCurrent ? "Current ($monthYear): $paid/$total Paid" : "Month $monthYear: $paid/$total Paid",
                        style: GoogleFonts.poppins(
                          color: isCurrent ? Colors.white : textColor,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControls({required bool isWeb}) {
    final shown = filteredStudents.length;
    return Padding(
      padding: EdgeInsets.fromLTRB(isWeb ? 24 : 14, 0, isWeb ? 24 : 14, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _buildSearchBar()),
              const SizedBox(width: 8),
              _filterButton(),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _appliedPills()),
              const SizedBox(width: 8),
              Text(
                _activeFilters > 0 || searchController.text.isNotEmpty
                    ? '$shown of ${allStudents.length} students'
                    : '${allStudents.length} students',
                style: GoogleFonts.poppins(color: secondaryText, fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _filterButton() {
    final n = _activeFilters;
    final on = n > 0;
    return Material(
      color: on ? navy : cardColor,
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        onTap: _openFilterPanel,
        borderRadius: BorderRadius.circular(11),
        child: Container(
          height: 46,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: on ? navy : borderColor),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.tune_rounded, size: 18, color: on ? Colors.white : navy),
              const SizedBox(width: 6),
              Text('Filter',
                  style: GoogleFonts.poppins(
                      color: on ? Colors.white : textColor, fontSize: 12, fontWeight: FontWeight.w700)),
              if (on) ...[
                const SizedBox(width: 6),
                Container(
                  width: 20,
                  height: 20,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(color: Color(0xFFF7DF55), shape: BoxShape.circle),
                  child: Text('$n',
                      style: GoogleFonts.poppins(color: textColor, fontSize: 10, fontWeight: FontWeight.w800)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _appliedPills() {
    final pills = <Widget>[];
    void add(String label, Color c, VoidCallback onRemove) => pills.add(Padding(
          padding: const EdgeInsets.only(right: 6),
          child: Container(
            padding: const EdgeInsets.only(left: 11, right: 4),
            decoration: BoxDecoration(
              color: c.withOpacity(.10),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: c.withOpacity(.35)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(label, style: GoogleFonts.poppins(color: c, fontSize: 11, fontWeight: FontWeight.w700)),
              InkWell(
                onTap: () => setState(onRemove),
                borderRadius: BorderRadius.circular(20),
                child: Padding(padding: const EdgeInsets.all(4), child: Icon(Icons.close_rounded, size: 15, color: c)),
              ),
            ]),
          ),
        ));
    if (selectedChannel != 'all') {
      add(selectedChannel == 'online' ? 'Online' : 'Offline',
          selectedChannel == 'online' ? blue : const Color(0xFF9A7500), () => selectedChannel = 'all');
    }
    if (selectedLanguage != 'all') add(selectedLanguage, navy, () => selectedLanguage = 'all');
    if (selectedStage != 'all') {
      add('Stage ${selectedStage.replaceAll('stage', '')}', successGreen, () => selectedStage = 'all');
    }
    if (selectedSection != 'all') add('Section $selectedSection', blue, () => selectedSection = 'all');
    if (selectedFeeFilter != 'all') {
      add(selectedFeeFilter == 'paid' ? 'Paid' : 'Unpaid', selectedFeeFilter == 'paid' ? successGreen : alertRed,
          () => selectedFeeFilter = 'all');
    }
    if (pills.isEmpty) return const SizedBox(height: 32);
    return SizedBox(
      height: 32,
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        children: [
          ...pills,
          TextButton(
            onPressed: _clearAllFilters,
            style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10), minimumSize: const Size(0, 32)),
            child: Text('Clear all', style: GoogleFonts.poppins(color: alertRed, fontSize: 11, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  // 🧰 FILTER PANEL — groups left, options right, live counts
  //   Web/tablet: side panel from the right • Phone: bottom sheet
  // ---------------------------------------------------------------------
  void _openFilterPanel() {
    String dChannel = selectedChannel;
    String dLanguage = selectedLanguage;
    String dStage = selectedStage;
    String dSection = selectedSection;
    String dFee = selectedFeeFilter;
    String active = 'channel';

    final groups = <Map<String, dynamic>>[
      {'key': 'channel', 'title': 'Online / Offline', 'icon': Icons.wifi_rounded},
      {'key': 'language', 'title': 'Language', 'icon': Icons.translate_rounded},
      {'key': 'stage', 'title': 'Stage', 'icon': Icons.layers_rounded},
      {'key': 'section', 'title': 'Section', 'icon': Icons.view_module_rounded},
      {'key': 'fee', 'title': 'Fee status', 'icon': Icons.payments_rounded},
    ];

    Widget panel(BuildContext ctx, StateSetter setPanel, bool wide) {
      int countWith(String skip, bool Function(dynamic s) test) => allStudents
          .where((s) =>
              _passes(s,
                  channel: dChannel, language: dLanguage, stage: dStage, section: dSection, fee: dFee, skip: skip) &&
              test(s))
          .length;
      final total = allStudents
          .where((s) => _passes(s, channel: dChannel, language: dLanguage, stage: dStage, section: dSection, fee: dFee))
          .length;

      bool isSet(String key) => {
            'channel': dChannel,
            'language': dLanguage,
            'stage': dStage,
            'section': dSection,
            'fee': dFee,
          }[key] != 'all';

      Widget option(String label, bool selected, int count, VoidCallback onTap, {Color color = navy}) => InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              setPanel(onTap);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 140),
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: selected ? color : Colors.transparent,
                      shape: BoxShape.circle,
                      border: Border.all(color: selected ? color : const Color(0xFFB7C9D6), width: 1.6),
                    ),
                    child: selected ? const Icon(Icons.check_rounded, size: 15, color: Colors.white) : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(label,
                        style: GoogleFonts.poppins(
                            color: textColor, fontSize: 12.5, fontWeight: selected ? FontWeight.w700 : FontWeight.w500)),
                  ),
                  Text('$count',
                      style: GoogleFonts.poppins(color: secondaryText, fontSize: 11.5, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          );

      List<Widget> options() {
        switch (active) {
          case 'channel':
            return [
              option('Online + Offline', dChannel == 'all', countWith('channel', (_) => true), () => dChannel = 'all'),
              option('Online', dChannel == 'online', countWith('channel', (s) => _modeOf(s) == 'online'),
                  () => dChannel = 'online', color: blue),
              option('Offline', dChannel == 'offline', countWith('channel', (s) => _modeOf(s) == 'offline'),
                  () => dChannel = 'offline', color: const Color(0xFF9A7500)),
            ];
          case 'language':
            return [
              option('All languages', dLanguage == 'all', countWith('language', (_) => true), () => dLanguage = 'all'),
              option('English', dLanguage == 'English', countWith('language', (s) => _hasLang(s, 'English')),
                  () => dLanguage = 'English'),
              option('Hindi', dLanguage == 'Hindi', countWith('language', (s) => _hasLang(s, 'Hindi')),
                  () => dLanguage = 'Hindi', color: teal),
            ];
          case 'stage':
            return [
              for (final st in stageKeys)
                option(
                  st == 'all' ? 'All stages' : 'Stage ${st.replaceAll('stage', '')}',
                  dStage == st,
                  countWith('stage', (s) => st == 'all' || _hasStage(s, dLanguage, st)),
                  () => dStage = st,
                  color: successGreen,
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 6, 14, 0),
                child: Text(
                    dLanguage == 'all' ? 'Stage of English or Hindi' : 'Stage of the $dLanguage course',
                    style: GoogleFonts.poppins(color: secondaryText, fontSize: 10)),
              ),
            ];
          case 'section':
            return [
              for (final sec in ['all', 'A', 'B', 'C', 'D', 'E'])
                option(
                  sec == 'all' ? 'All sections' : 'Section $sec',
                  dSection == sec,
                  countWith('section', (s) => sec == 'all' || (_modeOf(s) == 'online' && _sectionOf(s) == sec)),
                  () => dSection = sec,
                  color: blue,
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 6, 14, 0),
                child: Text('Sections are for online students',
                    style: GoogleFonts.poppins(color: secondaryText, fontSize: 10)),
              ),
            ];
          default:
            return [
              option('Paid + Unpaid', dFee == 'all', countWith('fee', (_) => true), () => dFee = 'all'),
              option('Paid', dFee == 'paid', countWith('fee', _isPaid), () => dFee = 'paid', color: successGreen),
              option('Unpaid', dFee == 'unpaid', countWith('fee', (s) => !_isPaid(s)), () => dFee = 'unpaid',
                  color: alertRed),
            ];
        }
      }

      final draftCount = [dChannel, dLanguage, dStage, dSection, dFee].where((e) => e != 'all').length;

      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 8, 10),
            child: Row(
              children: [
                const Icon(Icons.tune_rounded, color: navy, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Filters',
                          style: GoogleFonts.poppins(color: textColor, fontSize: 17, fontWeight: FontWeight.w700)),
                      Text('Fee management', style: GoogleFonts.poppins(color: secondaryText, fontSize: 10.5)),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: draftCount == 0
                      ? null
                      : () => setPanel(() {
                            dChannel = 'all';
                            dLanguage = 'all';
                            dStage = 'all';
                            dSection = 'all';
                            dFee = 'all';
                          }),
                  child: Text('Clear all',
                      style: GoogleFonts.poppins(
                          color: draftCount == 0 ? secondaryText : alertRed, fontSize: 12, fontWeight: FontWeight.w700)),
                ),
                IconButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  icon: const Icon(Icons.close_rounded, color: secondaryText),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: borderColor),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: wide ? 160 : 132,
                  color: softSurface,
                  child: ListView(
                    children: [
                      for (final g in groups)
                        InkWell(
                          onTap: () => setPanel(() => active = g['key'] as String),
                          child: Container(
                            padding: const EdgeInsets.fromLTRB(12, 15, 10, 15),
                            decoration: BoxDecoration(
                              color: active == g['key'] ? cardColor : Colors.transparent,
                              border: Border(
                                left: BorderSide(color: active == g['key'] ? navy : Colors.transparent, width: 4),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(g['icon'] as IconData, size: 16, color: active == g['key'] ? navy : secondaryText),
                                const SizedBox(width: 7),
                                Expanded(
                                  child: Text(g['title'] as String,
                                      style: GoogleFonts.poppins(
                                        color: active == g['key'] ? textColor : secondaryText,
                                        fontSize: 12,
                                        fontWeight: active == g['key'] ? FontWeight.w700 : FontWeight.w600,
                                      )),
                                ),
                                if (isSet(g['key'] as String))
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(color: navy, shape: BoxShape.circle),
                                  ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(child: ListView(padding: const EdgeInsets.symmetric(vertical: 6), children: options())),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.of(ctx).padding.bottom),
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: borderColor))),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('$total', style: GoogleFonts.poppins(color: textColor, fontSize: 18, fontWeight: FontWeight.w800)),
                      Text('students found', style: GoogleFonts.poppins(color: secondaryText, fontSize: 10.5)),
                    ],
                  ),
                ),
                SizedBox(
                  height: 46,
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        selectedChannel = dChannel;
                        selectedLanguage = dLanguage;
                        selectedStage = dStage;
                        selectedSection = dSection;
                        selectedFeeFilter = dFee;
                      });
                      Navigator.of(ctx).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: navy,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 26),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text('Show $total students',
                        style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    final wide = MediaQuery.of(context).size.width >= 700;
    if (wide) {
      showGeneralDialog(
        context: context,
        barrierDismissible: true,
        barrierLabel: 'Filters',
        barrierColor: Colors.black.withOpacity(.35),
        transitionDuration: const Duration(milliseconds: 220),
        pageBuilder: (ctx, _, __) => Align(
          alignment: Alignment.centerRight,
          child: Material(
            color: cardColor,
            elevation: 12,
            child: SizedBox(
              width: 470,
              height: double.infinity,
              child: SafeArea(child: StatefulBuilder(builder: (c, sp) => panel(c, sp, true))),
            ),
          ),
        ),
        transitionBuilder: (ctx, anim, _, child) => SlideTransition(
          position: Tween(begin: const Offset(1, 0), end: Offset.zero)
              .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: child,
        ),
      );
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: cardColor,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
        builder: (ctx) => SizedBox(
          height: MediaQuery.of(ctx).size.height * .8,
          child: StatefulBuilder(builder: (c, sp) => panel(c, sp, false)),
        ),
      );
    }
  }

  Widget _buildSearchBar() {
    return TextField(
      controller: searchController,
      onChanged: (_) => setState(() {}),
      style: GoogleFonts.poppins(color: textColor, fontSize: 12, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        hintText: 'Search students by name or phone',
        hintStyle: GoogleFonts.poppins(color: secondaryText, fontSize: 11),
        prefixIcon: const Icon(Icons.search_rounded, color: navy, size: 19),
        suffixIcon: searchController.text.isNotEmpty
            ? IconButton(
                tooltip: 'Clear search',
                onPressed: () {
                  searchController.clear();
                  setState(() {});
                },
                icon: const Icon(Icons.close_rounded, color: secondaryText, size: 17),
              )
            : null,
        filled: true,
        fillColor: softSurface,
        contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 13),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(11), borderSide: const BorderSide(color: borderColor)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(11), borderSide: const BorderSide(color: borderColor)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(11), borderSide: const BorderSide(color: navy, width: 1.4)),
      ),
    );
  }



  Widget _buildStudentCard(dynamic student, {required bool compact}) {
    final String name = (student['name'] ?? 'Student').toString();
    final String phone = (student['phone'] ?? 'No phone').toString();
    final String userId = (student['_id'] ?? student['id']).toString();
    final String mode = (student['mode'] ?? 'online').toString().toLowerCase();
    final bool isOnline = mode == 'online';
    final String section = (student['onlineSection'] ?? 'A').toString().toUpperCase();
    final bool isPaid = (student['feeStatus'] ?? 'unpaid').toString().toLowerCase() == 'paid';

    final Color statusColor = isPaid ? successGreen : alertRed;
    final Color modeColor = isOnline ? blue : const Color(0xFF9A7500);

    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
        boxShadow: const [BoxShadow(color: Color(0x07155A88), blurRadius: 9, offset: Offset(0, 3))],
      ),
      child: Row(
        children: [
          Container(
            width: compact ? 38 : 42,
            height: compact ? 38 : 42,
            decoration: BoxDecoration(color: statusColor.withOpacity(.10), shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'S', style: GoogleFonts.poppins(color: statusColor, fontSize: 14, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.poppins(color: textColor, fontSize: compact ? 11.5 : 12.5, fontWeight: FontWeight.w700))),
                    const SizedBox(width: 6),
                    _miniBadge(isPaid ? 'PAID' : 'UNPAID', statusColor),
                  ],
                ),
                const SizedBox(height: 3),
                Text(isOnline ? '$phone  •  Online  •  Sec $section' : '$phone  •  Offline center', maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.poppins(color: secondaryText, fontSize: compact ? 8.5 : 9.5, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          const SizedBox(width: 6),
          if (!compact) ...[
            _smallActionButton(icon: Icons.chat_rounded, color: const Color(0xFF16A66A), tooltip: 'WhatsApp reminder', onPressed: () => _sendWhatsAppReminder(phone, name)),
            _smallActionButton(icon: Icons.call_rounded, color: blue, tooltip: 'Call student', onPressed: () => _makePhoneCall(phone)),
            const SizedBox(width: 4),
          ],
          if (compact)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _miniBadge(isOnline ? 'ONLINE' : 'OFFLINE', modeColor),
                  const SizedBox(height: 5),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _smallActionButton(icon: Icons.chat_rounded, color: const Color(0xFF16A66A), tooltip: 'WhatsApp reminder', onPressed: () => _sendWhatsAppReminder(phone, name)),
                      _smallActionButton(icon: Icons.call_rounded, color: blue, tooltip: 'Call student', onPressed: () => _makePhoneCall(phone)),
                    ],
                  ),
                ],
              ),
            ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _toggleStudentFeeStatus(userId, student['feeStatus'] ?? 'unpaid'),
              borderRadius: BorderRadius.circular(9),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(.09),
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: statusColor.withOpacity(.45)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(isPaid ? Icons.check_circle_rounded : Icons.pending_rounded, size: 13, color: statusColor),
                    const SizedBox(width: 4),
                    Text(isPaid ? 'Paid' : 'Unpaid', style: GoogleFonts.poppins(color: statusColor, fontSize: 9, fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(color: color.withOpacity(.09), borderRadius: BorderRadius.circular(6)),
      child: Text(text, style: GoogleFonts.poppins(color: color, fontSize: 7, fontWeight: FontWeight.w800)),
    );
  }

  Widget _smallActionButton({required IconData icon, required Color color, required String tooltip, required VoidCallback onPressed}) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
      icon: Icon(icon, color: color, size: 17),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 450),
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(18), border: Border.all(color: borderColor)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 58, height: 58, decoration: BoxDecoration(color: navy.withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.people_outline_rounded, color: navy, size: 29)),
              const SizedBox(height: 12),
              Text('No students found', style: GoogleFonts.poppins(color: textColor, fontSize: 14, fontWeight: FontWeight.w700)),
              const SizedBox(height: 5),
              Text('Try changing the filters or search term.', textAlign: TextAlign.center, style: GoogleFonts.poppins(color: secondaryText, fontSize: 10.5)),
              if (_activeFilters > 0 || searchController.text.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: TextButton(
                    onPressed: () {
                      searchController.clear();
                      _clearAllFilters();
                    },
                    child: Text('Clear filters', style: GoogleFonts.poppins(color: navy, fontSize: 11, fontWeight: FontWeight.w700)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}