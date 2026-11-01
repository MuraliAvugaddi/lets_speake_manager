import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:lets_speake_manager/Api/ApiendPoints.dart';
import 'package:lets_speake_manager/Controllers/adminController.dart';
import 'package:lets_speake_manager/Navigation/AdminShellNavigation.dart';
import 'package:lets_speake_manager/screens/AdminPromoScreen.dart';
import 'package:lets_speake_manager/screens/AdminSpecialClassScreen.dart';

// =====================================================================
// 🔎 Student filters (Flipkart / Amazon style)
// Inside one group = OR (Stage 1 or Stage 2), between groups = AND.
// =====================================================================
class _StudentFilter {
  Set<String> langs; // english, hindi
  Set<int> stages; // 1..7
  Set<String> sections; // A..E (online only)
  Set<String> fees; // paid, unpaid
  Set<String> batches; // batchTime values ('' = not chosen)

  _StudentFilter({
    Set<String>? langs,
    Set<int>? stages,
    Set<String>? sections,
    Set<String>? fees,
    Set<String>? batches,
  })  : langs = langs ?? <String>{},
        stages = stages ?? <int>{},
        sections = sections ?? <String>{},
        fees = fees ?? <String>{},
        batches = batches ?? <String>{};

  _StudentFilter copy() => _StudentFilter(
        langs: {...langs},
        stages: {...stages},
        sections: {...sections},
        fees: {...fees},
        batches: {...batches},
      );

