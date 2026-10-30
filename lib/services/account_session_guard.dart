import 'dart:async';
import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'account_deletion_state.dart';
import 'account_erasure.dart';
import 'auth_service.dart';
import 'network_service.dart';

class AccountSessionGuard with WidgetsBindingObserver {
  AccountSessionGuard({
    required this.onRevoked,
    http.Client? client,
    Future<String?> Function()? token,
    Future<void> Function()? erase,
  }) : _client = client ?? http.Client(),
       _token = token ?? AuthService.getToken,
       _erase = erase ?? AccountErasure.run;
  final VoidCallback onRevoked;
  final http.Client _client;
  final Future<String?> Function() _token;
  final Future<void> Function() _erase;
  Future<void>? _checking;
  bool _disposed = false;
  void start() => WidgetsBinding.instance.addObserver(this);
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _client.close();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(check());
  }

  Future<void> check() =>
      _checking ??= _check().whenComplete(() => _checking = null);
  Future<void> _check() async {
    try {
      final generation = AccountDeletionState.generation;
      final token = await _token();
      if (_disposed || token == null) return;
      final parts = token.split('.');
      if (parts.length != 3) return;
      final claims = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      );
      final email = claims['email'];
      if (email is! String || email.isEmpty) return;
      final response = await _client
          .get(
            Uri.parse(
              '${NetworkService.baseUrl}/mobile/api/users/me/${Uri.encodeComponent(email)}',
            ),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(const Duration(seconds: 10));
      if (_disposed ||
          generation != AccountDeletionState.generation ||
          token != await _token())
        return;
      if ([401, 404, 410].contains(response.statusCode)) {
        await _erase();
        if (!_disposed) onRevoked();
      }
    } catch (_) {
      // Connectivity/provider failures never imply account deletion.
    }
  }
}
