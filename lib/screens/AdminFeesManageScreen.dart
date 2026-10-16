import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:get_storage/get_storage.dart';
import 'package:lets_speake_manager/Api/ApiendPoints.dart';
import 'package:lets_speake_manager/Api/api_headers.dart';
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
  String selectedLanguage = "English";
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
  }

  @override
  void dispose() {
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

  List<dynamic> get filteredStudents {
    List<dynamic> list = List.from(allStudents);

    if (selectedChannel != "all") {
      list = list.where((s) => (s['mode'] ?? 'online').toString().toLowerCase() == selectedChannel).toList();
    }

    if (selectedStage != "all") {
      list = list.where((s) {
        if (selectedLanguage.toLowerCase() == "english") {
          final english = s['englishAccess'];
          return english != null && english[selectedStage] == true;
        } else {
          final hindi = s['hindiAccess'];
          return hindi != null && hindi[selectedStage] == true;
        }
      }).toList();
    }

    if (selectedChannel == "online" && selectedLanguage == "English" && selectedSection != "all") {
      list = list.where((s) => (s['onlineSection'] ?? 'A').toString().toUpperCase() == selectedSection).toList();
    }

    if (selectedFeeFilter == "paid") {
      list = list.where((s) => (s['feeStatus'] ?? 'unpaid') == 'paid').toList();
    } else if (selectedFeeFilter == "unpaid") {
      list = list.where((s) => (s['feeStatus'] ?? 'unpaid') != 'paid').toList();
    }

    final query = searchController.text.trim().toLowerCase();
    if (query.isNotEmpty) {
      list = list.where((s) {
        final name = (s['name'] ?? '').toString().toLowerCase();
        final phone = (s['phone'] ?? '').toString().toLowerCase();
        return name.contains(query) || phone.contains(query);
      }).toList();
    }

    return list;
  }

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
          icon: const Icon(Icons.menu_rounded, color: textColor, size: 23),
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
                                      mainAxisExtent: 116,
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
    return Padding(
      padding: EdgeInsets.fromLTRB(isWeb ? 24 : 14, 0, isWeb ? 24 : 14, 10),
      child: Container(
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSearchBar(),
            const SizedBox(height: 10),
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 760;

                final channel = _horizontalFilter(
                  children: [
                    _buildChoicePill('All', selectedChannel == 'all', () => setState(() => selectedChannel = 'all'), navy),
                    _buildChoicePill('Online', selectedChannel == 'online', () => setState(() => selectedChannel = 'online'), blue),
                    _buildChoicePill('Offline', selectedChannel == 'offline', () => setState(() => selectedChannel = 'offline'), const Color(0xFF9A7500)),
                  ],
                );

                final language = _horizontalFilter(
                  children: [
                    _buildChoicePill('English', selectedLanguage == 'English', () => setState(() => selectedLanguage = 'English'), navy),
                    _buildChoicePill('Hindi', selectedLanguage == 'Hindi', () => setState(() => selectedLanguage = 'Hindi'), blue),
                  ],
                );

                final stages = _horizontalFilter(
                  children: stageKeys.map((st) {
                    final selected = selectedStage == st;
                    final label = st == 'all' ? 'All stages' : 'Stage ${st.replaceAll('stage', '')}';
                    return _buildStageFilterChip(label, selected, () => setState(() => selectedStage = st));
                  }).toList(),
                );

                final sections = (selectedChannel == 'online' && selectedLanguage == 'English')
                    ? _horizontalFilter(
                        children: ['all', 'A', 'B', 'C', 'D', 'E'].map((sec) {
                          return _buildStageFilterChip(sec == 'all' ? 'All sections' : 'Sec $sec', selectedSection == sec, () => setState(() => selectedSection = sec));
                        }).toList(),
                      )
                    : const SizedBox.shrink();

                if (compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _filterLabel('Channel'),
                      const SizedBox(height: 5),
                      channel,
                      const SizedBox(height: 9),
                      _filterLabel('Language'),
                      const SizedBox(height: 5),
                      language,
                      const SizedBox(height: 9),
                      _filterLabel('Stage'),
                      const SizedBox(height: 5),
                      stages,
                      if (selectedChannel == 'online' && selectedLanguage == 'English') ...[
                        const SizedBox(height: 9),
                        _filterLabel('Section'),
                        const SizedBox(height: 5),
                        sections,
                      ],
                    ],
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_filterLabel('Channel'), const SizedBox(height: 5), channel])),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_filterLabel('Language'), const SizedBox(height: 5), language])),
                      ],
                    ),
                    const SizedBox(height: 9),
                    _filterLabel('Stage'),
                    const SizedBox(height: 5),
                    stages,
                    if (selectedChannel == 'online' && selectedLanguage == 'English') ...[
                      const SizedBox(height: 9),
                      _filterLabel('Section'),
                      const SizedBox(height: 5),
                      sections,
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
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

  Widget _filterLabel(String text) {
    return Text(text, style: GoogleFonts.poppins(color: secondaryText, fontSize: 8.5, fontWeight: FontWeight.w700));
  }

  Widget _horizontalFilter({required List<Widget> children}) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(children: children),
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChoicePill(String title, bool isSelected, VoidCallback onTap, Color activeColor) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(9),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? activeColor : softSurface,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: isSelected ? activeColor : borderColor),
            ),
            child: Text(title, style: GoogleFonts.poppins(color: isSelected ? Colors.white : textColor, fontSize: 9.5, fontWeight: FontWeight.w700)),
          ),
        ),
      ),
    );
  }

  Widget _buildStageFilterChip(String label, bool isSelected, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(9),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? navy : softSurface,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: isSelected ? navy : borderColor),
            ),
            child: Text(label, style: GoogleFonts.poppins(color: isSelected ? Colors.white : textColor, fontSize: 9.2, fontWeight: FontWeight.w700)),
          ),
        ),
      ),
    );
  }
}

