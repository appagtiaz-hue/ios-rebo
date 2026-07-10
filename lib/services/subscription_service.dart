import 'dart:convert';
import 'package:http/http.dart' as http;
import 'network_service.dart';
import 'test_config.dart';
import 'auth_service.dart';

class SubscriptionService {
  static String get baseUrl => NetworkService.baseUrl;

  // Get all active subscriptions for a user
  static Future<List<Map<String, dynamic>>> getActiveSubscriptions(
    String userId,
  ) async {
    try {
      final url = Uri.parse(
        '$baseUrl/mobile/api/subscriptions/active?userId=$userId',
      );
      final headers = await AuthService.authHeaders();
      final response = await http
          .get(url, headers: headers)
          .timeout(Duration(seconds: TestConfig.requestTimeout));

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        if (jsonData['success'] == true && jsonData['data'] != null) {
          final data = jsonData['data'];
          if (data['subscriptions'] != null) {
            return List<Map<String, dynamic>>.from(data['subscriptions']);
          }
        }
      }

      if (TestConfig.enableDebugLogs) {
        print('❌ Error fetching active subscriptions: ${response.statusCode}');
      }
      return [];
    } catch (e) {
      if (TestConfig.enableDebugLogs) {
        print('❌ Exception fetching active subscriptions: $e');
      }
      return [];
    }
  }

  // Switch active subscription (if needed in future, currently just navigational)
  static Future<bool> switchActiveSubscription(
    String userId,
    String planId,
  ) async {
    try {
      final url = Uri.parse('$baseUrl/mobile/api/subscriptions/switch');
      final headers = await AuthService.authHeaders();
      final response = await http
          .post(
            url,
            headers: headers,
            body: jsonEncode({'userId': userId, 'planId': planId}),
          )
          .timeout(Duration(seconds: TestConfig.requestTimeout));

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        return jsonData['success'] == true;
      }
      return false;
    } catch (e) {
      print('❌ Exception switching subscription: $e');
      return false;
    }
  }
}
