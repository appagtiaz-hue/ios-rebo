import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'localization_service.dart';

class AuthMessages {
  static const _messages = <String, (String, String)>{
    'AUTH_REQUEST_DENIED': (
      'تعذّر السماح بهذا الطلب. أعد فتح التطبيق وحاول مجددًا، أو تواصل مع الدعم إذا استمرت المشكلة.',
      'This request could not be permitted. Reopen the app and try again, or contact support if it continues.',
    ),
    'AUTH_EMAIL_INVALID': (
      'اكتب بريدًا إلكترونيًا صحيحًا ثم حاول مجددًا.',
      'Enter a valid email address and try again.',
    ),
    'AUTH_PASSWORD_REQUIRED': (
      'اكتب كلمة المرور ثم حاول تسجيل الدخول مجددًا.',
      'Enter your password and try signing in again.',
    ),
    'AUTH_PASSWORD_WEAK': (
      'كلمة المرور الجديدة يجب أن تحتوي على 6 أحرف على الأقل.',
      'Your new password must contain at least 6 characters.',
    ),
    'AUTH_NAME_REQUIRED': (
      'اكتب اسمك لإكمال إنشاء الحساب.',
      'Enter your name to finish creating your account.',
    ),
    'OTP_FORMAT_INVALID': (
      'اكتب رمز التحقق المكوّن من 6 أرقام كما وصلك في البريد.',
      'Enter the 6-digit verification code from your email.',
    ),
    'AUTH_INPUT_INVALID': (
      'راجع البريد الإلكتروني وكلمة المرور أو رمز التحقق، ثم حاول مجددًا.',
      'Check your email, password or verification code, then try again.',
    ),
    'AUTH_CREDENTIALS_INVALID': (
      'البريد الإلكتروني أو كلمة المرور غير صحيحة. راجعهما أو استخدم طريقة دخولك الأصلية أو استعادة كلمة المرور.',
      'Email or password is incorrect. Check them, use your original sign-in method, or reset your password.',
    ),
    'AUTH_ACCOUNT_LOCKED': (
      'تم إيقاف محاولات الدخول مؤقتًا لحماية الحساب. انتظر ثم حاول مجددًا.',
      'Sign-in attempts are temporarily paused to protect your account. Wait, then try again.',
    ),
    'AUTH_RATE_LIMITED': (
      'محاولات كثيرة خلال فترة قصيرة. انتظر ثم حاول مجددًا.',
      'Too many attempts in a short time. Wait, then try again.',
    ),
    'AUTH_PROVIDER_CONFLICT': (
      'لا يمكن الدخول بهذه الطريقة لهذا الحساب حاليًا. استخدم طريقة الدخول الأصلية لحساب اجتياز أو تواصل مع الدعم. لم يتم ربط الحسابات تلقائيًا.',
      'This sign-in method cannot access this account yet. Use your original Agtiaz sign-in method or contact support. Accounts were not automatically linked.',
    ),
    'AUTH_APPLE_RETRY': (
      'تعذّر التحقق من موافقة أبل. اضغط المتابعة باستخدام Apple من جديد وأكمل الموافقة.',
      'Apple authorization could not be verified. Tap Continue with Apple again and complete authorization.',
    ),
    'AUTH_GOOGLE_RETRY': (
      'تعذّر إتمام تسجيل جوجل. اختر حساب جوجل من جديد وأكمل الموافقة.',
      'Google sign-in could not be completed. Select your Google account again and complete authorization.',
    ),
    'AUTH_APPLE_UNAVAILABLE': (
      'تسجيل أبل غير متاح على هذا الجهاز حاليًا. تحقق من تسجيل حساب أبل في إعدادات الجهاز، أو استخدم طريقة دخولك الأصلية.',
      'Apple sign-in is unavailable on this device. Check your Apple account in device settings, or use your original sign-in method.',
    ),
    'AUTH_UNAVAILABLE': (
      'خدمة الدخول غير متاحة مؤقتًا. حاول بعد قليل؛ لا تحتاج إلى إنشاء حساب جديد.',
      'Sign-in is temporarily unavailable. Try again shortly; you do not need a new account.',
    ),
    'AUTH_NETWORK': (
      'تعذّر الاتصال. تحقق من الإنترنت ثم حاول مرة أخرى.',
      'Could not connect. Check your internet connection and try again.',
    ),
    'AUTH_TIMEOUT': (
      'الاتصال استغرق وقتًا طويلًا ولم يتأكد اكتمال الطلب. تحقق من الإنترنت ثم حاول مجددًا.',
      'The request timed out and completion was not confirmed. Check your connection and try again.',
    ),
    'AUTH_RESPONSE_INVALID': (
      'وصل رد غير مكتمل من الخدمة. حاول بعد قليل؛ لم يتأكد اكتمال العملية.',
      'The service returned an incomplete response. Try again shortly; completion was not confirmed.',
    ),
    'AUTH_SESSION_FAILED': (
      'تعذّر حفظ جلسة الدخول على الجهاز. أغلق التطبيق وافتحه ثم حاول مجددًا؛ لا تحتاج إلى حساب جديد.',
      'Could not save your session on this device. Reopen the app and try again; you do not need a new account.',
    ),
    'OTP_INVALID': (
      'الرمز غير صحيح أو منتهي الصلاحية أو مستخدم بالفعل. استخدم آخر رمز وصلك أو اطلب رمزًا جديدًا.',
      'The code is incorrect, expired or already used. Use the latest code you received or request a new one.',
    ),
    'OTP_REQUEST_REQUIRED': (
      'ابدأ التسجيل من جديد لطلب رمز تحقق، ثم استخدم آخر رمز يصلك.',
      'Start sign-up again to request a verification code, then use the latest code.',
    ),
    'OTP_ACCOUNT_WAIT': (
      'تم إيقاف التحقق مؤقتًا بسبب المحاولات المتكررة. انتظر ثم حاول مجددًا.',
      'Verification is temporarily paused after repeated attempts. Wait, then try again.',
    ),
    'OTP_RESEND_WAIT': (
      'انتظر قبل طلب رمز جديد، واستخدم آخر رمز وصلك فقط.',
      'Wait before requesting another code. Use only the latest code you received.',
    ),
    'OTP_UNAVAILABLE': (
      'خدمة التحقق غير متاحة مؤقتًا. حاول بعد قليل؛ لم يتأكد اكتمال العملية.',
      'Verification is temporarily unavailable. Try again shortly; completion was not confirmed.',
    ),
    'SIGNUP_CONFLICT': (
      'تعذّر إنشاء الحساب بهذه البيانات. جرّب طريقة دخولك الأصلية أو استعادة كلمة المرور.',
      'Could not create an account with these details. Try your original sign-in method or password reset.',
    ),
  };

