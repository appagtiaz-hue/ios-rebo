import 'dart:async';
import 'dart:convert';
import 'package:agtiaz/services/account_session_guard.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  String session(String email) =>
      'header.${base64Url.encode(utf8.encode(jsonEncode({'email': email})))}.signature';
  for (final status in [200, 401, 404, 410, 403, 500]) {
    test(
      'other-device session validation only erases on definitive rejection $status',
      () async {
        var erased = 0, revoked = 0;
        final guard = AccountSessionGuard(
          onRevoked: () {
            revoked++;
          },
          token: () async => session('dummy@example.invalid'),
          erase: () async {
            erased++;
          },
          client: MockClient((_) async => http.Response('{}', status)),
        );
        await guard.check();
        guard.dispose();
        final expected = [401, 404, 410].contains(status) ? 1 : 0;
        expect(erased, expected);
        expect(revoked, expected);
      },
    );
  }
  test(
    'late rejection of an old session cannot clear a newly signed-in account',
    () async {
      var erased = 0;
      var token = session('one@example.invalid');
      final response = Completer<http.Response>();
      final started = Completer<void>();
      final guard = AccountSessionGuard(
        onRevoked: () => fail('New account must remain signed in'),
        token: () async => token,
        erase: () async {
          erased++;
        },
        client: MockClient((_) {
          started.complete();
          return response.future;
        }),
      );
      final pending = guard.check();
      await started.future;
      token = session('two@example.invalid');
      response.complete(http.Response('{}', 401));
      await pending;
      guard.dispose();
      expect(erased, 0);
    },
  );
}
