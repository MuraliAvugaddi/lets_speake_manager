import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:lets_speake_manager/Api/ApiendPoints.dart';
import 'package:lets_speake_manager/Navigation/AdminShellNavigation.dart';



class RegisterAccountScreen extends StatefulWidget {
  const RegisterAccountScreen({super.key});

  @override
  State<RegisterAccountScreen> createState() => _RegisterAccountScreenState();
}

class _RegisterAccountScreenState extends State<RegisterAccountScreen> {
  static const Color navy = Color(0xFF155A88);
  static const Color deepNavy = Color(0xFF0E466D);
  static const Color blue = Color(0xFF2C6F9F);
  static const Color teal = Color(0xFF28C2C2);
  static const Color yellow = Color(0xFFF7DF55);

  static const Color background = Color(0xFFE8F2F8);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color softSurface = Color(0xFFF4F9FC);
  static const Color border = Color(0xFFD5E5EE);
  static const Color textColor = Color(0xFF173A52);
  static const Color secondaryText = Color(0xFF678196);
  static const Color success = Color(0xFF16A66A);
  static const Color error = Color(0xFFE45757);
  static const Color warning = Color(0xFFF2B84B);

  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  final passwordController = TextEditingController();

  String selectedRole = "teacher";
  String selectedMode = "online";
  String selectedLanguage = "English";
  String selectedStage = "stage1";
  String selectedSection = "A";

  bool isLoading = false;
  bool isFetchingStaff = true;
  bool obscurePassword = true;

  List<dynamic> registeredStaffList = [];

  final List<String> allStages = [
    "stage1",
    "stage2",
    "stage3",
    "stage4",
    "stage5",
    "stage6",
    "stage7",
  ];
  final List<String> allSections = ["A", "B", "C", "D", "E", "None"];
  final box = GetStorage();

  @override
  void initState() {
    super.initState();
    fetchRegisteredStaff();
  }

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  void _goBack() {
    if (Navigator.of(context).canPop()) {
      Get.back();
      return;
    }

    // If this screen is the shell's first route, open the admin drawer.
    AdminShellNavigation.openDrawer();
  }