  int get count => langs.length + stages.length + sections.length + fees.length + batches.length;
  bool get isEmpty => count == 0;
}

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override 
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with SingleTickerProviderStateMixin {
  static const Color textColor = Color(0xFF173A52);
  static const Color secondaryText = Color(0xFF6B8496);
  static const Color borderColor = Color(0xFFD5E5EE);
  static const Color softSurface = Color(0xFFEAF4FA);

  void _openAdminDrawerOrBack() {
    if (AdminShellNavigation.scaffoldKey.currentState != null) {
      AdminShellNavigation.openDrawer();
    } else {
      Get.back();
    }
  }

  final searchController = TextEditingController();
  final box = GetStorage();
  final AdminController adminController = Get.put(AdminController());

  late TabController mainChannelTabController;
  int selectedStatusFilter = 0; // 0 = Access Granted, 1 = Pending Approval

  // 🔎 Applied filters (kept separately per tab: online / offline)
  final Map<String, _StudentFilter> _filters = {
    'online': _StudentFilter(),
    'offline': _StudentFilter(),
  };
  static const List<String> _sections = ['A', 'B', 'C', 'D', 'E'];
  static const Color hindiColor = Color(0xFFE07B00);

  final ScrollController onlineScrollController = ScrollController();
  final ScrollController offlineScrollController = ScrollController();

  final Color backgroundColor = const Color(0xFFF5FAFD);
  final Color cardColor = const Color(0xFFFFFFFF);
  final Color surfaceSubtle = const Color(0xFFEAF4FA);
  final Color accentPurple = const Color(0xFF0A4A75);
  final Color accentBlue = const Color(0xFF2E86C9);
  final Color accentOrange = const Color(0xFFF4C542);
  final Color successGreen = const Color(0xFF16A66A);
  final Color alertRed = const Color(0xFFE45757);
  final Color goldenYellow = const Color(0xFFF4C542);

  String? onlineNotification;
  String? offlineNotification;
  bool isLoadingNotifs = false;

  @override
  void initState() {
    super.initState();
    mainChannelTabController = TabController(length: 2, vsync: this);

    _setupPagination(onlineScrollController);
    _setupPagination(offlineScrollController);
    _fetchActiveNotifications();
  }

  void _setupPagination(ScrollController controller) {
    controller.addListener(() {
      if (controller.position.pixels >=
          controller.position.maxScrollExtent - 200) {
        adminController.fetchAllUsers(isRefresh: false);
      }
    });
  }

  @override
  void dispose() {
    searchController.dispose();
    onlineScrollController.dispose();
    offlineScrollController.dispose();
    mainChannelTabController.dispose();
    super.dispose();
  }

  Future<void> _fetchActiveNotifications() async {
    setState(() => isLoadingNotifs = true);
    try {
      final results = await Future.wait([
        http.get(Uri.parse("${ApiEndpoints.notification}?mode=online")),
        http.get(Uri.parse("${ApiEndpoints.notification}?mode=offline")),
      ]);

      if (results[0].statusCode == 200) {
        final data = jsonDecode(results[0].body);
        setState(() {
          onlineNotification = (data['hasNotification'] == true &&
                  data['targetMode']?.toString().toLowerCase() == 'online')
              ? data['message']
              : null;
        });
      }
      if (results[1].statusCode == 200) {
        final data = jsonDecode(results[1].body);
        setState(() {
          offlineNotification = (data['hasNotification'] == true &&
                  data['targetMode']?.toString().toLowerCase() == 'offline')
              ? data['message']
              : null;
        });
      }
    } catch (e) {
      debugPrint("Error fetching notifications: $e");
    } finally {
      if (mounted) setState(() => isLoadingNotifs = false);
    }
  }

  Future<void> _postNotification(String message, String targetMode) async {
    final cleanMode = targetMode.toLowerCase().trim();
    try {
      final response = await http.post(
        Uri.parse(ApiEndpoints.notification),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer ${box.read('token')}",
        },
        body: jsonEncode({"message": message, "targetMode": cleanMode}),
      );

      if (response.statusCode == 200) {
        Get.back();
        setState(() {
          if (cleanMode == 'online') {
            onlineNotification = message;
          } else {
            offlineNotification = message;
          }
        });
        Get.snackbar(
          "Broadcast Sent",
          "${cleanMode.toUpperCase()} notification published successfully.",
          backgroundColor: successGreen.withOpacity(0.9),
          colorText: Colors.white,
          snackPosition: SnackPosition.TOP,
          margin: const EdgeInsets.all(16),
          borderRadius: 14,
        );
        _fetchActiveNotifications();
      }
    } catch (e) {
      Get.snackbar(
        "Error",
        "Failed to broadcast: $e",
        backgroundColor: alertRed.withOpacity(0.9),
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
        margin: const EdgeInsets.all(16),
        borderRadius: 14,
      );
    }
  }

  Future<void> _deleteNotification(String targetMode) async {
    final cleanMode = targetMode.toLowerCase().trim();
    try {
      final response = await http.delete(
        Uri.parse("${ApiEndpoints.notification}?targetMode=$cleanMode"),
        headers: {"Authorization": "Bearer ${box.read('token')}"},
      );

      if (response.statusCode == 200) {
        setState(() {
          if (cleanMode == 'online') {
            onlineNotification = null;
          } else {
            offlineNotification = null;
          }
        });

        Get.snackbar(
          "Notice Cleared",
          "${cleanMode.toUpperCase()} announcement removed successfully.",
          backgroundColor: accentOrange.withOpacity(0.9),
          colorText: Colors.white,
          snackPosition: SnackPosition.TOP,
          margin: const EdgeInsets.all(16),
          borderRadius: 14,
        );
        _fetchActiveNotifications();
      }
    } catch (e) {
      Get.snackbar(
        "Error",
        "Failed to clear notice: $e",
        backgroundColor: alertRed.withOpacity(0.9),
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
        margin: const EdgeInsets.all(16),
        borderRadius: 14,
      );
    }
  }

  void _openBroadcastDialog(String targetMode) {
    final cleanMode = targetMode.toLowerCase().trim();
    final bool isOnline = cleanMode == "online";
    final String currentNotice =
        (isOnline ? onlineNotification : offlineNotification) ?? '';
    final textController = TextEditingController(text: currentNotice);
    final Color modeColor = isOnline ? accentBlue : accentOrange;

    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: modeColor.withOpacity(0.3)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.campaign_rounded, color: modeColor, size: 24),
                      const SizedBox(width: 10),
                      Text(
                        "${cleanMode.toUpperCase()} Broadcast",
                        style: GoogleFonts.poppins(
                          color: textColor,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  GestureDetector(
                    onTap: () => Get.back(),
                    child: const Icon(
                      Icons.close_rounded,
                      color: secondaryText,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                "Broadcasts exclusively to ${cleanMode.toUpperCase()} students in real time.",
                style: GoogleFonts.poppins(color: secondaryText, fontSize: 12),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: textController,
                maxLines: 3,
                style: GoogleFonts.poppins(color: textColor, fontSize: 13),
                decoration: InputDecoration(
                  hintText:
                      "Enter ${cleanMode.toLowerCase()} announcement notice...",
                  hintStyle: GoogleFonts.poppins(
                    color: secondaryText,
                    fontSize: 12,
                  ),
                  filled: true,
                  fillColor: backgroundColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: textColor.withOpacity(0.06)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: modeColor, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () {
                    final msg = textController.text.trim();
                    if (msg.isNotEmpty) {
                      _postNotification(msg, cleanMode);
                    }
                  },
                  icon: const Icon(Icons.send_rounded, size: 16),
                  label: Text(
                    "Post ${cleanMode.toUpperCase()} Notice",
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: modeColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      isScrollControlled: true,
    );
  }

  bool _hasUserBeenGrantedAccess(dynamic user) {
    final eng = user['englishAccess'] as Map? ?? {};
    final hin = user['hindiAccess'] as Map? ?? {};
    bool hasEng = eng.values.any((val) => val == true);
    bool hasHin = hin.values.any((val) => val == true);
    return hasEng || hasHin;
  }

  // ---------------------------------------------------------------------
  // 🔎 FILTER LOGIC
  // ---------------------------------------------------------------------
  bool _hasStage(dynamic user, String lang, int stage) {
    final access = (lang == 'hindi' ? user['hindiAccess'] : user['englishAccess']) as Map? ?? {};
    if (stage == 0) return access.values.any((v) => v == true);
    return access['stage$stage'] == true;
  }

  String _sectionOf(dynamic user) => (user['onlineSection'] ?? '').toString().trim().toUpperCase();
  String _feeOf(dynamic user) =>
      (user['feeStatus'] ?? 'unpaid').toString().toLowerCase() == 'paid' ? 'paid' : 'unpaid';
  String _batchOf(dynamic user) => (user['batchTime'] ?? '').toString().trim();

  /// Does [user] pass filter [f]? [skip] = ignore one group (used for the counts next to each option).
  bool _passes(dynamic user, _StudentFilter f, String mode, {required bool grantedOnly, String? skip}) {
    // language + stage (only for students who have access)
    if (grantedOnly && skip != 'course') {
      final langs = f.langs.isEmpty ? const ['english', 'hindi'] : f.langs.toList();
      final stages = f.stages.isEmpty ? const [0] : f.stages.toList();
      if (!f.langs.isEmpty || !f.stages.isEmpty) {
        final ok = langs.any((l) => stages.any((st) => _hasStage(user, l, st)));
        if (!ok) return false;
      }
    }
    if (mode == 'online' && skip != 'section' && f.sections.isNotEmpty && !f.sections.contains(_sectionOf(user))) {
      return false;
    }
    if (skip != 'fee' && f.fees.isNotEmpty && !f.fees.contains(_feeOf(user))) return false;
    if (skip != 'batch' && f.batches.isNotEmpty && !f.batches.contains(_batchOf(user))) return false;
    return true;
  }

  /// Students of this tab (mode + access) + search, before filters
  List<dynamic> _baseList(String mode, bool grantedOnly) {
    final q = adminController.searchQuery.value.toLowerCase();
    return adminController.usersList.where((user) {
      if (user['mode']?.toString().toLowerCase() != mode) return false;
      final hasAccess = _hasUserBeenGrantedAccess(user);
      if (grantedOnly ? !hasAccess : hasAccess) return false;
      if (q.isNotEmpty) {
        final phone = user['phone']?.toString().toLowerCase() ?? '';
        final name = user['name']?.toString().toLowerCase() ?? '';
        if (!phone.contains(q) && !name.contains(q)) return false;
      }
      return true;
    }).toList();
  }

  /// Number of filters that actually apply on this tab
  int _activeCount(String mode, bool grantedOnly) {
    final f = _filters[mode]!;
    return (grantedOnly ? f.langs.length + f.stages.length : 0) +
        (mode == 'online' ? f.sections.length : 0) +
        f.fees.length +
        f.batches.length;
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isWide = width >= 1050;
    final isTablet = width >= 700 && width < 1050;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(isWide ? 60 : 54),
        child: Container(
          height: isWide ? 60 : 54,
          decoration: BoxDecoration(
            color: cardColor,
            border: const Border(
              bottom: BorderSide(color: borderColor, width: 1),
            ),
          ),
          child: Row(
            children: [
              SizedBox(
                width: isWide ? 58 : 50,
                child: Center(
                  child: IconButton(
                    tooltip: 'Menu',
                    onPressed: _openAdminDrawerOrBack,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 42,
                      minHeight: 42,
                    ),
                    splashRadius: 20,
                    icon: const Icon(
                      Icons.menu_rounded,
                      color: textColor,
                      size: 25,
                    ),
                  ),
                ),
              ),
              Container(
                width: isWide ? 38 : 34,
                height: isWide ? 38 : 34,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF0E466D),
                      Color(0xFF155A88),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(
                  Icons.people_alt_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Students',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        color: textColor,
                        fontSize: isWide ? 18 : 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (isWide)
                      Text(
                        'Manage students, access and learning status',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          color: secondaryText,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
              ),
              // 🌧 Rain day online / 🎙 Principal class
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: isWide
                    ? TextButton.icon(
                        onPressed: () => Get.to(() => const AdminSpecialClassScreen()),
                        icon: const Icon(Icons.campaign_rounded, size: 18, color: Color(0xFF7B2FF7)),
                        label: Text(
                          'Special classes',
                          style: GoogleFonts.poppins(
                            color: const Color(0xFF7B2FF7),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          backgroundColor: const Color(0xFF7B2FF7).withOpacity(.08),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
                        ),
                      )
                    : IconButton(
                        tooltip: 'Special classes (rain day / principal)',
                        onPressed: () => Get.to(() => const AdminSpecialClassScreen()),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 42, minHeight: 42),
                        splashRadius: 20,
                        icon: const Icon(Icons.campaign_rounded, color: Color(0xFF7B2FF7), size: 22),
                      ),
              ),
              // 🎬 Posters & Reels → popup on the student home screen
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: isWide
                    ? TextButton.icon(
                        onPressed: () => Get.to(() => const AdminPromoScreen()),
                        icon: const Icon(Icons.perm_media_rounded, size: 18, color: Color(0xFFD6336C)),
                        label: Text(
                          'Posters & Reels',
                          style: GoogleFonts.poppins(
                            color: const Color(0xFFD6336C),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          backgroundColor: const Color(0xFFD6336C).withOpacity(.08),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
                        ),
                      )
                    : IconButton(
                        tooltip: 'Posters & Reels',
                        onPressed: () => Get.to(() => const AdminPromoScreen()),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 42, minHeight: 42),
                        splashRadius: 20,
                        icon: const Icon(Icons.perm_media_rounded, color: Color(0xFFD6336C), size: 22),
                      ),
              ),
              IconButton(
                tooltip: 'Refresh',
                onPressed: () {
                  adminController.fetchAllUsers(isRefresh: true);
                  _fetchActiveNotifications();
                },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                  minWidth: 42,
                  minHeight: 42,
                ),
                splashRadius: 20,
                icon: const Icon(
                  Icons.refresh_rounded,
                  color: textColor,
                  size: 23,
                ),
              ),
              SizedBox(width: isWide ? 8 : 4),
            ],
          ),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1320),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                isWide ? 28 : (isTablet ? 20 : 14),
                18,
                isWide ? 28 : (isTablet ? 20 : 14),
                20,
              ),
              child: Column(
                children: [
                  _buildSummaryBar(isWide: isWide),
                  const SizedBox(height: 14),
                  _buildSearchBar(),
                  const SizedBox(height: 12),
                  Expanded(
                    child: TabBarView(
                      controller: mainChannelTabController,
                      children: [
                        _buildModeChannelContainer(
                          mode: "online",
                          controller: adminController,
                          scrollController: onlineScrollController,
                          activeNotif: onlineNotification,
                          accentColor: accentBlue,
                        ),
                        _buildModeChannelContainer(
                          mode: "offline",
                          controller: adminController,
                          scrollController: offlineScrollController,
                          activeNotif: offlineNotification,
                          accentColor: accentOrange,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryBar({required bool isWide}) {
    return Obx(() {
      final users = adminController.usersList;
      final online = users
          .where((u) => u['mode']?.toString().toLowerCase() == 'online')
          .length;
      final offline = users
          .where((u) => u['mode']?.toString().toLowerCase() == 'offline')
          .length;
      final granted = users.where(_hasUserBeenGrantedAccess).length;
      final pending = users.length - granted;

      final items = [
        _summaryItem(Icons.wifi_rounded, 'Online', online, accentBlue),
        _summaryItem(
          Icons.location_on_rounded,
          'Offline',
          offline,
          accentOrange,
        ),
        _summaryItem(
          Icons.verified_rounded,
          'Access ready',
          granted,
          successGreen,
        ),
        _summaryItem(
          Icons.pending_actions_rounded,
          'Pending',
          pending,
          goldenYellow,
        ),
      ];

      return LayoutBuilder(
        builder: (context, constraints) {
          return Row(
            children: [
              for (int i = 0; i < items.length; i++) ...[
                Expanded(child: items[i]),
                if (i != items.length - 1) const SizedBox(width: 8),
              ],
            ],
          );
        },
      );
    });
  }

  Widget _summaryItem(IconData icon, String label, int value, Color color) {
    return Container(
      height: 62,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withOpacity(.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 17),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$value',
                  style: GoogleFonts.poppins(
                    color: textColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    color: secondaryText,
                    fontSize: 9,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      controller: searchController,
      onChanged: (value) => adminController.searchQuery.value = value.trim(),
      style: GoogleFonts.poppins(color: textColor, fontSize: 12.5),
      decoration: InputDecoration(
        hintText: 'Search by student name or phone number',
        hintStyle: GoogleFonts.poppins(color: secondaryText, fontSize: 11.5),
        prefixIcon: Icon(Icons.search_rounded, color: accentPurple, size: 20),
        suffixIcon: Obx(
          () => adminController.searchQuery.value.isNotEmpty
              ? IconButton(
                  onPressed: () {
                    searchController.clear();
                    adminController.searchQuery.value = '';
                  },
                  icon: Icon(
                    Icons.close_rounded,
                    color: secondaryText,
                    size: 18,
                  ),
                )
              : const SizedBox.shrink(),
        ),
        filled: true,
        fillColor: cardColor,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 15,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: accentBlue, width: 1.4),
        ),
      ),
    );
  }

  Widget _buildModeChannelContainer({
    required String mode,
    required AdminController controller,
    required ScrollController scrollController,
    required String? activeNotif,
    required Color accentColor,
  }) {
    final isOnline = mode == 'online';

    return Column(
      children: [
        _buildChannelAndAnnouncementRow(
          mode: mode,
          isOnline: isOnline,
          accentColor: accentColor,
          activeNotif: activeNotif,
        ),
        const SizedBox(height: 10),
        _buildAccessFilter(mode, controller, accentColor),
        const SizedBox(height: 10),
        _buildFilterToolbar(mode, accentColor, grantedOnly: selectedStatusFilter == 0),
        const SizedBox(height: 10),
        Expanded(
          child: _buildSubcategorizedList(
            controller,
            mode,
            scrollController,
            grantedOnly: selectedStatusFilter == 0,
          ),
        ),
      ],
    );
  }

  Widget _buildChannelAndAnnouncementRow({
    required String mode,
    required bool isOnline,
    required Color accentColor,
    required String? activeNotif,
  }) {
    return Row(
      children: [
        Expanded(child: _buildChannelSwitcher(mode, isOnline, accentColor)),
        const SizedBox(width: 10),
        _buildAnnouncementAction(
          mode: mode,
          activeNotif: activeNotif,
          accentColor: accentColor,
        ),
      ],
    );
  }

  Widget _buildAnnouncementAction({
    required String mode,
    required String? activeNotif,
    required Color accentColor,
  }) {
    final cleanMode = mode.toLowerCase().trim();
    final hasNotice = activeNotif != null && activeNotif.trim().isNotEmpty;
    final displayMode = cleanMode == 'online' ? 'Online' : 'Offline';

    return PopupMenuButton<String>(
      tooltip: 'Manage announcement',
      offset: const Offset(0, 8),
      color: cardColor,
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: borderColor),
      ),
      onSelected: (value) {
        if (value == 'post') {
          _openBroadcastDialog(cleanMode);
        } else if (value == 'clear') {
          _deleteNotification(cleanMode);
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          value: 'post',
          child: Row(
            children: [
              Icon(
                hasNotice ? Icons.edit_rounded : Icons.add_rounded,
                color: accentColor,
                size: 18,
              ),
              const SizedBox(width: 10),
              Text(
                hasNotice ? 'Edit $displayMode Notice' : 'Post $displayMode Notice',
                style: GoogleFonts.poppins(
                  color: textColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        if (hasNotice)
          PopupMenuItem<String>(
            value: 'clear',
            child: Row(
              children: [
                Icon(Icons.delete_outline_rounded, color: alertRed, size: 18),
                const SizedBox(width: 10),
                Text(
                  'Clear $displayMode Notice',
                  style: GoogleFonts.poppins(
                    color: alertRed,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
      ],
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 11),
        decoration: BoxDecoration(
          color: hasNotice ? accentColor.withOpacity(.10) : cardColor,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: hasNotice ? accentColor.withOpacity(.35) : borderColor,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasNotice ? Icons.campaign_rounded : Icons.campaign_outlined,
              color: accentColor,
              size: 18,
            ),
            const SizedBox(width: 7),
            Text(
              hasNotice ? '$displayMode Notice' : 'Post $displayMode',
              style: GoogleFonts.poppins(
                color: accentColor,
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 3),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: secondaryText,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChannelSwitcher(String mode, bool isOnline, Color color) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: surfaceSubtle,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Expanded(
            child: _channelButton(
              title: 'Online students',
              icon: Icons.wifi_rounded,
              selected: isOnline,
              color: accentBlue,
              onTap: () => mainChannelTabController.animateTo(0),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _channelButton(
              title: 'Offline students',
              icon: Icons.location_on_rounded,
              selected: !isOnline,
              color: accentOrange,
              onTap: () => mainChannelTabController.animateTo(1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _channelButton({
    required String title,
    required IconData icon,
    required bool selected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(11),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
          decoration: BoxDecoration(
            color: selected ? color : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 15,
                color: selected ? Colors.white : secondaryText,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    color: selected ? Colors.white : secondaryText,
                    fontSize: 10.5,
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

  Widget _buildAccessFilter(
    String mode,
    AdminController controller,
    Color accentColor,
  ) {
    return Obx(() {
      final granted = controller.usersList
          .where(
            (user) =>
                user['mode']?.toString().toLowerCase() == mode &&
                _hasUserBeenGrantedAccess(user),
          )
          .length;
      final pending = controller.usersList
          .where(
            (user) =>
                user['mode']?.toString().toLowerCase() == mode &&
                !_hasUserBeenGrantedAccess(user),
          )
          .length;

      return Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: surfaceSubtle,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            Expanded(
              child: _filterButton(
                label: 'Ready to learn',
                count: granted,
                selected: selectedStatusFilter == 0,
                color: successGreen,
                onTap: () => setState(() => selectedStatusFilter = 0),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: _filterButton(
                label: 'Needs access',
                count: pending,
                selected: selectedStatusFilter == 1,
                color: goldenYellow,
                onTap: () => setState(() => selectedStatusFilter = 1),
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _filterButton({
    required String label,
    required int count,
    required bool selected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: selected ? color : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                size: 14,
                color: selected ? Colors.white : secondaryText,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  '$label  $count',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    color: selected ? Colors.white : secondaryText,
                    fontSize: 10.5,
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

  Widget _buildSubcategorizedList(
    AdminController controller,
    String mode,
    ScrollController scrollController, {
    required bool grantedOnly,
  }) {
    return Obx(() {
      if (controller.isLoading.value && controller.usersList.isEmpty) {
        return Center(
          child: CircularProgressIndicator(
            color: accentPurple,
            strokeWidth: 2.2,
          ),
        );
      }

      final f = _filters[mode]!;
      final filteredList = _baseList(mode, grantedOnly)
          .where((u) => _passes(u, f, mode, grantedOnly: grantedOnly))
          .toList();

      if (filteredList.isEmpty && _activeCount(mode, grantedOnly) > 0) {
        return _buildEmptyState(
          'No students match these filters',
          'Remove a filter above or tap "Clear all".',
          Icons.filter_alt_off_rounded,
        );
      }

      if (filteredList.isEmpty) {
        return _buildEmptyState(
          grantedOnly
              ? 'No students with active access'
              : 'No students waiting for access',
          grantedOnly
              ? 'Students with granted stages will appear here.'
              : 'New registrations without course access will appear here.',
          grantedOnly ? Icons.verified_rounded : Icons.person_add_alt_1_rounded,
        );
      }

      return LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;

          final int columns;
          if (width < 600) {
            columns = 1;
          } else if (width < 950) {
            columns = 2;
          } else if (width < 1250) {
            columns = 3;
          } else {
            columns = 4;
          }

          return RefreshIndicator(
            onRefresh: () => controller.fetchAllUsers(isRefresh: true),
            color: accentPurple,
            backgroundColor: cardColor,
            child: GridView.builder(
              controller: scrollController,
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              padding: const EdgeInsets.only(top: 2, bottom: 24),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                crossAxisSpacing: columns == 1 ? 0 : 10,
                mainAxisSpacing: 10,
                mainAxisExtent: columns == 1 ? 142 : 150,
              ),
              itemCount: filteredList.length + 1,
              itemBuilder: (context, index) {
                if (index == filteredList.length) {
                  return controller.isMoreLoading.value
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: accentPurple,
                            ),
                          ),
                        )
                      : const SizedBox.shrink();
                }

                return _buildStudentTile(filteredList[index], mode, controller);
              },
            ),
          );
        },
      );
    });
  }

  Widget _buildEmptyState(String title, String subtitle, IconData icon) {
    return Center(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 32),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: accentBlue, size: 34),
            const SizedBox(height: 10),
            Text(
              title,
              style: GoogleFonts.poppins(
                color: textColor,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: GoogleFonts.poppins(color: secondaryText, fontSize: 10.5),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentTile(
    dynamic user,
    String mode,
    AdminController controller,
  ) {
    final name = user['name']?.toString().trim().isNotEmpty == true
        ? user['name'].toString().trim()
        : 'Unknown';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final phone = user['phone']?.toString() ?? 'No Phone';
    final isOnline = mode.toLowerCase() == 'online';
    final isPaid =
        (user['feeStatus'] ?? 'unpaid').toString().toLowerCase() == 'paid';
    final section = user['onlineSection']?.toString() ?? 'A';
    final hasAccess = _hasUserBeenGrantedAccess(user);

    final modeColor = isOnline ? accentBlue : const Color(0xFFB58A00);
    final actionColor = hasAccess ? accentPurple : accentBlue;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => AdminShellNavigation.openUserControl(user),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: hasAccess ? borderColor : goldenYellow.withOpacity(.40),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(.025),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: modeColor.withOpacity(.10),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: modeColor.withOpacity(.16)),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      initial,
                      style: GoogleFonts.poppins(
                        color: isOnline
                            ? accentPurple
                            : const Color(0xFF9A7400),
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            color: textColor,
                            fontWeight: FontWeight.w700,
                            fontSize: 12.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          phone,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            color: secondaryText,
                            fontSize: 9.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'More actions',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 36,
                      minHeight: 36,
                    ),
                    icon: Icon(
                      Icons.more_horiz_rounded,
                      color: secondaryText,
                      size: 19,
                    ),
                    onSelected: (value) {
                      if (value == 'delete') {
                        Get.defaultDialog(
                          title: 'Delete Student?',
                          titleStyle: GoogleFonts.poppins(
                            color: textColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                          middleText: 'Permanently delete $name?',
                          middleTextStyle: GoogleFonts.poppins(
                            color: secondaryText,
                            fontSize: 12,
                          ),
                          textConfirm: 'Delete',
                          textCancel: 'Cancel',
                          confirmTextColor: Colors.white,
                          buttonColor: alertRed,
                          backgroundColor: cardColor,
                          radius: 14,
                          onConfirm: () {
                            controller.deleteUser(user['_id'] ?? user['id']);
                            Get.back();
                          },
                        );
                      }
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem<String>(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(
                              Icons.delete_outline_rounded,
                              color: alertRed,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            const Text('Delete student'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 5,
                runSpacing: 5,
                children: [
                  _smallChip(isOnline ? 'Online' : 'Offline', modeColor),
                  if (isOnline && section.isNotEmpty && section != 'None')
                    _smallChip('Section $section', accentBlue),
                  _smallChip(
                    isPaid ? 'Paid' : 'Unpaid',
                    isPaid ? successGreen : alertRed,
                  ),
                  _smallChip(
                    hasAccess ? 'Access ready' : 'Needs access',
                    hasAccess ? successGreen : goldenYellow,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 32,
                child: OutlinedButton.icon(
                  onPressed: () => AdminShellNavigation.openUserControl(user),
                  icon: Icon(
                    hasAccess ? Icons.tune_rounded : Icons.lock_open_rounded,
                    size: 14,
                  ),
                  label: Text(
                    hasAccess ? 'Manage student' : 'Grant access',
                    style: GoogleFonts.poppins(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: actionColor,
                    side: BorderSide(color: actionColor.withOpacity(.28)),
                    backgroundColor: actionColor.withOpacity(.035),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // 🔎 TOOLBAR: [ Filter (2) ]  [ Counts ]  +  applied filter pills
  // ---------------------------------------------------------------------
  Widget _buildFilterToolbar(String mode, Color accentColor, {required bool grantedOnly}) {
    return Obx(() {
      final f = _filters[mode]!;
      final base = _baseList(mode, grantedOnly);
      final shown = base.where((u) => _passes(u, f, mode, grantedOnly: grantedOnly)).length;
      final active = _activeCount(mode, grantedOnly);

      final pills = <Widget>[];
      void addPill(String label, Color color, VoidCallback onRemove) => pills.add(_appliedPill(label, color, onRemove));
      if (grantedOnly) {
        for (final l in f.langs) {
          addPill(l == 'english' ? 'English' : 'Hindi', l == 'english' ? accentBlue : hindiColor,
              () => setState(() => f.langs.remove(l)));
        }
        for (final st in (f.stages.toList()..sort())) {
          addPill('Stage $st', successGreen, () => setState(() => f.stages.remove(st)));
        }
      }
      if (mode == 'online') {
        for (final sec in (f.sections.toList()..sort())) {
          addPill('Section $sec', accentBlue, () => setState(() => f.sections.remove(sec)));
        }
      }
      for (final fee in f.fees) {
        addPill(fee == 'paid' ? 'Fee paid' : 'Fee unpaid', fee == 'paid' ? successGreen : alertRed,
            () => setState(() => f.fees.remove(fee)));
      }
      for (final b in f.batches) {
        addPill(b.isEmpty ? 'No timing' : b, accentPurple, () => setState(() => f.batches.remove(b)));
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _toolbarButton(
                icon: Icons.tune_rounded,
                label: 'Filter',
                badge: active,
                color: accentPurple,
                filled: active > 0,
                onTap: () => _openFilterPanel(mode, grantedOnly: grantedOnly),
              ),
              const SizedBox(width: 8),
              _toolbarButton(
                icon: Icons.bar_chart_rounded,
                label: 'Counts',
                color: accentPurple,
                onTap: () => _openBreakdownSheet(mode),
              ),
              const Spacer(),
              Text(
                active > 0 ? '$shown of ${base.length} students' : '${base.length} students',
                style: GoogleFonts.poppins(color: secondaryText, fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          if (pills.isNotEmpty) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 32,
              child: ListView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                children: [
                  for (final p in pills) ...[p, const SizedBox(width: 6)],
                  TextButton(
                    onPressed: () => setState(() => _filters[mode] = _StudentFilter()),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      minimumSize: const Size(0, 32),
                    ),
                    child: Text('Clear all',
                        style: GoogleFonts.poppins(color: alertRed, fontSize: 11, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
          ],
        ],
      );
    });
  }

  Widget _toolbarButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    int badge = 0,
    bool filled = false,
  }) {
    return Material(
      color: filled ? color : cardColor,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: filled ? color : borderColor),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 17, color: filled ? Colors.white : color),
              const SizedBox(width: 6),
              Text(label,
                  style: GoogleFonts.poppins(
                      color: filled ? Colors.white : textColor, fontSize: 12, fontWeight: FontWeight.w700)),
              if (badge > 0) ...[
                const SizedBox(width: 6),
                Container(
                  width: 20,
                  height: 20,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: goldenYellow, shape: BoxShape.circle),
                  child: Text('$badge',
                      style: GoogleFonts.poppins(color: textColor, fontSize: 10, fontWeight: FontWeight.w800)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _appliedPill(String label, Color color, VoidCallback onRemove) {
    return Container(
      padding: const EdgeInsets.only(left: 11, right: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: GoogleFonts.poppins(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
          InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              onRemove();
            },
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(Icons.close_rounded, size: 15, color: color),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  // 🧰 FILTER PANEL — groups on the left, options on the right (like Flipkart)
  // Phone: full-height sheet from the bottom • Web/tablet: side panel
  // ---------------------------------------------------------------------
  void _openFilterPanel(String mode, {required bool grantedOnly}) {
    final isOnline = mode == 'online';
    final draft = _filters[mode]!.copy();
    final base = _baseList(mode, grantedOnly);

    // groups shown on this tab
    final groups = <Map<String, dynamic>>[
      if (grantedOnly) {'key': 'lang', 'title': 'Language', 'icon': Icons.translate_rounded},
      if (grantedOnly) {'key': 'stage', 'title': 'Stage', 'icon': Icons.stairs_rounded},
      if (isOnline) {'key': 'section', 'title': 'Section', 'icon': Icons.view_module_rounded},
      {'key': 'fee', 'title': 'Fee status', 'icon': Icons.payments_rounded},
      {'key': 'batch', 'title': 'Class timing', 'icon': Icons.schedule_rounded},
    ];

    // all class timings that exist on this tab
    final batches = base.map(_batchOf).toSet().toList()
      ..sort((a, b) {
        if (a.isEmpty) return 1;
        if (b.isEmpty) return -1;
        return _batchSortKey(a).compareTo(_batchSortKey(b));
      });

    String active = groups.first['key'] as String;

    int groupCount(String key) {
      switch (key) {
        case 'lang':
          return draft.langs.length;
        case 'stage':
          return draft.stages.length;
        case 'section':
          return draft.sections.length;
        case 'fee':
          return draft.fees.length;
        default:
          return draft.batches.length;
      }
    }

    Widget panel(BuildContext ctx, StateSetter setPanel, bool wide) {
      // how many students each option would give (other groups applied, own group ignored)
      int countWith(String skip, bool Function(dynamic u) test) => base
          .where((u) => _passes(u, draft, mode, grantedOnly: grantedOnly, skip: skip) && test(u))
          .length;
      final total = base.where((u) => _passes(u, draft, mode, grantedOnly: grantedOnly)).length;

      void toggle<T>(Set<T> set, T v) => setPanel(() => set.contains(v) ? set.remove(v) : set.add(v));

      List<Widget> options() {
        switch (active) {
          case 'lang':
            return [
              _optionTile('English', countWith('course', (u) {
                final st = draft.stages.isEmpty ? [0] : draft.stages.toList();
                return st.any((s) => _hasStage(u, 'english', s));
              }), draft.langs.contains('english'), () => toggle(draft.langs, 'english'), accentBlue),
              _optionTile('Hindi', countWith('course', (u) {
                final st = draft.stages.isEmpty ? [0] : draft.stages.toList();
                return st.any((s) => _hasStage(u, 'hindi', s));
              }), draft.langs.contains('hindi'), () => toggle(draft.langs, 'hindi'), hindiColor),
            ];
          case 'stage':
            return [
              for (int st = 1; st <= 7; st++)
                _optionTile('Stage $st', countWith('course', (u) {
                  final ls = draft.langs.isEmpty ? ['english', 'hindi'] : draft.langs.toList();
                  return ls.any((l) => _hasStage(u, l, st));
                }), draft.stages.contains(st), () => toggle(draft.stages, st), successGreen),
            ];
          case 'section':
            return [
              for (final sec in _sections)
                _optionTile('Section $sec', countWith('section', (u) => _sectionOf(u) == sec),
                    draft.sections.contains(sec), () => toggle(draft.sections, sec), accentBlue),
            ];
          case 'fee':
            return [
              _optionTile('Paid', countWith('fee', (u) => _feeOf(u) == 'paid'), draft.fees.contains('paid'),
                  () => toggle(draft.fees, 'paid'), successGreen),
              _optionTile('Unpaid', countWith('fee', (u) => _feeOf(u) == 'unpaid'), draft.fees.contains('unpaid'),
                  () => toggle(draft.fees, 'unpaid'), alertRed),
            ];
          default:
            if (batches.isEmpty) {
              return [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('No class timings yet', style: GoogleFonts.poppins(color: secondaryText, fontSize: 12)),
                )
              ];
            }
            return [
              for (final b in batches)
                _optionTile(b.isEmpty ? 'Not chosen' : b, countWith('batch', (u) => _batchOf(u) == b),
                    draft.batches.contains(b), () => toggle(draft.batches, b), accentPurple),
            ];
        }
      }

      return Column(
        children: [
          // ---- header
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 8, 10),
            child: Row(
              children: [
                Icon(Icons.tune_rounded, color: accentPurple, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Filters',
                          style: GoogleFonts.poppins(color: textColor, fontSize: 17, fontWeight: FontWeight.w700)),
                      Text('${isOnline ? 'Online' : 'Offline'} • ${grantedOnly ? 'Ready to learn' : 'Needs access'}',
                          style: GoogleFonts.poppins(color: secondaryText, fontSize: 10.5)),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: draft.isEmpty ? null : () => setPanel(() {
                    draft.langs.clear();
                    draft.stages.clear();
                    draft.sections.clear();
                    draft.fees.clear();
                    draft.batches.clear();
                  }),
                  child: Text('Clear all',
                      style: GoogleFonts.poppins(
                          color: draft.isEmpty ? secondaryText : alertRed, fontSize: 12, fontWeight: FontWeight.w700)),
                ),
                IconButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  icon: const Icon(Icons.close_rounded, color: secondaryText),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: borderColor),
          // ---- body: groups | options
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: wide ? 150 : 128,
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
                                left: BorderSide(
                                  color: active == g['key'] ? accentPurple : Colors.transparent,
                                  width: 4,
                                ),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(g['icon'] as IconData,
                                    size: 16, color: active == g['key'] ? accentPurple : secondaryText),
                                const SizedBox(width: 7),
                                Expanded(
                                  child: Text(
                                    g['title'] as String,
                                    style: GoogleFonts.poppins(
                                      color: active == g['key'] ? textColor : secondaryText,
                                      fontSize: 12,
                                      fontWeight: active == g['key'] ? FontWeight.w700 : FontWeight.w600,
                                    ),
                                  ),
                                ),
                                if (groupCount(g['key'] as String) > 0)
                                  Container(
                                    width: 18,
                                    height: 18,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(color: accentPurple, shape: BoxShape.circle),
                                    child: Text('${groupCount(g['key'] as String)}',
                                        style: GoogleFonts.poppins(
                                            color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w700)),
                                  ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    children: options(),
                  ),
                ),
              ],
            ),
          ),
          // ---- footer: live result + apply
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
                      Text('$total',
                          style: GoogleFonts.poppins(color: textColor, fontSize: 18, fontWeight: FontWeight.w800)),
                      Text('students found', style: GoogleFonts.poppins(color: secondaryText, fontSize: 10.5)),
                    ],
                  ),
                ),
                SizedBox(
                  height: 46,
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() => _filters[mode] = draft);
                      Navigator.of(ctx).pop();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentPurple,
                      foregroundColor: Colors.white,
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
      // side panel sliding in from the right
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
          height: MediaQuery.of(ctx).size.height * .86,
          child: StatefulBuilder(builder: (c, sp) => panel(c, sp, false)),
        ),
      );
    }
  }

  /// "05:30 AM - 07:00 AM" → minutes from midnight (for sorting)
  int _batchSortKey(String b) {
    final m = RegExp(r'(\d{1,2}):(\d{2})\s*([AP]M)', caseSensitive: false).firstMatch(b);
    if (m == null) return 99999;
    var h = int.parse(m.group(1)!) % 12;
    if (m.group(3)!.toUpperCase() == 'PM') h += 12;
    return h * 60 + int.parse(m.group(2)!);
  }

  Widget _optionTile(String label, int count, bool selected, VoidCallback onTap, Color color) {
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: selected ? color : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: selected ? color : const Color(0xFFB7C9D6), width: 1.6),
              ),
              child: selected ? const Icon(Icons.check_rounded, size: 16, color: Colors.white) : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label,
                  style: GoogleFonts.poppins(
                      color: count == 0 && !selected ? secondaryText : textColor,
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500)),
            ),
            Text('$count',
                style: GoogleFonts.poppins(
                    color: count == 0 ? const Color(0xFFB7C9D6) : secondaryText,
                    fontSize: 12,
                    fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // 📊 COUNTS SHEET — stage × language, sections. Tap a number to filter.
  // ---------------------------------------------------------------------
  void _openBreakdownSheet(String mode) {
    final isOnline = mode == 'online';
    final all = adminController.usersList.where((u) => u['mode']?.toString().toLowerCase() == mode).toList();
    final ready = all.where(_hasUserBeenGrantedAccess).toList();

    int count(String lang, int stage, {String? section}) => ready.where((u) {
          final ok = lang == 'all'
              ? (_hasStage(u, 'english', stage) || _hasStage(u, 'hindi', stage))
              : _hasStage(u, lang, stage);
          return ok && (section == null || _sectionOf(u) == section);
        }).length;

    void pick({String? lang, int? stage, String? section}) {
      Get.back();
      setState(() {
        selectedStatusFilter = 0;
        _filters[mode] = _StudentFilter(
          langs: lang == null ? null : {lang},
          stages: stage == null ? null : {stage},
          sections: section == null ? null : {section},
        );
      });
    }

    Widget cell(String text, {VoidCallback? onTap, bool bold = false, Color? color, int flex = 2}) => Expanded(
          flex: flex,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(
                text,
                textAlign: flex == 3 ? TextAlign.left : TextAlign.center,
                style: GoogleFonts.poppins(
                  color: color ?? textColor,
                  fontSize: 12.5,
                  fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ),
          ),
        );

    Widget header(List<String> cols) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(color: softSurface, borderRadius: BorderRadius.circular(10)),
          child: Row(children: [
            for (int i = 0; i < cols.length; i++)
              Expanded(
                flex: i == 0 ? 3 : 2,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  child: Text(cols[i],
                      textAlign: i == 0 ? TextAlign.left : TextAlign.center,
                      style: GoogleFonts.poppins(color: secondaryText, fontSize: 10.5, fontWeight: FontWeight.w700)),
                ),
              ),
          ]),
        );

    Widget row(List<Widget> cells, {bool total = false}) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: total ? accentPurple.withOpacity(.06) : null,
            border: const Border(bottom: BorderSide(color: borderColor)),
          ),
          child: Row(children: cells),
        );

    Widget title(String t, IconData icon) => Padding(
          padding: const EdgeInsets.only(top: 18, bottom: 8),
          child: Row(children: [
            Icon(icon, size: 17, color: accentPurple),
            const SizedBox(width: 6),
            Text(t, style: GoogleFonts.poppins(color: textColor, fontSize: 13.5, fontWeight: FontWeight.w700)),
          ]),
        );

    Get.bottomSheet(
      Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * .88),
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(color: borderColor, borderRadius: BorderRadius.circular(4)),
                ),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Icon(isOnline ? Icons.wifi_rounded : Icons.location_on_rounded,
                    color: isOnline ? accentBlue : accentOrange),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('${isOnline ? 'Online' : 'Offline'} students — counts',
                      style: GoogleFonts.poppins(color: textColor, fontSize: 16, fontWeight: FontWeight.w700)),
                ),
                IconButton(onPressed: () => Get.back(), icon: const Icon(Icons.close_rounded, color: secondaryText)),
              ]),
              Text('Tap any number to see those students.',
                  style: GoogleFonts.poppins(color: secondaryText, fontSize: 11)),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _summaryItem(Icons.groups_rounded, 'Total', all.length, accentPurple)),
                const SizedBox(width: 8),
                Expanded(child: _summaryItem(Icons.verified_rounded, 'Access ready', ready.length, successGreen)),
                const SizedBox(width: 8),
                Expanded(
                    child: _summaryItem(
                        Icons.pending_actions_rounded, 'Needs access', all.length - ready.length, goldenYellow)),
              ]),
              title('Stage wise', Icons.stairs_rounded),
              header(['Stage', 'English', 'Hindi', 'Total']),
              for (int st = 1; st <= 7; st++)
                row([
                  cell('Stage $st', flex: 3, bold: true),
                  cell('${count('english', st)}', color: accentBlue, onTap: () => pick(lang: 'english', stage: st)),
                  cell('${count('hindi', st)}', color: hindiColor, onTap: () => pick(lang: 'hindi', stage: st)),
                  cell('${count('all', st)}', bold: true, onTap: () => pick(stage: st)),
                ]),
              row([
                cell('All stages', flex: 3, bold: true),
                cell('${count('english', 0)}', bold: true, color: accentBlue, onTap: () => pick(lang: 'english')),
                cell('${count('hindi', 0)}', bold: true, color: hindiColor, onTap: () => pick(lang: 'hindi')),
                cell('${ready.length}', bold: true, onTap: () => pick()),
              ], total: true),
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'A student in English and Hindi (or 2 stages) is counted in each row, but only once in "All stages".',
                  style: GoogleFonts.poppins(color: secondaryText, fontSize: 9.5),
                ),
              ),
              if (isOnline) ...[
                title('Section wise', Icons.view_module_rounded),
                header(['Section', 'English', 'Hindi', 'Total']),
                for (final sec in _sections)
                  row([
                    cell('Section $sec', flex: 3, bold: true),
                    cell('${count('english', 0, section: sec)}',
                        color: accentBlue, onTap: () => pick(lang: 'english', section: sec)),
                    cell('${count('hindi', 0, section: sec)}',
                        color: hindiColor, onTap: () => pick(lang: 'hindi', section: sec)),
                    cell('${count('all', 0, section: sec)}', bold: true, onTap: () => pick(section: sec)),
                  ]),
                title('Stage × Section', Icons.grid_on_rounded),
                header(['Stage', ..._sections]),
                for (int st = 1; st <= 7; st++)
                  row([
                    cell('Stage $st', flex: 3, bold: true),
                    for (final sec in _sections)
                      cell('${count('all', st, section: sec)}', onTap: () => pick(stage: st, section: sec)),
                  ]),
              ],
            ],
          ),
        ),
      ),
      isScrollControlled: true,
    );
  }

  Widget _smallChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(.10),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: GoogleFonts.poppins(
          color: color,
          fontSize: 8.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}