import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../models/user.dart';

class SplashScreenAr extends StatefulWidget {
  const SplashScreenAr({super.key});

  @override
  State<SplashScreenAr> createState() => _SplashScreenArState();
}

class _SplashScreenArState extends State<SplashScreenAr>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.5,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.elasticOut));

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeIn),
      ),
    );

    _controller.forward();

    // Navigate after 3 seconds
    Future.delayed(const Duration(milliseconds: 3000), () async {
      if (mounted) {
        final prefs = await SharedPreferences.getInstance();
        final onboardingCompleted =
            prefs.getBool('onboarding_completed') ?? false;

        if (!onboardingCompleted) {
          Navigator.pushReplacementNamed(context, '/onboarding');
          return;
        }

        // Try Auto Login
        try {
          final userData = await AuthService.autoLogin();
          if (userData != null) {
            // Auto-login successful, navigate to home
            final user = User.fromJson(userData);
            await DatabaseService.setCurrentUser(user);
            if (mounted) {
              Navigator.pushReplacementNamed(context, '/home');
            }
            return;
          }
        } catch (e) {
          print('Auto-login check failed: $e');
        }

        // No auto-login, go to login screen
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/login');
        }
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF006C35), // Saudi Green
              const Color(0xFF006C35).withOpacity(0.8),
              const Color(0xFFFFD700).withOpacity(0.3), // Gold
            ],
          ),
        ),
        child: Center(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return FadeTransition(
                opacity: _fadeAnimation,
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Logo Container
                      Container(
                        width: 150.w,
                        height: 150.h,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(35.r),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 30.r,
                              offset: Offset(0, 15.h),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(35.r),
                          child: Image.asset(
                            'assets/images/app_icon.png',
                            width: 150.w,
                            height: 150.h,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      SizedBox(height: 40.h),
                      // App Name (Arabic Hardcoded)
                      Text(
                        'اجتياز',
                        style: TextStyle(
                          fontSize: 42.sp,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontFamily:
                              'Cairo', // Assuming Cairo font exists or default
                          shadows: [
                            Shadow(
                              color: Colors.black.withOpacity(0.3),
                              offset: Offset(0, 4.h),
                              blurRadius: 10.r,
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 12.h),
                      // Subtitle (Arabic Hardcoded)
                      Text(
                        'منصة التعليم الإلكتروني',
                        style: TextStyle(
                          fontSize: 18.sp,
                          color: Colors.white.withOpacity(0.9),
                          fontWeight: FontWeight.w500,
                          fontFamily: 'Cairo',
                        ),
                      ),
                      SizedBox(height: 60.h),
                      // Loading Indicator
                      SizedBox(
                        width: 50.w,
                        height: 50.h,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            const Color(0xFFFFD700),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