  static String text(String code, {int? retryAfterSeconds}) {
    final value = _messages[code] ?? _messages['AUTH_UNAVAILABLE']!;
    final arabic = LocalizationService.isArabic();
    var message = arabic ? value.$1 : value.$2;
    if (retryAfterSeconds != null && retryAfterSeconds > 0) {
      message += arabic
          ? ' حاول بعد $retryAfterSeconds ثانية.'
          : ' Try again in $retryAfterSeconds seconds.';
    }
    return message;
  }

  static Map<String, dynamic> failure(
    String code, {
    int? retryAfterSeconds,
    int? status,
  }) => {
    'success': false,
    'errorCode': code,
    'error': text(code, retryAfterSeconds: retryAfterSeconds),
    if (retryAfterSeconds != null) 'retryAfterSeconds': retryAfterSeconds,
    if (status != null) 'statusCode': status,
    if (code == 'AUTH_ACCOUNT_LOCKED') 'locked': true,
    if (code == 'SIGNUP_CONFLICT') 'alreadyRegistered': true,
  };

  static Map<String, dynamic> exception(
    Object error, {
    String fallback = 'AUTH_UNAVAILABLE',
  }) {
    if (error is TimeoutException) return failure('AUTH_TIMEOUT');
    if (error is SocketException ||
        error is http.ClientException ||
        error is HandshakeException) {
      return failure('AUTH_NETWORK');
    }
    if (error is FormatException) return failure('AUTH_RESPONSE_INVALID');
    if (error is PlatformException) {
      if ([
        'sign_in_canceled',
        'sign_in_cancelled',
        'canceled',
      ].contains(error.code)) {
        return {'success': false, 'cancelled': true};
      }
      if (error.code == 'network_error') return failure('AUTH_NETWORK');
    }
    return failure(fallback);
  }

