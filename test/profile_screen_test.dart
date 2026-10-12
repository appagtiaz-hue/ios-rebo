import 'dart:io';
import 'dart:ui' as ui;
import 'package:agtiaz/l10n/app_localizations.dart';
import 'package:agtiaz/models/payment_plan.dart';
import 'package:agtiaz/models/user.dart';
import 'package:agtiaz/screens/profile_screen.dart';
import 'package:agtiaz/services/content_cache.dart';
import 'package:agtiaz/services/localization_service.dart';
import 'package:agtiaz/services/theme_service.dart';
import 'package:agtiaz/widgets/app_bottom_navigation.dart';
import 'package:agtiaz/widgets/profile_content.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late http.Client originalClient;
  late ThemeMode originalMode;
  late Locale originalLocale;
  var requests = 0;
  final routes = <String, Object?>{};

  final user = User(
    id: 'profile-user',
    fullName: 'أحمد محمد',
    email: 'ahmed@example.com',
    password: '',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );
  final mainPlan = PaymentPlan.fromJson({
    'id': 'main-plan',
    'name': 'الخطة الذهبية',
    'nameEn': 'Golden plan',
    'question_count': 120,
  });
  final additionalPlan = PaymentPlan.fromJson({
    'id': 'additional-plan',
    'name': 'اختبار إضافي',
    'nameEn': 'Additional test',
    'question_count': 20,
  });
  List<Map<String, dynamic>> subscriptions({bool jsonPlans = false}) => [
    {
      'planId': 'main-plan',
      'planName': 'الخطة الذهبية',
      'questionCount': 120,
      'planObject': jsonPlans ? mainPlan.toJson() : mainPlan,
    },
    {
      'planId': {'_id': 'additional-plan'},
      'planName': 'اختبار إضافي',
      'questionCount': 20,
      'planObject': jsonPlans ? additionalPlan.toJson() : additionalPlan,
    },
  ];

  setUpAll(() async {
    if (Platform.isWindows) {
      final font = FontLoader('ProfilePreview');
      font.addFont(
        Future.value(
          ByteData.sublistView(
            await File('C:/Windows/Fonts/arial.ttf').readAsBytes(),
          ),
        ),
      );
      await font.load();
    }
    final icons = FontLoader('MaterialIcons');
    icons.addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    requests = 0;
    routes.clear();
    originalClient = ContentCache.client;
    originalMode = ThemeService.themeMode.value;
    originalLocale = LocalizationService.locale.value;
    ContentCache.client = MockClient((request) async {
      requests++;
      return http.Response('{"success":true,"data":[]}', 200);
    });
  });
  tearDown(() {
    ContentCache.client.close();
    ContentCache.client = originalClient;
    ThemeService.themeMode.value = originalMode;
    LocalizationService.locale.value = originalLocale;
  });

  Widget host(
    Widget child, {
    String language = 'ar',
    bool dark = false,
    double scale = 1,
  }) => MaterialApp(
    debugShowCheckedModeBanner: false,
    locale: Locale(language),
    supportedLocales: const [Locale('ar'), Locale('en')],
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    theme: ThemeData(
      brightness: dark ? Brightness.dark : Brightness.light,
      fontFamily: Platform.isWindows ? 'ProfilePreview' : null,
    ),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(scale), disableAnimations: true),
      child: child!,
    ),
    onGenerateRoute: (settings) {
      routes[settings.name!] = settings.arguments;
      return MaterialPageRoute<void>(
        settings: settings,
        builder: (_) =>
            Scaffold(appBar: AppBar(), body: Text('route-${settings.name}')),
      );
    },
    home: child,
  );

  Future<void> start(
    WidgetTester tester,
    Widget child, {
    String language = 'ar',
    bool dark = false,
    double scale = 1,
  }) async {
    await tester.pumpWidget(
      host(child, language: language, dark: dark, scale: scale),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, String key) async {
    final target = find.byKey(ValueKey(key));
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  Future<void> preview(WidgetTester tester, GlobalKey key, String name) async {
    if (!const bool.fromEnvironment('GENERATE_PROFILE_PREVIEW')) return;
    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final folder = Directory('build/profile-preview');
      await folder.create(recursive: true);
      await File(
        '${folder.path}/$name.png',
      ).writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  for (final language in ['ar', 'en']) {
    for (final dark in [false, true]) {
      for (final size in [
        const Size(320, 640),
        const Size(390, 844),
        const Size(844, 390),
      ]) {
        testWidgets('profile layout $language dark=$dark size=$size', (
          tester,
        ) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          tester.view.padding = const FakeViewPadding(top: 30);
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.view.resetPadding);
          var actions = 0;
          void action() => actions++;
          final key = GlobalKey();
          await start(
            tester,
            RepaintBoundary(
              key: key,
              child: Scaffold(
                body: ProfileContent(
                  name: size.width == 390
                      ? 'أحمد محمد'
                      : 'أحمد محمد عبد الرحمن معلم الرخصة المهنية',
                  email: 'ahmed.profile.long.email@example.com',
                  subscriptions: subscriptions(jsonPlans: true),
                  loadingSubscriptions: false,
                  themeMode: dark ? ThemeMode.dark : ThemeMode.light,
                  language: language,
                  onBack: action,
                  onEditName: action,
                  onEditPhoto: action,
                  onStatistics: action,
                  onBrowsePlans: action,
                  onOpenSubscription: (_) => action(),
                  onTheme: action,
                  onLanguage: action,
                  onSupport: action,
                  onLogout: action,
                ),
                bottomNavigationBar: AppBottomNavigation(
                  selectedIndex: 3,
                  onSelect: (_) {},
                ),
              ),
            ),
            language: language,
            dark: dark,
            scale: size.width == 390 ? 1 : 1.8,
          );
          expect(tester.takeException(), isNull);
          final email = find.byKey(const ValueKey('profile-email'));
          final name = find.byKey(const ValueKey('profile-name'));
          expect(tester.widget<Text>(email).style?.fontSize, 12);
          expect(
            tester.getTopLeft(email).dy - tester.getBottomLeft(name).dy,
            closeTo(6, 0.1),
          );
          expect(tester.getTopLeft(email).dx, tester.getTopLeft(name).dx);
          expect(
            tester.getTopLeft(find.byKey(const ValueKey('profile-back'))).dy,
            greaterThanOrEqualTo(30),
          );
          expect(find.byKey(const ValueKey('profile-plan-0')), findsOneWidget);
          expect(find.byKey(const ValueKey('profile-plan-1')), findsOneWidget);
          if (size.width == 390 && language == 'ar') {
            await preview(
              tester,
              key,
              'profile-${dark ? 'dark' : 'light'}-top',
            );
          }
          for (final name in [
            'profile-edit-name',
            'profile-edit-photo',
            'profile-statistics',
            'profile-enter-plan-0',
            'profile-enter-plan-1',
            'profile-browse-plans',
            'profile-theme',
            'profile-language',
            'profile-contact-support',
            'profile-logout',
          ]) {
            final target = find.byKey(ValueKey(name));
            expect(tester.getSize(target).height, greaterThanOrEqualTo(48));
            await tap(tester, name);
          }
          expect(actions, 10);
          expect(requests, 0);
          expect(tester.takeException(), isNull);
          if (size.width == 390 && language == 'ar') {
            await preview(
              tester,
              key,
              'profile-${dark ? 'dark' : 'light'}-settings',
            );
          }
          await tester.pumpWidget(const SizedBox.shrink());
        });
      }
    }
  }

  testWidgets('profile preserves regular and additional plan route arguments', (
    tester,
  ) async {
    await start(
      tester,
      ProfileScreen(user: user, subscriptions: subscriptions()),
    );
    await tap(tester, 'profile-enter-plan-0');
    expect(routes['/examList'], {
      'planId': 'main-plan',
      'planName': 'الخطة الذهبية',
      'totalQuestions': 120,
    });
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();
    await tap(tester, 'profile-enter-plan-1');
    expect(routes['/additionalTest'], {
      'testId': 'additional-plan',
      'title': 'اختبار إضافي',
    });
    expect(requests, 0);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('empty profile uses saved name and handles missing saved photo', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'local_user_name': 'الاسم المحفوظ',
      'profile_image_path': 'missing-profile-photo.png',
    });
    await start(tester, ProfileScreen(user: user, subscriptions: const []));
    expect(find.text('الاسم المحفوظ'), findsOneWidget);
    expect(find.byKey(const ValueKey('profile-plan-0')), findsNothing);
    await tap(tester, 'profile-edit-name');
    await tester.enterText(find.byType(TextField), 'الاسم الجديد');
    await tester.tap(find.text('حفظ'));
    await tester.pumpAndSettle();
    expect(find.text('الاسم الجديد'), findsOneWidget);
    expect(
      (await SharedPreferences.getInstance()).getString('local_user_name'),
      'الاسم الجديد',
    );
    await tap(tester, 'profile-edit-photo');
    expect(find.byKey(const ValueKey('profile-pick-photo')), findsOneWidget);
    expect(find.byKey(const ValueKey('profile-remove-photo')), findsNothing);
    Navigator.of(
      tester.element(find.byKey(const ValueKey('profile-pick-photo'))),
    ).pop();
    await tester.pumpAndSettle();
    await tap(tester, 'profile-browse-plans');
    expect(routes.containsKey('/payment'), isTrue);
    expect(requests, 0);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('settings persist and cancelled logout keeps account data', (
    tester,
  ) async {
    await start(tester, ProfileScreen(user: user, subscriptions: const []));
    await tap(tester, 'profile-theme');
    await tester.tap(find.text('داكن'));
    await tester.pumpAndSettle();
    expect(ThemeService.themeMode.value, ThemeMode.dark);
    expect(
      (await SharedPreferences.getInstance()).getString('theme_mode'),
      'dark',
    );
    await tap(tester, 'profile-language');
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    expect(LocalizationService.locale.value.languageCode, 'en');
    expect(
      (await SharedPreferences.getInstance()).getString('language_code'),
      'en',
    );
    await tap(tester, 'profile-logout');
    await tester.tap(find.text('إلغاء'));
    await tester.pumpAndSettle();
    expect(
      (await SharedPreferences.getInstance()).getString('language_code'),
      'en',
    );
    expect(routes.containsKey('/login'), isFalse);
    expect(requests, 0);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'statistics opens original destination and back callback is preserved',
    (tester) async {
      var back = false;
      await start(
        tester,
        ProfileScreen(
          user: user,
          subscriptions: const [],
          onBack: () => back = true,
        ),
      );
      await tap(tester, 'profile-statistics');
      expect(routes.containsKey('/statistics'), isTrue);
      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pumpAndSettle();
      await tap(tester, 'profile-back');
      expect(back, isTrue);
      expect(requests, 0);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  for (final language in ['ar', 'en']) {
    testWidgets('profile dialogs fit enlarged text in landscape $language', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(844, 390);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      LocalizationService.locale.value = Locale(language);
      await start(
        tester,
        ProfileScreen(user: user, subscriptions: const []),
        language: language,
        scale: 1.8,
      );
      for (final key in [
        'profile-edit-name',
        'profile-theme',
        'profile-language',
        'profile-contact-support',
        'profile-logout',
      ]) {
        await tap(tester, key);
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(tester.takeException(), isNull);
        Navigator.of(tester.element(find.byType(AlertDialog))).pop();
        await tester.pumpAndSettle();
      }
      expect(requests, 0);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
