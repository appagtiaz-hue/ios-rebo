import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../widgets/startup_brand_view.dart';

class StartupScreen extends StatefulWidget {
  const StartupScreen({super.key, required this.languageCode});
  final String languageCode;

  @override
  State<StartupScreen> createState() => _StartupScreenState();
}

class _StartupScreenState extends State<StartupScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _navigateWhenReady();
    });
  }

  Future<void> _navigateWhenReady() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    if (!(prefs.getBool('onboarding_completed') ?? false)) {
      Navigator.pushReplacementNamed(context, '/onboarding');
      return;
    }
    try {
      final userData = await AuthService.autoLogin();
      if (!mounted) return;
      if (userData != null) {
        await DatabaseService.setCurrentUser(User.fromJson(userData));
        if (mounted) Navigator.pushReplacementNamed(context, '/home');
        return;
      }
    } catch (error) {
      debugPrint('Auto-login check failed: $error');
    }
    if (mounted) Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) =>
      StartupBrandView(languageCode: widget.languageCode);
}
