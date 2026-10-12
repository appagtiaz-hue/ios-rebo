import 'dart:io';
import 'dart:ui' as ui;
import 'package:agtiaz/l10n/app_localizations.dart';
import 'package:agtiaz/screens/home_screen.dart';
import 'package:agtiaz/services/content_cache.dart';
import 'package:agtiaz/widgets/app_bottom_navigation.dart';
import 'package:agtiaz/widgets/premium_tab_label.dart';
import 'package:agtiaz/models/professional_standard.dart';
import 'package:agtiaz/screens/standards_screen.dart';
import 'package:agtiaz/theme/home_palette.dart';
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
  final routeArguments = <String, Object?>{};

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
    routeArguments.clear();
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
          fontFamily: Platform.isWindows ? 'HomePreview' : null,
          scaffoldBackgroundColor: const Color(0xFFF9F9F9),
        ),
        darkTheme: ThemeData(
          brightness: Brightness.dark,
          fontFamily: Platform.isWindows ? 'HomePreview' : null,
        ),
        routes: {
          '/test': (context) => const Scaffold(body: Text('trial-target')),
          '/payment': (context) => const Scaffold(body: Text('plans-target')),
          '/standards': (context) {
            final argument = ModalRoute.of(context)?.settings.arguments;
            routeArguments['/standards'] = argument;
            return StandardsScreen(
              initialDomain: argument is ProfessionalDomain ? argument : null,
            );
          },
        },
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

  testWidgets('Home greeting stays below system status bars and notches', (
    tester,
  ) async {
    final key = GlobalKey();
    tester.view.padding = const FakeViewPadding(top: 30, bottom: 20);
    addTearDown(tester.view.resetPadding);
    await start(tester, key);
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('home-greeting'))).dy,
      greaterThanOrEqualTo(54),
    );
    await tester.tap(find.byKey(const ValueKey('home-premium-tab')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('free home keeps compact header and finishes near navigation', (
    tester,
  ) async {
    final key = GlobalKey();
    await start(tester, key);
    expect(find.byType(SliverAppBar), findsOneWidget);
    expect(
      tester.widget<SliverAppBar>(find.byType(SliverAppBar)).flexibleSpace,
      isNull,
    );
    expect(find.byType(TabBarView), findsNothing);
    expect(find.byIcon(Icons.logout), findsNothing);
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(find.byIcon(Icons.support_agent_rounded), findsNothing);
    await preview(tester, key, 'home-free-top');
    await tester.drag(
      find.byKey(const PageStorageKey('home-scroll')),
      const Offset(0, -2000),
    );
    await tester.pumpAndSettle();
    final lastAction = find.byKey(const ValueKey('home-select-premium'));
    final gap =
        tester.getTopLeft(find.byType(AppBottomNavigation)).dy -
        tester.getBottomLeft(lastAction).dy;
    expect(gap, inInclusiveRange(0, 24));
    expect(tester.takeException(), isNull);
    await preview(tester, key, 'home-free-bottom');
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('premium switch keeps header stable and does not request data', (
    tester,
  ) async {
    final key = GlobalKey();
    await start(tester, key);
    final position = tester.getTopLeft(find.byType(TabBar));
    final initialRequests = requests;
    await tester.tap(find.byKey(const ValueKey('home-premium-tab')));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.getTopLeft(find.byType(TabBar)), position);
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.byType(TabBar)), position);
    expect(requests, initialRequests);
    expect(
      find.byKey(const ValueKey('home-browse-plans')).hitTestable(),
      findsOneWidget,
    );
    final tabs = tester.widget<TabBar>(find.byType(TabBar));
    expect((tabs.indicator as BoxDecoration).color, const Color(0xFFF1D185));
    expect(find.byType(PremiumTabLabel), findsNothing);
    expect(find.byType(FloatingActionButton), findsNothing);
    await preview(tester, key, 'home-premium-top');
    await tester.tap(find.byKey(const ValueKey('home-free-tab')));
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const ValueKey('home-tab-content')),
      const Offset(150, 0),
    );
    await tester.pumpAndSettle();
    expect(tester.widget<TabBar>(find.byType(TabBar)).controller!.index, 1);
    expect(tester.getTopLeft(find.byType(TabBar)), position);
    expect(requests, initialRequests);
    await tester.drag(
      find.byKey(const PageStorageKey('home-scroll')),
      const Offset(0, -2000),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'Home actions reuse routes and pass the selected domain without extra reads',
    (tester) async {
      final key = GlobalKey();
      await start(tester, key);
      final initialRequests = requests;
      final homeContext = tester.element(find.byType(HomeScreen));
      await tester.tap(find.byKey(const ValueKey('home-start-trial')));
      await tester.pumpAndSettle();
      expect(find.text('trial-target'), findsOneWidget);
      Navigator.of(homeContext).pop();
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('home-select-premium')),
      );
      await tester.tap(find.byKey(const ValueKey('home-select-premium')));
      await tester.pumpAndSettle();
      final browse = find.byKey(const ValueKey('home-browse-plans'));
      await tester.ensureVisible(browse);
      await tester.pumpAndSettle();
      await tester.tap(browse);
      await tester.pumpAndSettle();
      expect(find.text('plans-target'), findsOneWidget);
      Navigator.of(homeContext).pop();
      await tester.pumpAndSettle();
      final domain = find.byKey(const ValueKey('home-domain-practice'));
      await tester.ensureVisible(domain);
      await tester.pumpAndSettle();
      await tester.tap(domain);
      await tester.pumpAndSettle();
      expect(routeArguments['/standards'], ProfessionalDomain.practice);
      expect(find.byType(StandardsScreen), findsOneWidget);
      Navigator.of(homeContext).pop();
      await tester.pumpAndSettle();
      expect(requests, initialRequests);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('system theme changes recolor Home without reloading data', (
    tester,
  ) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    final key = GlobalKey();
    await start(tester, key);
    final initialRequests = requests;
    final home = find
        .descendant(
          of: find.byType(HomeScreen),
          matching: find.byType(Scaffold),
        )
        .first;
    final light = tester.widget<Scaffold>(home).backgroundColor;
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    await tester.pumpAndSettle();
    expect(
      tester.widget<Scaffold>(home).backgroundColor,
      HomePalette.of(tester.element(home)).background,
    );
    expect(tester.widget<Scaffold>(home).backgroundColor, isNot(light));
    expect(requests, initialRequests);
    await preview(tester, key, 'home-free-dark');
    await tester.tap(find.byKey(const ValueKey('home-premium-tab')));
    await tester.pumpAndSettle();
    await preview(tester, key, 'home-premium-dark');
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
      final trial = find.byKey(const ValueKey('home-start-trial'));
      await tester.ensureVisible(trial);
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
