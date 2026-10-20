import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

import 'package:lets_speake_manager/Api/ApiendPoints.dart';
import 'package:lets_speake_manager/Api/api_headers.dart';
import 'package:lets_speake_manager/Navigation/AdminShellNavigation.dart';

class AdminFeeVerificationScreen extends StatefulWidget {
  const AdminFeeVerificationScreen({super.key});

  @override
  State<AdminFeeVerificationScreen> createState() =>
      _AdminFeeVerificationScreenState();
}

class _AdminFeeVerificationScreenState
    extends State<AdminFeeVerificationScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  static const Color primary = Color(0xFF2563EB);
  static const Color primarySoft = Color(0xFFEFF6FF);

  static const Color background = Color(0xFFF7F9FC);
  static const Color surface = Colors.white;

  static const Color textPrimary = Color(0xFF172033);
  static const Color textSecondary = Color(0xFF667085);
  static const Color border = Color(0xFFE4EAF2);

  static const Color success = Color(0xFF16A34A);
  static const Color successSoft = Color(0xFFECFDF3);

  static const Color danger = Color(0xFFDC2626);
  static const Color dangerSoft = Color(0xFFFEF2F2);

  static const Color warning = Color(0xFFD97706);
  static const Color warningSoft = Color(0xFFFFF7ED);

  late TabController _tabController;

  bool isLoading = true;
  bool isUpdating = false;

  List<dynamic> pendingStudents = [];
  List<dynamic> historyStudents = [];

  String selectedFilter = 'all';
  String selectedLanguage = 'all'; // all | English | Hindi
  DateTime? selectedDateFilter;

  final TextEditingController searchController = TextEditingController();

  String searchQuery = '';
  Timer? _autoRefreshTimer;
  IO.Socket? _socket; // 🚀 Real-time socket connection

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });

    fetchAllData();
    _initSocketListener();

    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      fetchAllData(silent: true);
    });
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    _socket?.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _tabController.dispose();
    searchController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      fetchAllData(silent: true);
    }
  }

  void _initSocketListener() {
    try {
      final uri = Uri.parse(ApiEndpoints.baseUrl);
      final host = "${uri.scheme}://${uri.host}:${uri.port}";

      _socket = IO.io(host, <String, dynamic>{
        'transports': ['websocket'],
        'autoConnect': true,
        'auth': {'token': ApiHeaders.token ?? ''},
      });

      _socket?.onConnect((_) {
        debugPrint("🔌 Fee verification connected to Socket.io");
        _socket?.emit('join_admin_room');
      });

      // 🚀 Instantly refresh pending lists when a student uploads a screenshot
      _socket?.on('fee_update', (_) {
        debugPrint("⚡ Real-time fee update received! Refreshing lists.");
        fetchAllData(silent: true);
      });
    } catch (e) {
      debugPrint("Socket init error: $e");
    }
  }

  Future<void> fetchAllData({bool silent = false}) async {
    if (!silent && mounted) {
      setState(() => isLoading = true);
    }

    await Future.wait([
      fetchPendingFees(),
      fetchFeeHistory(),
    ]);

    if (!silent && mounted) {
      setState(() => isLoading = false);
    }
  }

  Future<void> fetchPendingFees() async {
    try {
      final response = await http.get(Uri.parse(ApiEndpoints.pendingFees), headers: ApiHeaders.auth());
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            pendingStudents = data['students'] ?? [];
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching pending fees: $e');
    }
  }

  Future<void> fetchFeeHistory() async {
    try {
      final response = await http.get(Uri.parse(ApiEndpoints.feeHistory), headers: ApiHeaders.auth());
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            historyStudents = data['students'] ?? [];
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching fee history: $e');
    }
  }

  Future<void> verifyFee(String userId, String status) async {
    if (isUpdating) return;
    setState(() => isUpdating = true);

    try {
      final response = await http.post(
        Uri.parse(ApiEndpoints.verifyFee),
        headers: ApiHeaders.json(),
        body: jsonEncode({'userId': userId, 'status': status}),
      );

      if (response.statusCode == 200) {
        Get.snackbar(
          'Updated',
          status == 'verified' ? 'Payment approved successfully' : 'Payment rejected successfully',
          backgroundColor: status == 'verified' ? success : danger,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
          margin: const EdgeInsets.all(16),
          borderRadius: 14,
        );

        await fetchAllData(silent: true);
      } else {
        Get.snackbar(
          'Error',
          'Unable to update payment status',
          backgroundColor: danger,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
          margin: const EdgeInsets.all(16),
          borderRadius: 14,
        );
      }
    } catch (e) {
      debugPrint('verifyFee error: $e');
    } finally {
      if (mounted) setState(() => isUpdating = false);
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDateFilter ?? DateTime.now(),
      firstDate: DateTime(2025),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: primary),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && mounted) {
      setState(() => selectedDateFilter = picked);
    }
  }

  /// Course the fee is for (student picks it when uploading; old uploads are guessed by the server)
  String _language(dynamic student) {
    final v = (student['feeLanguage'] ?? '').toString().toLowerCase();
    return v == 'hindi' ? 'Hindi' : 'English';
  }

  bool _isOnline(dynamic student) {
    return (student['mode'] ?? 'online').toString().toLowerCase() == 'online';
  }

  String _studentName(dynamic student) {
    return (student['name'] ?? student['studentName'] ?? 'Student').toString();
  }

  String _studentPhone(dynamic student) {
    return (student['phone'] ?? student['mobile'] ?? '').toString();
  }

  String _status(dynamic student) {
    return (student['feePaymentStatus'] ?? student['status'] ?? 'pending_verification')
        .toString()
        .toLowerCase();
  }

  String _statusText(String status) {
    switch (status) {
      case 'verified':
      case 'approved':
        return 'VERIFIED';
      case 'rejected':
        return 'REJECTED';
      case 'pending_verification':
      case 'pending':
        return 'PENDING';
      default:
        return status.replaceAll('_', ' ').toUpperCase();
    }
  }

  DateTime? _getSubmittedDate(dynamic student) {
    final value = student['feeSubmittedAt'];
    if (value == null) return null;
    try {
      return DateTime.parse(value.toString());
    } catch (_) {
      return null;
    }
  }

  bool _matchesDate(dynamic student) {
    if (selectedDateFilter == null) return true;
    final date = _getSubmittedDate(student);
    if (date == null) return false;
    return date.year == selectedDateFilter!.year &&
        date.month == selectedDateFilter!.month &&
        date.day == selectedDateFilter!.day;
  }

  bool _matchesSearch(dynamic student) {
    final query = searchQuery.trim().toLowerCase();
    if (query.isEmpty) return true;
    return _studentName(student).toLowerCase().contains(query) ||
        _studentPhone(student).toLowerCase().contains(query);
  }

  List<dynamic> _filteredStudents(List<dynamic> list, {required bool isHistory}) {
    return list.where((student) {
      final online = _isOnline(student);
      if (selectedFilter == 'online' && !online) return false;
      if (selectedFilter == 'offline' && online) return false;
      if (selectedLanguage != 'all' && _language(student) != selectedLanguage) return false;
      if (isHistory && !_matchesDate(student)) return false;
      if (!_matchesSearch(student)) return false;
      return true;
    }).toList();
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'verified':
      case 'approved':
        return success;
      case 'rejected':
        return danger;
      default:
        return warning;
    }
  }

  Color _statusBackground(String status) {
    switch (status) {
      case 'verified':
      case 'approved':
        return successSoft;
      case 'rejected':
        return dangerSoft;
      default:
        return warningSoft;
    }
  }

  void _openAdminDrawer() {
    AdminShellNavigation.openDrawer();
  }

  Widget _buildHeader(BuildContext context, bool isMobile) {
    return Container(
      width: double.infinity,
      height: isMobile ? 54 : 60,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: border, width: 1)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: isMobile ? 50 : 58,
            child: Center(
              child: IconButton(
                tooltip: 'Open menu',
                onPressed: _openAdminDrawer,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 42, minHeight: 42),
                icon: const Icon(Icons.menu_rounded, color: textPrimary, size: 25),
              ),
            ),
          ),
          Container(
            width: isMobile ? 34 : 38,
            height: isMobile ? 34 : 38,
            decoration: BoxDecoration(
              color: const Color(0xFF0F5A87),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(Icons.verified_rounded, color: Colors.white, size: isMobile ? 18 : 20),
          ),
          SizedBox(width: isMobile ? 9 : 11),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Fee Verification',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(color: textPrimary, fontSize: isMobile ? 15 : 18, fontWeight: FontWeight.w700, height: 1.05),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.only(right: isMobile ? 5 : 9),
            child: IconButton(
              tooltip: 'Refresh',
              onPressed: isLoading ? null : () => fetchAllData(),
              icon: isLoading
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: primary))
                  : const Icon(Icons.refresh_rounded, color: textPrimary, size: 23),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Color iconBackground,
    required bool isMobile,
  }) {
    return Container(
      height: 58,
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 7 : 9, vertical: 5),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(isMobile ? 17 : 20),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Container(
            width: isMobile ? 28 : 30,
            height: isMobile ? 28 : 30,
            decoration: BoxDecoration(color: iconBackground, borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: iconColor, size: isMobile ? 14 : 15),
          ),
          SizedBox(width: isMobile ? 6 : 7),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.poppins(color: textSecondary, fontSize: isMobile ? 8 : 8.5, fontWeight: FontWeight.w500)),
                Text(value, maxLines: 1, style: GoogleFonts.poppins(color: textPrimary, fontSize: isMobile ? 16 : 17, fontWeight: FontWeight.w700, height: 1.05)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabs(bool isMobile) {
    return Container(
      height: isMobile ? 38 : 40,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: border),
      ),
      child: TabBar(
        controller: _tabController,
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(color: primary, borderRadius: BorderRadius.circular(13)),
        labelColor: Colors.white,
        unselectedLabelColor: textSecondary,
        labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: isMobile ? 9.5 : 11),
        unselectedLabelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w500, fontSize: isMobile ? 9.5 : 11),
        tabs: [
          Tab(height: 32, text: 'Pending Review (${pendingStudents.length})'),
          Tab(height: 32, text: 'Accounting History (${historyStudents.length})'),
        ],
      ),
    );
  }

  // 🇬🇧 English / 🇮🇳 Hindi split
  Widget _buildLanguageBar(bool isMobile) {
    final list = _tabController.index == 0 ? pendingStudents : historyStudents;
    final en = list.where((s) => _language(s) == 'English').length;
    final hi = list.where((s) => _language(s) == 'Hindi').length;

    Widget seg(String value, String label, int count, Color color) {
      final selected = selectedLanguage == value;
      return Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(11),
          onTap: () => setState(() => selectedLanguage = value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: EdgeInsets.symmetric(vertical: isMobile ? 7 : 8),
            decoration: BoxDecoration(
              color: selected ? color : Colors.transparent,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      color: selected ? Colors.white : textSecondary,
                      fontSize: isMobile ? 10.5 : 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 5),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: selected ? Colors.white.withOpacity(.22) : border,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$count',
                    style: GoogleFonts.poppins(
                      color: selected ? Colors.white : textSecondary,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          seg('all', 'All courses', list.length, const Color(0xFF0F5A87)),
          const SizedBox(width: 3),
          seg('English', '🇬🇧 English', en, primary),
          const SizedBox(width: 3),
          seg('Hindi', '🇮🇳 Hindi', hi, const Color(0xFFEA580C)),
        ],
      ),
    );
  }

  Widget _buildFilterSection(BuildContext context, bool isMobile) {
    final showDateFilter = _tabController.index == 1;

    return Container(
      padding: EdgeInsets.all(isMobile ? 6 : 7),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Column(
        children: [
          TextField(
            controller: searchController,
            onChanged: (value) => setState(() => searchQuery = value),
            style: GoogleFonts.poppins(color: textPrimary, fontSize: 11.5),
            decoration: InputDecoration(
              hintText: 'Search student name or phone...',
              hintStyle: GoogleFonts.poppins(color: textSecondary, fontSize: 11.5),
              prefixIcon: const Icon(Icons.search_rounded, color: textSecondary),
              suffixIcon: searchQuery.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        searchController.clear();
                        setState(() => searchQuery = '');
                      },
                      icon: const Icon(Icons.close_rounded, color: textSecondary),
                    ),
              filled: true,
              fillColor: const Color(0xFFF7F9FC),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: border)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: primary, width: 1.3)),
            ),
          ),
          const SizedBox(height: 6),
          if (isMobile)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: _filterButtons(context, showDateFilter, true)),
            )
          else
            Row(children: _filterButtons(context, showDateFilter, false)),
        ],
      ),
    );
  }

  List<Widget> _filterButtons(BuildContext context, bool showDateFilter, bool isMobile) {
    final widgets = <Widget>[];

    if (showDateFilter) {
      widgets.add(
        _buildFilterButton(
          icon: Icons.calendar_month_rounded,
          text: selectedDateFilter == null ? 'All Dates' : DateFormat('dd MMM yyyy').format(selectedDateFilter!),
          selected: false,
          onTap: () => _selectDate(context),
        ),
      );
      widgets.add(const SizedBox(width: 8));
      if (selectedDateFilter != null) {
        widgets.add(
          _buildFilterButton(
            icon: Icons.close_rounded,
            text: 'Clear Date',
            selected: false,
            isDanger: true,
            onTap: () => setState(() => selectedDateFilter = null),
          ),
        );
        widgets.add(const SizedBox(width: 8));
      }
    }

    if (!isMobile && widgets.isNotEmpty) widgets.add(const Spacer());

    widgets.add(_buildFilterButton(icon: Icons.list_alt_rounded, text: 'All', selected: selectedFilter == 'all', onTap: () => setState(() => selectedFilter = 'all')));
    widgets.add(const SizedBox(width: 8));
    widgets.add(_buildFilterButton(icon: Icons.wifi_rounded, text: 'Online', selected: selectedFilter == 'online', onTap: () => setState(() => selectedFilter = 'online')));
    widgets.add(const SizedBox(width: 8));
    widgets.add(_buildFilterButton(icon: Icons.person_outline_rounded, text: 'Offline', selected: selectedFilter == 'offline', onTap: () => setState(() => selectedFilter = 'offline')));

    return widgets;
  }

  Widget _buildFilterButton({
    required IconData icon,
    required String text,
    required bool selected,
    required VoidCallback onTap,
    bool isDanger = false,
  }) {
    final Color contentColor = selected ? Colors.white : (isDanger ? danger : textSecondary);
    final Color borderColor = selected ? primary : (isDanger ? danger.withOpacity(0.25) : border);

    return Material(
      color: selected ? primary : surface,
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        borderRadius: BorderRadius.circular(13),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: borderColor)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: contentColor),
              const SizedBox(width: 7),
              Text(text, style: GoogleFonts.poppins(color: contentColor, fontSize: 12.5, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }

  void _showProof(BuildContext context, String imageUrl) {
    Get.dialog(
      Dialog(
        backgroundColor: Colors.white,
        insetPadding: const EdgeInsets.all(18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800, maxHeight: 820),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text('Payment Proof', style: GoogleFonts.poppins(color: textPrimary, fontSize: 17, fontWeight: FontWeight.w700)),
                    const Spacer(),
                    IconButton(onPressed: Get.back, icon: const Icon(Icons.close_rounded)),
                  ],
                ),
                const SizedBox(height: 8),
                Flexible(
                  child: InteractiveViewer(
                    minScale: 0.7,
                    maxScale: 4,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(imageUrl, fit: BoxFit.contain),
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

  Future<void> _confirmVerification(dynamic student, String status) async {
    final name = _studentName(student);
    final isApprove = status == 'verified';

    final result = await Get.dialog<bool>(
      AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(isApprove ? 'Approve Payment?' : 'Reject Payment?', style: GoogleFonts.poppins(color: textPrimary, fontWeight: FontWeight.w700)),
        content: Text(isApprove ? 'Approve payment submitted by $name?' : 'Reject payment submitted by $name?', style: GoogleFonts.poppins(color: textSecondary, fontSize: 13)),
        actions: [
          TextButton(onPressed: () => Get.back(result: false), child: Text('Cancel', style: GoogleFonts.poppins(color: textSecondary, fontWeight: FontWeight.w600))),
          ElevatedButton(
            onPressed: isUpdating ? null : () => Get.back(result: true),
            style: ElevatedButton.styleFrom(backgroundColor: isApprove ? success : danger, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: Text(isApprove ? 'Approve' : 'Reject', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (result != true) return;
    final userId = (student['_id'] ?? student['id'])?.toString();
    if (userId == null || userId.isEmpty) return;
    await verifyFee(userId, status);
  }

  Widget _buildPaymentCard(BuildContext context, dynamic student, {required bool isHistory, required bool isMobile}) {
    final name = _studentName(student);
    final phone = _studentPhone(student);
    final online = _isOnline(student);
    final status = _status(student);
    final submittedDate = _getSubmittedDate(student);

    final statusColor = _statusColor(status);
    final statusBackground = _statusBackground(status);

    final screenshot = student['feePaymentScreenshot']?.toString();
    final hasScreenshot = screenshot != null && screenshot.isNotEmpty;
    final compactImageSize = isMobile ? 66.0 : 78.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(isMobile ? 8 : 9),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: hasScreenshot ? () => _showProof(context, screenshot) : null,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: compactImageSize,
                height: compactImageSize,
                color: const Color(0xFFF2F4F7),
                child: hasScreenshot
                    ? Image.network(screenshot, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined, color: textSecondary, size: 24))
                    : const Icon(Icons.image_outlined, color: textSecondary, size: 24),
              ),
            ),
          ),
          SizedBox(width: isMobile ? 9 : 11),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.poppins(color: textPrimary, fontSize: isMobile ? 13.5 : 15, fontWeight: FontWeight.w700)),
                const SizedBox(height: 3),
                Wrap(
                  spacing: 5,
                  runSpacing: 3,
                  children: [
                    _buildBadge(
                      _language(student) == 'Hindi' ? '🇮🇳 HINDI' : '🇬🇧 ENGLISH',
                      _language(student) == 'Hindi' ? const Color(0xFFEA580C) : const Color(0xFF0F5A87),
                      _language(student) == 'Hindi' ? const Color(0xFFFFF1E6) : const Color(0xFFE6F0F7),
                    ),
                    _buildBadge(online ? 'ONLINE' : 'OFFLINE', online ? primary : warning, online ? primarySoft : warningSoft),
                    _buildBadge(_statusText(status), statusColor, statusBackground),
                  ],
                ),
                if (phone.isNotEmpty || submittedDate != null) ...[
                  const SizedBox(height: 3),
                  Wrap(
                    spacing: 10,
                    runSpacing: 2,
                    children: [
                      if (phone.isNotEmpty) Text(phone, style: GoogleFonts.poppins(color: textSecondary, fontSize: isMobile ? 10.5 : 11.5)),
                      if (submittedDate != null) Text(DateFormat('dd MMM yyyy, hh:mm a').format(submittedDate), style: GoogleFonts.poppins(color: textSecondary, fontSize: isMobile ? 10 : 11)),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (hasScreenshot)
            SizedBox(
              height: 32,
              child: OutlinedButton.icon(
                onPressed: () => _showProof(context, screenshot),
                icon: const Icon(Icons.image_outlined, size: 14),
                label: Text(isMobile ? 'Proof' : 'View Proof', style: GoogleFonts.poppins(fontSize: 10.5, fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(foregroundColor: primary, backgroundColor: primarySoft, padding: const EdgeInsets.symmetric(horizontal: 9), side: const BorderSide(color: Color(0xFFB7D2FF)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9))),
              ),
            ),
          if (!isHistory && (status == 'pending_verification' || status == 'pending')) ...[
            const SizedBox(width: 6),
            SizedBox(
              height: 32,
              child: OutlinedButton(
                onPressed: isUpdating ? null : () => _confirmVerification(student, 'rejected'),
                style: OutlinedButton.styleFrom(foregroundColor: danger, backgroundColor: dangerSoft, padding: const EdgeInsets.symmetric(horizontal: 9), side: const BorderSide(color: Color(0xFFFECACA)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9))),
                child: const Icon(Icons.close_rounded, size: 16),
              ),
            ),
            const SizedBox(width: 6),
            SizedBox(
              height: 32,
              child: ElevatedButton(
                onPressed: isUpdating ? null : () => _confirmVerification(student, 'verified'),
                style: ElevatedButton.styleFrom(backgroundColor: success, foregroundColor: Colors.white, elevation: 0, padding: const EdgeInsets.symmetric(horizontal: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9))),
                child: const Icon(Icons.check_rounded, size: 16),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBadge(String text, Color color, Color backgroundColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(color: backgroundColor, borderRadius: BorderRadius.circular(8)),
      child: Text(text, style: GoogleFonts.poppins(color: color, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: .2)),
    );
  }

  Widget _buildStudentList(List<dynamic> list, {required bool isHistory}) {
    if (isLoading && list.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: primary));
    }
    final filtered = _filteredStudents(list, isHistory: isHistory);
    if (filtered.isEmpty) {
      return _buildEmptyState(isHistory: isHistory);
    }
    return RefreshIndicator(
      color: primary,
      onRefresh: fetchAllData,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(top: 8, bottom: 18),
        itemCount: filtered.length,
        itemBuilder: (context, index) {
          return _buildPaymentCard(context, filtered[index], isHistory: isHistory, isMobile: MediaQuery.sizeOf(context).width < 700);
        },
      ),
    );
  }

  Widget _buildEmptyState({required bool isHistory}) {
    return Center(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(width: 76, height: 64, decoration: BoxDecoration(color: primarySoft, borderRadius: BorderRadius.circular(22)), child: const Icon(Icons.receipt_long_outlined, color: primary, size: 36)),
              const SizedBox(height: 18),
              Text(isHistory ? 'No transaction history found' : 'No pending fee verifications', textAlign: TextAlign.center, style: GoogleFonts.poppins(color: textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStats(bool isMobile, int onlineCount, int offlineCount, int showingCount) {
    final cards = [
      _buildStatCard(title: 'Pending', value: '${pendingStudents.length}', subtitle: 'Awaiting review', icon: Icons.pending_actions_rounded, iconColor: warning, iconBackground: warningSoft, isMobile: isMobile),
      _buildStatCard(title: 'Pending English', value: '${pendingStudents.where((s) => _language(s) == 'English').length}', subtitle: 'English course', icon: Icons.translate_rounded, iconColor: const Color(0xFF0F5A87), iconBackground: const Color(0xFFE6F0F7), isMobile: isMobile),
      _buildStatCard(title: 'Pending Hindi', value: '${pendingStudents.where((s) => _language(s) == 'Hindi').length}', subtitle: 'Hindi course', icon: Icons.language_rounded, iconColor: const Color(0xFFEA580C), iconBackground: const Color(0xFFFFF1E6), isMobile: isMobile),
      _buildStatCard(title: 'Showing', value: '$showingCount', subtitle: 'Filtered list', icon: Icons.filter_alt_outlined, iconColor: success, iconBackground: successSoft, isMobile: isMobile),
    ];

    if (isMobile) {
      return SizedBox(
        height: 76,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.zero,
          itemCount: cards.length,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (context, index) => SizedBox(width: 118, child: cards[index]),
        ),
      );
    }

    return Row(
      children: [
        for (int i = 0; i < cards.length; i++) ...[
          Expanded(child: cards[i]),
          if (i != cards.length - 1) const SizedBox(width: 10),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 700;
        final pendingFiltered = _filteredStudents(pendingStudents, isHistory: false);
        final historyFiltered = _filteredStudents(historyStudents, isHistory: true);
        final currentList = _tabController.index == 0 ? pendingFiltered : historyFiltered;

        final onlineCount = historyStudents.where((student) => _isOnline(student)).length;
        final offlineCount = historyStudents.where((student) => !_isOnline(student)).length;

        return Scaffold(
          backgroundColor: background,
          body: SafeArea(
            child: Column(
              children: [
                _buildHeader(context, isMobile),
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1200),
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 24),
                        child: Column(
                          children: [
                            const SizedBox(height: 10),
                            _buildStats(isMobile, onlineCount, offlineCount, currentList.length),
                            SizedBox(height: isMobile ? 8 : 10),
                            _buildTabs(isMobile),
                            SizedBox(height: isMobile ? 7 : 9),
                            AnimatedBuilder(
                              animation: _tabController,
                              builder: (context, child) => _buildLanguageBar(isMobile),
                            ),
                            SizedBox(height: isMobile ? 6 : 8),
                            AnimatedBuilder(
                              animation: _tabController,
                              builder: (context, child) => _buildFilterSection(context, isMobile),
                            ),
                            const SizedBox(height: 8),
                            Expanded(
                              child: TabBarView(
                                controller: _tabController,
                                children: [
                                  _buildStudentList(pendingStudents, isHistory: false),
                                  _buildStudentList(historyStudents, isHistory: true),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

