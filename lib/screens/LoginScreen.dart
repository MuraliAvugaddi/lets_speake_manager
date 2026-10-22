import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:lets_speake_manager/Api/ApiendPoints.dart';
import 'package:lets_speake_manager/screens/Homescreen.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final phoneController = TextEditingController();
  final passwordController = TextEditingController();

  final box = GetStorage();
  final isLoading = false.obs;
  final obscurePassword = true.obs;

  // Colors taken from the supplied Let's Speak logo.
  static const Color logoNavy = Color(0xFF0A4A75);
  static const Color logoNavyDark = Color(0xFF073B5F);
  static const Color logoBlue = Color(0xFF2E86C9);
  static const Color logoTeal = Color(0xFF19B8B8);
  static const Color logoYellow = Color.fromARGB(8, 244, 197, 66);

  static const Color pageBackground = Color(0xFFF6FAFC);
  static const Color softBlue = Color(0xFFEAF4F9);
  static const Color softTeal = Color(0xFFE7F8F8);
  static const Color border = Color(0xFFD7E7EF);
  static const Color heading = Color(0xFF103E5D);
  static const Color body = Color(0xFF56758B);

  @override
  void dispose() {
    phoneController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> submitAdminLogin() async {
    final phone = phoneController.text.trim();
    final password = passwordController.text.trim();

    if (phone.isEmpty || password.isEmpty) {
      Get.snackbar(
        'Required',
        'Enter phone and password.',
        backgroundColor: logoNavy,
        colorText: Colors.white,
        margin: const EdgeInsets.all(16),
        borderRadius: 14,
      );
      return;
    }

    isLoading.value = true;

    try {
      final response = await http.post(
        Uri.parse(ApiEndpoints.login),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'phone': phone, 'password': password}),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final userRole = (data['user']['role'] ?? '').toString().toLowerCase();

        if (userRole == 'admin') {
          await box.write('token', data['token']);
          await box.write('user', data['user']);

          Get.offAll(() => Adime_home_screen());

          Get.snackbar(
            'Welcome back',
            'Administrator login successful.',
            backgroundColor: logoTeal,
            colorText: Colors.white,
            margin: const EdgeInsets.all(16),
            borderRadius: 14,
          );
        } else {
          Get.snackbar(
            'Access Denied',
            'This portal is strictly for administrators.',
            backgroundColor: Colors.red.shade600,
            colorText: Colors.white,
            margin: const EdgeInsets.all(16),
            borderRadius: 14,
          );
        }
      } else {
        Get.snackbar(
          'Sign In Failed',
          data['message'] ?? 'Invalid credentials.',
          backgroundColor: Colors.red.shade600,
          colorText: Colors.white,
          margin: const EdgeInsets.all(16),
          borderRadius: 14,
        );
      }
    } catch (_) {
      Get.snackbar(
        'Connection Error',
        'Unable to connect to the server. Please try again.',
        backgroundColor: Colors.red.shade600,
        colorText: Colors.white,
        margin: const EdgeInsets.all(16),
        borderRadius: 14,
      );
    } finally {
      isLoading.value = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: pageBackground,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final bool isDesktop = constraints.maxWidth >= 850;

            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: SizedBox(
                  width: double.infinity,
                  child: isDesktop
                      ? _desktopLayout(context, constraints.maxWidth)
                      : _mobileLayout(context),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _desktopLayout(BuildContext context, double width) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1180),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 64, vertical: 52),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(flex: 11, child: _brandSection(isDesktop: true)),
              const SizedBox(width: 90),
              Expanded(flex: 9, child: _loginSection()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _mobileLayout(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _brandHeaderMobile(),
          const SizedBox(height: 34),
          _loginSection(),
        ],
      ),
    );
  }

  Widget _brandSection({required bool isDesktop}) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          right: -30,
          top: -55,
          child: _softCircle(180, logoBlue.withValues(alpha: 0.08)),
        ),
        Positioned(
          left: -70,
          bottom: -70,
          child: _softCircle(190, logoTeal.withValues(alpha: 0.07)),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Image.asset(
              'assets/images/Blue Chat 4x.png',
              width: 80,
              height: 80,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 25),
            _brandTitle(fontSize: 46),
            const SizedBox(height: 5),
            Text(
              'Administration Portal',
              style: GoogleFonts.poppins(
                color: body,
                fontSize: 19,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 20),
            _yellowLine(),
            const SizedBox(height: 25),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Text(
                'Manage your learning platform from one secure place.',
                style: GoogleFonts.poppins(
                  color: heading,
                  fontSize: 16,
                  height: 1.65,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 34),
            _featureRow(
              Icons.people_alt_rounded,
              'Manage students and teachers',
            ),
            const SizedBox(height: 16),
            _featureRow(Icons.school_rounded, 'Control classes and learning'),
            const SizedBox(height: 16),
            _featureRow(Icons.dashboard_rounded, 'Access your admin dashboard'),
            const SizedBox(height: 35),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 9,
                  height: 9,
                  decoration: const BoxDecoration(
                    color: logoTeal,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 9),
                Text(
                  'Secure administrator access',
                  style: GoogleFonts.poppins(
                    color: body,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _brandHeaderMobile() {
    return Row(
      children: [
        Image.asset(
          'assets/images/blue icon.png',
          width: 58,
          height: 58,
          fit: BoxFit.contain,
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _brandTitle(fontSize: 27),
              const SizedBox(height: 1),
              Text(
                'Administration Portal',
                style: GoogleFonts.poppins(
                  color: body,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _loginSection() {
    return Obx(
      () => ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 430),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
              decoration: BoxDecoration(
                color: softBlue,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.admin_panel_settings_rounded,
                    color: logoNavy,
                    size: 15,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'ADMINISTRATOR',
                    style: GoogleFonts.poppins(
                      color: logoNavy,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.7,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 17),
            Text(
              'Welcome back',
              style: GoogleFonts.poppins(
                color: heading,
                fontSize: 30,
                fontWeight: FontWeight.w800,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              "Sign in to manage your Let's Speak platform.",
              style: GoogleFonts.poppins(
                color: body,
                fontSize: 12.5,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 27),
            _fieldLabel('Phone number'),
            const SizedBox(height: 8),
            _inputField(
              controller: phoneController,
              hint: 'Enter admin phone number',
              icon: Icons.phone_rounded,
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 17),
            _fieldLabel('Password'),
            const SizedBox(height: 8),
            _inputField(
              controller: passwordController,
              hint: 'Enter your password',
              icon: Icons.lock_outline_rounded,
              obscureText: obscurePassword.value,
              suffix: IconButton(
                tooltip: obscurePassword.value
                    ? 'Show password'
                    : 'Hide password',
                onPressed: () {
                  obscurePassword.value = !obscurePassword.value;
                },
                icon: Icon(
                  obscurePassword.value
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: body,
                  size: 20,
                ),
              ),
              onSubmitted: (_) => submitAdminLogin(),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 1),
                  child: Icon(
                    Icons.verified_user_rounded,
                    color: logoTeal,
                    size: 15,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Only authorized administrators can access this portal.',
                    style: GoogleFonts.poppins(
                      color: body,
                      fontSize: 10.5,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: isLoading.value ? null : submitAdminLogin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: logoNavy,
                  disabledBackgroundColor: logoNavy.withValues(alpha: 0.55),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: isLoading.value
                    ? const SizedBox(
                        width: 21,
                        height: 21,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: Colors.white,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.login_rounded, size: 19),
                          const SizedBox(width: 9),
                          Text(
                            'Sign In to Admin Portal',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                "Let's Speak  •  Learn  •  Speak  •  Grow",
                style: GoogleFonts.poppins(
                  color: body.withValues(alpha: 0.78),
                  fontSize: 9.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _inputField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffix,
    ValueChanged<String>? onSubmitted,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textInputAction: onSubmitted == null
          ? TextInputAction.next
          : TextInputAction.done,
      onSubmitted: onSubmitted,
      style: GoogleFonts.poppins(
        color: heading,
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
      cursorColor: logoTeal,
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white,
        hintText: hint,
        hintStyle: GoogleFonts.poppins(
          color: body.withValues(alpha: 0.72),
          fontSize: 12,
        ),
        prefixIcon: Icon(icon, color: logoNavy, size: 19),
        suffixIcon: suffix,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 15,
          vertical: 15,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: logoTeal, width: 1.5),
        ),
      ),
    );
  }

  Widget _fieldLabel(String label) {
    return Text(
      label,
      style: GoogleFonts.poppins(
        color: heading,
        fontSize: 11.5,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Widget _featureRow(IconData icon, String label) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: softBlue,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: border),
          ),
          child: Icon(icon, color: logoNavy, size: 19),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.poppins(
              color: heading,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _brandTitle({required double fontSize}) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: "Let's ",
            style: GoogleFonts.poppins(
              color: logoNavy,
              fontSize: fontSize,
              fontWeight: FontWeight.w800,
              height: 1.05,
            ),
          ),
          TextSpan(
            text: 'Speak',
            style: GoogleFonts.poppins(
              color: logoNavy,
              fontSize: fontSize,
              fontWeight: FontWeight.w800,
              height: 1.05,
            ),
          ),
        ],
      ),
    );
  }

  Widget _yellowLine() {
    return Container(
      width: 62,
      height: 5,
      decoration: BoxDecoration(
        color: logoYellow,
        borderRadius: BorderRadius.circular(20),
      ),
    );
  }

  Widget _softCircle(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
