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

      var filteredList = controller.usersList.where((user) {
        final matchesMode =
            user['mode']?.toString().toLowerCase() == mode.toLowerCase();
        final hasAccess = _hasUserBeenGrantedAccess(user);
        return matchesMode && (grantedOnly ? hasAccess : !hasAccess);
      }).toList();

      if (controller.searchQuery.value.isNotEmpty) {
        final query = controller.searchQuery.value.toLowerCase();
        filteredList = filteredList.where((user) {
          final phone = user['phone']?.toString().toLowerCase() ?? '';
          final name = user['name']?.toString().toLowerCase() ?? '';
          return phone.contains(query) || name.contains(query);
        }).toList();
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