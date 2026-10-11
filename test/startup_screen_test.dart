import 'dart:io';
import 'dart:ui' as ui;
import 'package:agtiaz/l10n/app_localizations.dart';
import 'package:agtiaz/screens/startup_screen.dart';
import 'package:agtiaz/widgets/startup_brand_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    if (Platform.isWindows) {
      final font = FontLoader('StartupPreview');
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

  Widget host({
    String language = 'ar',
    bool reducedMotion = false,
    double scale = 1,
    Brightness brightness = Brightness.light,
    GlobalKey? previewKey,
  }) => MaterialApp(
    theme: ThemeData(
      brightness: brightness,
      fontFamily: Platform.isWindows ? 'StartupPreview' : null,
    ),
    home: MediaQuery(
      data: MediaQueryData(
        disableAnimations: reducedMotion,
        textScaler: TextScaler.linear(scale),
      ),
      child: RepaintBoundary(
        key: previewKey,
        child: StartupBrandView(languageCode: language),
      ),
    ),
  );

  for (final language in ['ar', 'en']) {
    testWidgets(
      'messages type in order, replace every second, and loop $language',
      (tester) async {
        await tester.pumpWidget(host(language: language));
        await tester.pump();
        final text = AppLocalizations(Locale(language));
        final message = find.byKey(const ValueKey('startup-typed-message'));
        expect(StartupBrandView.messageDuration, const Duration(seconds: 1));
        for (final key in [
          ...StartupBrandView.messageKeys,
          StartupBrandView.messageKeys.first,
        ]) {
          final letters = text.translate(key).characters;
          await tester.pump(const Duration(milliseconds: 500));
          expect(
            tester.widget<Text>(message).data,
            letters.take((letters.length / 2).ceil()).toString(),
          );
          await tester.pump(const Duration(milliseconds: 500));
          await tester.pump();
        }
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  for (final variant in const [
    ('ar', Size(320, 568), 1.6, Brightness.light),
    ('en', Size(320, 568), 1.6, Brightness.dark),
    ('ar', Size(390, 844), 1.0, Brightness.light),
    ('ar', Size(844, 390), 1.0, Brightness.light),
  ]) {
    testWidgets(
      'startup fits ${variant.$1} ${variant.$2} with reduced motion',
      (tester) async {
        tester.view.physicalSize = variant.$2;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final key = GlobalKey();
        await tester.pumpWidget(
          host(
            language: variant.$1,
            scale: variant.$3,
            brightness: variant.$4,
            reducedMotion: true,
            previewKey: key,
          ),
        );
        await tester.pumpAndSettle();
        final expected = AppLocalizations(
          Locale(variant.$1),
        ).translate(StartupBrandView.messageKeys.first);
        expect(find.text(expected), findsOneWidget);
        expect(find.text(expected).hitTestable(), findsOneWidget);
        await tester.pump(const Duration(seconds: 3));
        expect(find.text(expected), findsOneWidget);
        expect(tester.takeException(), isNull);
        if (const bool.fromEnvironment('GENERATE_HOME_PREVIEW') &&
            variant.$2.width == 390) {
          await tester.runAsync(() async {
            final boundary =
                key.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            final image = await boundary.toImage(pixelRatio: 2);
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await Directory('build/home-preview').create(recursive: true);
            await File(
              'build/home-preview/startup.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  for (final onboarded in [false, true]) {
    testWidgets('ready startup navigates immediately, onboarded=$onboarded', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({
        'onboarding_completed': onboarded,
      });
      const channel = MethodChannel(
        'plugins.it_nomads.com/flutter_secure_storage',
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (_) async => null);
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: const StartupScreen(languageCode: 'ar'),
          routes: {
            '/onboarding': (_) =>
                const Scaffold(body: Text('onboarding-ready')),
            '/login': (_) => const Scaffold(body: Text('login-ready')),
          },
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(
        find.text(onboarded ? 'login-ready' : 'onboarding-ready'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
