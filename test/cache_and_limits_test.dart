import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:agtiaz/services/content_cache.dart';
import 'package:agtiaz/services/database_service.dart';
import 'package:agtiaz/services/otp_cooldown.dart';
import 'package:agtiaz/services/pull_refresh_limiter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('pull refresh allows two calls across a rolling minute', () {
    var now = DateTime(2026, 1, 1);
    final limiter = PullRefreshLimiter(now: () => now);
    expect(limiter.tryAcquire(), isTrue);
    now = now.add(const Duration(seconds: 1));
    expect(limiter.tryAcquire(), isTrue);
    expect(limiter.tryAcquire(), isFalse);
    now = now.add(const Duration(seconds: 58));
    expect(limiter.tryAcquire(), isFalse);
    now = now.add(const Duration(seconds: 1));
    expect(limiter.tryAcquire(), isTrue);
    expect(limiter.tryAcquire(), isFalse);
  });

  test(
    'first OTP resend waits one minute, survives reopening and never restarts an expired deadline',
    () async {
      SharedPreferences.setMockInitialValues({});
      expect(
        await OtpCooldown.remaining(
          'User@Example.com',
          'reset',
          startIfMissing: true,
        ),
        60,
      );
      expect(
        await OtpCooldown.remaining('user@example.com', 'reset'),
        inInclusiveRange(59, 60),
      );
      expect(await OtpCooldown.remaining('another@example.com', 'reset'), 0);
      expect(await OtpCooldown.remaining('user@example.com', 'signup'), 0);
      expect(
        await OtpCooldown.startAfterSend('user@example.com', 'reset', 0),
        60,
      );
      expect(
        await OtpCooldown.startAfterSend('user@example.com', 'reset', 20),
        60,
      );
      expect(
        await OtpCooldown.startAfterSend('user@example.com', 'reset', 120),
        120,
      );
      expect(
        await OtpCooldown.remaining('user@example.com', 'reset'),
        inInclusiveRange(119, 120),
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
        'otp_cooldown_reset_user@example.com',
        DateTime.now()
            .subtract(const Duration(seconds: 1))
            .millisecondsSinceEpoch,
      );
      expect(
        await OtpCooldown.remaining(
          'user@example.com',
          'reset',
          startIfMissing: true,
        ),
        0,
      );
    },
  );

  test(
    'catalog cache avoids data requests and rebuilds after a dashboard revision',
    () async {
      SharedPreferences.setMockInitialValues({});
      final directory = await Directory.systemTemp.createTemp(
        'agtiaz-cache-test-',
      );
      ContentCache.directoryForTesting = directory;
      var revision = 1;
      var loads = 0;
      final original = ContentCache.client;
      ContentCache.client = MockClient((request) async {
        if (request.url.path == '/api/content-version') {
          return http.Response(
            jsonEncode({'success': true, 'version': revision}),
            200,
          );
        }
        loads++;
        return http.Response(
          jsonEncode({
            'success': true,
            'data': ['plan-$revision'],
          }),
          200,
          headers: {'x-content-version': '$revision', 'etag': '"$revision"'},
        );
      });
      final uri = Uri.parse('https://catalog-test.example/api/plans');
      try {
        expect(
          (await ContentCache.get(uri, cacheFirst: true)).body,
          contains('plan-1'),
        );
        expect(
          (await ContentCache.get(uri, cacheFirst: true)).body,
          contains('plan-1'),
        );
        await ContentCache.checkForChanges(uri, force: true);
        expect(loads, 1);
        revision = 2;
        expect(await ContentCache.checkForChanges(uri, force: true), isTrue);
        expect(
          (await ContentCache.get(uri, cacheFirst: true)).body,
          contains('plan-2'),
        );
        expect(loads, 2);
      } finally {
        ContentCache.client.close();
        ContentCache.client = original;
        ContentCache.directoryForTesting = null;
        await directory.delete(recursive: true);
      }
    },
  );

  test(
    'question cache reuses a 304 but a revoked entitlement rejects the cached body',
    () async {
      SharedPreferences.setMockInitialValues({});
      final directory = await Directory.systemTemp.createTemp(
        'agtiaz-private-cache-test-',
      );
      ContentCache.directoryForTesting = directory;
      final original = ContentCache.client;
      var allowed = true;
      var loads = 0;
      ContentCache.client = MockClient((request) async {
        loads++;
        if (!allowed) return http.Response('{"success":false}', 403);
        if (request.headers['If-None-Match'] == '"questions-1"')
          return http.Response('', 304);
        return http.Response(
          '{"success":true,"data":["question"]}',
          200,
          headers: {'etag': '"questions-1"'},
        );
      });
      final uri = Uri.parse(
        'https://questions-test.example/api/questions/page/1/10?planId=p1',
      );
      try {
        final first = await ContentCache.get(uri);
        final second = await ContentCache.get(uri);
        expect(second.body, first.body);
        expect(second.statusCode, 200);
        expect(loads, 2);
        allowed = false;
        expect((await ContentCache.get(uri)).statusCode, 403);
      } finally {
        ContentCache.client.close();
        ContentCache.client = original;
        ContentCache.directoryForTesting = null;
        await directory.delete(recursive: true);
      }
    },
  );

  test(
    'cached questions are isolated by account and cleared on logout',
    () async {
      SharedPreferences.setMockInitialValues({});
      final directory = await Directory.systemTemp.createTemp(
        'agtiaz-account-cache-test-',
      );
      ContentCache.directoryForTesting = directory;
      final original = ContentCache.client;
      final validators = <String?>[];
      ContentCache.client = MockClient((request) async {
        validators.add(request.headers['If-None-Match']);
        final payload = request.headers['Authorization']!
            .split(' ')
            .last
            .split('.')[1];
        final user = jsonDecode(
          utf8.decode(base64Url.decode(base64Url.normalize(payload))),
        )['id'];
        return http.Response(
          jsonEncode({'success': true, 'data': user}),
          200,
          headers: {'etag': '"$user"'},
        );
      });
      Map<String, String> headers(String user) => {
        'Authorization':
            'Bearer header.${base64Url.encode(utf8.encode(jsonEncode({'id': user})))}.signature',
      };
      final uri = Uri.parse(
        'https://accounts-test.example/api/questions/page/1/10',
      );
      try {
        expect(
          (await ContentCache.get(uri, headers: headers('a'))).body,
          contains('"a"'),
        );
        expect(
          (await ContentCache.get(uri, headers: headers('b'))).body,
          contains('"b"'),
        );
        expect(validators, [null, null]);
        await ContentCache.clearPrivate(uri);
        await ContentCache.get(uri, headers: headers('a'));
        expect(validators.last, isNull);
      } finally {
        ContentCache.client.close();
        ContentCache.client = original;
        ContentCache.directoryForTesting = null;
        await directory.delete(recursive: true);
      }
    },
  );

  test(
    'a delayed old revision never repopulates an invalidated cache',
    () async {
      SharedPreferences.setMockInitialValues({});
      final directory = await Directory.systemTemp.createTemp(
        'agtiaz-revision-race-test-',
      );
      ContentCache.directoryForTesting = directory;
      final original = ContentCache.client;
      final oldResponse = Completer<http.Response>();
      final started = Completer<void>();
      var revision = 1;
      var loads = 0;
      ContentCache.client = MockClient((request) async {
        if (request.url.path == '/api/content-version') {
          return http.Response(
            jsonEncode({'success': true, 'version': revision}),
            200,
          );
        }
        loads++;
        if (loads == 2) {
          started.complete();
          return oldResponse.future;
        }
        return http.Response(
          jsonEncode({'success': true, 'data': 'revision-$revision'}),
          200,
          headers: {'x-content-version': '$revision', 'etag': '"$revision"'},
        );
      });
      final uri = Uri.parse('https://race-test.example/api/plans');
      try {
        await ContentCache.get(uri);
        final delayed = ContentCache.get(uri, forceFresh: true);
        await started.future;
        revision = 2;
        await ContentCache.checkForChanges(uri, force: true);
        oldResponse.complete(
          http.Response(
            '{"success":true,"data":"old-response"}',
            200,
            headers: {'x-content-version': '1', 'etag': '"1"'},
          ),
        );
        await delayed;
        final fresh = await ContentCache.get(uri, cacheFirst: true);
        expect(fresh.body, contains('revision-2'));
        expect(loads, 3);
      } finally {
        ContentCache.client.close();
        ContentCache.client = original;
        ContentCache.directoryForTesting = null;
        await directory.delete(recursive: true);
      }
    },
  );
  test(
    'segmented question order belongs to the current user and plan bank',
    () async {
      SharedPreferences.setMockInitialValues({});
      final directory = await Directory.systemTemp.createTemp(
        'agtiaz-fixed-bank-test-',
      );
      ContentCache.directoryForTesting = directory;
      final original = ContentCache.client;
      var currentUser = 'a';
      const channel = MethodChannel(
        'plugins.it_nomads.com/flutter_secure_storage',
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            channel,
            (call) async =>
                'header.${base64Url.encode(utf8.encode(jsonEncode({'id': currentUser})))}.signature',
          );
      ContentCache.client = MockClient((request) async {
        final plan = request.url.queryParameters['planId'];
        return http.Response(
          jsonEncode({
            'success': true,
            'data': List.generate(
              2,
              (i) => {
                'id': '$plan-$i',
                'question_text': 'question $plan $i',
                'options': ['a', 'b'],
                'correct_answer_index': 0,
                'category': 'test',
              },
            ),
          }),
          200,
        );
      });
      try {
        final first = await DatabaseService.getFixedPlanQuestions(
          userId: 'a',
          planId: 'p1',
          questionCount: 2,
        );
        final repeated = await DatabaseService.getFixedPlanQuestions(
          userId: 'a',
          planId: 'p1',
          questionCount: 2,
        );
        expect(
          repeated.map((q) => q.id).toList(),
          first.map((q) => q.id).toList(),
        );
        final otherPlan = await DatabaseService.getFixedPlanQuestions(
          userId: 'a',
          planId: 'p2',
          questionCount: 2,
        );
        expect(otherPlan.every((q) => q.id.startsWith('p2-')), isTrue);
        currentUser = 'b';
        await DatabaseService.getFixedPlanQuestions(
          userId: 'b',
          planId: 'p1',
          questionCount: 2,
        );
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.containsKey('fixed_plan_question_ids_a_p1'), isTrue);
        expect(prefs.containsKey('fixed_plan_question_ids_a_p2'), isTrue);
        expect(prefs.containsKey('fixed_plan_question_ids_b_p1'), isTrue);
      } finally {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
        ContentCache.client.close();
        ContentCache.client = original;
        ContentCache.directoryForTesting = null;
        await directory.delete(recursive: true);
      }
    },
  );

  test(
    'empty versioned trial content uses the built-in sample even when cached',
    () async {
      SharedPreferences.setMockInitialValues({});
      final directory = await Directory.systemTemp.createTemp(
        'agtiaz-trial-cache-test-',
      );
      ContentCache.directoryForTesting = directory;
      final original = ContentCache.client;
      ContentCache.client = MockClient((request) async {
        if (request.url.path == '/api/content-version')
          return http.Response('{}', 404);
        return http.Response(
          '{"success":true,"data":[]}',
          200,
          headers: {'x-content-version': '1'},
        );
      });
      try {
        expect(await DatabaseService.getTrialQuestions(), hasLength(5));
        expect(await DatabaseService.getTrialQuestions(), hasLength(5));
        await ContentCache.checkForChanges(
          Uri.parse('https://agtiaz.online'),
          force: true,
        );
      } finally {
        ContentCache.client.close();
        ContentCache.client = original;
        ContentCache.directoryForTesting = null;
        await directory.delete(recursive: true);
      }
    },
  );

  test('concurrent reads share one request', () async {
    SharedPreferences.setMockInitialValues({});
    final directory = await Directory.systemTemp.createTemp(
      'agtiaz-concurrent-cache-test-',
    );
    ContentCache.directoryForTesting = directory;
    final original = ContentCache.client;
    final response = Completer<http.Response>();
    var loads = 0;
    ContentCache.client = MockClient((request) {
      loads++;
      return response.future;
    });
    final uri = Uri.parse('https://concurrent-test.example/api/plans');
    try {
      final first = ContentCache.get(uri);
      final second = ContentCache.get(uri);
      await Future<void>.delayed(const Duration(milliseconds: 30));
      response.complete(http.Response('{"success":true,"data":[]}', 200));
      await Future.wait([first, second]);
      expect(loads, 1);
    } finally {
      ContentCache.client.close();
      ContentCache.client = original;
      ContentCache.directoryForTesting = null;
      await directory.delete(recursive: true);
    }
  });
}
