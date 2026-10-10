import 'dart:io';

import 'package:agtiaz/services/apple_push_token.dart';
import 'package:agtiaz/services/ios_notification_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('non-iOS platforms do not initialize the iOS push service', () async {
    if (!Platform.isIOS) {
      await IosNotificationService.instance.synchronize();
    }
  });

  test('denied permission never requests APNs or FCM tokens', () async {
    final token = await getApplePushToken(
      hasPermission: () async => false,
      getAPNSToken: () async => throw StateError('APNs must not be requested'),
      getFCMToken: () async => throw StateError('FCM must not be requested'),
    );
    expect(token, isNull);
  });

  test('waits for APNs before requesting FCM', () async {
    var checks = 0;
    var waits = 0;
    final token = await getApplePushToken(
      hasPermission: () async => true,
      getAPNSToken: () async => ++checks == 3 ? 'apns' : null,
      getFCMToken: () async {
        expect(checks, 3);
        return 'fcm';
      },
      delay: (_) async => waits++,
    );
    expect(token, 'fcm');
    expect(waits, 2);
  });

  test('APNs timeout is bounded and never requests FCM', () async {
    var checks = 0;
    var waits = 0;
    final token = await getApplePushToken(
      hasPermission: () async => true,
      getAPNSToken: () async {
        checks++;
        return '';
      },
      getFCMToken: () async => throw StateError('FCM must not be requested'),
      delay: (_) async => waits++,
      attempts: 3,
    );
    expect(token, isNull);
    expect(checks, 3);
    expect(waits, 2);
  });

  test('transient FCM failure is not treated as a registered token', () async {
    await expectLater(
      getApplePushToken(
        hasPermission: () async => true,
        getAPNSToken: () async => 'apns',
        getFCMToken: () async => throw StateError('temporary failure'),
      ),
      throwsStateError,
    );
  });
}
