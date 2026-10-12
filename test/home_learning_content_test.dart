import 'dart:io';
import 'dart:ui' as ui;
import 'package:agtiaz/l10n/app_localizations.dart';
import 'package:agtiaz/models/home_practice_state.dart';
import 'package:agtiaz/models/payment_plan.dart';
import 'package:agtiaz/models/professional_standard.dart';
import 'package:agtiaz/theme/home_palette.dart';
import 'package:agtiaz/widgets/home_greeting_header.dart';
import 'package:agtiaz/widgets/home_learning_content.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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

  Widget host({
    required String language,
    required Brightness brightness,
    double scale = 1,
    required Widget child,
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
      brightness: brightness,
      fontFamily: Platform.isWindows ? 'HomePreview' : null,
    ),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(scale), disableAnimations: true),
      child: child!,
    ),
    home: Builder(
      builder: (context) => RepaintBoundary(
        key: previewKey,
        child: Scaffold(
          backgroundColor: HomePalette.of(context).background,
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: child,
              ),
            ),
          ),
        ),
      ),
    ),
  );

  HomeLearningContent content(
    bool premium,
    List<String> events, {
    HomePracticeMode mode = HomePracticeMode.browsePlans,
    String? name,
  }) => HomeLearningContent(
    premium: premium,
    practiceMode: mode,
    planName: name,
    onStartTrial: () => events.add('trial'),
    onShowProgress: () => events.add('results'),
    onSelectPremium: () => events.add('premium'),
    onBrowsePlans: () => events.add('plans'),
    onContinuePractice: () => events.add('continue'),
    onExploreStandards: () => events.add('all'),
    onOpenDomain: (domain) => events.add(domain.name),
  );

  for (final language in ['ar', 'en']) {
    for (final brightness in Brightness.values) {
      for (final size in const [
        Size(320, 844),
        Size(390, 844),
        Size(600, 844),
        Size(844, 390),
      ]) {
        for (final premium in [false, true]) {
          testWidgets(
            'content fits $language $brightness $size premium=$premium',
            (tester) async {
              tester.view.physicalSize = size;
              tester.view.devicePixelRatio = 1;
              addTearDown(tester.view.resetPhysicalSize);
              addTearDown(tester.view.resetDevicePixelRatio);
              final events = <String>[];
              await tester.pumpWidget(
                host(
                  language: language,
                  brightness: brightness,
                  scale: 1.6,
                  child: content(premium, events),
                ),
              );
              await tester.pumpAndSettle();
              final actions = premium
                  ? [
                      'home-browse-plans',
                      'home-explore-standards',
                      ...ProfessionalDomain.values.map(
                        (d) => 'home-domain-${d.name}',
                      ),
                    ]
                  : [
                      'home-start-trial',
                      'home-show-progress',
                      'home-select-premium',
                    ];
              for (final key in actions) {
                final action = find.byKey(ValueKey(key));
                await tester.ensureVisible(action);
                await tester.pumpAndSettle();
                expect(tester.getSize(action).height, greaterThanOrEqualTo(48));
                await tester.tap(action);
              }
              expect(
                events,
                premium
                    ? ['plans', 'all', 'ethics', 'knowledge', 'practice']
                    : ['trial', 'results', 'premium'],
              );
              expect(tester.takeException(), isNull);
              expect(find.byType(FloatingActionButton), findsNothing);
              await tester.pumpWidget(const SizedBox.shrink());
            },
          );
        }
      }
    }
  }

  for (final mode in HomePracticeMode.values) {
    testWidgets('premium action state $mode', (tester) async {
      final events = <String>[];
      await tester.pumpWidget(
        host(
          language: 'ar',
          brightness: Brightness.dark,
          child: content(
            true,
            events,
            mode: mode,
            name: 'خطة تدريب طويلة للرخصة المهنية',
          ),
        ),
      );
      await tester.pumpAndSettle();
      if (mode == HomePracticeMode.browsePlans) {
        expect(find.text('استعد لاختبار الرخصة المهنية'), findsOneWidget);
      }
      final primary = mode == HomePracticeMode.browsePlans
          ? 'home-browse-plans'
          : 'home-continue-training';
      final button = find.byKey(ValueKey(primary));
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();
      expect(
        tester.widget<FilledButton>(button).onPressed == null,
        mode == HomePracticeMode.loading,
      );
      if (mode != HomePracticeMode.loading) await tester.tap(button);
      expect(
        events,
        mode == HomePracticeMode.loading
            ? []
            : [mode == HomePracticeMode.browsePlans ? 'plans' : 'continue'],
      );
      if (mode != HomePracticeMode.browsePlans) {
        final browse = find.byKey(const ValueKey('home-browse-plans'));
        await tester.ensureVisible(browse);
        await tester.tap(browse);
        expect(events.last, 'plans');
      }
      expect(tester.takeException(), isNull);
    });
  }

  test(
    'one subscription opens directly and multiple subscriptions always require a choice',
    () {
      Map<String, dynamic> sub(
        String id, {
        bool main = false,
        bool selected = false,
      }) => {'planId': id, 'isMain': main, 'isCurrentlyActive': selected};
      HomePracticeState select(
        List<Map<String, dynamic>> subs, {
        bool loading = false,
      }) => HomePracticeState.fromSubscriptions(
        loading: loading,
        subscriptions: subs,
      );
      expect(select([], loading: true).mode, HomePracticeMode.loading);
      expect(select([]).mode, HomePracticeMode.browsePlans);
      expect(select([sub('single')]).subscription?['planId'], 'single');
      expect(
        select([sub('main', main: true), sub('chosen', selected: true)]).mode,
        HomePracticeMode.choosePlan,
      );
      expect(
        select([sub('extra'), sub('main', main: true)]).mode,
        HomePracticeMode.choosePlan,
      );
      expect(select([sub('a'), sub('b')]).mode, HomePracticeMode.choosePlan);
      expect(
        select([sub('a', selected: true), sub('b', selected: true)]).mode,
        HomePracticeMode.choosePlan,
      );
      expect(
        select([
          {'planId': ''},
        ]).mode,
        HomePracticeMode.browsePlans,
      );
      final inactive = PaymentPlan(
        id: 'inactive',
        name: '',
        nameEn: '',
        description: '',
        descriptionEn: '',
        questionCount: 10,
        price: 10,
        currency: 'SAR',
        isActive: false,
      );
      expect(
        select([
          {'planId': 'inactive', 'planObject': inactive},
        ]).mode,
        HomePracticeMode.browsePlans,
      );
    },
  );

  for (final language in ['ar', 'en']) {
    for (final count in <int?>[null, 0, 3]) {
      testWidgets(
        'greeting reflects recorded activity $language count=$count',
        (tester) async {
          tester.view.physicalSize = const Size(320, 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final name = language == 'ar'
              ? 'مستخدم باسم طويل لاختبار تنسيق الواجهة الجديدة'
              : 'A learner with a deliberately long name';
          await tester.pumpWidget(
            host(
              language: language,
              brightness: Brightness.light,
              scale: 1.6,
              child: HomeGreetingHeader(name: name, completedTests: count),
            ),
          );
          await tester.pumpAndSettle();
          final text = AppLocalizations(Locale(language));
          expect(
            find.text(
              text.translate('homeGreeting').replaceAll('{name}', name),
            ),
            findsOneWidget,
          );
          expect(
            find.text(
              text.translate(
                count == null
                    ? 'homeGreetingNeutral'
                    : count > 0
                    ? 'homeGreetingReturning'
                    : 'homeGreetingNew',
              ),
            ),
            findsOneWidget,
          );
          expect(find.byType(IconButton), findsNothing);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets(
    'missing names use fallback and palette text meets contrast requirements',
    (tester) async {
      for (final brightness in Brightness.values) {
        late HomePalette palette;
        await tester.pumpWidget(
          host(
            language: 'ar',
            brightness: brightness,
            child: Builder(
              builder: (context) {
                palette = HomePalette.of(context);
                return const HomeGreetingHeader(name: '  ');
              },
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('أهلاً بك'), findsOneWidget);
        double contrast(Color a, Color b) {
          final first = a.computeLuminance(), second = b.computeLuminance();
          return ((first > second ? first : second) + .05) /
              ((first > second ? second : first) + .05);
        }

        for (final pair in [
          (palette.ink, palette.background),
          (palette.secondary, palette.panel),
          (palette.buttonInk, palette.button),
          (palette.gold, palette.goldSoft),
        ]) {
          expect(contrast(pair.$1, pair.$2), greaterThanOrEqualTo(4.5));
        }
      }
    },
  );

  if (const bool.fromEnvironment('GENERATE_HOME_PREVIEW')) {
    for (final brightness in Brightness.values) {
      for (final premium in [false, true]) {
        testWidgets('render redesign $brightness premium=$premium', (
          tester,
        ) async {
          tester.view.physicalSize = const Size(390, 1100);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final key = GlobalKey();
          await tester.pumpWidget(
            host(
              language: 'ar',
              brightness: brightness,
              previewKey: key,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const HomeGreetingHeader(name: 'بودة', completedTests: 2),
                  const SizedBox(height: 24),
                  content(premium, []),
                ],
              ),
            ),
          );
          await tester.pumpAndSettle();
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
              'build/home-preview/redesign-${brightness.name}-${premium ? 'premium' : 'free'}.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        });
      }
    }
  }
}
