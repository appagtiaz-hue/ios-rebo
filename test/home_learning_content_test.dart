import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:agtiaz/l10n/app_localizations.dart';
import 'package:agtiaz/widgets/home_learning_content.dart';
import 'package:agtiaz/widgets/premium_tab_label.dart';

void main() {
  setUpAll(() async {
    if (Platform.isWindows) {
      final font = FontLoader('HomePreview');
      final bytes = await File('C:/Windows/Fonts/arial.ttf').readAsBytes();
      font.addFont(Future.value(ByteData.sublistView(bytes)));
      await font.load();
    }
    final icons = FontLoader('MaterialIcons');
    icons.addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });

  Widget host({
    required String locale,
    required bool premium,
    required Brightness brightness,
    required double scale,
    required VoidCallback onProgress,
    GlobalKey? contentKey,
  }) {
    return MaterialApp(
      locale: Locale(locale),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        brightness: brightness,
        fontFamily: Platform.isWindows ? 'HomePreview' : null,
        scaffoldBackgroundColor: brightness == Brightness.dark
            ? const Color(0xFF121212)
            : const Color(0xFFF9F9F9),
        cardColor: brightness == Brightness.dark
            ? const Color(0xFF202020)
            : Colors.white,
      ),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(scale),
          disableAnimations: true,
        ),
        child: child!,
      ),
      home: Scaffold(
        body: RepaintBoundary(
          key: contentKey,
          child: ColoredBox(
            color: brightness == Brightness.dark
                ? const Color(0xFF121212)
                : const Color(0xFFF9F9F9),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                key: const ValueKey('home-preview-content'),
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (premium) ...[
                    HomePlanBrowseAction(onBrowsePlans: onProgress),
                    const SizedBox(height: 16),
                  ],
                  HomeLearningContent(
                    premium: premium,
                    onShowProgress: onProgress,
                    onStartTrial: onProgress,
                    onExploreStandards: onProgress,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  for (final variant in const [
    ('ar', 320.0, Brightness.light, 1.6),
    ('ar', 390.0, Brightness.light, 1.0),
    ('ar', 390.0, Brightness.dark, 1.6),
    ('en', 320.0, Brightness.light, 1.6),
    ('en', 600.0, Brightness.dark, 1.0),
  ]) {
    for (final premium in [false, true]) {
      testWidgets(
        'home content ${variant.$1} ${variant.$2} premium=$premium fits and actions work',
        (tester) async {
          tester.view.physicalSize = Size(variant.$2, 900);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          var opens = 0;
          await tester.pumpWidget(
            host(
              locale: variant.$1,
              premium: premium,
              brightness: variant.$3,
              scale: variant.$4,
              onProgress: () => opens++,
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          if (premium) {
            final action = find.byType(HomePlanBrowseAction);
            final button = find.byKey(const ValueKey('home-browse-plans'));
            expect(
              tester.getCenter(button).dx,
              closeTo(tester.getCenter(action).dx, 0.5),
            );
            final style = tester.widget<FilledButton>(button).style!;
            expect(style.shape!.resolve({}), isA<StadiumBorder>());
            expect(style.elevation!.resolve({}), 4);
            expect(
              find.descendant(
                of: action,
                matching: find.byIcon(Icons.auto_awesome),
              ),
              findsNWidgets(2),
            );
          }
          final texts = tester.widgetList<Text>(find.byType(Text));
          expect(
            texts.any(
              (text) => RegExp(
                r'[\u{1F300}-\u{1FAFF}]',
                unicode: true,
              ).hasMatch(text.data ?? ''),
            ),
            isFalse,
          );
          final actions = premium
              ? ['home-explore-standards', 'home-browse-plans']
              : ['home-start-trial', 'home-show-progress'];
          for (final action in actions) {
            final button = find.byKey(ValueKey(action));
            await tester.ensureVisible(button);
            await tester.pumpAndSettle();
            expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
            await tester.tap(button);
          }
          expect(opens, 2);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets(
    'premium sparkle keeps a stable size and respects reduced motion',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              disableAnimations: false,
              textScaler: TextScaler.linear(1.8),
            ),
            child: const Center(
              child: SizedBox(
                width: 100,
                height: 48,
                child: PremiumTabLabel(label: 'Premium'),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      final size = tester.getSize(find.byType(PremiumTabLabel));
      final star = find
          .descendant(
            of: find.byType(PremiumTabLabel),
            matching: find.byType(Opacity),
          )
          .first;
      final initialOpacity = tester.widget<Opacity>(star).opacity;
      await tester.pump(const Duration(milliseconds: 900));
      expect(tester.widget<Opacity>(star).opacity, isNot(initialOpacity));
      expect(tester.getSize(find.byType(PremiumTabLabel)), size);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: const Center(
              child: SizedBox(
                width: 100,
                height: 48,
                child: PremiumTabLabel(label: 'Premium'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final reducedOpacity = tester.widget<Opacity>(star).opacity;
      await tester.pump(const Duration(seconds: 3));
      expect(tester.widget<Opacity>(star).opacity, reducedOpacity);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  if (const bool.fromEnvironment('GENERATE_HOME_PREVIEW')) {
    for (final premium in [false, true]) {
      testWidgets('render home preview premium=$premium', (tester) async {
        tester.view.physicalSize = const Size(390, 2400);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final key = GlobalKey();
        await tester.pumpWidget(
          host(
            locale: 'ar',
            premium: premium,
            brightness: Brightness.light,
            scale: 1,
            onProgress: () {},
            contentKey: key,
          ),
        );
        await tester.pumpAndSettle();
        final contentHeight = tester
            .getSize(find.byKey(const ValueKey('home-preview-content')))
            .height;
        tester.view.physicalSize = Size(390, contentHeight + 32);
        await tester.pumpAndSettle();
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 2);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final directory = Directory('build/home-preview');
          await directory.create(recursive: true);
          await File(
            '${directory.path}/${premium ? 'premium' : 'free'}.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
        expect(tester.takeException(), isNull);
      });
    }
  }
}
