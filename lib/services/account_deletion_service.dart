import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'account_deletion_state.dart';
import 'account_erasure.dart';
import 'network_service.dart';

enum DeletionOutcome { deleted, notDeleted, unknown, cleanupPending }

class AccountDeletionFailure implements Exception {
  const AccountDeletionFailure(this.status, [this.message]);
  final int status;
  final String? message;
}

abstract interface class AccountDeletionGateway {
  Future<Map<String, dynamic>> options();
  Future<bool> hasPending();
  Future<String?> authorize(String method, String password);
  Future<DeletionOutcome> delete(String authorizationId);
  Future<DeletionOutcome> recover();
}

class AccountDeletionService implements AccountDeletionGateway {
  AccountDeletionService({
    http.Client? client,
    String? baseUrl,
    Future<String?> Function()? token,
    Future<Map<String, dynamic>?> Function()? pending,
    Future<void> Function(Map<String, dynamic>)? savePending,
    Future<void> Function()? clearPending,
    Future<void> Function()? erase,
    this.providerProof,
  }) : _client = client ?? http.Client(),
       _baseUrl = baseUrl ?? NetworkService.baseUrl,
       _token = token ?? AccountDeletionState.rawToken,
       _pending = pending ?? AccountDeletionState.pending,
       _savePending = savePending ?? AccountDeletionState.begin,
       _clearPending = clearPending ?? AccountDeletionState.finish,
       _erase = erase ?? AccountErasure.run;

  final http.Client _client;
  final String _baseUrl;
  final Future<String?> Function() _token;
  final Future<Map<String, dynamic>?> Function() _pending;
  final Future<void> Function(Map<String, dynamic>) _savePending;
  final Future<void> Function() _clearPending;
  final Future<void> Function() _erase;
  final Future<Map<String, String>?> Function(
    String method,
    String nonce,
    String state,
  )?
  providerProof;
  Future<DeletionOutcome>? _operation;

  Future<Map<String, dynamic>> _request(
    String path,
    String token, {
    Map<String, dynamic>? body,
  }) async {
    final uri = Uri.parse('$_baseUrl/mobile/api/users/account-deletion$path');
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
    final response =
        await (body == null
                ? _client.get(uri, headers: headers)
                : _client.post(uri, headers: headers, body: jsonEncode(body)))
            .timeout(const Duration(seconds: 30));
    final data = jsonDecode(utf8.decode(response.bodyBytes));
    if (response.statusCode != 200 ||
        data is! Map<String, dynamic> ||
        data['success'] != true) {
      throw AccountDeletionFailure(
        response.statusCode,
        data is Map ? data['error'] as String? : null,
      );
    }
    return data;
  }

  Future<String> _session() async {
    final token = await _token();
    if (token == null || token.isEmpty) throw const AccountDeletionFailure(401);
    return token;
  }

  @override
  Future<Map<String, dynamic>> options() async =>
      _request('/options', await _session());

  @override
  Future<bool> hasPending() async => await _pending() != null;

  @override
  Future<String?> authorize(String method, String password) async {
    final token = await _session();
    final challenge = await _request('/challenge', token, body: {});
    final body = <String, dynamic>{
      'challengeId': challenge['challengeId'],
      'method': method,
    };
    if (method == 'password') {
      body['password'] = password;
    } else {
      final proof = await providerProof?.call(
        method,
        challenge['nonce'] as String,
        challenge['challengeId'] as String,
      );
      if (proof == null) return null;
      body.addAll(proof);
    }
    final result = await _request('/authorize', token, body: body);
    return result['authorizationId'] as String;
  }

  @override
  Future<DeletionOutcome> delete(String authorizationId) => _operation ??=
      _delete(authorizationId).whenComplete(() => _operation = null);

  Future<DeletionOutcome> _delete(String authorizationId) async {
    if (await hasPending()) return _recover();
    final token = await _session();
    final random = Random.secure();
    final receipt = List.generate(
      32,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    // Persist before sending: a lost response must not lose the deletion receipt.
    await _savePending({'token': token, 'receipt': receipt});
    try {
      final response = await _request(
        '',
        token,
        body: {
          'authorizationId': authorizationId,
          'receipt': receipt,
          'confirmation': 'DELETE',
        },
      );
      if (response['deleted'] == true) return _complete();
    } catch (_) {
      // A failed response does not prove that the server rolled back.
    }
    return _recover();
  }

  Future<DeletionOutcome> _complete() async {
    try {
      await _erase();
      await _clearPending();
      return DeletionOutcome.deleted;
    } catch (_) {
      return DeletionOutcome.cleanupPending;
    }
  }

  @override
  Future<DeletionOutcome> recover() =>
      _operation ??= _recover().whenComplete(() => _operation = null);

  Future<DeletionOutcome> _recover() async {
    try {
      final pending = await _pending();
      if (pending == null) return DeletionOutcome.notDeleted;
      final response = await _request(
        '/status',
        pending['token'] as String,
        body: {'receipt': pending['receipt']},
      );
      if (response['deleted'] == true) return _complete();
      if (response['deleted'] == false) {
        await _clearPending();
        return DeletionOutcome.notDeleted;
      }
    } catch (_) {
      /* Keep the receipt and block background writes until resolved. */
    }
    return DeletionOutcome.unknown;
  }
}
