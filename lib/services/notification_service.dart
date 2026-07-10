import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'network_service.dart';
import 'auth_service.dart';

import 'package:flutter/material.dart';

class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  /**
   * Initialize notification service
   */
  static Future<void> initialize() async {
    if (kDebugMode) {
      print('🚀 Initializing Notification Service...');
    }

    // Get token and save it immediately (especially for Android < 13)
    await _getToken();
    _setupHandlers();

    // Request permissions (mainly for iOS and Android 13+)
    try {
      NotificationSettings settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (kDebugMode) {
        print(
          '💡 Notification Permission Status: ${settings.authorizationStatus}',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Notification permission request error: $e');
      }
    }
  }

  /**
   * Get FCM Token and save it locally
   */
  static Future<String?> _getToken() async {
    try {
      String? token = await _messaging.getToken();
      if (token != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('fcm_token', token);
        if (kDebugMode) {
          print('🔑 FCM token obtained');
        }
      }
      return token;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error getting FCM token: $e');
      }
      return null;
    }
  }

  /**
   * Setup message handlers for different app states
   */
  static void _setupHandlers() {
    // Foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (kDebugMode) {
        print(
          '📱 Message received in foreground: ${message.notification?.title}',
        );
      }

      // Show dialog if we have a notification body
      if (message.notification != null) {
        _showForegroundDialog(message);
      }
    });

    // Background messages when app is opened via notification
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      if (kDebugMode) {
        print('📂 App opened via notification: ${message.notification?.title}');
      }
      // Handle navigation or specific action
    });
  }

  /**
   * Show a custom dialog for foreground notifications
   */
  static void _showForegroundDialog(RemoteMessage message) {
    final context = navigatorKey.currentContext;
    if (context == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Text(
          message.notification?.title ?? 'تنبيه جديد',
          textAlign: TextAlign.right,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(
          message.notification?.body ?? '',
          textAlign: TextAlign.right,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'موافق',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  /**
   * Register token with backend for the current user
   */
  static Future<void> updateTokenOnServer(String email) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString('fcm_token');

      if (token == null) {
        token = await _getToken();
      }

      if (token != null && email.isNotEmpty) {
        final response = await http.post(
          Uri.parse('${NetworkService.baseUrl}/mobile/api/users/register-fcm'),
          headers: await AuthService.authHeaders(),
          body: jsonEncode({'email': email, 'fcmToken': token}),
        );

        if (response.statusCode == 200) {
          if (kDebugMode) {
            print('✅ FCM Token updated on server for $email');
          }
        } else {
          if (kDebugMode) {
            print('❌ Failed to update FCM token on server: ${response.statusCode}');
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error updating token on server: $e');
      }
    }
  }
}

/**
 * Global background message handler
 */
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Initialize Firebase if needed (already initialized in main usually)
  // await Firebase.initializeApp();
  if (kDebugMode) {
    print("💤 Handling background message: ${message.messageId}");
  }
}
