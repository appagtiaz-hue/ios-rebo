import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:agtiaz/l10n/app_localizations.dart';
import 'package:agtiaz/models/payment_plan.dart';
import 'package:agtiaz/models/user.dart';
import 'package:agtiaz/screens/payment_screen.dart';
import 'package:agtiaz/services/content_cache.dart';
import 'package:agtiaz/theme/home_palette.dart';
import 'package:agtiaz/widgets/plan_catalog_content.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

PaymentPlan plan(
  String id,
  String name,
  double price,
  String primary, {
  bool active = true,
}) => PaymentPlan(
  id: id,
  name: name,
  nameEn: 'Plan $id',
  description: 'تدريب منظم على أسئلة الرخصة المهنية.',
  descriptionEn: 'Structured practice for your professional license.',
  questionCount: 300,
  price: price,
  currency: 'SAR',
  isActive: active,
  primaryColor: primary,
  secondaryColor: '#D09E38',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const secure = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  final plans = [
    plan('free', 'الخطة المجانية', 0, '#355B45'),
    plan('silver', 'الخطة الفضية', 100.5, '#567C86'),
    plan('gold', 'الخطة الذهبية', 200, '#A27718'),
  ];
  late Directory cache;
  late http.Client original;
  var requests = 0;
  List<PaymentPlan> serverPlans = [];
  List<Map<String, dynamic>> extraPlans = [];
  final navigations = <RouteSettings>[];

  setUpAll(() async {
    if (Platform.isWindows) {
      const folder = String.fromEnvironment('PLANS_PREVIEW_FONT_DIR');
      final fonts = folder.isEmpty
          ? [File('C:/Windows/Fonts/arial.ttf')]
          : Directory(folder).listSync().whereType<File>().where(
              (file) =>
                  file.path.contains('Cairo_regular_') ||
                  file.path.contains('Cairo_700_'),
            );
      final loader = FontLoader('PlansPreview');
      for (final file in fonts) {
        loader.addFont(
          Future.value(ByteData.sublistView(await file.readAsBytes())),
        );
      }
      await loader.load();
    }
    final icons = FontLoader('MaterialIcons');
    icons.addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    original = ContentCache.client;
    cache = await Directory.systemTemp.createTemp('agtiaz-plans-ui-');
    ContentCache.directoryForTesting = cache;
    requests = 0;
    navigations.clear();
    serverPlans = [...plans];
    extraPlans = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secure, (_) async => 'plans-test-token');
    ContentCache.client = MockClient((request) async {
      requests++;
      if (request.url.path == '/api/content-version') {
        return http.Response('{}', 404);
      }
      if (request.url.path == '/api/plans') {
        return http.Response(
          jsonEncode({
            'success': true,
            'data': serverPlans.map((p) => p.toJson()).toList(),
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      expect(request.url.path, '/mobile/api/additional-tests');
      return http.Response(
        jsonEncode({'success': true, 'data': extraPlans}),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
  });

  tearDown(() async {
    ContentCache.client.close();
    ContentCache.client = original;
    ContentCache.directoryForTesting = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secure, null);
    await cache.delete(recursive: true);
  });

  Widget host(
    Widget child, {
    String language = 'ar',
    bool dark = false,
    double scale = 1,
    GlobalKey? previewKey,
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
      fontFamily: Platform.isWindows ? 'PlansPreview' : null,
    ),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(scale), disableAnimations: true),
      child: child!,
    ),
    onGenerateRoute: (settings) {
      navigations.add(settings);
      return MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => const Scaffold(body: Text('Destination')),
      );
    },
    home: RepaintBoundary(
      key: previewKey,
      child: child is PaymentScreen
          ? child
          : Builder(
              builder: (context) {
                final p = HomePalette.of(context);
                return Scaffold(
                  backgroundColor: p.background,
                  appBar: AppBar(
                    backgroundColor: p.background,
                    foregroundColor: p.ink,
                    surfaceTintColor: Colors.transparent,
                    leading: BackButton(onPressed: () {}),
                    title: Text(
                      AppLocalizations.of(context)!.translate('catalogTitle'),
                      style: const TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  body: child,
                );
              },
            ),
    ),
  );

  Widget content({
    PaymentPlan? selected,
    bool owned = false,
    bool loading = false,
    bool error = false,
    bool empty = false,
    VoidCallback? retry,
    VoidCallback? proceed,
  }) => PlanCatalogContent(
    plans: empty ? [] : plans,
    selectedPlan: selected,
    isOwned: (_) => owned,
    onSelect: (_) {},
    onProceed: proceed ?? () {},
    onRetry: retry ?? () {},
    isLoading: loading,
    hasError: error,
  );

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 40; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pumpAndSettle();
  }

  void viewport(WidgetTester tester, Size size) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 24, bottom: 16);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);
  }

  Future<void> select(WidgetTester tester, String id) async {
    final card = find.byKey(ValueKey('catalog-plan-$id'));
    await tester.ensureVisible(card);
    await tester.tap(card);
    await tester.pumpAndSettle();
  }

  Future<void> preview(WidgetTester tester, GlobalKey key, String name) async {
    if (!const bool.fromEnvironment('GENERATE_PLANS_PREVIEW')) return;
    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final folder = Directory('build/plans-preview');
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
        const Size(320, 568),
        const Size(390, 844),
        const Size(844, 390),
      ]) {
        testWidgets('catalog layout $language dark=$dark $size', (
          tester,
        ) async {
          viewport(tester, size);
          final key = GlobalKey();
          await tester.pumpWidget(
            host(
              content(selected: plans.last),
              language: language,
              dark: dark,
              scale: size.width == 390 ? 1 : 1.8,
              previewKey: key,
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          final button = find.byKey(const ValueKey('catalog-proceed'));
          expect(tester.getSize(button).height, greaterThanOrEqualTo(52));
          final bottom = tester.getBottomLeft(button).dy;
          await tester.drag(find.byType(ListView), const Offset(0, -800));
          await tester.pumpAndSettle();
          expect(tester.getBottomLeft(button).dy, bottom);
          expect(tester.takeException(), isNull);
          if (size.width == 390 && language == 'ar') {
            await tester.drag(find.byType(ListView), const Offset(0, 1000));
            await tester.pumpAndSettle();
            await preview(tester, key, dark ? 'plans-dark' : 'plans-light');
          }
          expect(requests, 0);
          await tester.pumpWidget(const SizedBox.shrink());
        });
      }
    }
  }

  testWidgets('no selection disables proceed', (tester) async {
    await tester.pumpWidget(host(content()));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('catalog-proceed')))
          .onPressed,
      isNull,
    );
    expect(find.text('اختر خطة للمتابعة'), findsOneWidget);
  });

  for (final state in ['free', 'owned', 'paid']) {
    testWidgets('correct action for $state', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        host(
          content(
            selected: state == 'free' ? plans.first : plans.last,
            owned: state == 'owned',
            proceed: () => taps++,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final expected = state == 'free'
          ? 'ابدأ مجانًا'
          : state == 'owned'
          ? 'فتح الخطة'
          : 'متابعة للدفع';
      expect(find.text(expected), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('catalog-proceed')));
      expect(taps, 1);
    });
  }

  testWidgets('empty, loading and retry states', (tester) async {
    await tester.pumpWidget(host(content(empty: true)));
    await tester.pumpAndSettle();
    expect(find.text('لا توجد خطط متاحة حاليًا.'), findsOneWidget);
    expect(find.byKey(const ValueKey('catalog-proceed')), findsNothing);
    await tester.pumpWidget(host(content(loading: true)));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    var retries = 0;
    await tester.pumpWidget(host(content(error: true, retry: () => retries++)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('catalog-retry')));
    expect(retries, 1);
  });

  testWidgets('dashboard colors and decimal prices remain distinct', (
    tester,
  ) async {
    viewport(tester, const Size(390, 844));
    await tester.pumpWidget(host(content(selected: plans[1]), language: 'en'));
    await tester.pumpAndSettle();
    final card = find.byKey(const ValueKey('catalog-plan-silver'));
    final material = tester.widget<Material>(
      find.descendant(of: card, matching: find.byType(Material)).first,
    );
    final shape = material.shape! as RoundedRectangleBorder;
    expect(shape.borderRadius, BorderRadius.circular(8));
    expect(plans[1].getPrimaryColor(), const Color(0xFF567C86));
    final contrast =
        (material.color!.computeLuminance() + .05) /
        (shape.side.color.computeLuminance() + .05);
    expect(contrast, greaterThanOrEqualTo(4.5));
    expect(find.text('100.5 SR'), findsNWidgets(2));
    expect(tester.widget<Semantics>(card).properties.selected, isTrue);
    final primaryIcon = tester.widget<Icon>(
      find.descendant(
        of: card,
        matching: find.byIcon(Icons.star_outline_rounded),
      ),
    );
    expect(primaryIcon.color, shape.side.color);
  });

  testWidgets('long content and pale dashboard colors stay usable', (
    tester,
  ) async {
    viewport(tester, const Size(320, 568));
    final long = plan(
      'long',
      List.filled(8, 'خطة تدريب مهني متكاملة').join(' '),
      12345.75,
      '#FFFFFF',
    ).copyWith(secondaryColor: '#FFFFFF');
    await tester.pumpWidget(
      host(
        PlanCatalogContent(
          plans: [long],
          selectedPlan: long,
          isOwned: (_) => false,
          onSelect: (_) {},
          onProceed: () {},
          onRetry: () {},
        ),
        scale: 2,
      ),
    );
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -1500));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(
      tester.getSize(find.byKey(const ValueKey('catalog-proceed'))).height,
      greaterThanOrEqualTo(52),
    );
  });

  Future<void> saveUser({
    String? main,
    List<Map<String, dynamic>> extra = const [],
    List<Map<String, dynamic>> purchased = const [],
  }) async {
    final user = User(
      id: '123456789012345678901234',
      fullName: 'Catalog User',
      email: 'catalog@example.invalid',
      password: '',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
      subscriptionPlanId: main,
      additionalSubscriptions: extra,
      purchasedTests: purchased,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('current_user', jsonEncode(user.toJson()));
  }

  for (final scenario in [
    'free',
    'paid',
    'main',
    'extraString',
    'extraMap',
    'purchased',
    'inactiveExtra',
    'additionalTest',
  ]) {
    testWidgets(
      'catalog routes $scenario without repeated selection requests',
      (tester) async {
        viewport(tester, const Size(390, 844));
        if (scenario == 'main') await saveUser(main: 'silver');
        if (scenario == 'extraString') {
          await saveUser(
            extra: [
              {'planId': 'silver', 'isActive': true},
            ],
          );
        }
        if (scenario == 'extraMap') {
          await saveUser(
            extra: [
              {
                'planId': {'_id': 'silver'},
                'isActive': true,
              },
            ],
          );
        }
        if (scenario == 'inactiveExtra') {
          await saveUser(
            extra: [
              {'planId': 'silver', 'isActive': false},
            ],
          );
        }
        if (scenario == 'purchased') {
          await saveUser(
            purchased: [
              {'testId': 'silver'},
            ],
          );
        }
        if (scenario == 'additionalTest') {
          extraPlans = [
            {
              'id': 'extra-test',
              'nameAr': 'تدريب مستقل',
              'nameEn': 'Extra practice',
              'price': 0,
              'questionCount': 25,
              'examQuestionCount': 15,
              'isActive': true,
            },
          ];
        }
        await tester.pumpWidget(host(const PaymentScreen()));
        await settle(tester);
        expect(tester.takeException(), isNull);
        final before = requests;
        final id = scenario == 'free'
            ? 'free'
            : scenario == 'additionalTest'
            ? 'extra-test'
            : 'silver';
        await select(tester, id);
        await select(tester, id);
        expect(requests, before);
        final proceed = tester
            .widget<FilledButton>(find.byKey(const ValueKey('catalog-proceed')))
            .onPressed!;
        proceed();
        proceed();
        await tester.pump();
        await tester.pumpAndSettle();
        expect(navigations, hasLength(1));
        final route = navigations.single;
        if (scenario == 'paid' || scenario == 'inactiveExtra') {
          expect(route.name, '/paymentDetails');
          expect((route.arguments as PaymentPlan).id, 'silver');
        } else if (scenario == 'additionalTest') {
          expect(route.name, '/additionalTest');
          expect(route.arguments, {
            'testId': 'extra-test',
            'title': 'تدريب مستقل',
            'questionCount': 15,
          });
        } else {
          expect(route.name, '/examList');
          final arguments = route.arguments! as Map;
          expect(arguments['planId'], id);
          expect(
            arguments['planName'],
            id == 'free' ? 'الخطة المجانية' : 'الخطة الفضية',
          );
          expect(arguments['totalQuestions'], 300);
          expect(arguments.containsKey('plan'), isFalse);
        }
        await tester.pumpWidget(const SizedBox.shrink());
        await settle(tester);
      },
    );
  }

  testWidgets(
    'inactive plans excluded and selection survives cache notification',
    (tester) async {
      serverPlans.add(plan('hidden', 'Hidden', 99, '#355B45', active: false));
      extraPlans = [
        {'id': 'hidden-extra', 'name': 'Hidden extra', 'isActive': false},
      ];
      await tester.pumpWidget(host(const PaymentScreen()));
      await settle(tester);
      expect(find.byKey(const ValueKey('catalog-plan-hidden')), findsNothing);
      expect(
        find.byKey(const ValueKey('catalog-plan-hidden-extra')),
        findsNothing,
      );
      await select(tester, 'gold');
      final before = requests;
      ContentCache.changes.value++;
      await settle(tester);
      expect(find.text('الخطة الذهبية'), findsNWidgets(2));
      expect(
        tester
            .widget<Semantics>(find.byKey(const ValueKey('catalog-plan-gold')))
            .properties
            .selected,
        isTrue,
      );
      expect(requests - before, lessThanOrEqualTo(1));
      await tester.pumpWidget(const SizedBox.shrink());
      await settle(tester);
      final disposedRequests = requests;
      ContentCache.changes.value++;
      await settle(tester);
      expect(requests, disposedRequests);
      expect(tester.takeException(), isNull);
    },
  );
}
