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
      title: 'Lets Talk Admin',

      // 3. Global Theme Setup
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xff0D0D0D), // Dark Background
        // Default App Bar Theme
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xff1E1E1E),
          iconTheme: IconThemeData(color: Colors.white),
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),

        // Default Text Theme (Poppins)
        textTheme: GoogleFonts.poppinsTextTheme(),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xff7F56D9), // Your accent purple
          brightness: Brightness.dark,
        ),
      ),

      // 4. Start at the Admin Dashboard
      // Note: In a real app, you would check if the admin is logged in here.
      // For now, we go straight to the dashboard to test the toggles.
      home: AdminLoginScreen(),
    );
  }
}