  static int? retryAfter(http.Response response, Map<String, dynamic>? body) {
    final fromBody = body?['retryAfterSeconds'];
    final header = response.headers['retry-after'];
    final seconds = fromBody is num
        ? (fromBody.isFinite ? fromBody.ceil() : null)
        : int.tryParse(fromBody is String ? fromBody : '');
    final numeric = seconds != null && seconds > 0
        ? seconds
        : int.tryParse(header ?? '');
    if (numeric != null && numeric > 0) return numeric.clamp(1, 86400);
    if (header != null) {
      try {
        final delay = HttpDate.parse(
          header,
        ).difference(DateTime.now()).inSeconds;
        if (delay > 0) return delay.clamp(1, 86400);
      } catch (_) {
        /* Invalid server headers never reach the screen. */
      }
    }
    return null;
  }

  static Map<String, dynamic> response(
    http.Response response, {
    required String operation,
  }) {
    Map<String, dynamic>? body;
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map<String, dynamic>) body = decoded;
    } catch (_) {
      /* Proxies may return HTML or an empty body. */
    }
    final status = response.statusCode;
    final retry = retryAfter(response, body);
    if (status == 408) return failure('AUTH_TIMEOUT', status: status);
    if (status == 403) return failure('AUTH_REQUEST_DENIED', status: status);
    if (status >= 500) {
      return failure(
        operation.contains('otp') ||
                operation.contains('password') ||
                operation == 'signup'
            ? 'OTP_UNAVAILABLE'
            : 'AUTH_UNAVAILABLE',
        status: status,
        retryAfterSeconds: retry,
      );
    }
    if (status == 429) {
      final code = body?['errorCode'];
      return failure(
        ['OTP_ACCOUNT_WAIT', 'OTP_RESEND_WAIT'].contains(code)
            ? code as String
            : 'AUTH_RATE_LIMITED',
        status: status,
        retryAfterSeconds: retry,
      );
    }
    if (status == 423) {
      return failure(
        'AUTH_ACCOUNT_LOCKED',
        status: status,
        retryAfterSeconds: retry,
      );
    }
    if (body == null) return failure('AUTH_RESPONSE_INVALID', status: status);
    if (status == 200 && body['success'] == true) return body;
    final code = body['errorCode'];
    if (status == 409) {
      return failure(
        operation == 'signup' || operation == 'verify-signup-otp'
            ? 'SIGNUP_CONFLICT'
            : 'AUTH_PROVIDER_CONFLICT',
        status: status,
      );
    }
    if (status == 401) {
      return failure(
        operation.startsWith('auth/apple')
            ? 'AUTH_APPLE_RETRY'
            : operation == 'auth/google'
            ? 'AUTH_GOOGLE_RETRY'
            : 'AUTH_CREDENTIALS_INVALID',
        status: status,
      );
    }
    if ([400, 404, 410, 413, 422].contains(status)) {
      final fallback =
          operation.startsWith('verify-') || operation == 'reset-password'
          ? 'OTP_INVALID'
          : operation == 'resend-signup-otp' && status == 404
          ? 'OTP_REQUEST_REQUIRED'
          : 'AUTH_INPUT_INVALID';
      return failure(
        [
              'AUTH_INPUT_INVALID',
              'AUTH_EMAIL_INVALID',
              'AUTH_PASSWORD_REQUIRED',
              'AUTH_PASSWORD_WEAK',
              'AUTH_NAME_REQUIRED',
              'OTP_FORMAT_INVALID',
              'OTP_INVALID',
              'OTP_REQUEST_REQUIRED',
            ].contains(code)
            ? code as String
            : fallback,
        status: status,
      );
    }
    return failure(
      status == 200 ? 'AUTH_RESPONSE_INVALID' : 'AUTH_UNAVAILABLE',
      status: status,
    );
  }
}

