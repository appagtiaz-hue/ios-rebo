import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/payment_plan.dart';
import 'auth_service.dart';
import 'network_service.dart';

class PlanUsageSession {
  final String userId;
  final String token;
  const PlanUsageSession(this.userId, this.token);
}

class FreePlanUsageService {
  static final instance = FreePlanUsageService();
  final http.Client _client;
  final String _baseUrl;
  final Future<PlanUsageSession?> Function() _session;
  final Future<SharedPreferences> Function() _preferences;
  final DateTime Function() _now;
  final Map<String, DateTime> _retryAfter = {};
  Future<void>? _flushing;

  FreePlanUsageService({
    http.Client? client,
    String? baseUrl,
    Future<PlanUsageSession?> Function()? session,
    Future<SharedPreferences> Function()? preferences,
    DateTime Function()? now,
  }) : _client = client ?? http.Client(),
       _baseUrl = baseUrl ?? NetworkService.baseUrl,
       _session = session ?? _currentSession,
       _preferences = preferences ?? SharedPreferences.getInstance,
       _now = now ?? DateTime.now;

  static Future<PlanUsageSession?> _currentSession() async {
    final token = await AuthService.getToken();
    if (token == null) return null;
    final parts = token.split('.');
    if (parts.length != 3) return null;
    // The claim only partitions local storage; the server authenticates it.
    final claims = jsonDecode(
      utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
    );
    final id = claims['id'];
    if (id is! String || !RegExp(r'^[a-fA-F0-9]{24}$').hasMatch(id)) {
      return null;
    }
    return PlanUsageSession(id, token);
  }

  String _prefix(String userId) =>
      'free_plan_open_v1_${Uri.encodeComponent(_baseUrl)}_${userId}_';

  Future<void> recordOpen(PaymentPlan plan) async {
    if (plan.price != 0 ||
        !plan.isActive ||
        !RegExp(r'^[a-fA-F0-9]{24}$').hasMatch(plan.id)) {
      return;
    }
    try {
      final session = await _session();
      if (session == null) return;
      final prefs = await _preferences();
      final key = '${_prefix(session.userId)}${plan.id}';
      if (prefs.getString(key) == 'sent') return;
      await prefs.setString(key, 'pending');
      await flushPending();
    } catch (_) {
      // Measurement must never block or interrupt training.
    }
  }

  Future<void> flushPending() async {
    if (_flushing != null) return _flushing;
    final work = _flush();
    _flushing = work;
    try {
      await work;
    } finally {
      _flushing = null;
    }
  }

  Future<void> _flush() async {
    try {
      final session = await _session();
      if (session == null) return;
      final prefs = await _preferences();
      final prefix = _prefix(session.userId);
      final keys = prefs
          .getKeys()
          .where(
            (key) =>
                key.startsWith(prefix) && prefs.getString(key) == 'pending',
          )
          .take(10)
          .toList();
      for (final key in keys) {
        if (_retryAfter[key]?.isAfter(_now()) ?? false) continue;
        final current = await _session();
        if (current == null || current.userId != session.userId) return;
        final planId = key.substring(prefix.length);
        if (!RegExp(r'^[a-fA-F0-9]{24}$').hasMatch(planId)) continue;
        _retryAfter[key] = _now().add(const Duration(minutes: 1));
        try {
          final response = await _client
              .post(
                Uri.parse('$_baseUrl/mobile/api/usage/free-plan-open'),
                headers: {
                  'Content-Type': 'application/json',
                  'Authorization': 'Bearer ${current.token}',
                },
                body: jsonEncode({'planId': planId}),
              )
              .timeout(const Duration(seconds: 5));
          if (response.statusCode == 200 &&
              jsonDecode(response.body)['success'] == true) {
            await prefs.setString(key, 'sent');
            _retryAfter.remove(key);
          } else if ([400, 403, 404, 410].contains(response.statusCode)) {
            await prefs.remove(key);
          } else if (response.statusCode == 429) {
            final seconds =
                int.tryParse(response.headers['retry-after'] ?? '') ?? 60;
            _retryAfter[key] = _now().add(
              Duration(seconds: seconds.clamp(60, 900)),
            );
            return;
          } else {
            return;
          }
        } catch (_) {
          return;
        }
      }
    } catch (_) {
      // Pending opens stay scoped to their owner until the next sync.
    }
  }
}
