import 'dart:async';
import 'dart:convert';
import 'package:agtiaz/models/payment_plan.dart';
import 'package:agtiaz/services/free_plan_usage_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const firstPlan = '111111111111111111111111';
  const secondPlan = '222222222222222222222222';
  PlanUsageSession? session;
  late MockClient client;
  late DateTime now;
  var calls = 0;
  var status = 200;
  var offline = false;
  final owners = <String>[];

  PaymentPlan plan(String id, {double price = 0, bool active = true}) =>
      PaymentPlan.fromJson({
        '_id': id,
        'name': 'Free',
        'price': price,
        'is_active': active,
      });

  FreePlanUsageService service({String baseUrl = 'https://test.invalid'}) =>
      FreePlanUsageService(
        client: client,
        baseUrl: baseUrl,
        session: () async => session,
        now: () => now,
      );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    session = const PlanUsageSession('alice', 'alice-token');
    now = DateTime(2026, 10, 15);
    calls = 0;
    status = 200;
    offline = false;
    owners.clear();
    client = MockClient((request) async {
      calls++;
      owners.add(request.headers['Authorization']!);
      expect(request.method, 'POST');
      expect(request.url.path, '/mobile/api/usage/free-plan-open');
      expect(jsonDecode(request.body).keys, ['planId']);
      if (offline) throw Exception('No connection');
      return http.Response(
        jsonEncode({'success': status == 200}),
        status,
        headers: status == 429 ? {'retry-after': '120'} : {},
      );
    });
  });

  test('only an actual active free plan with a session is recorded', () async {
    final tracker = service();
    await tracker.recordOpen(plan(firstPlan, price: 10));
    await tracker.recordOpen(plan(firstPlan, active: false));
    await tracker.recordOpen(plan('invalid'));
    session = null;
    await tracker.recordOpen(plan(firstPlan));
    expect(calls, 0);
  });

  test(
    'repeated opens and concurrent refreshes send once, including after restart',
    () async {
      final tracker = service();
      await Future.wait(
        List.generate(5, (_) => tracker.recordOpen(plan(firstPlan))),
      );
      await tracker.recordOpen(plan(firstPlan));
      await service().recordOpen(plan(firstPlan));
      expect(calls, 1);
    },
  );

  test(
    'accounts and server environments have independent acknowledgments',
    () async {
      final tracker = service();
      await tracker.recordOpen(plan(firstPlan));
      session = const PlanUsageSession('bob', 'bob-token');
      await tracker.recordOpen(plan(firstPlan));
      await service(
        baseUrl: 'https://other.invalid',
      ).recordOpen(plan(firstPlan));
      expect(calls, 3);
      expect(owners, [
        'Bearer alice-token',
        'Bearer bob-token',
        'Bearer bob-token',
      ]);
    },
  );

  test(
    'offline open persists and syncs after restart under its original account',
    () async {
      offline = true;
      await service().recordOpen(plan(firstPlan));
      expect(calls, 1);
      offline = false;
      session = const PlanUsageSession('bob', 'bob-token');
      await service().flushPending();
      expect(calls, 1);
      session = const PlanUsageSession('alice', 'new-token');
      await service().flushPending();
      expect(calls, 2);
      expect(owners.last, 'Bearer new-token');
      await service().flushPending();
      expect(calls, 2);
    },
  );

  test(
    'failure is non-fatal, uses backoff, and retries without marking success',
    () async {
      final tracker = service();
      status = 503;
      await tracker.recordOpen(plan(firstPlan));
      await tracker.recordOpen(plan(firstPlan));
      expect(calls, 1);
      status = 200;
      now = now.add(const Duration(minutes: 1));
      await tracker.flushPending();
      expect(calls, 2);
      await tracker.flushPending();
      expect(calls, 2);
    },
  );

  test('server rate-limit Retry-After is honored', () async {
    final tracker = service();
    status = 429;
    await tracker.recordOpen(plan(firstPlan));
    now = now.add(const Duration(minutes: 1));
    await tracker.flushPending();
    expect(calls, 1);
    now = now.add(const Duration(minutes: 1));
    status = 200;
    await tracker.flushPending();
    expect(calls, 2);
  });

  test('multiple pending plans remain durable and all sync later', () async {
    offline = true;
    final tracker = service();
    await Future.wait([
      tracker.recordOpen(plan(firstPlan)),
      tracker.recordOpen(plan(secondPlan)),
    ]);
    offline = false;
    await service().flushPending();
    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getKeys().where((key) => prefs.getString(key) == 'sent').length,
      2,
    );
  });

  test(
    'account switch during a flush never sends old pending opens as the new user',
    () async {
      final gate = Completer<http.Response>();
      client = MockClient((request) async {
        calls++;
        return gate.future;
      });
      final tracker = service();
      final work = tracker.recordOpen(plan(firstPlan));
      while (calls == 0) {
        await Future<void>.delayed(Duration.zero);
      }
      session = const PlanUsageSession('bob', 'bob-token');
      gate.complete(http.Response('{"success":true}', 200));
      await work;
      client = MockClient((request) async {
        calls++;
        return http.Response('{"success":true}', 200);
      });
      await service().recordOpen(plan(firstPlan));
      expect(calls, 2);
    },
  );
}