class AuthApi {
  AuthApi({
    required this.baseUrl,
    required this.saveToken,
    http.Client? client,
    this.timeout = const Duration(seconds: 20),
  }) : _client = client;
  final String baseUrl;
  final Future<void> Function(String) saveToken;
  final http.Client? _client;
  final Duration timeout;

  Future<Map<String, dynamic>> google(
    Future<String?> Function() authorize,
  ) async {
    try {
      final idToken = await authorize();
      if (idToken == null) return {'success': false, 'cancelled': true};
      if (idToken.isEmpty) return AuthMessages.failure('AUTH_GOOGLE_RETRY');
      return await post('auth/google', {'idToken': idToken}, session: true);
    } catch (error) {
      return AuthMessages.exception(error, fallback: 'AUTH_GOOGLE_RETRY');
    }
  }

  Future<Map<String, dynamic>> post(
    String operation,
    Map<String, dynamic> body, {
    bool session = false,
  }) async {
    final client = _client ?? http.Client();
    try {
      final response = await client
          .post(
            Uri.parse('$baseUrl/mobile/api/users/$operation'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(timeout);
      final data = AuthMessages.response(response, operation: operation);
      if (data['success'] != true) return data;
      if (session) {
        final user = data['data'];
        if (data['token'] is! String ||
            (data['token'] as String).trim().isEmpty ||
            user is! Map<String, dynamic> ||
            user['id'] is! String ||
            (user['id'] as String).trim().isEmpty ||
            user['email'] is! String ||
            (user['email'] as String).trim().isEmpty) {
          return AuthMessages.failure('AUTH_RESPONSE_INVALID');
        }
        try {
          await saveToken(data['token'] as String);
        } catch (_) {
          return AuthMessages.failure('AUTH_SESSION_FAILED');
        }
        return {'success': true, 'user': user};
      }
      final message = switch (operation) {
        'verify-signup-otp' =>
          LocalizationService.isArabic()
              ? 'تم تفعيل حسابك. يمكنك تسجيل الدخول الآن.'
              : 'Your account is verified. You can sign in now.',
        'verify-reset-otp' =>
          LocalizationService.isArabic()
              ? 'تم التحقق من الرمز.'
              : 'Code verified.',
        'reset-password' =>
          LocalizationService.isArabic()
              ? 'تم تغيير كلمة المرور. سجّل الدخول بكلمة المرور الجديدة.'
              : 'Password changed. Sign in with your new password.',
        _ =>
          LocalizationService.isArabic()
              ? 'إذا كان الطلب صالحًا، سيصلك رمز التحقق. راجع البريد والرسائل غير المرغوب فيها.'
              : 'If the request is eligible, a verification code will arrive. Check your inbox and spam folder.',
      };
      return {
        'success': true,
        'message': message,
        if (data['data'] is Map<String, dynamic>) 'user': data['data'],
        if (AuthMessages.retryAfter(response, data) case final int delay)
          'retryAfterSeconds': delay,
      };
    } catch (error) {
      return AuthMessages.exception(error);
    } finally {
      if (_client == null) client.close();
    }
  }
}
