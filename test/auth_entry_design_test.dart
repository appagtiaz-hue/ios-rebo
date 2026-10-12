import 'dart:io';
import 'dart:ui' as ui;
import 'package:agtiaz/l10n/app_localizations.dart';
import 'package:agtiaz/screens/language_selection_screen.dart';
import 'package:agtiaz/screens/login_screen.dart';
import 'package:agtiaz/services/localization_service.dart';
import 'package:agtiaz/widgets/agtiaz_brand_logo.dart';
import 'package:agtiaz/widgets/login_welcome_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Locale originalLocale;
  final destinations = <String>[];
  setUpAll(() async {
    if (Platform.isWindows) {
      final font = FontLoader('AuthPreview');
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
    originalLocale = LocalizationService.locale.value;
    destinations.clear();
  });
  tearDown(() => LocalizationService.locale.value = originalLocale);

  Widget host(
    Widget child, {
    String language = 'ar',
    bool dark = false,
    double scale = 1,
    bool reducedMotion = true,
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
      fontFamily: Platform.isWindows ? 'AuthPreview' : null,
    ),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        disableAnimations: reducedMotion,
        textScaler: TextScaler.linear(scale),
      ),
      child: child!,
    ),
    onGenerateRoute: (settings) {
      destinations.add(settings.name!);
      return MaterialPageRoute<void>(
        settings: settings,
        builder: (_) =>
            Scaffold(appBar: AppBar(), body: Text('target-${settings.name}')),
      );
    },
    home: RepaintBoundary(key: previewKey, child: child),
  );

  Future<void> start(
    WidgetTester tester,
    Widget child, {
    String language = 'ar',
    bool dark = false,
    double scale = 1,
    bool reducedMotion = true,
    GlobalKey? previewKey,
  }) async {
    await tester.pumpWidget(
      host(
        child,
        language: language,
        dark: dark,
        scale: scale,
        reducedMotion: reducedMotion,
        previewKey: previewKey,
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump();
    await tester.runAsync(() async {
      final context = tester.element(find.byType(AgtiazBrandLogo));
      await precacheImage(const AssetImage(AgtiazBrandLogo.asset), context);
      if (child is LoginScreen) {
        await precacheImage(
          const AssetImage('assets/images/google_logo.png'),
          context,
        );
      }
    });
    await tester.pumpAndSettle();
  }

  Future<void> preview(WidgetTester tester, GlobalKey key, String name) async {
    if (!const bool.fromEnvironment('GENERATE_AUTH_PREVIEW')) return;
    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final folder = Directory('build/auth-preview');
      await folder.create(recursive: true);
      await File(
        '${folder.path}/$name.png',
      ).writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  for (final language in ['ar', 'en']) {
    testWidgets(
      'welcome types in three seconds, holds two, fades as a whole and loops $language',
      (tester) async {
        final sentence = AppLocalizations(
          Locale(language),
        ).translate('welcomeMessage');
        await tester.pumpWidget(
          host(
            Scaffold(
              body: LoginWelcomeText(
                text: sentence,
                style: const TextStyle(fontSize: 24),
              ),
            ),
            language: language,
            reducedMotion: false,
          ),
        );
        final typed = find.byKey(const ValueKey('login-typed-welcome'));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump();
        final initialSize = tester.getSize(find.byType(LoginWelcomeText));
        expect(tester.widget<Text>(typed).data, '');
        await tester.pump(const Duration(milliseconds: 1500));
        expect(
          tester.widget<Text>(typed).data,
          sentence.characters
              .take((sentence.characters.length / 2).ceil())
              .toString(),
        );
        await tester.pump(const Duration(milliseconds: 1500));
        expect(tester.widget<Text>(typed).data, sentence);
        await tester.pump(const Duration(milliseconds: 1999));
        expect(tester.widget<Text>(typed).data, sentence);
        await tester.pump(const Duration(milliseconds: 91));
        expect(tester.widget<Text>(typed).data, sentence);
        expect(
          tester
              .widget<Opacity>(
                find.byKey(const ValueKey('login-welcome-opacity')),
              )
              .opacity,
          closeTo(0.5, 0.01),
        );
        expect(tester.getSize(find.byType(LoginWelcomeText)), initialSize);
        await tester.pump(const Duration(milliseconds: 90));
        expect(tester.widget<Text>(typed).data, '');
        await tester.pump(const Duration(seconds: 3));
        expect(tester.widget<Text>(typed).data, sentence);
        await tester.pumpWidget(const SizedBox.shrink());
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'reduced motion stops animation and locale changes restart cleanly',
    (tester) async {
      await tester.pumpWidget(
        host(
          const Scaffold(
            body: LoginWelcomeText(
              text: 'Welcome',
              style: TextStyle(fontSize: 24),
            ),
          ),
          reducedMotion: false,
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpWidget(
        host(
          const Scaffold(
            body: LoginWelcomeText(
              text: 'مرحباً',
              style: TextStyle(fontSize: 24),
            ),
          ),
          reducedMotion: false,
        ),
      );
      await tester.pump(const Duration(seconds: 3));
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('login-typed-welcome')))
            .data,
        'مرحباً',
      );
      await tester.pumpWidget(
        host(
          const Scaffold(
            body: LoginWelcomeText(
              text: 'Welcome',
              style: TextStyle(fontSize: 24),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('login-typed-welcome')))
            .data,
        'Welcome',
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  for (final login in [false, true]) {
    for (final language in ['ar', 'en']) {
      for (final dark in [false, true]) {
        for (final size in [
          const Size(320, 640),
          const Size(390, 844),
          const Size(844, 390),
        ]) {
          testWidgets(
            'auth layout login=$login $language dark=$dark size=$size',
            (tester) async {
              tester.view.physicalSize = size;
              tester.view.devicePixelRatio = 1;
              tester.view.padding = const FakeViewPadding(top: 30, bottom: 20);
              addTearDown(tester.view.resetPhysicalSize);
              addTearDown(tester.view.resetDevicePixelRatio);
              addTearDown(tester.view.resetPadding);
              final key = GlobalKey();
              await start(
                tester,
                login ? const LoginScreen() : const LanguageSelectionScreen(),
                language: language,
                dark: dark,
                scale: size.width == 390 ? 1 : 1.8,
                previewKey: key,
              );
              expect(find.byType(AgtiazBrandLogo), findsOneWidget);
              expect(
                find.descendant(
                  of: find.byType(AgtiazBrandLogo),
                  matching: find.byType(ClipOval),
                ),
                findsOneWidget,
              );
              final logo = tester.widget<Image>(
                find.descendant(
                  of: find.byType(AgtiazBrandLogo),
                  matching: find.byType(Image),
                ),
              );
              expect(
                (logo.image as AssetImage).assetName,
                AgtiazBrandLogo.asset,
              );
              expect(tester.takeException(), isNull);
              if (size.width == 390 && language == 'ar') {
                await preview(
                  tester,
                  key,
                  '${login ? 'login' : 'language'}-${dark ? 'dark' : 'light'}',
                );
              }
              if (login) {
                expect(
                  tester
                      .widget<Text>(
                        find.byKey(const ValueKey('login-typed-welcome')),
                      )
                      .data,
                  AppLocalizations(
                    Locale(language),
                  ).translate('welcomeMessage'),
                );
                await tester.ensureVisible(
                  find.byKey(const ValueKey('login-submit')),
                );
                await tester.pumpAndSettle();
                expect(
                  tester
                      .getSize(find.byKey(const ValueKey('login-submit')))
                      .height,
                  greaterThanOrEqualTo(48),
                );
                await tester.tap(find.byKey(const ValueKey('login-submit')));
                await tester.pumpAndSettle();
                expect(
                  find.text(
                    AppLocalizations(
                      Locale(language),
                    ).translate('emailRequired'),
                  ),
                  findsOneWidget,
                );
                expect(destinations, isEmpty);
                expect(tester.takeException(), isNull);
              } else {
                expect(
                  tester
                      .getSize(find.byKey(const ValueKey('language-option-ar')))
                      .height,
                  greaterThanOrEqualTo(48),
                );
                expect(
                  tester
                      .getSize(find.byKey(const ValueKey('language-option-en')))
                      .height,
                  greaterThanOrEqualTo(48),
                );
              }
              await tester.pumpWidget(const SizedBox.shrink());
            },
          );
        }
      }
    }
  }

  for (final language in ['ar', 'en']) {
    testWidgets('language selection persists and navigates once $language', (
      tester,
    ) async {
      await start(tester, const LanguageSelectionScreen());
      await tester.ensureVisible(
        find.byKey(ValueKey('language-option-$language')),
      );
      final button = tester.widget<InkWell>(
        find.byKey(ValueKey('language-option-$language')),
      );
      button.onTap!();
      button.onTap!();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pumpAndSettle();
      expect(LocalizationService.locale.value.languageCode, language);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('language_code'), language);
      expect(prefs.getBool('has_selected_language'), isTrue);
      expect(destinations, [language == 'ar' ? '/splashAr' : '/splashEn']);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets(
    'login restores saved email, toggles password and preserves forgot/signup routes',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'remember_me': true,
        'saved_email': 'saved@example.com',
      });
      await start(tester, const LoginScreen(), language: 'en');
      expect(find.text('saved@example.com'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField).last).obscureText,
        isTrue,
      );
      await tester.ensureVisible(find.byIcon(Icons.visibility_outlined));
      await tester.tap(find.byIcon(Icons.visibility_outlined));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField).last).obscureText,
        isFalse,
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('login-forgot-password')),
      );
      await tester.tap(find.byKey(const ValueKey('login-forgot-password')));
      await tester.pumpAndSettle();
      expect(destinations, ['/forgotPassword']);
      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pumpAndSettle();
      final signup = find.widgetWithText(
        TextButton,
        AppLocalizations(const Locale('en')).translate('signup'),
      );
      await tester.ensureVisible(signup);
      await tester.tap(signup);
      await tester.pumpAndSettle();
      expect(destinations, ['/forgotPassword', '/signup']);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'login is scrollable with the keyboard visible and welcome does not move fields',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      tester.view.viewInsets = const FakeViewPadding(bottom: 320);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpWidget(host(const LoginScreen(), reducedMotion: false));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
      final before = tester.getTopLeft(find.byType(TextFormField).first);
      await tester.pump(const Duration(seconds: 3));
      expect(tester.getTopLeft(find.byType(TextFormField).first), before);
      await tester.ensureVisible(find.byKey(const ValueKey('login-submit')));
      await tester.pump();
      expect(
        find.byKey(const ValueKey('login-submit')).hitTestable(),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  for (final size in [const Size(390, 844), const Size(430, 932)]) {
    testWidgets('login keeps compact gaps and lowers its logo slightly $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      tester.view.padding = const FakeViewPadding(top: 30, bottom: 20);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPadding);
      await start(tester, const LoginScreen());
      final signup = find.byKey(const ValueKey('login-signup'));
      expect(signup.hitTestable(), findsOneWidget);
      final logo = find.byType(AgtiazBrandLogo);
      expect(tester.getTopLeft(logo).dy, closeTo(110, 0.1));
      final bottomGap = size.height - 20 - tester.getBottomLeft(signup).dy;
      expect(bottomGap, closeTo(24, 0.1));
      final fields = find.byType(TextFormField);
      final emailGroup = find
          .ancestor(of: fields.first, matching: find.byType(Column))
          .first;
      final passwordGroup = find
          .ancestor(of: fields.last, matching: find.byType(Column))
          .first;
      expect(
        tester.getTopLeft(passwordGroup).dy -
            tester.getBottomLeft(emailGroup).dy,
        closeTo(12, 0.1),
      );
      final rememberRow = find
          .ancestor(of: find.byType(Checkbox), matching: find.byType(Wrap))
          .first;
      final buttons = find
          .ancestor(
            of: find.byKey(const ValueKey('login-submit')),
            matching: find.byType(Row),
          )
          .first;
      expect(
        tester.getTopLeft(buttons).dy - tester.getBottomLeft(rememberRow).dy,
        closeTo(16, 0.1),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
