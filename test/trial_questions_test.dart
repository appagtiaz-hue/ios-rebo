import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:agtiaz/l10n/app_localizations.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:agtiaz/models/question.dart';
import 'package:agtiaz/screens/test_screen.dart';
import 'package:agtiaz/services/content_cache.dart';
import 'package:agtiaz/services/database_service.dart';
import 'package:agtiaz/services/test_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late http.Client original;
  dynamic data;
  bool offline = false;
  bool versioned = true;

  setUpAll(() async {
    if (Platform.isWindows) {
      final font = FontLoader('TrialPreview');
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
    SharedPreferences.setMockInitialValues({});
    directory = await Directory.systemTemp.createTemp('agtiaz-trial-');
    ContentCache.directoryForTesting = directory;
    original = ContentCache.client;
    data = [];
    offline = false;
    versioned = true;
    ContentCache.client = MockClient((request) async {
      if (request.url.path == '/api/content-version') {
        return http.Response('{}', 404);
      }
      if (offline) throw const SocketException('offline');
      return http.Response(
        jsonEncode({'success': true, 'data': data}),
        200,
        headers: {
          'content-type': 'application/json; charset=utf-8',
          if (versioned) 'x-content-version': '0',
        },
      );
    });
  });

  tearDown(() async {
    await ContentCache.checkForChanges(
      Uri.parse(TestConfig.serverUrl),
      force: true,
    );
    ContentCache.client.close();
    ContentCache.client = original;
    ContentCache.directoryForTesting = null;
    await directory.delete(recursive: true);
  });

  void expectPlayable(List<Question> questions) {
    expect(questions, hasLength(5));
    for (final question in questions) {
      expect(question.questionText.trim(), isNotEmpty);
      expect(question.options, hasLength(4));
      expect(
        question.options.every((option) => option.trim().isNotEmpty),
        isTrue,
      );
      expect(question.correctAnswerIndex, inInclusiveRange(0, 3));
      expect(question.answerJustification.trim(), isNotEmpty);
    }
  }

  test(
    'empty and cached empty responses retain five playable trial questions',
    () async {
      expectPlayable(await DatabaseService.getTrialQuestions());
      offline = true;
      expectPlayable(await DatabaseService.getTrialQuestions());
    },
  );

  test('first launch offline retains the built-in trial', () async {
    offline = true;
    expectPlayable(await DatabaseService.getTrialQuestions());
  });

  test(
    'blank or invalid remote questions do not render an empty trial',
    () async {
      data = [
        {
          'question_text': '',
          'options': ['A', 'B'],
          'correct_answer_index': 0,
        },
        {
          'question_text': 'Missing answers',
          'options': [],
          'correct_answer_index': 0,
        },
        {
          'question_text': 'Invalid answer',
          'options': ['A', 'B'],
          'correct_answer_index': 4,
        },
        {
          'question_text': 'Blank answer',
          'options': ['A', ' '],
          'correct_answer_index': 0,
        },
      ];
      expectPlayable(await DatabaseService.getTrialQuestions());
    },
  );

  test(
    'valid remote questions still override the built-in trial and remain cached',
    () async {
      data = [
        {
          'id': 'remote-trial',
          'question_text': 'Updated trial question',
          'options': ['A', 'B', 'C', 'D'],
          'correct_answer_index': 2,
          'answer_justification': 'Updated explanation',
        },
      ];
      final questions = await DatabaseService.getTrialQuestions();
      expect(questions, hasLength(1));
      expect(questions.single.id, 'remote-trial');
      expect(questions.single.correctAnswerIndex, 2);
      offline = true;
      expect(
        (await DatabaseService.getTrialQuestions()).single.id,
        'remote-trial',
      );
    },
  );

  testWidgets(
    'trial screen displays a question and four answers after empty response',
    (tester) async {
      await tester.pumpWidget(
        ScreenUtilInit(
          designSize: const Size(390, 844),
          builder: (_, __) => const MaterialApp(
            home: Directionality(
              textDirection: TextDirection.rtl,
              child: TestScreen(),
            ),
          ),
        ),
      );
      for (
        var attempt = 0;
        attempt < 100 && find.text('1/5').evaluate().isEmpty;
        attempt++
      ) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump();
      }
      await tester.pumpAndSettle();
      expect(find.text('1/5'), findsOneWidget);
      expect(find.text('لا توجد أسئلة متاحة'), findsNothing);
      expect(find.text('خطأ في تحميل الأسئلة'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      final questions = await tester.runAsync(
        DatabaseService.getTrialQuestions,
      );
      final visible = questions!.where(
        (q) => find.text(q.questionText).evaluate().isNotEmpty,
      );
      expect(visible, hasLength(1));
      for (final option in visible.single.options) {
        expect(find.text(option), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
      for (var index = 0; index < 5; index++) {
        final question = questions.firstWhere(
          (q) => find.text(q.questionText).evaluate().isNotEmpty,
        );
        final correctOption = question.options[question.correctAnswerIndex];
        final option = index == 0
            ? question.options.firstWhere((option) => option != correctOption)
            : correctOption;
        await tester.ensureVisible(find.text(option));
        await tester.tap(find.text(option));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('trial-primary')));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('trial-explanation')), findsOneWidget);
        expect(find.text(question.answerJustification), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('trial-primary')));
        await tester.pumpAndSettle();
      }
      expect(find.text('80%'), findsOneWidget);
      expect(find.textContaining('إجابتك:'), findsOneWidget);
      expect(
        find.text('هذه نتيجة تجربتك الحالية، ولا تُضاف إلى سجل نتائجي.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  Future<void> settleQuestions(WidgetTester tester) async {
    for (
      var attempt = 0;
      attempt < 100 && find.text('1/5').evaluate().isEmpty;
      attempt++
    ) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();
  }

  for (final language in ['ar', 'en']) {
    for (final dark in [false, true]) {
      for (final size in [
        const Size(320, 640),
        const Size(390, 844),
        const Size(844, 390),
      ]) {
        testWidgets('trial layout $language dark=$dark size=$size', (
          tester,
        ) async {
          tester.view.physicalSize = size;
          versioned = false;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final key = GlobalKey();
          await tester.pumpWidget(
            MaterialApp(
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
                fontFamily: Platform.isWindows ? 'TrialPreview' : null,
              ),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(size.width == 390 ? 1 : 1.8),
                  disableAnimations: true,
                ),
                child: child!,
              ),
              home: RepaintBoundary(key: key, child: const TestScreen()),
            ),
          );
          await settleQuestions(tester);
          expect(find.text('1/5'), findsOneWidget);
          expect(tester.takeException(), isNull);
          expect(
            tester.getSize(find.byKey(const ValueKey('trial-primary'))).height,
            greaterThanOrEqualTo(48),
          );
          expect(
            tester.getSize(find.byKey(const ValueKey('trial-option-0'))).height,
            greaterThanOrEqualTo(48),
          );
          if (const bool.fromEnvironment('GENERATE_TRIAL_PREVIEW') &&
              language == 'ar' &&
              size.width == 390) {
            await tester.runAsync(() async {
              final boundary =
                  key.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary;
              final image = await boundary.toImage(pixelRatio: 2);
              final bytes = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              final target = Directory('build/trial-preview');
              await target.create(recursive: true);
              await File(
                '${target.path}/trial-${dark ? 'dark' : 'light'}.png',
              ).writeAsBytes(bytes!.buffer.asUint8List());
              image.dispose();
            });
          }
          await tester.ensureVisible(
            find.byKey(const ValueKey('trial-option-0')),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const ValueKey('trial-option-0')));
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const ValueKey('trial-primary')));
          await tester.pumpAndSettle();
          expect(
            find.byKey(const ValueKey('trial-explanation')),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        });
      }
    }
  }
}
