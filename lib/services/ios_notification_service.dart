import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'apple_push_token.dart';
import 'auth_service.dart';
import 'network_service.dart';

class IosNotificationService with WidgetsBindingObserver {
  IosNotificationService._();

  static final instance = IosNotificationService._();
  Future<void>? _initialization;
  Future<void>? _synchronization;
  bool _initialized = false;
  bool _observing = false;
  bool _listening = false;
  bool _synchronizeAgain = false;

  FirebaseMessaging get _messaging => FirebaseMessaging.instance;

  Future<void> _initialize() async {
    if (Firebase.apps.isEmpty) await Firebase.initializeApp();
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
    if (!_listening) {
      _messaging.onTokenRefresh.listen(
        (_) => unawaited(synchronize()),
        onError: (Object _) => _logFailure(),
      );
      _listening = true;
    }
    await _messaging.requestPermission(alert: true, badge: true, sound: true);
    _initialized = true;
  }

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    final initialization = _initialization ??= _initialize();
    try {
      await initialization;
    } finally {
      if (identical(_initialization, initialization)) _initialization = null;
    }
  }

  Future<void> synchronize() {
    if (!Platform.isIOS) return Future<void>.value();
    if (!_observing) {
      WidgetsBinding.instance.addObserver(this);
      _observing = true;
    }
    if (_synchronization != null) {
      _synchronizeAgain = true;
      return _synchronization!;
    }
    return _synchronization = _synchronize().whenComplete(() {
      _synchronization = null;
    });
  }

  Future<void> _synchronize() async {
    do {
      _synchronizeAgain = false;
      try {
        await _ensureInitialized();
        final token = await getApplePushToken(
          hasPermission: () async {
            final settings = await _messaging.getNotificationSettings();
            return settings.authorizationStatus ==
                    AuthorizationStatus.authorized ||
                settings.authorizationStatus == AuthorizationStatus.provisional;
          },
          getAPNSToken: _messaging.getAPNSToken,
          getFCMToken: _messaging.getToken,
        );
        if (token == null || token.isEmpty) continue;
        final preferences = await SharedPreferences.getInstance();
        await preferences.setString('fcm_token', token);
        await _registerToken(token);
      } catch (_) {
        _logFailure();
      }
    } while (_synchronizeAgain);
  }

  Future<void> _registerToken(String token) async {
    final session = await AuthService.getToken();
    if (session == null) return;
    final parts = session.split('.');
    if (parts.length != 3) return;
    final claims = jsonDecode(
      utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
    );
    final email = claims is Map<String, dynamic> ? claims['email'] : null;
    if (email is! String || email.isEmpty) return;
    if (await AuthService.getToken() != session) {
      _synchronizeAgain = true;
      return;
    }
    final response = await http
        .post(
          Uri.parse('${NetworkService.baseUrl}/mobile/api/users/register-fcm'),
          headers: {
            ...NetworkService.headers,
            'Authorization': 'Bearer $session',
          },
          body: jsonEncode({'email': email, 'fcmToken': token}),
        )
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) _logFailure();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(synchronize());
  }

  void _logFailure() {
    if (kDebugMode) debugPrint('iOS push registration will retry on resume.');
  }
}
