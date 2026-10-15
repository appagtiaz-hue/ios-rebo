import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:agtiaz/l10n/app_localizations.dart';
import 'package:agtiaz/models/user.dart';
import 'package:agtiaz/screens/statistics_screen.dart';
import 'package:agtiaz/services/content_cache.dart';
import 'package:agtiaz/widgets/app_bottom_navigation.dart';
import 'package:agtiaz/widgets/statistics_content.dart';
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
  const secure = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  late http.Client originalClient;
  late Directory cache;
  var requests = 0;
  var responseStatus = 200;
  var malformed = false;
  final user = User(
    id: '123456789012345678901234',
    fullName: 'A very long display name',
    email: 'statistics@example.invalid',
    password: '',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );
  const sample = {
    'completedTests': 12,
    'totalPoints': 680,
    'level': 4,
    'progress': 40,
  };

  setUpAll(() async {
    if (Platform.isWindows) {
      const folder = String.fromEnvironment('STATISTICS_PREVIEW_FONT_DIR');
      final fonts = folder.isEmpty
          ? [File('C:/Windows/Fonts/arial.ttf')]
          : Directory(folder).listSync().whereType<File>().where(
              (file) =>
                  file.path.contains('Cairo_regular_') ||
                  file.path.contains('Cairo_700_'),
            );
      final loader = FontLoader('StatisticsPreview');
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
    originalClient = ContentCache.client;
    cache = await Directory.systemTemp.createTemp('agtiaz-statistics-ui-');
    ContentCache.directoryForTesting = cache;
    requests = 0;
    responseStatus = 200;
    malformed = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secure, (_) async => 'statistics-test-token');
    ContentCache.client = MockClient((request) async {
      requests++;
      expect(request.url.path, '/mobile/api/users/${user.id}/statistics');
      return http.Response(
        malformed
            ? '{"success":false}'
            : jsonEncode({'success': true, 'data': sample}),
        responseStatus,
      );
    });
  });

  tearDown(() async {
    ContentCache.client.close();
    ContentCache.client = originalClient;
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
    bool navigation = false,
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
      fontFamily: Platform.isWindows ? 'StatisticsPreview' : null,
    ),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(scale), disableAnimations: true),
      child: child!,
    ),
    home: RepaintBoundary(
      key: previewKey,
      child: Scaffold(
        body: child,
        bottomNavigationBar: navigation
            ? AppBottomNavigation(selectedIndex: 2, onSelect: (_) {})
            : null,
      ),
    ),
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

  Future<void> preview(WidgetTester tester, GlobalKey key, String name) async {
    if (!const bool.fromEnvironment('GENERATE_STATISTICS_PREVIEW')) return;
    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final folder = Directory('build/statistics-preview');
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
        testWidgets('statistics layout $language dark=$dark $size', (
          tester,
        ) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          tester.view.padding = const FakeViewPadding(top: 24, bottom: 16);
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.view.resetPadding);
          final key = GlobalKey();
          await tester.pumpWidget(
            host(
              StatisticsScreen(onBack: () {}, user: user, statistics: sample),
              language: language,
              dark: dark,
              scale: size.width == 390 ? 1 : 1.8,
              navigation: true,
              previewKey: key,
            ),
          );
          await settle(tester);
          expect(tester.takeException(), isNull);
          expect(find.byType(StatisticsContent), findsOneWidget);
          expect(
            tester.getSize(find.byKey(const ValueKey('stats-level-ring'))),
            const Size(164, 164),
          );
          expect(
            tester.widget<Text>(find.byKey(const ValueKey('stats-tests'))).data,
            '12',
          );
          expect(
            tester
                .widget<Text>(find.byKey(const ValueKey('stats-points')))
                .data,
            '680',
          );
          expect(
            tester.widget<Text>(find.byKey(const ValueKey('stats-level'))).data,
            '4',
          );
          expect(
            tester
                .widget<Text>(find.byKey(const ValueKey('stats-progress')))
                .data,
            '40%',
          );
          if (size.width == 390 && language == 'ar') {
            await preview(
              tester,
              key,
              dark ? 'statistics-dark' : 'statistics-light',
            );
          }
          await tester.ensureVisible(
            find.byKey(const ValueKey('stats-remaining')),
          );
          await tester.pumpAndSettle();
          expect(
            tester
                .widget<Text>(find.byKey(const ValueKey('stats-remaining')))
                .data,
            language == 'ar'
                ? 'متبقي 120 نقطة للمستوى 5'
                : '120 points to level 5',
          );
          expect(tester.takeException(), isNull);
          expect(requests, 0);
          await tester.pumpWidget(const SizedBox.shrink());
        });
      }
    }
  }

  for (final points in [0, 199, 200, 399, 400, 680]) {
    testWidgets('level boundaries remain server-compatible at $points points', (
      tester,
    ) async {
      final level = points ~/ 200 + 1;
      final progress = ((points % 200) / 200 * 100).round();
      await tester.pumpWidget(
        host(
          StatisticsScreen(
            onBack: () {},
            statistics: {
              'completedTests': points == 0 ? 0 : 12,
              'totalPoints': points,
              'level': level,
              'progress': progress,
            },
          ),
          language: 'en',
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('stats-level'))).data,
        '$level',
      );
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('stats-progress'))).data,
        '$progress%',
      );
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('stats-remaining'))).data,
        '${200 - points % 200} points to level ${level + 1}',
      );
      expect(find.text('${points % 200} / 200'), findsOneWidget);
      expect(requests, 0);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets(
    'home data updates in place without requests and back callback is preserved',
    (tester) async {
      var backs = 0;
      final callback = () {
        backs++;
      };
      await tester.pumpWidget(
        host(
          StatisticsScreen(onBack: callback, user: user),
          language: 'en',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Loading your statistics…'), findsOneWidget);
      expect(find.byType(StatisticsContent), findsNothing);
      await tester.pumpWidget(
        host(
          StatisticsScreen(onBack: callback, user: user, statistics: sample),
          language: 'en',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(StatisticsContent), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('stats-back')));
      expect(backs, 1);
      expect(requests, 0);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('invalid numbers are bounded and do not overflow the ring', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        StatisticsScreen(
          onBack: () {},
          statistics: {
            'completedTests': -1,
            'totalPoints': double.nan,
            'level': -2,
            'progress': 999,
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('stats-tests'))).data,
      '0',
    );
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('stats-points'))).data,
      '0',
    );
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('stats-level'))).data,
      '1',
    );
    expect(
      tester
          .widget<CircularProgressIndicator>(
            find.byType(CircularProgressIndicator),
          )
          .value,
      1,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'standalone uses the same private cache and removes its listener on exit',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'current_user': jsonEncode(user.toJson()),
      });
      await tester.pumpWidget(host(const StatisticsScreen(), language: 'en'));
      await settle(tester);
      expect(find.byType(StatisticsContent), findsOneWidget);
      expect(requests, 1);
      ContentCache.changes.value++;
      ContentCache.changes.value++;
      await settle(tester);
      expect(requests, 1);
      await tester.pumpWidget(const SizedBox.shrink());
      ContentCache.changes.value++;
      await settle(tester);
      expect(requests, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'failed standalone load shows an error, not fake zeros, and retries once',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'current_user': jsonEncode(user.toJson()),
      });
      responseStatus = 503;
      await tester.pumpWidget(host(const StatisticsScreen(), language: 'en'));
      await settle(tester);
      expect(find.text('Your statistics could not be loaded.'), findsOneWidget);
      expect(find.byType(StatisticsContent), findsNothing);
      expect(requests, 1);
      responseStatus = 200;
      await tester.tap(find.byKey(const ValueKey('stats-retry')));
      await settle(tester);
      expect(find.byType(StatisticsContent), findsOneWidget);
      expect(requests, 2);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'missing account and malformed response never leave an endless loader',
    (tester) async {
      await tester.pumpWidget(host(const StatisticsScreen(), language: 'en'));
      await settle(tester);
      expect(find.text('Your statistics could not be loaded.'), findsOneWidget);
      expect(requests, 0);
      await tester.pumpWidget(const SizedBox.shrink());
      SharedPreferences.setMockInitialValues({
        'current_user': jsonEncode(user.toJson()),
      });
      malformed = true;
      await tester.pumpWidget(host(const StatisticsScreen(), language: 'en'));
      await settle(tester);
      expect(find.text('Your statistics could not be loaded.'), findsOneWidget);
      expect(find.byType(StatisticsContent), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
