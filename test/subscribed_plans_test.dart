import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:agtiaz/l10n/app_localizations.dart';
import 'package:agtiaz/models/home_practice_state.dart';
import 'package:agtiaz/models/payment_plan.dart';
import 'package:agtiaz/models/user.dart';
import 'package:agtiaz/screens/home_screen.dart';
import 'package:agtiaz/screens/subscribed_plans_screen.dart';
import 'package:agtiaz/services/content_cache.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late http.Client original;
  late MockClient client;
  var requests = 0;
  var count = 2;
  final routeArguments = <String, Object?>{};
  final previewKey = GlobalKey();

  setUpAll(() async {
    if (Platform.isWindows) {
      final font = FontLoader('SubscriptionsPreview');
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
  final user = User(
    id: 'choice-user',
    fullName: 'Test User',
    email: 'choice@example.com',
    password: '',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );
  final plans = [
    {
      'id': 'main',
      'name': 'الخطة الذهبية',
      'nameEn': 'Golden plan',
      'question_count': 120,
    },
    {
      'id': 'extra',
      'name': 'اختبار إضافي',
      'nameEn': 'Additional test',
      'question_count': 20,
    },
    {
      'id': 'not-owned',
      'name': 'خطة غير مشترك بها',
      'nameEn': 'Unsubscribed plan',
    },
  ];

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'current_user': jsonEncode(user.toJson()),
    });
    directory = await Directory.systemTemp.createTemp('agtiaz-choice-');
    ContentCache.directoryForTesting = directory;
    original = ContentCache.client;
    requests = 0;
    count = 2;
    routeArguments.clear();
    client = MockClient((request) async {
      requests++;
      Object data;
      if (request.url.path == '/api/plans') {
        data = plans;
      } else if (request.url.path == '/mobile/api/subscriptions/active') {
        data = {
          'subscriptions': [
            if (count >= 1)
              {
                'planId': 'main',
                'planName': 'الخطة الذهبية',
                'questionCount': 120,
                'isMain': true,
                'isCurrentlyActive': true,
              },
            if (count >= 2)
              {
                'planId': 'extra',
                'planName': 'اختبار إضافي',
                'questionCount': 20,
              },
          ],
        };
      } else if (request.url.path.contains('/users/me/')) {
        data = user.toJson();
      } else if (request.url.path.endsWith('/statistics')) {
        data = {'completedTests': 0};
      } else {
        return http.Response('{}', 404);
      }
      return http.Response(
        jsonEncode({'success': true, 'data': data}),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
    ContentCache.client = client;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (_) async => 'test-token',
        );
  });
  tearDown(() async {
    ContentCache.client = original;
    ContentCache.directoryForTesting = null;
    client.close();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          null,
        );
    await directory.delete(recursive: true);
  });

  Widget host({String language = 'ar', bool dark = false, double scale = 1}) =>
      ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, __) => MaterialApp(
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
            fontFamily: Platform.isWindows ? 'SubscriptionsPreview' : null,
          ),
          builder: (context, child) => RepaintBoundary(
            key: previewKey,
            child: MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(scale),
                disableAnimations: true,
              ),
              child: child!,
            ),
          ),
          routes: {
            for (final route in ['/examList', '/additionalTest', '/payment'])
              route: (context) {
                routeArguments[route] = ModalRoute.of(
                  context,
                )!.settings.arguments;
                return Scaffold(body: Text('target-$route'));
              },
          },
          home: const HomeScreen(),
        ),
      );

  Future<void> start(
    WidgetTester tester, {
    String language = 'ar',
    bool dark = false,
    double scale = 1,
  }) async {
    await tester.pumpWidget(host(language: language, dark: dark, scale: scale));
    for (var i = 0; i < 40; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();
    final premium = find.byKey(const ValueKey('home-premium-tab'));
    await tester.ensureVisible(premium);
    await tester.pumpAndSettle();
    await tester.tap(premium);
    await tester.pumpAndSettle();
    final button = find.byKey(
      ValueKey(count == 0 ? 'home-browse-plans' : 'home-continue-training'),
    );
    await tester.scrollUntilVisible(
      button,
      150,
      scrollable: find.descendant(
        of: find.byKey(const PageStorageKey('home-scroll')),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'two subscriptions always show owned plans only, even with selected main plan',
    (tester) async {
      await http.runWithClient(() async {
        await start(tester);
        final before = requests;
        await tester.tap(find.byKey(const ValueKey('home-continue-training')));
        await tester.pumpAndSettle();
        expect(find.byType(SubscribedPlansScreen), findsOneWidget);
        expect(find.text('الخطة الذهبية'), findsOneWidget);
        expect(find.text('اختبار إضافي'), findsOneWidget);
        expect(find.text('خطة غير مشترك بها'), findsNothing);
        expect(find.byKey(const ValueKey('library-trial')), findsNothing);
        expect(find.text('تصفّح الخطط'), findsNothing);
        expect(requests, before);
        await tester.tap(find.byKey(const ValueKey('subscribed-plan-1')));
        await tester.pumpAndSettle();
        expect(find.text('target-/additionalTest'), findsOneWidget);
        expect(routeArguments['/additionalTest'], {
          'testId': 'extra',
          'title': 'اختبار إضافي',
          'questionCount': 20,
        });
        expect(requests, before);
        await tester.pumpWidget(const SizedBox.shrink());
      }, () => client);
    },
  );

  testWidgets('single subscription opens directly without a chooser', (
    tester,
  ) async {
    count = 1;
    await http.runWithClient(() async {
      await start(tester);
      final before = requests;
      await tester.tap(find.byKey(const ValueKey('home-continue-training')));
      await tester.pumpAndSettle();
      expect(find.byType(SubscribedPlansScreen), findsNothing);
      expect(find.text('target-/examList'), findsOneWidget);
      final arguments = routeArguments['/examList'] as Map;
      expect(arguments['planId'], 'main');
      expect(arguments['totalQuestions'], 120);
      expect(arguments['plan'], isA<PaymentPlan>());
      expect(requests, before);
      await tester.pumpWidget(const SizedBox.shrink());
    }, () => client);
  });

  testWidgets('cancelling the chooser preserves Home and allows reopening', (
    tester,
  ) async {
    await http.runWithClient(() async {
      await start(tester);
      final before = requests;
      await tester.tap(find.byKey(const ValueKey('home-continue-training')));
      await tester.pumpAndSettle();
      Navigator.of(tester.element(find.byType(SubscribedPlansScreen))).pop();
      await tester.pumpAndSettle();
      expect(routeArguments, isEmpty);
      await tester.tap(find.byKey(const ValueKey('home-continue-training')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('subscribed-plan-0')));
      await tester.pumpAndSettle();
      expect(find.text('target-/examList'), findsOneWidget);
      expect(requests, before);
      await tester.pumpWidget(const SizedBox.shrink());
    }, () => client);
  });

  for (final language in ['ar', 'en']) {
    for (final dark in [false, true]) {
      testWidgets('chooser fits $language dark=$dark enlarged landscape', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(640, 360);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await http.runWithClient(() async {
          await start(tester, language: language, dark: dark, scale: 1.8);
          await tester.tap(
            find.byKey(const ValueKey('home-continue-training')),
          );
          await tester.pumpAndSettle();
          expect(find.byType(SubscribedPlansScreen), findsOneWidget);
          expect(
            tester
                .getSize(find.byKey(const ValueKey('subscribed-plan-0')))
                .height,
            greaterThanOrEqualTo(48),
          );
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        }, () => client);
      });
    }
  }

  test(
    'inactive plans are excluded from both selection count and chooser data',
    () {
      final state = HomePracticeState.fromSubscriptions(
        loading: false,
        subscriptions: [
          {
            'planId': 'inactive',
            'planObject': PaymentPlan.fromJson({
              'id': 'inactive',
              'is_active': false,
            }),
          },
          {'planId': 'valid'},
        ],
      );
      expect(state.mode, HomePracticeMode.continuePlan);
      expect(state.subscriptions.map((sub) => sub['planId']), ['valid']);
      expect(state.subscription?['planId'], 'valid');
    },
  );

  testWidgets('repeated continue taps open only one chooser', (tester) async {
    await http.runWithClient(() async {
      await start(tester);
      final button = tester.widget<FilledButton>(
        find.byKey(const ValueKey('home-continue-training')),
      );
      button.onPressed!();
      button.onPressed!();
      await tester.pumpAndSettle();
      expect(find.byType(SubscribedPlansScreen), findsOneWidget);
      Navigator.of(tester.element(find.byType(SubscribedPlansScreen))).pop();
      await tester.pumpAndSettle();
      expect(find.byType(SubscribedPlansScreen), findsNothing);
      expect(routeArguments, isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
    }, () => client);
  });

  for (final dark in [false, true]) {
    testWidgets('chooser portrait dark=$dark', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await http.runWithClient(() async {
        await start(tester, dark: dark);
        await tester.tap(find.byKey(const ValueKey('home-continue-training')));
        await tester.pumpAndSettle();
        if (const bool.fromEnvironment('GENERATE_SUBSCRIPTIONS_PREVIEW')) {
          await tester.runAsync(() async {
            final boundary =
                previewKey.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            final image = await boundary.toImage(pixelRatio: 2);
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            final folder = Directory('build/subscriptions-preview');
            await folder.create(recursive: true);
            await File(
              '${folder.path}/chooser-${dark ? 'dark' : 'light'}.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      }, () => client);
    });
  }
}
