import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'network_service.dart';

/// Authentication Service for MongoDB API with OTP verification & Google Sign-In
class AuthService {
  static const _storage = FlutterSecureStorage();

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
    await _storage.write(key: 'jwt_token', value: token);
  }

  /// Get stored JWT token
  static Future<String?> getToken() async {
    return await _storage.read(key: 'jwt_token');
  }

  /// Delete stored token (Logout)
  static Future<void> deleteToken() async {
    await _storage.delete(key: 'jwt_token');
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

      print('🔄 Fetching profile for auto-login: $email');

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

      print('⚠️ Token expired or invalid, logging out.');
      await deleteToken();
      return null;
    } catch (e) {
      print('❌ Auto-login error: $e');
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
    } catch (e) {
      print('⚠️ Google disconnect failed (normal if not signed in): $e');
    }

    try {
      await _googleSignIn.signOut();
    } catch (e) {
      print('⚠️ Google sign out failed: $e');
    }

    print('✅ Logged out successfully');
  }

  // ==========================
  // GOOGLE SIGN-IN (6.x API)
  // ==========================

  /// Sign in with Google
  static Future<Map<String, dynamic>> signInWithGoogle() async {
    try {
      print('🔄 Starting Google Sign-In...');

      // Force account selection by signing out first
      await _googleSignIn.signOut();

      // Trigger the authentication flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        print('⚠️ Google Sign-In cancelled by user');
        return {'success': false, 'cancelled': true};
      }

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final String? idToken = googleAuth.idToken;

      if (idToken == null) {
        print('❌ Failed to get ID token from Google');
        return {'success': false, 'error': 'فشل في الحصول على التوكن من جوجل'};
      }

      print('✅ Google Auth successful. ID Token obtained.');

      // Send ID Token to Backend
      final response = await http.post(
        Uri.parse('${NetworkService.baseUrl}/mobile/api/users/auth/google'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'idToken': idToken}),
      );

      final data = json.decode(response.body);
      print('Response status: ${response.statusCode}');

      if (response.statusCode == 200 && data['success'] == true) {
        if (data['token'] != null) {
          await saveToken(data['token']);
        }
        return {'success': true, 'user': data['data']};
      } else {
        return {
          'success': false,
          'error': data['error'] ?? 'فشل تسجيل الدخول بجوجل',
        };
      }
    } catch (e) {
      print('❌ Google Sign-In error: $e');
      return {'success': false, 'error': 'حدث خطأ غير متوقع: $e'};
    }
  }

  // ==========================
  // EXISTING METHODS
  // ==========================

  /// Sign up - Request OTP for email verification
  static Future<Map<String, dynamic>> signup({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      print('📝 Requesting signup OTP for: $email');

      final response = await http.post(
        Uri.parse('${NetworkService.baseUrl}/mobile/api/users/signup'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'name': name, 'email': email, 'password': password}),
      );

      final data = json.decode(response.body);
      print('Response status: ${response.statusCode}');

      if (response.statusCode == 200 && data['success'] == true) {
        return {'success': true, 'message': data['message']};
      } else {
        return {
          'success': false,
          'error': data['error'] ?? 'حدث خطأ في التسجيل',
        };
      }
    } catch (e) {
      print('❌ Signup error: $e');
      return {'success': false, 'error': 'حدث خطأ في الاتصال بالخادم'};
    }
  }

  /// Verify signup OTP and create user account
  static Future<Map<String, dynamic>> verifySignupOTP({
    required String email,
    required String otp,
  }) async {
    try {
      print('🔍 Verifying signup OTP for: $email');

      final response = await http.post(
        Uri.parse(
          '${NetworkService.baseUrl}/mobile/api/users/verify-signup-otp',
        ),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'email': email, 'otp': otp}),
      );

      final data = json.decode(response.body);
      print('Response status: ${response.statusCode}');

      if (response.statusCode == 200 && data['success'] == true) {
        return {
          'success': true,
          'message': data['message'],
          'user': data['data'],
        };
      } else {
        return {
          'success': false,
          'error': data['error'] ?? 'رمز التحقق غير صحيح',
        };
      }
    } catch (e) {
      print('❌ Verify OTP error: $e');
      return {'success': false, 'error': 'حدث خطأ في الاتصال بالخادم'};
    }
  }

  /// Resend signup OTP
  static Future<Map<String, dynamic>> resendSignupOTP({
    required String email,
  }) async {
    try {
      print('🔄 Resending signup OTP for: $email');

      final response = await http.post(
        Uri.parse(
          '${NetworkService.baseUrl}/mobile/api/users/resend-signup-otp',
        ),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'email': email}),
      );

      final data = json.decode(response.body);
      print('Response status: ${response.statusCode}');

      if (response.statusCode == 200 && data['success'] == true) {
        return {'success': true, 'message': data['message']};
      } else {
        return {
          'success': false,
          'error': data['error'] ?? 'فشل في إعادة إرسال الرمز',
        };
      }
    } catch (e) {
      print('❌ Resend OTP error: $e');
      return {'success': false, 'error': 'حدث خطأ في الاتصال بالخادم'};
    }
  }

  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      final url = '${NetworkService.baseUrl}/mobile/api/users/login';
      print('🔐 Logging in: $email');
      print('🌐 Target URL: $url');

      final response = await http
          .post(
            Uri.parse('${NetworkService.baseUrl}/mobile/api/users/login'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'email': email, 'password': password}),
          )
          .timeout(
            const Duration(seconds: 3),
            onTimeout: () {
              throw Exception('انتهت مهلة الاتصال');
            },
          );

      final data = json.decode(response.body);
      print('Response status: ${response.statusCode}');

      if (response.statusCode == 200 && data['success'] == true) {
        if (data['token'] != null) {
          await saveToken(data['token']);
        }
        return {'success': true, 'user': data['data']};
      } else if (response.statusCode == 423) {
        // Account is locked
        return {
          'success': false,
          'error': data['error'] ?? 'تم قفل حسابك مؤقتاً',
          'locked': true,
        };
      } else {
        return {
          'success': false,
          'error': data['error'] ?? 'فشل في تسجيل الدخول',
        };
      }
    } catch (e) {
      print('❌ Login error: $e');
      return {'success': false, 'error': 'حدث خطأ في الاتصال بالخادم'};
    }
  }

  /// Request password reset OTP
  static Future<Map<String, dynamic>> requestPasswordReset({
    required String email,
  }) async {
    try {
      print('📧 Requesting password reset OTP for: $email');

      final response = await http.post(
        Uri.parse(
          '${NetworkService.baseUrl}/mobile/api/users/request-password-reset',
        ),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'email': email}),
      );

      final data = json.decode(response.body);
      print('Response status: ${response.statusCode}');

      if (response.statusCode == 200 && data['success'] == true) {
        return {'success': true, 'message': data['message']};
      } else {
        return {
          'success': false,
          'error': data['error'] ?? 'فشل في إرسال رمز التحقق',
        };
      }
    } catch (e) {
      print('❌ Request password reset error: $e');
      return {'success': false, 'error': 'حدث خطأ في الاتصال بالخادم'};
    }
  }

  /// Verify password reset OTP
  static Future<Map<String, dynamic>> verifyResetOTP({
    required String email,
    required String otp,
  }) async {
    try {
      print('🔍 Verifying reset OTP for: $email');

      final response = await http.post(
        Uri.parse(
          '${NetworkService.baseUrl}/mobile/api/users/verify-reset-otp',
        ),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'email': email, 'otp': otp}),
      );

      final data = json.decode(response.body);
      print('Response status: ${response.statusCode}');

      if (response.statusCode == 200 && data['success'] == true) {
        return {'success': true, 'message': data['message']};
      } else {
        return {
          'success': false,
          'error': data['error'] ?? 'رمز التحقق غير صحيح',
        };
      }
    } catch (e) {
      print('❌ Verify reset OTP error: $e');
      return {'success': false, 'error': 'حدث خطأ في الاتصال بالخادم'};
    }
  }

  /// Reset password with verified OTP
  static Future<Map<String, dynamic>> resetPassword({
    required String email,
    required String otp,
    required String newPassword,
  }) async {
    try {
      print('🔄 Resetting password for: $email');

      final response = await http.post(
        Uri.parse('${NetworkService.baseUrl}/mobile/api/users/reset-password'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': email,
          'otp': otp,
          'newPassword': newPassword,
        }),
      );

      final data = json.decode(response.body);
      print('Response status: ${response.statusCode}');

      if (response.statusCode == 200 && data['success'] == true) {
        return {'success': true, 'message': data['message']};
      } else {
        return {
          'success': false,
          'error': data['error'] ?? 'فشل في تغيير كلمة المرور',
        };
      }
    } catch (e) {
      print('❌ Reset password error: $e');
      return {'success': false, 'error': 'حدث خطأ في الاتصال بالخادم'};
    }
  }
}