  Future<void> fetchRegisteredStaff() async {
    if (!mounted) return;
    setState(() => isFetchingStaff = true);
    final String? token = box.read('token');

    try {
      final response = await http.get(
        Uri.parse("${ApiEndpoints.baseUrl}/admin/teachers"),
        headers: {"Authorization": "Bearer $token"},
      );

      if (!mounted) return;
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          registeredStaffList = data['teachers'] ?? [];
          isFetchingStaff = false;
        });
      } else {
        setState(() => isFetchingStaff = false);
      }
    } catch (e) {
      debugPrint("Fetch staff error: $e");
      if (mounted) setState(() => isFetchingStaff = false);
    }
  }

  Future<void> registerAccount() async {
    final name = nameController.text.trim();
    final phone = phoneController.text.trim();
    final password = passwordController.text.trim();

    if (name.isEmpty || phone.isEmpty || password.isEmpty) {
      _message(
        "Required fields",
        "Please enter name, phone number and password.",
        error: true,
      );
      return;
    }

    // Existing business rule: Hindi is online-only and has no section.
    final String finalMode = selectedLanguage == "Hindi"
        ? "online"
        : selectedMode;
    final String finalSection =
        (finalMode == "online" && selectedLanguage == "English")
        ? selectedSection
        : "None";

    if (!mounted) return;
    setState(() => isLoading = true);

    try {
      final response = await http.post(
        Uri.parse(ApiEndpoints.register),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "name": name,
          "phone": phone,
          "password": password,
          "mode": finalMode,
          "role": selectedRole,
          "language": selectedLanguage,
          "teacherStage": selectedStage,
          "teacherSection": finalSection,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 201) {
        _message(
          "Account created",
          "${selectedRole == "teacher" ? "Trainer" : "Manager"} account registered successfully.",
        );

        nameController.clear();
        phoneController.clear();
        passwordController.clear();

        if (mounted) {
          setState(() {
            selectedRole = "teacher";
            selectedMode = "online";
            selectedLanguage = "English";
            selectedStage = "stage1";
            selectedSection = "A";
          });
        }

        await fetchRegisteredStaff();
      } else {
        _message(
          "Registration failed",
          data['message']?.toString() ?? "Registration failed.",
          error: true,
        );
      }
    } catch (e) {
      debugPrint("Register account error: $e");
      _message(
        "Connection error",
        "Could not connect to the server.",
        error: true,
      );
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> deleteStaff(String staffId) async {
    final String? token = box.read('token');

    try {
      final response = await http.delete(
        Uri.parse("${ApiEndpoints.baseUrl}/users/$staffId"),
        headers: {"Authorization": "Bearer $token"},
      );

      if (response.statusCode == 200) {
        _message("Deleted", "Staff member removed successfully.");
        await fetchRegisteredStaff();
      } else {
        _message(
          "Delete failed",
          "Could not delete this staff member.",
          error: true,
        );
      }
    } catch (e) {
      debugPrint("Delete staff error: $e");
      _message(
        "Connection error",
        "Could not connect to the server.",
        error: true,
      );
    }
  }

  void _message(String title, String message, {bool error = false}) {
    Get.snackbar(
      title,
      message,
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.all(14),
      borderRadius: 12,
      backgroundColor: error ? _RegisterAccountScreenState.error : success,
      colorText: Colors.white,
      duration: const Duration(seconds: 3),
    );
  }

  void _confirmDelete(String staffId, String staffName) {
    Get.dialog(
      Dialog(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 410),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: error.withOpacity(.10),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.delete_outline_rounded, color: error),
                ),
                const SizedBox(height: 13),
                Text(
                  "Delete staff account?",
                  style: GoogleFonts.poppins(
                    color: textColor,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  "Remove $staffName from the registered staff list?",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    color: secondaryText,
                    fontSize: 11.5,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Get.back(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: textColor,
                          side: const BorderSide(color: border),
                          minimumSize: const Size.fromHeight(44),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(11),
                          ),
                        ),
                        child: const Text("Cancel"),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Get.back();
                          deleteStaff(staffId);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: error,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          minimumSize: const Size.fromHeight(44),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(11),
                          ),
                        ),
                        child: const Text("Delete"),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isWeb = width >= 900;

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: isWeb ? 70 : 60,
        leading: IconButton(
          tooltip: "Go back",
          onPressed: _goBack,
          icon: const Icon(Icons.arrow_back_rounded, color: textColor),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [deepNavy, blue]),
                borderRadius: BorderRadius.circular(11),
              ),
              child: const Icon(
                Icons.person_add_alt_1_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Trainer Registration",
                  style: GoogleFonts.poppins(
                    color: textColor,
                    fontSize: isWeb ? 18 : 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (isWeb)
                  Text(
                    "Create accounts and manage registered staff",
                    style: GoogleFonts.poppins(
                      color: secondaryText,
                      fontSize: 10,
                    ),
                  ),
              ],
            ),
          ],
        ),
        actions: [
          if (isWeb)
            Padding(
              padding: const EdgeInsets.only(right: 18),
              child: _headerCount(),
            ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final content = isWeb ? _webLayout() : _mobileLayout();

            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.only(bottom: isWeb ? 28 : 20),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: 1380,
                    minWidth: isWeb ? 0 : constraints.maxWidth,
                  ),
                  child: content,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _webLayout() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 390, child: _registrationPanel()),
          const SizedBox(width: 16),
          Expanded(child: _directoryPanel()),
        ],
      ),
    );
  }

  Widget _mobileLayout() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 4),
      child: Column(
        children: [
          _registrationPanel(),
          const SizedBox(height: 14),
          _directoryPanel(),
        ],
      ),
    );
  }

  Widget _registrationPanel() {
    final isHindi = selectedLanguage == "Hindi";
    final isEnglishOnline =
        selectedLanguage == "English" && selectedMode == "online";

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _panelHeader(
            Icons.person_add_alt_1_rounded,
            "Create account",
            "Set the login and teaching assignment.",
          ),
          const SizedBox(height: 16),
          _label("Account type"),
          const SizedBox(height: 7),
          Row(
            children: [
              Expanded(
                child: _choice(
                  title: "Trainer",
                  subtitle: "Teacher",
                  icon: Icons.school_rounded,
                  selected: selectedRole == "teacher",
                  onTap: () => setState(() => selectedRole = "teacher"),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _choice(
                  title: "Manager",
                  subtitle: "Management",
                  icon: Icons.manage_accounts_rounded,
                  selected: selectedRole == "manager",
                  onTap: () => setState(() => selectedRole = "manager"),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _textField(
            nameController,
            "Full name",
            "Enter name",
            Icons.person_outline_rounded,
          ),
          const SizedBox(height: 10),
          _textField(
            phoneController,
            "Phone / Login ID",
            "Enter phone number",
            Icons.phone_outlined,
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 10),
          _textField(
            passwordController,
            "Password",
            "Create password",
            Icons.lock_outline_rounded,
            obscureText: obscurePassword,
            suffixIcon: IconButton(
              onPressed: () =>
                  setState(() => obscurePassword = !obscurePassword),
              icon: Icon(
                obscurePassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                color: secondaryText,
                size: 18,
              ),
            ),
          ),
          const SizedBox(height: 16),
          _sectionDivider("Teaching assignment"),
          const SizedBox(height: 11),
          _dropdown(
            label: "Language",
            value: selectedLanguage,
            icon: Icons.translate_rounded,
            items: const ["English", "Hindi"],
            display: (v) => v,
            onChanged: (value) {
              if (value == null) return;
              setState(() {
                selectedLanguage = value;
                if (value == "Hindi") {
                  selectedMode = "online";
                  selectedSection = "None";
                } else if (selectedSection == "None") {
                  selectedSection = "A";
                }
              });
            },
          ),
          if (!isHindi) ...[
            const SizedBox(height: 9),
            _dropdown(
              label: "Mode",
              value: selectedMode,
              icon: selectedMode == "online"
                  ? Icons.wifi_rounded
                  : Icons.location_on_outlined,
              items: const ["online", "offline"],
              display: (v) => v == "online" ? "Online" : "Offline",
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  selectedMode = value;
                  selectedSection = value == "offline" ? "None" : "A";
                });
              },
            ),
          ],
          const SizedBox(height: 9),
          _dropdown(
            label: "Stage",
            value: selectedStage,
            icon: Icons.layers_outlined,
            items: allStages,
            display: (v) => v.toUpperCase(),
            onChanged: (value) {
              if (value != null) setState(() => selectedStage = value);
            },
          ),
          if (isEnglishOnline) ...[
            const SizedBox(height: 9),
            _dropdown(
              label: "Section",
              value: selectedSection,
              icon: Icons.groups_outlined,
              items: allSections,
              display: (v) => v == "None" ? "No section" : "Section $v",
              onChanged: (value) {
                if (value != null) setState(() => selectedSection = value);
              },
            ),
          ],
          if (isHindi)
            Padding(
              padding: const EdgeInsets.only(top: 9),
              child: _info(
                Icons.wifi_rounded,
                "Hindi is automatically Online. Section is not required.",
                teal,
              ),
            ),
          const SizedBox(height: 15),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton.icon(
              onPressed: isLoading ? null : registerAccount,
              style: ElevatedButton.styleFrom(
                backgroundColor: navy,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(11),
                ),
              ),
              icon: isLoading
                  ? const SizedBox(
                      width: 17,
                      height: 17,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.add_rounded, size: 19),
              label: Text(
                isLoading ? "Creating..." : "Create account",
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _directoryPanel() {
    return _card(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _panelHeader(
            Icons.groups_rounded,
            "Registered staff",
            "Grouped by language → mode → stage. Managers are separate.",
            trailing: _headerCount(),
          ),
          const SizedBox(height: 14),
          if (isFetchingStaff)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 70),
              child: Center(
                child: CircularProgressIndicator(color: navy, strokeWidth: 2.2),
              ),
            )
          else if (registeredStaffList.isEmpty)
            _emptyState()
          else
            _buildGroupedDirectory(),
        ],
      ),
    );
  }

  Widget _buildGroupedDirectory() {
    final grouped = <String, List<dynamic>>{};

    for (final staff in registeredStaffList) {
      final role = (staff['role'] ?? 'teacher').toString().toLowerCase();

      if (role == "manager") {
        grouped.putIfAbsent("MANAGERS", () => []).add(staff);
        continue;
      }

      final language = (staff['language'] ?? 'English')
          .toString()
          .trim()
          .toLowerCase();
      final mode = (staff['mode'] ?? 'online').toString().trim().toLowerCase();
      final stage = (staff['teacherStage'] ?? 'stage1')
          .toString()
          .trim()
          .toLowerCase();

      final languageName = language == "hindi" ? "Hindi" : "English";
      final modeName = mode == "offline" ? "Offline" : "Online";
      final stageName = stage.replaceFirst("stage", "Stage ");
      final key = "$languageName • $modeName • $stageName";

      grouped.putIfAbsent(key, () => []).add(staff);
    }

    final keys = grouped.keys.toList()
      ..sort((a, b) {
        if (a == "MANAGERS") return -1;
        if (b == "MANAGERS") return 1;
        return a.compareTo(b);
      });

    return Column(
      children: [
        for (int i = 0; i < keys.length; i++) ...[
          _groupSection(
            title: keys[i],
            staff: grouped[keys[i]]!,
            isManagerGroup: keys[i] == "MANAGERS",
          ),
          if (i != keys.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget _groupSection({
    required String title,
    required List<dynamic> staff,
    required bool isManagerGroup,
  }) {
    final Color groupColor = isManagerGroup ? teal : navy;
    final parts = title.split(" • ");

    return Container(
      decoration: BoxDecoration(
        color: softSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 11, 12, 9),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: groupColor.withOpacity(.10),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(
                    isManagerGroup
                        ? Icons.manage_accounts_rounded
                        : (parts.length > 1 && parts[1] == "Online"
                              ? Icons.wifi_rounded
                              : Icons.location_on_outlined),
                    color: groupColor,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.poppins(
                          color: textColor,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (!isManagerGroup)
                        Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Wrap(
                            spacing: 5,
                            children: [
                              _badge(parts[0], navy),
                              _badge(
                                parts.length > 1 ? parts[1] : "",
                                parts.length > 1 && parts[1] == "Online"
                                    ? teal
                                    : warning,
                              ),
                              if (parts.length > 2)
                                _badge(parts[2], secondaryText),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                _countBadge(staff.length),
              ],
            ),
          ),
          const Divider(height: 1, color: border),
          ...staff.map((staff) => _staffRow(staff)),
        ],
      ),
    );
  }

  Widget _staffRow(dynamic staff) {
    final String id = (staff['_id'] ?? staff['id'] ?? '').toString();
    final String name = (staff['name'] ?? 'Unknown').toString();
    final String phone = (staff['phone'] ?? 'No phone').toString();
    final String role = (staff['role'] ?? 'teacher').toString();
    final String language = (staff['language'] ?? 'English').toString();
    final String mode = (staff['mode'] ?? 'online').toString();
    final String stage = (staff['teacherStage'] ?? 'stage1').toString();
    final String section = (staff['teacherSection'] ?? 'None').toString();

    final bool isManager = role.toLowerCase() == "manager";
    final Color roleColor = isManager ? teal : blue;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 9, 8, 9),
      child: Row(
        children: [
          Container(
            width: 39,
            height: 39,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: roleColor.withOpacity(.10),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Text(
              name.trim().isEmpty ? "T" : name.trim()[0].toUpperCase(),
              style: GoogleFonts.poppins(
                color: roleColor,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          color: textColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    _badge(isManager ? "MANAGER" : "TRAINER", roleColor),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  phone,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(color: secondaryText, fontSize: 9),
                ),
                if (!isManager)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Wrap(
                      spacing: 5,
                      runSpacing: 3,
                      children: [
                        _badge(language, navy),
                        _badge(
                          mode.toLowerCase() == "online" ? "ONLINE" : "OFFLINE",
                          mode.toLowerCase() == "online" ? teal : warning,
                        ),
                        _badge(stage.toUpperCase(), secondaryText),
                        if (section.toLowerCase() != "none")
                          _badge("SEC $section", blue),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            tooltip: "Delete",
            onPressed: () => _confirmDelete(id, name),
            icon: const Icon(
              Icons.delete_outline_rounded,
              color: error,
              size: 19,
            ),
          ),
        ],
      ),
    );
  }

  Widget _choice({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(11),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 9),
          decoration: BoxDecoration(
            color: selected ? navy.withOpacity(.08) : softSurface,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(
              color: selected ? navy : border,
              width: selected ? 1.2 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(icon, color: selected ? navy : secondaryText, size: 18),
              const SizedBox(width: 7),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.poppins(
                        color: textColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: GoogleFonts.poppins(
                        color: secondaryText,
                        fontSize: 7.5,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                const Icon(Icons.check_circle_rounded, color: navy, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _textField(
    TextEditingController controller,
    String label,
    String hint,
    IconData icon, {
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffixIcon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(label),
        const SizedBox(height: 5),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText,
          style: GoogleFonts.poppins(color: textColor, fontSize: 11),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.poppins(color: secondaryText, fontSize: 10),
            prefixIcon: Icon(icon, color: navy, size: 18),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: softSurface,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 11,
              vertical: 11,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: navy, width: 1.2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _dropdown<T>({
    required String label,
    required T value,
    required IconData icon,
    required List<T> items,
    required String Function(T) display,
    required ValueChanged<T?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(label),
        const SizedBox(height: 5),
        DropdownButtonFormField<T>(
          value: value,
          isExpanded: true,
          dropdownColor: surface,
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: secondaryText,
            size: 19,
          ),
          style: GoogleFonts.poppins(
            color: textColor,
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
          ),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: navy, size: 18),
            filled: true,
            fillColor: softSurface,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 9,
              vertical: 5,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: navy, width: 1.2),
            ),
          ),
          items: items
              .map(
                (item) => DropdownMenuItem<T>(
                  value: item,
                  child: Text(display(item), overflow: TextOverflow.ellipsis),
                ),
              )
              .toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _card({
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(16),
  }) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A155A88),
            blurRadius: 14,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _panelHeader(
    IconData icon,
    String title,
    String subtitle, {
    Widget? trailing,
  }) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: navy.withOpacity(.09),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: navy, size: 19),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.poppins(
                  color: textColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  color: secondaryText,
                  fontSize: 9.5,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 8), trailing],
      ],
    );
  }

  Widget _sectionDivider(String title) {
    return Row(
      children: [
        Expanded(child: Container(height: 1, color: border)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 9),
          child: Text(
            title,
            style: GoogleFonts.poppins(
              color: navy,
              fontSize: 9,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(child: Container(height: 1, color: border)),
      ],
    );
  }

  Widget _info(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: color.withOpacity(.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(.18)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.poppins(
                color: textColor,
                fontSize: 8.8,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _badge(String text, Color color) {
    if (text.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: GoogleFonts.poppins(
          color: color,
          fontSize: 7.2,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _countBadge(int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: navy.withOpacity(.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        "$count",
        style: GoogleFonts.poppins(
          color: navy,
          fontSize: 9,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _headerCount() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: teal.withOpacity(.09),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: teal.withOpacity(.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.groups_rounded, color: teal, size: 15),
          const SizedBox(width: 5),
          Text(
            "${registeredStaffList.length} staff",
            style: GoogleFonts.poppins(
              color: textColor,
              fontSize: 9,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 55, horizontal: 20),
      decoration: BoxDecoration(
        color: softSurface,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: border),
      ),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: navy.withOpacity(.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.groups_outlined, color: navy, size: 26),
          ),
          const SizedBox(height: 11),
          Text(
            "No registered staff",
            style: GoogleFonts.poppins(
              color: textColor,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "Create a trainer or manager from the registration panel.",
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(color: secondaryText, fontSize: 9.5),
          ),
        ],
      ),
    );
  }

  Widget _label(String text) {
    return Text(
      text,
      style: GoogleFonts.poppins(
        color: textColor,
        fontSize: 9.5,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}