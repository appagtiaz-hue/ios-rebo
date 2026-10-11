import 'dart:convert';
import 'dart:io';
import 'package:agtiaz/l10n/app_localizations.dart';
import 'package:agtiaz/models/payment_plan.dart';
import 'package:agtiaz/models/user.dart';
import 'package:agtiaz/screens/exam_list_screen.dart';
import 'package:agtiaz/services/content_cache.dart';
import 'package:agtiaz/services/database_service.dart';
import 'package:flutter/material.dart';
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
  final plan = PaymentPlan(
    id: 'reload-control-test',
    name: 'Test plan',
    nameEn: 'Test plan',
    description: '',
    descriptionEn: '',
    questionCount: 100,
    price: 0,
    currency: 'SAR',
    isActive: true,
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    const secureStorage = MethodChannel(
      'plugins.it_nomads.com/flutter_secure_storage',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorage, (_) async => null);
    await DatabaseService.setCurrentUser(
      User(
        id: 'exam-controls-user',
        fullName: 'Test user',
        email: 'test@example.com',
        password: '',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    );
    originalClient = ContentCache.client;
    directory = await Directory.systemTemp.createTemp('agtiaz-exam-controls-');
    ContentCache.directoryForTesting = directory;
    ContentCache.client = MockClient(
      (request) async => http.Response(
        jsonEncode({
          'success': true,
          'data': request.url.path == '/api/plans' ? [plan.toJson()] : [],
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      ),
    );
  });

  tearDown(() async {
    ContentCache.client.close();
    ContentCache.client = originalClient;
    ContentCache.directoryForTesting = null;
    await directory.delete(recursive: true);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          null,
        );
  });

  for (final language in ['ar', 'en']) {
    testWidgets(
      'segmented exams have no reload button and retain navigation $language',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          ScreenUtilInit(
            designSize: const Size(390, 844),
            builder: (_, _) => MaterialApp(
              locale: Locale(language),
              supportedLocales: const [Locale('ar'), Locale('en')],
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              home: Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => ExamListScreen(
                          planId: plan.id,
                          planName: plan.name,
                          totalQuestions: plan.questionCount,
                          plan: plan,
                        ),
                      ),
                    ),
                    child: const Text('open-plan'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.runAsync(() async {
          await tester.tap(find.text('open-plan'));
          await tester.pump();
          await Future<void>.delayed(const Duration(milliseconds: 150));
        });
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.refresh), findsNothing);
        expect(tester.widget<AppBar>(find.byType(AppBar)).actions, isNull);
        expect(
          find.text(
            language == 'en'
                ? 'Divided Tests'
                : AppLocalizations(Locale(language)).translate('dividedTests'),
          ),
          findsOneWidget,
        );
        expect(
          tester
              .widget<GridView>(find.byType(GridView))
              .childrenDelegate
              .estimatedChildCount,
          2,
        );
        expect(tester.takeException(), isNull);
        await tester.tap(find.byIcon(Icons.arrow_back));
        await tester.pumpAndSettle();
        expect(find.text('open-plan'), findsOneWidget);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
