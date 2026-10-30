import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:agtiaz/l10n/app_localizations.dart';
import 'package:agtiaz/screens/login_screen.dart';
import 'package:agtiaz/services/apple_sign_in_service.dart';
import 'package:agtiaz/widgets/agtiaz_brand_logo.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final id = 'a' * 64;
  final nonce = 'b' * 64;
  AuthorizationCredentialAppleID credential(String state) =>
      AuthorizationCredentialAppleID(
        userIdentifier: 'dummy-subject',
        givenName: null,
        familyName: null,
        email: null,
        identityToken: 'dummy-identity',
        authorizationCode: 'dummy-code',
        state: state,
      );

  test(
    'Apple flow passes server nonce/state, supports returning private-email user and saves only verified session',
    () async {
      var requests = 0;
      String? saved;
      final client = MockClient((request) async {
        requests++;
        expect(request.url.query, isEmpty);
        if (request.url.path.endsWith('/challenge')) {
          return http.Response(
            jsonEncode({'success': true, 'challengeId': id, 'nonce': nonce}),
            200,
          );
        }
        final body = jsonDecode(request.body);
        expect(body['challengeId'], id);
        expect(body['authorizationCode'], 'dummy-code');
        expect(body['identityToken'], 'dummy-identity');
        expect(body.containsKey('email'), false);
        expect(body.containsKey('name'), false);
        return http.Response(
          jsonEncode({
            'success': true,
            'token': 'dummy-session',
            'data': {
              'id': 'dummy-id',
              'name': 'Dummy',
              'email': 'dummy@privaterelay.appleid.com',
            },
          }),
          200,
        );
      });
      final result = await AppleSignInService(
        baseUrl: 'https://dummy.invalid',
        client: client,
        saveToken: (token) async => saved = token,
        authorize: (receivedNonce, state) async {
          expect(receivedNonce, nonce);
          expect(state, id);
          expect(saved, isNull);
          return credential(state);
        },
      ).signIn();
      expect(result['success'], true);
      expect(saved, 'dummy-session');
      expect(requests, 2);
    },
  );

  test(
    'Apple cancellation does not submit credentials or alter the saved session',
    () async {
      var requests = 0;
      final result = await AppleSignInService(
        baseUrl: 'https://dummy.invalid',
        client: MockClient((_) async {
          requests++;
          return http.Response(
            jsonEncode({'success': true, 'challengeId': id, 'nonce': nonce}),
            200,
          );
        }),
        saveToken: (_) async => fail('Cancellation must not replace session'),
        authorize: (_, _) async =>
            throw const SignInWithAppleAuthorizationException(
              code: AuthorizationErrorCode.canceled,
              message: 'dummy-cancel',
            ),
      ).signIn();
      expect(result['cancelled'], true);
      expect(requests, 1);
    },
  );

  test(
    'unavailable challenge, state mismatch, server errors and malformed success never save a session',
    () async {
      for (final scenario in [
        'unavailable',
        'state',
        'conflict',
        'invalid-json',
        'missing-session',
      ]) {
        var requests = 0;
        final result = await AppleSignInService(
          baseUrl: 'https://dummy.invalid',
          client: MockClient((request) async {
            requests++;
            if (request.url.path.endsWith('/challenge')) {
              return http.Response(
                jsonEncode({
                  'success': scenario != 'unavailable',
                  'challengeId': id,
                  'nonce': nonce,
                }),
                scenario == 'unavailable' ? 503 : 200,
              );
            }
            if (scenario == 'invalid-json') {
              return http.Response('not json', 500);
            }
            if (scenario == 'conflict') {
              return http.Response(
                jsonEncode({'success': false, 'error': 'dummy-conflict'}),
                409,
              );
            }
            return http.Response(
              jsonEncode({'success': true, 'data': {}}),
              200,
            );
          }),
          saveToken: (_) async => fail('Unverified session must not be saved'),
          authorize: (_, state) async =>
              credential(scenario == 'state' ? 'wrong-state' : state),
        ).signIn();
        expect(result['success'], false, reason: scenario);
        expect(requests, ['unavailable', 'state'].contains(scenario) ? 1 : 2);
      }
    },
  );

  setUpAll(() async {
    if (Platform.isWindows) {
      final font = FontLoader('ApplePreview');
      font.addFont(
        Future.value(
          ByteData.sublistView(
            await File('C:/Windows/Fonts/arial.ttf').readAsBytes(),
          ),
        ),
      );
      await font.load();
      final systemFont = FontLoader('.SF Pro Text');
      systemFont.addFont(
        Future.value(
          ByteData.sublistView(
            await File('C:/Windows/Fonts/arial.ttf').readAsBytes(),
          ),
        ),
      );
      await systemFont.load();
    }
    final icons = FontLoader('MaterialIcons');
    icons.addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });

  for (final language in ['ar', 'en']) {
    for (final size in [
      const Size(320, 700),
      const Size(390, 844),
      const Size(820, 1180),
    ]) {
      testWidgets(
        'iOS Apple login layout $language ${size.width}',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          SharedPreferences.setMockInitialValues({});
          final boundary = GlobalKey();
          await tester.pumpWidget(
            MaterialApp(
              locale: Locale(language),
              supportedLocales: const [Locale('ar'), Locale('en')],
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              theme: ThemeData(
                brightness: Brightness.dark,
                fontFamily: Platform.isWindows ? 'ApplePreview' : null,
              ),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(disableAnimations: true),
                child: child!,
              ),
              home: RepaintBoundary(key: boundary, child: const LoginScreen()),
            ),
          );
          await tester.pumpAndSettle();
          await tester.runAsync(() async {
            final context = tester.element(find.byType(AgtiazBrandLogo));
            await precacheImage(
              const AssetImage(AgtiazBrandLogo.asset),
              context,
            );
            await precacheImage(
              const AssetImage('assets/images/google_logo.png'),
              context,
            );
          });
          await tester.pumpAndSettle();
          final apple = find.byKey(const ValueKey('login-apple'));
          expect(apple, findsOneWidget);
          expect(find.byKey(const ValueKey('login-google')), findsOneWidget);
          await tester.ensureVisible(apple);
          await tester.pumpAndSettle();
          expect(tester.getSize(apple).height, 48);
          expect(tester.getRect(apple).left, greaterThanOrEqualTo(0));
          expect(tester.getRect(apple).right, lessThanOrEqualTo(size.width));
          final label = find.descendant(of: apple, matching: find.byType(Text));
          expect(
            tester.getRect(label).top,
            greaterThanOrEqualTo(tester.getRect(apple).top),
          );
          expect(
            tester.getRect(label).bottom,
            lessThanOrEqualTo(tester.getRect(apple).bottom),
          );
          expect(tester.takeException(), isNull);
          if (const bool.fromEnvironment('APPLE_LOGIN_SCREENSHOTS')) {
            await tester.runAsync(() async {
              final render =
                  boundary.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary;
              final image = await render.toImage(pixelRatio: 1);
              final bytes = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              final directory = Directory('../.apple-signin-review');
              await directory.create(recursive: true);
              await File(
                '${directory.path}/login-$language-${size.width.toInt()}.png',
              ).writeAsBytes(bytes!.buffer.asUint8List());
              image.dispose();
            });
          }
        },
        variant: TargetPlatformVariant.only(TargetPlatform.iOS),
      );
    }
  }

  testWidgets(
    'Android login remains unchanged without an Apple button',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byKey(const ValueKey('login-apple')), findsNothing);
      expect(find.byKey(const ValueKey('login-google')), findsOneWidget);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );
}
