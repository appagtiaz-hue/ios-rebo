import 'package:agtiaz/l10n/app_localizations.dart';
import 'package:agtiaz/models/professional_standard.dart';
import 'package:agtiaz/models/payment_plan.dart';
import 'package:agtiaz/screens/standards_screen.dart';
import 'package:agtiaz/screens/test_library_screen.dart';
import 'package:agtiaz/widgets/app_bottom_navigation.dart';
import 'package:agtiaz/widgets/standards_overview.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

Widget host(
  Widget child, {
  String language = 'ar',
  double scale = 1,
  Brightness brightness = Brightness.light,
}) {
  return MaterialApp(
    locale: Locale(language),
    supportedLocales: const [Locale('ar'), Locale('en')],
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    theme: ThemeData(brightness: brightness),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(scale), disableAnimations: true),
      child: child!,
    ),
    home: child,
  );
}

void main() {
  for (final domain in ProfessionalDomain.values) {
    testWidgets(
      'domain link scrolls to $domain while retaining all standards',
      (tester) async {
        tester.view.physicalSize = const Size(390, 600);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(host(StandardsScreen(initialDomain: domain)));
        await tester.pumpAndSettle();
        expect(
          find
              .text(
                AppLocalizations(const Locale('ar')).translate(domain.titleKey),
              )
              .hitTestable(),
          findsOneWidget,
        );
        for (final standard in professionalStandards) {
          expect(
            find.byKey(ValueKey('standard-${standard.id}')),
            findsOneWidget,
          );
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
  test(
    'standards match three domains and ten unique entries in both languages',
    () {
      expect(professionalStandards.length, 10);
      expect(professionalStandards.map((s) => s.id).toSet().length, 10);
      expect(
        ProfessionalDomain.values.map(
          (d) => professionalStandards.where((s) => s.domain == d).length,
        ),
        [3, 4, 3],
      );
      for (final language in ['ar', 'en']) {
        final text = AppLocalizations(Locale(language));
        for (final standard in professionalStandards) {
          for (final key in [
            standard.titleKey,
            standard.fullTitleKey,
            standard.descriptionKey,
          ]) {
            expect(text.translate(key), isNot(key));
            expect(text.translate(key).isNotEmpty, isTrue);
          }
        }
      }
    },
  );

  for (final language in ['ar', 'en']) {
    testWidgets(
      'standards expand inline, close, and remain readable $language',
      (tester) async {
        tester.view.physicalSize = const Size(320, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          host(
            const StandardsScreen(),
            language: language,
            scale: 1.6,
            brightness: Brightness.dark,
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('description-Values')), findsNothing);
        final first = find.byKey(const ValueKey('standard-Values'));
        await tester.tap(first);
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('description-Values')),
          findsOneWidget,
        );
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('standard-Development')),
          120,
          scrollable: find.byType(Scrollable),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('standard-Development')));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('description-Values')), findsNothing);
        expect(
          find.byKey(const ValueKey('description-Development')),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const ValueKey('standard-Development')));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('description-Development')),
          findsNothing,
        );
        final planning = find.byKey(const ValueKey('standard-Planning'));
        await tester.scrollUntilVisible(
          planning,
          180,
          scrollable: find.byType(Scrollable),
        );
        await tester.pumpAndSettle();
        await tester.tap(planning);
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('description-Planning')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'bottom navigation has four working compact destinations $language',
      (tester) async {
        tester.view.physicalSize = const Size(320, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final tapped = <int>[];
        await tester.pumpWidget(
          host(
            Scaffold(
              bottomNavigationBar: AppBottomNavigation(
                selectedIndex: 0,
                onSelect: tapped.add,
              ),
            ),
            language: language,
            scale: 1.8,
          ),
        );
        await tester.pumpAndSettle();
        final navigation = find.byType(AppBottomNavigation);
        expect(tester.getSize(navigation).height, 76);
        final surface = tester.widget<DecoratedBox>(
          find.byKey(const ValueKey('bottom-navigation-surface')),
        );
        expect((surface.decoration as BoxDecoration).border, isNotNull);
        final homeIcon = find.byKey(const ValueKey('destination-icon-0'));
        final examsIcon = find.byKey(const ValueKey('destination-icon-1'));
        expect(tester.getTopLeft(homeIcon).dy, tester.getTopLeft(examsIcon).dy);
        expect(tester.getSize(homeIcon), tester.getSize(examsIcon));
        final homePosition = tester.getCenter(homeIcon).dx;
        final examsPosition = tester.getCenter(examsIcon).dx;
        expect(
          language == 'ar'
              ? homePosition > examsPosition
              : homePosition < examsPosition,
          isTrue,
        );
        for (var i = 0; i < 4; i++) {
          final iconBackground = tester.widget<AnimatedContainer>(
            find.byKey(ValueKey('destination-icon-$i')),
          );
          expect(
            (iconBackground.decoration as BoxDecoration).color,
            isNot(Colors.black),
          );
          expect(iconBackground.duration, Duration.zero);
        }
        for (var i = 0; i < 4; i++) {
          final destination = find.byKey(ValueKey('destination-$i'));
          expect(tester.getSize(destination).height, greaterThanOrEqualTo(48));
          await tester.tap(destination);
        }
        expect(tapped, [0, 1, 2, 3]);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'standards circle is a map with equal slices and opens standards',
    (tester) async {
      var opened = 0;
      await tester.pumpWidget(
        host(
          Scaffold(
            body: Center(child: StandardsOverview(onExplore: () => opened++)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final chart = tester.widget<PieChart>(find.byType(PieChart));
      expect(chart.data.sections.length, 10);
      expect(
        chart.data.sections.every((s) => s.value == 1 && !s.showTitle),
        isTrue,
      );
      await tester.tap(find.byType(StandardsOverview));
      expect(opened, 1);
    },
  );

  testWidgets('exam library handles empty subscriptions and real actions', (
    tester,
  ) async {
    var trial = 0;
    var browse = 0;
    await tester.pumpWidget(
      host(
        TestLibraryScreen(
          subscriptions: const [],
          loading: false,
          onStartTrial: () => trial++,
          onOpenSubscription: (_) {},
          onBrowsePlans: () => browse++,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text(
        AppLocalizations(const Locale('ar')).translate('examLibraryEmpty'),
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('library-trial')));
    await tester.tap(find.byKey(const ValueKey('library-browse-plans')));
    expect(trial, 1);
    expect(browse, 1);
  });

  testWidgets(
    'exam library forwards selected subscription without fetching again',
    (tester) async {
      final plan = PaymentPlan(
        id: 'gold',
        name: 'ذهبية',
        nameEn: 'Gold',
        description: '',
        descriptionEn: '',
        questionCount: 60,
        price: 10,
        currency: 'SAR',
        isActive: true,
      );
      final subscriptions = [
        <String, dynamic>{
          'planId': 'gold',
          'planName': 'ذهبية',
          'questionCount': 60,
          'planObject': plan,
        },
        <String, dynamic>{
          'planId': 'extra',
          'planName': 'اختبار إضافي',
          'questionCount': 20,
        },
      ];
      final opened = <Map<String, dynamic>>[];
      await tester.pumpWidget(
        host(
          TestLibraryScreen(
            subscriptions: subscriptions,
            loading: false,
            onStartTrial: () {},
            onOpenSubscription: opened.add,
            onBrowsePlans: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (final subscription in subscriptions) {
        await tester.tap(
          find.byKey(ValueKey('library-plan-${subscription['planId']}')),
        );
      }
      expect(opened, subscriptions);
      expect(tester.takeException(), isNull);
    },
  );
}
