import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkLanguageAndNavigate();
  }

  Future<void> _checkLanguageAndNavigate() async {
    // Add a tiny delay to ensure generic initialization if needed
    // But mainly just check prefs quickly
    await Future.delayed(Duration.zero);

    if (!mounted) return;

    final prefs = await SharedPreferences.getInstance();
    final hasSelectedLanguage = prefs.getBool('has_selected_language') ?? false;
    final languageCode = prefs.getString('language_code');

    print('🚀 SplashScreen Dispatcher:');
    print('   -> hasSelectedLanguage: $hasSelectedLanguage');
    print('   -> languageCode: $languageCode');

    if (!hasSelectedLanguage) {
      // First time -> Language Selection
      print('   -> Navigating to /languageSelection');
      Navigator.of(context).pushReplacementNamed('/languageSelection');
    } else {
      // Already selected -> Show appropriate splash
      if (languageCode == 'ar') {
        print('   -> Navigating to /splashAr (Arabic)');
        Navigator.of(context).pushReplacementNamed('/splashAr');
      } else {
        // Default to English if 'en' or unknown
        print('   -> Navigating to /splashEn (English)');
        Navigator.of(context).pushReplacementNamed('/splashEn');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show black or empty screen for split second while deciding
    return const Scaffold(
      backgroundColor: Colors.white,
      body: SizedBox.expand(),
    );
  }
}
