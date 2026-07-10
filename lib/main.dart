import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';
import 'package:app_links/app_links.dart';
import 'constants/strings.dart';
import 'services/theme_service.dart';
import 'services/localization_service.dart';
import 'l10n/app_localizations.dart';
import 'services/sync_queue_service.dart';
import 'services/in_app_purchase_service.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/forgot_password_screen.dart';
import 'screens/new_password_screen.dart';
import 'screens/home_screen.dart';
import 'screens/test_screen.dart';
import 'screens/payment_screen.dart';
import 'screens/payment_details_screen.dart';
import 'screens/silver_test_screen.dart';
import 'screens/gold_test_screen.dart';
// Premium plan removed - import deleted
import 'screens/paid_test_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/exam_list_screen.dart';
import 'screens/test_report_screen.dart';
import 'screens/statistics_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/language_selection_screen.dart';
import 'screens/splash_screen_ar.dart';
import 'screens/splash_screen_en.dart';
import 'screens/additional_test_screen.dart'; // Added AdditionalTestScreen
import 'dart:io';
import 'models/payment_plan.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize app services
  await ThemeService.init();
  await LocalizationService.init();

  // Initialize In-App Purchase Service
  // Importing it dynamically if needed or just straight up
  // Better to move imports to top, but here works for snippet
  // We need to import it at top of file
  _initIAP();

  runApp(const MyApp());

  // Fire-and-forget background warmup after first frame to avoid blocking startup
  _scheduleBackgroundWarmup();
}

void _initIAP() {
  // Initialize asynchronously without blocking app startup
  InAppPurchaseService.instance
      .initialize()
      .then((_) {
        print('✅ IAP Service initialized');
      })
      .catchError((e) {
        print('❌ Failed to init IAP: $e');
      });
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
    _initSyncQueue();

    // Listen for connectivity changes to sync data when online
    Connectivity().onConnectivityChanged.listen((
      List<ConnectivityResult> results,
    ) {
      final isConnected =
          results.isNotEmpty && results.first != ConnectivityResult.none;
      if (isConnected) {
        // When connection is restored, sync pending data
        _scheduleBackgroundWarmup();
        _triggerSync();
      }
    });
  }

  Future<void> _initSyncQueue() async {
    try {
      await SyncQueueService.initialize();
      print('✅ Sync Queue initialized');
    } catch (e) {
      print('❌ Failed to initialize sync queue: $e');
    }
  }

  Future<void> _triggerSync() async {
    try {
      await SyncQueueService.processPendingSync();
    } catch (e) {
      print('❌ Error during auto-sync: $e');
    }
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initDeepLinks() async {
    _appLinks = AppLinks();

    // Check initial link if app was started by a deep link
    try {
      final initialLink = await _appLinks.getInitialLink();
      if (initialLink != null) {
        _handleDeepLink(initialLink);
      }
    } catch (e) {
      print('Error getting initial link: $e');
    }

    // Listen for new links while app is running
    _linkSubscription = _appLinks.uriLinkStream.listen(
      (Uri? uri) {
        if (uri != null) {
          _handleDeepLink(uri);
        }
      },
      onError: (err) {
        print('Error listening to links: $err');
      },
    );
  }

  void _handleDeepLink(Uri uri) async {
    print('🔗 Received Deep Link: $uri');

    // Deep link handling removed - Firebase no longer used
    // OTP-based authentication is now handled directly in the app
  }

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(360, 690),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return ValueListenableBuilder<ThemeMode>(
          valueListenable: ThemeService.themeMode,
          builder: (context, themeMode, _) {
            return ValueListenableBuilder<Locale>(
              valueListenable: LocalizationService.locale,
              builder: (context, locale, _) {
                return MaterialApp(
                  navigatorKey: _navigatorKey,
                  title: AppStrings.appName,
                  debugShowCheckedModeBanner: false,
                  theme: AppTheme.lightTheme(context),
                  darkTheme: AppTheme.darkTheme(context),
                  themeMode: themeMode,
                  locale: locale,
                  supportedLocales: const [Locale('ar'), Locale('en')],
                  localizationsDelegates: const [
                    AppLocalizations.delegate,
                    GlobalMaterialLocalizations.delegate,
                    GlobalWidgetsLocalizations.delegate,
                    GlobalCupertinoLocalizations.delegate,
                  ],
                  initialRoute: '/splash',
                  routes: {
                    '/splash': (context) => const SplashScreen(),
                    '/onboarding': (context) => const OnboardingScreen(),
                    '/login': (context) => const LoginScreen(),
                    '/signup': (context) => const SignupScreen(),
                    '/forgotPassword': (context) =>
                        const ForgotPasswordScreen(),
                    '/newPassword': (context) {
                      final args =
                          ModalRoute.of(context)?.settings.arguments
                              as Map<String, dynamic>?;
                      return NewPasswordScreen(
                        email: args?['email'] ?? '',
                        otp: args?['otp'] ?? '',
                      );
                    },
                    '/home': (context) => const HomeScreen(),
                    '/test': (context) => const TestScreen(),
                    '/payment': (context) => const PaymentScreen(),
                    '/paymentDetails': (context) {
                      final args =
                          ModalRoute.of(context)?.settings.arguments
                              as PaymentPlan?;
                      return PaymentDetailsScreen(selectedPlan: args!);
                    },
                    '/silverTest': (context) => const SilverTestScreen(),
                    '/goldTest': (context) => const GoldTestScreen(),
                    // Premium plan removed - route deleted
                    '/paidTest': (context) => const PaidTestScreen(),
                    '/profile': (context) => const ProfileScreen(),
                    '/examList': (context) {
                      final args =
                          ModalRoute.of(context)?.settings.arguments
                              as Map<String, dynamic>?;
                      return ExamListScreen(
                        planId: args!['planId'],
                        planName: args['planName'],
                        totalQuestions: args['totalQuestions'],
                        plan: args['plan'] as PaymentPlan?, // Pass plan object
                      );
                    },
                    '/testReport': (context) {
                      final args =
                          ModalRoute.of(context)?.settings.arguments
                              as Map<String, dynamic>?;
                      return TestReportScreen(
                        questions: args!['questions'],
                        userAnswers: args['userAnswers'],
                      );
                    },
                    '/additionalTest': (context) {
                      final args =
                          ModalRoute.of(context)?.settings.arguments
                              as Map<String, dynamic>?;
                      return AdditionalTestScreen(
                        testId: args?['testId'] ?? '',
                        testName: args?['title'] ?? 'اختبار إضافي',
                        questionCount: args?['questionCount'] ?? 0,
                      );
                    },
                    '/statistics': (context) => const StatisticsScreen(),
                    '/languageSelection': (context) =>
                        const LanguageSelectionScreen(),
                    '/splashAr': (context) => const SplashScreenAr(),
                    '/splashEn': (context) => const SplashScreenEn(),
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}

// Schedule network sync and cache warmup in background to keep first frame fast
void _scheduleBackgroundWarmup() {
  Future<void>(() async {
    try {
      // Quick connectivity check with a short timeout
      await InternetAddress.lookup(
        'example.com',
      ).timeout(const Duration(seconds: 10));

      // Process any cached notifications
      // await NotificationService.processCachedNotifications().timeout(
      //   const Duration(seconds: 3),
      // );
    } catch (_) {
      // Silently ignore background errors; app relies on local cache if needed
    }
  });
}
