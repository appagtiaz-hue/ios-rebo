import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AccountDeletionState {
  static const storage = FlutterSecureStorage();
  static const pendingKey = 'pending_account_deletion_v1';
  static int generation = 0;

  static Future<bool> isPending() async =>
      await storage.read(key: pendingKey) != null;

  static Future<Map<String, dynamic>?> pending() async {
    final value = await storage.read(key: pendingKey);
    return value == null ? null : jsonDecode(value) as Map<String, dynamic>;
  }

  static Future<void> begin(Map<String, dynamic> value) async {
    generation++;
    await storage.write(key: pendingKey, value: jsonEncode(value));
  }

  static Future<void> finish() => storage.delete(key: pendingKey);
  static Future<String?> rawToken() => storage.read(key: 'jwt_token');

  static Future<void> writeString(
    SharedPreferences preferences,
    String key,
    String value,
    int expectedGeneration,
  ) async {
    if (expectedGeneration != generation || await isPending()) return;
    if (!await preferences.setString(key, value)) {
      throw StateError('Local data could not be saved');
    }
    if (expectedGeneration != generation || await isPending()) {
      await preferences.remove(key);
    }
  }
}
