import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lets_speake_manager/screens/LoginScreen.dart';

void main() async {
  // 1. Ensure Flutter bindings are initialized
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Initialize Local Storage (Required for Auth Tokens)
  await GetStorage.init();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      title: "Let's Speak with Surendra • Admin",
      // 3. Global Theme Setup
      // ☀️ LIGHT theme — every admin screen is a light design.
      // (The old dark purple theme made all dialogs, bottom sheets,
      //  date pickers and popup menus dark grey.)
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF5FAFD),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0A4A75), // Let's Speak navy
          brightness: Brightness.light,
        ).copyWith(surface: Colors.white),
        textTheme: GoogleFonts.poppinsTextTheme(),
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF173A52),
          surfaceTintColor: Colors.white,
          elevation: 0,
          iconTheme: const IconThemeData(color: Color(0xFF173A52)),
          titleTextStyle: GoogleFonts.poppins(
            color: const Color(0xFF173A52),
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          titleTextStyle: GoogleFonts.poppins(
            color: const Color(0xFF173A52),
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
          contentTextStyle: GoogleFonts.poppins(
            color: const Color(0xFF6B8496),
            fontSize: 13,
            height: 1.45,
          ),
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
        ),
        popupMenuTheme: const PopupMenuThemeData(
          color: Colors.white,
          surfaceTintColor: Colors.white,
        ),
        datePickerTheme: const DatePickerThemeData(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: const Color(0xFF0A4A75)),
        ),
      ),

      // 4. Start at the Admin Dashboard
      // Note: In a real app, you would check if the admin is logged in here.
      // For now, we go straight to the dashboard to test the toggles.
      home: AdminLoginScreen(),
    );
  }
}
