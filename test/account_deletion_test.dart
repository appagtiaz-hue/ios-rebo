import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:agtiaz/l10n/app_localizations.dart';
import 'package:agtiaz/screens/account_deletion_screen.dart';
import 'package:agtiaz/services/account_deletion_service.dart';
import 'package:agtiaz/services/account_deletion_state.dart';
import 'package:agtiaz/services/account_erasure.dart';
import 'package:agtiaz/services/content_cache.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeDeletion implements AccountDeletionGateway {
  int authorized = 0, deleted = 0;
  bool pending = false;
  DeletionOutcome outcome = DeletionOutcome.deleted;
  @override
  Future<bool> hasPending() async => pending;
  @override
  Future<Map<String, dynamic>> options() async => {
    'methods': ['password'],
    'backupRetentionDays': 7,
  };
  @override
  Future<String?> authorize(String method, String password) async {
    authorized++;
    return 'dummy-ticket';
  }

  @override
  Future<DeletionOutcome> delete(String authorizationId) async {
    deleted++;
    return outcome;
  }

  @override
  Future<DeletionOutcome> recover() async => outcome;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final previewKey = GlobalKey();
  setUpAll(() async {
    if (Platform.isWindows) {
      final font = FontLoader('DeletionPreview');
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
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
  });
  http.Response response(Map<String, dynamic> body) =>
      http.Response(jsonEncode({'success': true, ...body}), 200);
  test(
    'fresh authorization cancellation sends no identity proof or deletion',
    () async {
      var calls = 0;
      final service = AccountDeletionService(
        token: () async => 'dummy-jwt',
        pending: () async => null,
        providerProof: (_, _, _) async => null,
        client: MockClient((request) async {
          calls++;
          return response({'challengeId': 'dummy', 'nonce': 'nonce'});
        }),
      );
      expect(await service.authorize('google', ''), isNull);
      expect(calls, 1);
    },
  );
  test(
    'receipt persists before request, duplicate taps share one deletion and cleanup',
    () async {
      Map<String, dynamic>? pending;
      var deleted = 0, erased = 0, cleared = 0;
      final release = Completer<void>();
      final service = AccountDeletionService(
        token: () async => 'dummy-jwt',
        pending: () async => pending,
        savePending: (value) async => pending = value,
        clearPending: () async {
          cleared++;
          pending = null;
        },
        erase: () async {
          erased++;
        },
        client: MockClient((request) async {
          deleted++;
          expect(pending, isNotNull);
          expect(request.url.query, isEmpty);
          final body = jsonDecode(request.body);
          expect(body['confirmation'], 'DELETE');
          expect(body['receipt'], matches(RegExp(r'^[a-f0-9]{64}$')));
          expect(body.containsKey('password'), false);
          await release.future;
          return response({'deleted': true});
        }),
      );
      final first = service.delete('dummy-ticket');
      final second = service.delete('dummy-ticket');
      release.complete();
      expect(await first, DeletionOutcome.deleted);
      expect(await second, DeletionOutcome.deleted);
      expect(deleted, 1);
      expect(erased, 1);
      expect(cleared, 1);
    },
  );
  for (final confirmed in [true, false]) {
    test(
      'lost deletion response recovers confirmed server outcome $confirmed',
      () async {
        Map<String, dynamic>? pending;
        var erased = 0;
        final service = AccountDeletionService(
          token: () async => 'dummy-jwt',
          pending: () async => pending,
          savePending: (value) async => pending = value,
          clearPending: () async => pending = null,
          erase: () async {
            erased++;
          },
          client: MockClient((request) async {
            if (!request.url.path.endsWith('/status'))
              throw const SocketException('dummy-disconnect');
            expect(jsonDecode(request.body)['receipt'], pending!['receipt']);
            return response({'deleted': confirmed});
          }),
        );
        expect(
          await service.delete('dummy-ticket'),
          confirmed ? DeletionOutcome.deleted : DeletionOutcome.notDeleted,
        );
        expect(erased, confirmed ? 1 : 0);
        expect(pending, isNull);
      },
    );
  }
  test(
    'unknown outcome and failed cleanup retain secure receipt for restart recovery',
    () async {
      Map<String, dynamic>? pending;
      var online = false, cleanupWorks = false;
      final service = AccountDeletionService(
        token: () async => 'dummy-jwt',
        pending: () async => pending,
        savePending: (value) async => pending = value,
        clearPending: () async => pending = null,
        erase: () async {
          if (!cleanupWorks) throw StateError('dummy-storage-failure');
        },
        client: MockClient((_) async {
          if (!online) throw const SocketException('offline');
          return response({'deleted': true});
        }),
      );
      expect(await service.delete('dummy-ticket'), DeletionOutcome.unknown);
      expect(pending, isNotNull);
      online = true;
      expect(await service.recover(), DeletionOutcome.cleanupPending);
      expect(pending, isNotNull);
      cleanupWorks = true;
      expect(await service.recover(), DeletionOutcome.deleted);
      expect(pending, isNull);
    },
  );
  test(
    'late local preference and network cache writes cannot revive deleted data',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final generation = AccountDeletionState.generation;
      AccountDeletionState.generation++;
      await AccountDeletionState.writeString(
        prefs,
        'current_user',
        'private',
        generation,
      );
      expect(prefs.getString('current_user'), isNull);
      final directory = await Directory.systemTemp.createTemp(
        'deletion-cache-',
      );
      final oldClient = ContentCache.client;
      ContentCache.directoryForTesting = directory;
      final release = Completer<http.Response>();
      ContentCache.client = MockClient((_) => release.future);
      try {
        final pending = ContentCache.get(
          Uri.parse('https://dummy.invalid/user'),
          headers: {'Authorization': 'Bearer dummy'},
          userData: true,
        );
        await Future<void>.delayed(const Duration(milliseconds: 30));
        await ContentCache.eraseAccountData();
        release.complete(response({'data': 'private'}));
        await pending;
        expect(
          await Directory('${directory.path}/content_cache').exists(),
          false,
        );
      } finally {
        ContentCache.client = oldClient;
        ContentCache.directoryForTesting = null;
        await directory.delete(recursive: true);
      }
    },
  );
  test(
    'photo cleanup deletes only application-owned paths, not external originals',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'deletion-photo-',
      );
      final root = await Directory('${directory.path}/owned').create();
      final inside = await File(
        '${root.path}/avatar.jpg',
      ).writeAsString('dummy');
      final outside = await File(
        '${directory.path}/original.jpg',
      ).writeAsString('dummy');
      try {
        await AccountErasure.removeOwnedPhoto(inside.path, [root]);
        await AccountErasure.removeOwnedPhoto(outside.path, [root]);
        expect(await inside.exists(), false);
        expect(await outside.exists(), true);
      } finally {
        await directory.delete(recursive: true);
      }
    },
  );
  test(
    'full local erasure keeps only appearance/language and the pending recovery receipt',
    () async {
      final root = await Directory.systemTemp.createTemp('deletion-device-');
      final photo = await File(
        '${root.path}/avatar.jpg',
      ).writeAsString('dummy-photo');
      final cached = await File(
        '${root.path}/content_cache/private.json',
      ).create(recursive: true);
      await cached.writeAsString('dummy-private-cache');
      SharedPreferences.setMockInitialValues({
        'current_user': 'dummy-user',
        'saved_email': 'dummy@example.invalid',
        'saved_password': 'dummy-password',
        'offline_plan_content_dummy': 'dummy-content',
        'fcm_token': 'dummy-push',
        'sync_queue': '[]',
        'profile_image_path': photo.path,
        'theme_mode': 'dark',
        'language_code': 'ar',
        'has_selected_language': true,
      });
      FlutterSecureStorage.setMockInitialValues({
        'jwt_token': 'dummy-jwt',
        AccountDeletionState.pendingKey: 'dummy-receipt',
      });
      ContentCache.directoryForTesting = root;
      try {
        await AccountErasure.run(ownedRoots: () async => [root]);
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getKeys(), {
          'theme_mode',
          'language_code',
          'has_selected_language',
        });
        expect(await AccountDeletionState.storage.readAll(), {
          AccountDeletionState.pendingKey: 'dummy-receipt',
        });
        expect(await photo.exists(), false);
        expect(await cached.exists(), false);
      } finally {
        ContentCache.directoryForTesting = null;
        await root.delete(recursive: true);
      }
    },
  );
  Future<void> show(
    WidgetTester tester,
    FakeDeletion service,
    String language,
    Size size,
  ) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      RepaintBoundary(
        key: previewKey,
        child: MaterialApp(
          theme: ThemeData(
            brightness: size.width > 500 ? Brightness.dark : Brightness.light,
            fontFamily: Platform.isWindows ? 'DeletionPreview' : null,
          ),
          locale: Locale(language),
          supportedLocales: const [Locale('ar'), Locale('en')],
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: AccountDeletionScreen(service: service),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final language in ['ar', 'en']) {
    for (final size in [const Size(320, 800), const Size(820, 1180)]) {
      testWidgets(
        'warning and cancel are safe without overflow $language $size',
        (tester) async {
          final service = FakeDeletion();
          await show(tester, service, language, size);
          expect(tester.takeException(), isNull);
          await tester.runAsync(() async {
            final boundary =
                previewKey.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            final image = await boundary.toImage(pixelRatio: 1);
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            final output = Directory('../.account-deletion-review');
            await output.create(recursive: true);
            await File(
              '${output.path}/deletion-$language-${size.width.toInt()}.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
          await tester.ensureVisible(
            find.byKey(const ValueKey('delete-password')),
          );
          await tester.enterText(
            find.byKey(const ValueKey('delete-password')),
            'dummy-password',
          );
          await tester.ensureVisible(
            find.byKey(const ValueKey('delete-understand')),
          );
          await tester.tap(find.byKey(const ValueKey('delete-understand')));
          await tester.pump();
          await tester.ensureVisible(
            find.byKey(const ValueKey('delete-start')),
          );
          await tester.tap(find.byKey(const ValueKey('delete-start')));
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const ValueKey('delete-cancel')));
          await tester.pumpAndSettle();
          expect(service.authorized, 0);
          expect(service.deleted, 0);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
  testWidgets(
    'final confirmation succeeds; unknown result exposes recovery instead of another delete',
    (tester) async {
      final service = FakeDeletion()..outcome = DeletionOutcome.unknown;
      await show(tester, service, 'en', const Size(390, 844));
      await tester.ensureVisible(find.byKey(const ValueKey('delete-password')));
      await tester.enterText(
        find.byKey(const ValueKey('delete-password')),
        'dummy-password',
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('delete-understand')),
      );
      await tester.tap(find.byKey(const ValueKey('delete-understand')));
      await tester.pump();
      await tester.ensureVisible(find.byKey(const ValueKey('delete-start')));
      await tester.tap(find.byKey(const ValueKey('delete-start')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('delete-final-confirm')));
      await tester.pumpAndSettle();
      expect(service.authorized, 1);
      expect(service.deleted, 1);
      expect(find.byKey(const ValueKey('delete-start')), findsNothing);
      service.outcome = DeletionOutcome.deleted;
      await tester.ensureVisible(find.byKey(const ValueKey('delete-recover')));
      await tester.tap(find.byKey(const ValueKey('delete-recover')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('delete-complete')), findsOneWidget);
      expect(service.deleted, 1);
      expect(tester.takeException(), isNull);
    },
  );
}
