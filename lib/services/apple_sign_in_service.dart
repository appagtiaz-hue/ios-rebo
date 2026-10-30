import 'package:http/http.dart' as http;
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'auth_api.dart';

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
      final challenge = AuthMessages.response(
        challengeResponse,
        operation: 'auth/apple/challenge',
      );
      if (challenge['success'] != true) return challenge;
      final id = challenge['challengeId'];
      final nonce = challenge['nonce'];
      final hex = RegExp(r'^[a-f0-9]{64}$');
      if (id is! String ||
          nonce is! String ||
          !hex.hasMatch(id) ||
          !hex.hasMatch(nonce)) {
        return AuthMessages.failure('AUTH_RESPONSE_INVALID');
      }
      final credential = await _authorize(nonce, id);
      if (credential.state != id ||
          credential.identityToken == null ||
          credential.authorizationCode.isEmpty) {
        return AuthMessages.failure('AUTH_APPLE_RETRY');
      }
      final name = [
        credential.givenName,
        credential.familyName,
      ].whereType<String>().where((part) => part.trim().isNotEmpty).join(' ');
      return await AuthApi(
        baseUrl: baseUrl,
        saveToken: saveToken,
        client: client,
      ).post('auth/apple', {
        'challengeId': id,
        'identityToken': credential.identityToken,
        'authorizationCode': credential.authorizationCode,
        if (name.isNotEmpty) 'name': name,
      }, session: true);
    } on SignInWithAppleAuthorizationException catch (error) {
      if (error.code == AuthorizationErrorCode.canceled)
        return {'success': false, 'cancelled': true};
      return AuthMessages.failure('AUTH_APPLE_RETRY');
    } on SignInWithAppleNotSupportedException {
      return AuthMessages.failure('AUTH_APPLE_UNAVAILABLE');
    } catch (error) {
      // Never log native credentials, authorization codes, or server tokens.
      return AuthMessages.exception(error, fallback: 'AUTH_APPLE_RETRY');
    } finally {
      if (_client == null) client.close();
    }
  }
}
