import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

typedef AppleAuthorization =
    Future<AuthorizationCredentialAppleID> Function(String nonce, String state);

class AppleSignInService {
  AppleSignInService({
    required this.baseUrl,
    required this.saveToken,
    http.Client? client,
    AppleAuthorization? authorize,
  }) : _client = client,
       _authorize = authorize ?? _nativeAuthorize;

  final String baseUrl;
  final Future<void> Function(String) saveToken;
  final http.Client? _client;
  final AppleAuthorization _authorize;

  static Future<AuthorizationCredentialAppleID> _nativeAuthorize(
    String nonce,
    String state,
  ) => SignInWithApple.getAppleIDCredential(
    scopes: [
      AppleIDAuthorizationScopes.email,
      AppleIDAuthorizationScopes.fullName,
    ],
    nonce: nonce,
    state: state,
  );

  Future<Map<String, dynamic>> signIn() async {
    final client = _client ?? http.Client();
    try {
      final endpoint = Uri.parse('$baseUrl/mobile/api/users/auth/apple');
      final challengeResponse = await client
          .post(
            Uri.parse('$endpoint/challenge'),
            headers: {'Content-Type': 'application/json'},
            body: '{}',
          )
          .timeout(const Duration(seconds: 15));
      final challenge = jsonDecode(challengeResponse.body);
      if (challengeResponse.statusCode != 200 || challenge['success'] != true) {
        return {'success': false, 'error': challenge['error']};
      }
      final id = challenge['challengeId'];
      final nonce = challenge['nonce'];
      final hex = RegExp(r'^[a-f0-9]{64}$');
      if (id is! String ||
          nonce is! String ||
          !hex.hasMatch(id) ||
          !hex.hasMatch(nonce)) {
        return {'success': false};
      }
      final credential = await _authorize(nonce, id);
      if (credential.state != id ||
          credential.identityToken == null ||
          credential.authorizationCode.isEmpty) {
        return {'success': false};
      }
      final name = [
        credential.givenName,
        credential.familyName,
      ].whereType<String>().where((part) => part.trim().isNotEmpty).join(' ');
      final response = await client
          .post(
            endpoint,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'challengeId': id,
              'identityToken': credential.identityToken,
              'authorizationCode': credential.authorizationCode,
              if (name.isNotEmpty) 'name': name,
            }),
          )
          .timeout(const Duration(seconds: 20));
      final result = jsonDecode(response.body);
      if (response.statusCode == 200 &&
          result['success'] == true &&
          result['token'] is String &&
          (result['token'] as String).isNotEmpty &&
          result['data'] is Map<String, dynamic>) {
        await saveToken(result['token'] as String);
        return {'success': true, 'user': result['data']};
      }
      return {'success': false, 'error': result['error']};
    } on SignInWithAppleAuthorizationException catch (error) {
      return {
        'success': false,
        'cancelled': error.code == AuthorizationErrorCode.canceled,
      };
    } catch (_) {
      // Never log native credentials, authorization codes, or server tokens.
      return {'success': false};
    } finally {
      if (_client == null) client.close();
    }
  }
}
