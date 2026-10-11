import 'dart:io';
import 'dart:ui' as ui;
import 'package:agtiaz/l10n/app_localizations.dart';
import 'package:agtiaz/screens/home_screen.dart';
import 'package:agtiaz/services/content_cache.dart';
import 'package:agtiaz/widgets/app_bottom_navigation.dart';
import 'package:agtiaz/widgets/premium_tab_label.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late http.Client originalClient;
  late Directory directory;
  var requests = 0;

  setUpAll(() async {
    if (Platform.isWindows) {
      final font = FontLoader('HomePreview');
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

  setUp(() async {
    originalClient = ContentCache.client;
    SharedPreferences.setMockInitialValues({});
    directory = await Directory.systemTemp.createTemp('agtiaz-home-ui-');
    ContentCache.directoryForTesting = directory;
    requests = 0;
    ContentCache.client = MockClient((request) async {
      requests++;
      return http.Response('{"success":true,"data":[]}', 200);
    });
  });

  tearDown(() async {
    ContentCache.client.close();
    ContentCache.client = originalClient;
    ContentCache.directoryForTesting = null;
    await directory.delete(recursive: true);
  });

  Widget host(GlobalKey key, {String language = 'ar'}) => ScreenUtilInit(
    designSize: const Size(390, 844),
    builder: (_, _) => RepaintBoundary(
      key: key,
      child: MaterialApp(
        locale: Locale(language),
        supportedLocales: const [Locale('ar'), Locale('en')],
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: ThemeData(
          fontFamily: Platform.isWindows ? 'HomePreview' : null,
          scaffoldBackgroundColor: const Color(0xFFF9F9F9),
        ),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: const HomeScreen(),
      ),
    ),
  );

  Future<void> start(
    WidgetTester tester,
    GlobalKey key, {
    String language = 'ar',
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(host(key, language: language));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
  }

  Future<void> preview(WidgetTester tester, GlobalKey key, String name) async {
    if (!const bool.fromEnvironment('GENERATE_HOME_PREVIEW')) return;
    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final target = Directory('build/home-preview');
      await target.create(recursive: true);
      await File(
        '${target.path}/$name.png',
      ).writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  testWidgets(
    'free home ends near navigation without nested-scroll blank space',
    (tester) async {
      final key = GlobalKey();
      await start(tester, key);
      expect(find.byType(SliverAppBar), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(TabBarView),
          matching: find.byType(SliverAppBar),
        ),
        findsNothing,
      );
      final header = find.byType(SliverAppBar);
      expect(
        find.descendant(of: header, matching: find.byIcon(Icons.logout)),
        findsNothing,
      );
      expect(
        find.descendant(
          of: header,
          matching: find.byIcon(Icons.person_outline),
        ),
        findsNothing,
      );
      expect(find.byType(FloatingActionButton), findsNothing);
      expect(find.byIcon(Icons.support_agent_rounded), findsNothing);
      expect(
        find.descendant(of: header, matching: find.byType(IconButton)),
        findsNothing,
      );
      await tester.drag(
        find.byKey(const PageStorageKey('home-scroll')),
        const Offset(0, -2000),
      );
      await tester.pumpAndSettle();
      final lastLabel = find.text(
        AppLocalizations(const Locale('ar')).translate('homeFollow'),
      );
      final gap =
          tester.getTopLeft(find.byType(AppBottomNavigation)).dy -
          tester.getBottomLeft(lastLabel).dy;
      expect(gap, inInclusiveRange(0, 28));
      expect(
        tester.getSize(find.byKey(const ValueKey('home-practice-steps'))).width,
        closeTo(358, 0.5),
      );
      expect(tester.takeException(), isNull);
      await preview(tester, key, 'home-free-bottom');
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('premium has top browse action, gold tab and black label', (
    tester,
  ) async {
    final key = GlobalKey();
    await start(tester, key);
    final headerPosition = tester.getTopLeft(find.byType(TabBar));
    await tester.tap(find.byType(PremiumTabLabel).hitTestable());
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.getTopLeft(find.byType(TabBar)), headerPosition);
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.byType(TabBar)), headerPosition);
    final browse = find.byKey(const ValueKey('home-browse-plans'));
    expect(browse.hitTestable(), findsOneWidget);
    expect(tester.getCenter(browse).dx, closeTo(195, 0.5));
    expect(
      tester.widget<FilledButton>(browse).style!.shape!.resolve({}),
      isA<StadiumBorder>(),
    );
    expect(
      tester.getTopLeft(browse).dy,
      lessThan(
        tester
            .getTopLeft(find.byKey(const ValueKey('home-explore-standards')))
            .dy,
      ),
    );
    final tabs = tester.widget<TabBar>(find.byType(TabBar).hitTestable());
    expect((tabs.indicator as BoxDecoration).color, const Color(0xFFE8B83F));
    expect(tabs.labelColor, const Color(0xFF1C1C1C));
    final sparkle = tester.widget<PremiumTabLabel>(
      find.byType(PremiumTabLabel).hitTestable(),
    );
    expect(sparkle.selected, isTrue);
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(find.byIcon(Icons.support_agent_rounded), findsNothing);
    expect(tester.takeException(), isNull);
    await preview(tester, key, 'home-premium-top');
    await tester.tap(
      find.text(AppLocalizations(const Locale('ar')).translate('free')),
    );
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const ValueKey('home-tab-content')),
      const Offset(150, 0),
    );
    await tester.pumpAndSettle();
    expect(
      tester.widget<PremiumTabLabel>(find.byType(PremiumTabLabel)).selected,
      isTrue,
    );
    expect(tester.getTopLeft(find.byType(TabBar)), headerPosition);
    await tester.drag(
      find.byKey(const PageStorageKey('home-scroll')),
      const Offset(0, -2000),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final language in ['ar', 'en']) {
    testWidgets(
      'support belongs to profile and opens contact channels $language',
      (tester) async {
        const channel = MethodChannel('plugins.flutter.io/url_launcher');
        final launches = <MethodCall>[];
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (call) async {
              launches.add(call);
              return true;
            });
        addTearDown(
          () => TestDefaultBinaryMessengerBinding
              .instance
              .defaultBinaryMessenger
              .setMockMethodCallHandler(channel, null),
        );
        final key = GlobalKey();
        await start(tester, key, language: language);
        final initialRequests = requests;
        final text = AppLocalizations(Locale(language));
        await tester.tap(find.byKey(const ValueKey('destination-3')));
        await tester.pumpAndSettle();
        final contact = find.byKey(const ValueKey('profile-contact-support'));
        await tester.ensureVisible(contact);
        await tester.pumpAndSettle();
        expect(contact.hitTestable(), findsOneWidget);
        expect(find.text(text.translate('supportSection')), findsOneWidget);
        expect(find.byType(FloatingActionButton), findsNothing);
        expect(tester.getSize(contact).height, greaterThanOrEqualTo(48));
        expect(requests, initialRequests);
        await preview(tester, key, 'profile-support-$language');
        await tester.tap(contact);
        await tester.pumpAndSettle();
        expect(find.byType(Dialog), findsOneWidget);
        expect(find.text('+966537583811').hitTestable(), findsOneWidget);
        expect(find.text('agtiazsupp@gmail.com').hitTestable(), findsOneWidget);
        await preview(tester, key, 'profile-support-dialog-$language');
        await tester.tap(find.text('+966537583811'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('agtiazsupp@gmail.com'));
        await tester.pumpAndSettle();
        expect(launches.map((call) => call.method), ['launch', 'launch']);
        final whatsapp = Uri.parse(
          (launches[0].arguments as Map)['url'] as String,
        );
        expect(whatsapp.host, 'wa.me');
        expect(whatsapp.path, '/966537583811');
        expect(
          whatsapp.queryParameters['text'],
          text.translate('supportWhatsappMessage'),
        );
        expect(
          (launches[1].arguments as Map)['url'],
          'mailto:agtiazsupp@gmail.com',
        );
        expect((launches[0].arguments as Map)['useWebView'], isFalse);
        expect((launches[1].arguments as Map)['useWebView'], isFalse);
        await tester.tap(
          find.descendant(
            of: find.byType(Dialog),
            matching: find.byIcon(Icons.close_rounded),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(Dialog), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets('switching bottom destinations does not fetch home data again', (
    tester,
  ) async {
    await start(tester, GlobalKey());
    final initialRequests = requests;
    for (final index in [1, 2, 3, 0]) {
      await tester.tap(find.byKey(ValueKey('destination-$index')));
      await tester.pumpAndSettle();
    }
    expect(requests, initialRequests);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'landscape keeps home content and tabs visible without clipping',
    (tester) async {
      final key = GlobalKey();
      await start(tester, key);
      tester.view.physicalSize = const Size(844, 390);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('home-start-trial')).hitTestable(),
        findsOneWidget,
      );
      final header = tester.widget<SliverAppBar>(find.byType(SliverAppBar));
      expect(header.flexibleSpace, isNull);
      await tester.drag(
        find.byKey(const PageStorageKey('home-scroll')),
        const Offset(0, -2000),
      );
      await tester.pumpAndSettle();
      expect(find.byType(FloatingActionButton), findsNothing);
      expect(find.byIcon(Icons.support_agent_rounded), findsNothing);
      expect(tester.takeException(), isNull);
      await preview(tester, key, 'home-landscape');
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
