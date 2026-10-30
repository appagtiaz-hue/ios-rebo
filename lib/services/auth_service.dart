import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'network_service.dart';
import 'auth_api.dart';
import 'content_cache.dart';
import 'apple_sign_in_service.dart';
import 'account_deletion_state.dart';
import 'account_deletion_service.dart';
import 'account_erasure.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

/// Authentication Service for MongoDB API with OTP verification & Google Sign-In
class AuthService {
  static const _storage = FlutterSecureStorage();

  static Future<Map<String, dynamic>> signInWithApple() => AppleSignInService(
    baseUrl: NetworkService.baseUrl,
    saveToken: saveToken,
  ).signIn();

  // Google Sign-In instance (6.x API)
  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    // Explicitly using Web Client ID to ensure idToken retrieval (fixes ApiException 10)
    serverClientId:
        '470623660750-2rpc0p647f7vcpb8bmaj5dthctcsbjsh.apps.googleusercontent.com',
    scopes: ['email', 'profile'],
  );

  // ==========================
  // SESSION MANAGEMENT (JWT)
  // ==========================

  /// Save JWT token securely
  static Future<void> saveToken(String token) async {
    if (await AccountDeletionState.isPending())
      throw StateError('Resolve pending account deletion first');
    await _storage.write(key: 'jwt_token', value: token);
  }

  /// Get stored JWT token
  static Future<String?> getToken() async {
    if (await AccountDeletionState.isPending()) return null;
    return await _storage.read(key: 'jwt_token');
  }

  /// Delete stored token (Logout)
  static Future<void> deleteToken() async {
    await _storage.delete(key: 'jwt_token');
    try {
      await ContentCache.clearPrivate(Uri.parse(NetworkService.baseUrl));
    } catch (_) {
      // Cache cleanup must not keep an authenticated session alive.
    }
  }

  static Future<Map<String, String>> authHeaders() async {
    final token = await getToken();
    return {
      ...NetworkService.headers,
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// Auto Login: Check if valid token exists
  /// Returns User data if token is valid, null otherwise
  static Future<Map<String, dynamic>?> autoLogin() async {
    try {
      if (await AccountDeletionState.isPending()) {
        final outcome = await AccountDeletionService().recover();
        if (outcome != DeletionOutcome.notDeleted) return null;
      }
      final token = await getToken();
      if (token == null) return null;

      print('🔄 Auto-login: Verifying token...');

      final parts = token.split('.');
      if (parts.length != 3) {
        await deleteToken();
        return null;
      }

      final payload = json.decode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      );

      final email = payload['email'];
      if (email == null) return null;

      final response = await http.get(
        Uri.parse('${NetworkService.baseUrl}/mobile/api/users/me/$email'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          print('✅ Auto-login successful');
          return data['data'];
        }
      }

      if ([401, 404, 410].contains(response.statusCode)) {
        await AccountErasure.run();
        return null;
      }

      print('⚠️ Token expired or invalid, logging out.');
      await deleteToken();
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Logout: Clear session and disconnect Google
  static Future<void> logout() async {
    print('🚪 Logging out...');
    await _storage.delete(key: 'jwt_token');

    // Force disconnect to ensure the user can choose an account next time
    try {
      await _googleSignIn.disconnect();
    } catch (_) {
      // Local sign-out still completes if provider disconnection is unavailable.
    }

    try {
      await _googleSignIn.signOut();
    } catch (_) {
      // The local session has already been removed.
    }

    print('✅ Logged out successfully');
  }

  // ==========================
  // GOOGLE SIGN-IN (6.x API)
  // ==========================

  /// Sign in with Google
  static AuthApi get _api =>
      AuthApi(baseUrl: NetworkService.baseUrl, saveToken: saveToken);

  static Future<Map<String, dynamic>> signInWithGoogle() =>
      _api.google(() async {
        await _googleSignIn.signOut();
        final account = await _googleSignIn.signIn();
        if (account == null) return null;
        final idToken = (await account.authentication).idToken;
        if (idToken == null || idToken.isEmpty) {
          return '';
        }
        return idToken;
      });

  static Future<Map<String, String>?> proofForAccountDeletion(
    String method,
    String nonce,
    String state,
  ) async {
    if (method == 'apple') {
      try {
        final credential = await SignInWithApple.getAppleIDCredential(
          scopes: [AppleIDAuthorizationScopes.email],
          nonce: nonce,
          state: state,
        );
        if (credential.state != state || credential.identityToken == null)
          throw StateError('Invalid authorization state');
        return {
          'identityToken': credential.identityToken!,
          'authorizationCode': credential.authorizationCode,
        };
      } on SignInWithAppleAuthorizationException catch (error) {
        if (error.code == AuthorizationErrorCode.canceled) return null;
        rethrow;
      }
    }
    await _googleSignIn.signOut();
    final account = await _googleSignIn.signIn();
    if (account == null) return null;
    final token = (await account.authentication).idToken;
    if (token == null) throw StateError('Google authorization unavailable');
    return {'idToken': token};
  }

  static Future<Map<String, dynamic>> signup({
    required String name,
    required String email,
    required String password,
  }) => _api.post('signup', {
    'name': name.trim(),
    'email': email.trim().toLowerCase(),
    'password': password,
  });

  static Future<Map<String, dynamic>> verifySignupOTP({
    required String email,
    required String otp,
  }) => _api.post('verify-signup-otp', {
    'email': email.trim().toLowerCase(),
    'otp': otp.trim(),
  });

  static Future<Map<String, dynamic>> resendSignupOTP({
    required String email,
  }) => _api.post('resend-signup-otp', {'email': email.trim().toLowerCase()});

  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) => _api.post('login', {
    'email': email.trim().toLowerCase(),
    'password': password,
  }, session: true);

  static Future<Map<String, dynamic>> requestPasswordReset({
    required String email,
  }) => _api.post('request-password-reset', {
    'email': email.trim().toLowerCase(),
  });

  static Future<Map<String, dynamic>> verifyResetOTP({
    required String email,
    required String otp,
  }) => _api.post('verify-reset-otp', {
    'email': email.trim().toLowerCase(),
    'otp': otp.trim(),
  });

  static Future<Map<String, dynamic>> resetPassword({
    required String email,
    required String otp,
    required String newPassword,
  }) => _api.post('reset-password', {
    'email': email.trim().toLowerCase(),
    'otp': otp.trim(),
    'newPassword': newPassword,
  });
}
