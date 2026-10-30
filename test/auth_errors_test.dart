import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:agtiaz/services/auth_api.dart';
import 'package:agtiaz/services/localization_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test(
    'signup and password recovery keep successful response fields without creating a session',
    () async {
      for (final operation in [
        'signup',
        'resend-signup-otp',
        'verify-signup-otp',
        'request-password-reset',
        'verify-reset-otp',
        'reset-password',
      ]) {
        final result = await AuthApi(
          baseUrl: 'https://dummy.invalid',
          saveToken: (_) async => fail('OTP operations do not create sessions'),
          client: MockClient(
            (_) async => http.Response(
              jsonEncode({
                'success': true,
                'message': 'dummy-private-internal-text',
                'retryAfterSeconds': '60',
                'data': {'id': 'dummy'},
              }),
              200,
            ),
          ),
        ).post(operation, {});
        expect(result['success'], true);
        expect(result['message'], isA<String>());
        expect(result['message'], isNot(contains('dummy-private')));
        expect(result['retryAfterSeconds'], 60);
        expect(result['user'], {'id': 'dummy'});
      }
    },
  );

  setUp(() => LocalizationService.locale.value = const Locale('ar'));
  tearDown(() => LocalizationService.locale.value = const Locale('ar'));

  for (final operation in [
    'login',
    'auth/google',
    'auth/apple',
    'signup',
    'verify-signup-otp',
    'verify-reset-otp',
    'reset-password',
    'resend-signup-otp',
    'request-password-reset',
  ]) {
    test(
      'safe structured failures across every auth operation: $operation',
      () async {
        for (final status in [
          400,
          401,
          403,
          408,
          404,
          409,
          410,
          413,
          422,
          423,
          429,
          500,
          502,
          503,
        ]) {
          final result = await AuthApi(
            baseUrl: 'https://dummy.invalid',
            saveToken: (_) async => fail('No session on failure'),
            client: MockClient(
              (_) async => http.Response(
                jsonEncode({
                  'success': false,
                  'error': [
                    {'msg': 'dummy-private-password'},
                  ],
                  'details': 'dummy-private-token',
                  'retryAfterSeconds': 63,
                }),
                status,
              ),
            ),
          ).post(operation, {}, session: true);
          expect(result['success'], false);
          expect(result['error'], isA<String>());
          expect(result['errorCode'], isA<String>());
          expect(result['error'], isNot(contains('dummy-private')));
          expect(result['error'], isNot(contains('Instance of')));
          if (status == 429 || status == 423) {
            expect(result['retryAfterSeconds'], 63);
            expect(result['error'], contains('63'));
          }
        }
      },
    );
  }

  test(
    'legacy conflict and rate limit responses remain actionable without new server codes',
    () {
      final conflict = AuthMessages.response(
        http.Response('{"success":false}', 409),
        operation: 'auth/apple',
      );
      expect(conflict['errorCode'], 'AUTH_PROVIDER_CONFLICT');
      expect(conflict['error'], contains('طريقة الدخول الأصلية'));
      final limited = AuthMessages.response(
        http.Response(
          '<html>proxy</html>',
          429,
          headers: {'retry-after': '90'},
        ),
        operation: 'login',
      );
      expect(limited['retryAfterSeconds'], 90);
      expect(limited['error'], contains('90'));
      expect(
        AuthMessages.response(
          http.Response('[]', 503),
          operation: 'auth/google',
        )['errorCode'],
        'AUTH_UNAVAILABLE',
      );
    },
  );

  test(
    'OTP limits are not confused with resend cooldown and retain exact delay',
    () {
      for (final code in ['OTP_ACCOUNT_WAIT', 'OTP_RESEND_WAIT']) {
        final result = AuthMessages.response(
          http.Response(
            jsonEncode({
              'success': false,
              'errorCode': code,
              'retryAfterSeconds': 17,
            }),
            429,
          ),
          operation: 'verify-reset-otp',
        );
        expect(result['errorCode'], code);
        expect(result['retryAfterSeconds'], 17);
      }
      final invalid = AuthMessages.response(
        http.Response('{"errorCode":"OTP_INVALID"}', 400),
        operation: 'reset-password',
      );
      expect(invalid['errorCode'], 'OTP_INVALID');
      expect(invalid['error'], contains('آخر رمز'));
    },
  );

  test(
    'malformed response and malformed success cannot save a session or expose response text',
    () async {
      for (final payload in [
        'not json',
        '[]',
        'null',
        '{"success":true}',
        '{"success":true,"token":"dummy","data":{}}',
        '{"success":true,"token":42,"data":{"id":"dummy","email":"a@example.invalid"}}',
      ]) {
        final result = await AuthApi(
          baseUrl: 'https://dummy.invalid',
          saveToken: (_) async =>
              fail('Invalid response must not save a session'),
          client: MockClient((_) async => http.Response(payload, 200)),
        ).post('login', {}, session: true);
        expect(result['errorCode'], 'AUTH_RESPONSE_INVALID');
      }
    },
  );

  test(
    'network, timeout, cancellation and device-storage failures are distinct',
    () async {
      expect(
        AuthMessages.exception(
          const SocketException('dummy-secret'),
        )['errorCode'],
        'AUTH_NETWORK',
      );
      expect(
        AuthMessages.exception(
          http.ClientException('dummy-secret'),
        )['errorCode'],
        'AUTH_NETWORK',
      );
      expect(
        AuthMessages.exception(TimeoutException('dummy-secret'))['errorCode'],
        'AUTH_TIMEOUT',
      );
      expect(
        AuthMessages.exception(
          const FormatException('dummy-secret'),
        )['errorCode'],
        'AUTH_RESPONSE_INVALID',
      );
      expect(
        AuthMessages.exception(
          PlatformException(code: 'sign_in_canceled'),
        )['cancelled'],
        true,
      );
      expect(
        AuthMessages.exception(
          PlatformException(code: 'network_error'),
        )['errorCode'],
        'AUTH_NETWORK',
      );
      final timed = await AuthApi(
        baseUrl: 'https://dummy.invalid',
        saveToken: (_) async {},
        timeout: const Duration(milliseconds: 1),
        client: MockClient((_) async {
          await Future<void>.delayed(const Duration(milliseconds: 30));
          return http.Response('{}', 200);
        }),
      ).post('login', {});
      expect(timed['errorCode'], 'AUTH_TIMEOUT');
      final storage = await AuthApi(
        baseUrl: 'https://dummy.invalid',
        saveToken: (_) async =>
            throw PlatformException(code: 'dummy-storage-secret'),
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'success': true,
              'token': 'dummy-session',
              'data': {'id': 'dummy', 'email': 'dummy@example.invalid'},
            }),
            200,
          ),
        ),
      ).post('login', {}, session: true);
      expect(storage['errorCode'], 'AUTH_SESSION_FAILED');
      expect(storage['error'], isNot(contains('dummy-storage')));
    },
  );

  test(
    'Google cancellation, missing token and native errors never send a login request',
    () async {
      final api = AuthApi(
        baseUrl: 'https://dummy.invalid',
        saveToken: (_) async {},
        client: MockClient(
          (_) async => fail('No request before native authorization'),
        ),
      );
      expect((await api.google(() async => null))['cancelled'], true);
      expect(
        (await api.google(() async => ''))['errorCode'],
        'AUTH_GOOGLE_RETRY',
      );
      expect(
        (await api.google(
          () async => throw PlatformException(code: 'network_error'),
        ))['errorCode'],
        'AUTH_NETWORK',
      );
      expect(
        (await api.google(
          () async => throw PlatformException(
            code: 'sign_in_failed',
            message: 'dummy-private',
          ),
        ))['errorCode'],
        'AUTH_GOOGLE_RETRY',
      );
    },
  );

  test(
    'successful login saves only a valid session and returns compatible user fields',
    () async {
      String? token;
      final user = {
        'id': 'dummy',
        'email': 'dummy@example.invalid',
        'name': 'Dummy',
      };
      final result = await AuthApi(
        baseUrl: 'https://dummy.invalid',
        saveToken: (value) async => token = value,
        client: MockClient((request) async {
          expect(request.url.path, '/mobile/api/users/auth/google');
          expect(jsonDecode(request.body)['idToken'], 'dummy-id-token');
          return http.Response(
            jsonEncode({
              'success': true,
              'token': 'dummy-session',
              'data': user,
            }),
            200,
          );
        }),
      ).google(() async => 'dummy-id-token');
      expect(result['success'], true);
      expect(result['user'], user);
      expect(token, 'dummy-session');
    },
  );

  test(
    'invalid retry metadata never crashes or extends local wait without a positive duration',
    () {
      for (final value in ['invalid', -1, 0, null, []]) {
        final result = AuthMessages.response(
          http.Response(
            jsonEncode({
              'errorCode': 'AUTH_RATE_LIMITED',
              'retryAfterSeconds': value,
            }),
            429,
            headers: {'retry-after': 'not-a-date'},
          ),
          operation: 'login',
        );
        expect(result['retryAfterSeconds'], null);
      }
      final huge = AuthMessages.response(
        http.Response('{"retryAfterSeconds":999999999}', 429),
        operation: 'login',
      );
      expect(huge['retryAfterSeconds'], 86400);
      final validHeader = AuthMessages.response(
        http.Response(
          '{"retryAfterSeconds":-1}',
          429,
          headers: {'retry-after': '90'},
        ),
        operation: 'login',
      );
      expect(validHeader['retryAfterSeconds'], 90);
    },
  );

  test(
    'Arabic and English copy never renders raw backend text or exception names',
    () {
      for (final language in ['ar', 'en']) {
        LocalizationService.locale.value = Locale(language);
        final result = AuthMessages.response(
          http.Response('{"error":"dummy-private","details":"E11000"}', 401),
          operation: 'login',
        );
        expect(result['error'], isNot(contains('dummy-private')));
        expect(result['error'], isNot(contains('E11000')));
        expect(
          result['error'],
          contains(language == 'ar' ? 'كلمة المرور' : 'password'),
        );
      }
    },
  );
}
