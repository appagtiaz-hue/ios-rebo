import 'package:shared_preferences/shared_preferences.dart';

class OtpCooldown {
  static const resendIntervalSeconds = 60;

  static String _key(String email, String type) =>
      'otp_cooldown_${type}_${email.trim().toLowerCase()}';

  static Future<void> save(String email, String type, int seconds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      _key(email, type),
      DateTime.now().add(Duration(seconds: seconds)).millisecondsSinceEpoch,
    );
  }

  static Future<int> startAfterSend(
    String email,
    String type,
    int? seconds,
  ) async {
    final delay = seconds != null && seconds > resendIntervalSeconds
        ? seconds
        : resendIntervalSeconds;
    await save(email, type, delay);
    return delay;
  }

  static Future<int> remaining(
    String email,
    String type, {
    bool startIfMissing = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final deadline = prefs.getInt(_key(email, type));
    if (deadline == null && startIfMissing) {
      await save(email, type, resendIntervalSeconds);
      return resendIntervalSeconds;
    }
    final milliseconds =
        (deadline ?? 0) - DateTime.now().millisecondsSinceEpoch;
    return milliseconds > 0 ? (milliseconds / 1000).ceil() : 0;
  }
}
