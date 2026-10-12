import 'package:flutter/material.dart';
import '../theme/home_palette.dart';
import '../widgets/agtiaz_brand_logo.dart';
import '../widgets/login_welcome_text.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/colors.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../models/user.dart';
import '../l10n/app_localizations.dart';
import '../services/notification_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _rememberMe = false;

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final savedEmail = prefs.getString('saved_email');
    final rememberMe = prefs.getBool('remember_me') ?? false;

    if (!mounted) return;
    if (rememberMe && savedEmail != null) {
      setState(() {
        _emailController.text = savedEmail;
        _rememberMe = true;
      });
    }
  }

  Future<void> _saveCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    if (_rememberMe) {
      await prefs.setString('saved_email', _emailController.text.trim());
      await prefs.setBool('remember_me', true);
    } else {
      await prefs.remove('saved_email');
      await prefs.setBool('remember_me', false);
    }
    await prefs.remove('saved_password');
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    // Save credentials if remember me is checked
    await _saveCredentials();

    try {
      final result = await AuthService.login(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (result['success'] == true) {
        try {
          if (result['user'] != null) {
            final user = User.fromJson(result['user']);
            await DatabaseService.setCurrentUser(user);
          }
        } catch (e) {
          print('Error saving user session: $e');
        }

        // إرسال FCM Token للسيرفر لكي تصل الإشعارات لهذا المستخدم
        NotificationService.updateTokenOnServer(_emailController.text.trim());

        if (mounted) {
          Navigator.pushReplacementNamed(context, '/home');
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                result['error'] ??
                    AppLocalizations.of(context)?.translate('loginError') ??
                    'فشل في تسجيل الدخول',
              ),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)?.translate('unexpectedError') ??
                  'حدث خطأ غير متوقع',
            ),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final result = await AuthService.signInWithGoogle();

      if (result['success'] == true) {
        try {
          if (result['user'] != null) {
            final user = User.fromJson(result['user']);
            await DatabaseService.setCurrentUser(user);
          }
        } catch (e) {
          print('Error saving user session: $e');
        }

        // إرسال FCM Token للسيرفر بعد تسجيل الدخول بجوجل
        if (result['user'] != null && result['user']['email'] != null) {
          NotificationService.updateTokenOnServer(result['user']['email']);
        }

        if (mounted) {
          Navigator.pushReplacementNamed(context, '/home');
        }
      } else if (result['cancelled'] == true) {
        // User cancelled login, do nothing
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                result['error'] ?? 'فشل تسجيل الدخول باستخدام Google',
              ),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ غير متوقع'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = HomePalette.of(context);
    return Scaffold(
      backgroundColor: p.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 440,
                  minHeight: (constraints.maxHeight - 52).clamp(
                    0,
                    double.infinity,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 52),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Center(child: AgtiazBrandLogo(size: 104)),
                          const SizedBox(height: 24),
                          LoginWelcomeText(
                            text:
                                AppLocalizations.of(
                                  context,
                                )?.translate('welcomeMessage') ??
                                'مرحباً بك في اجتياز',
                            style: TextStyle(
                              color: p.ink,
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 24),
                      child: _buildLoginForm(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginForm() => Form(
    key: _formKey,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Email Field
        _buildRoundedTextField(
          controller: _emailController,
          label:
              AppLocalizations.of(context)?.translate('email') ??
              'البريد الإلكتروني',
          hint: 'example@gmail.com',
          keyboardType: TextInputType.emailAddress,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return AppLocalizations.of(context)?.translate('emailRequired') ??
                  'يرجى إدخال البريد الإلكتروني';
            }
            if (!value.contains('@')) {
              return AppLocalizations.of(context)?.translate('invalidEmail') ??
                  'البريد الإلكتروني غير صحيح';
            }
            return null;
          },
        ),
        SizedBox(height: 12),

        // Password Field
        _buildRoundedTextField(
          controller: _passwordController,
          label:
              AppLocalizations.of(context)?.translate('password') ??
              'كلمة المرور',
          obscureText: _obscurePassword,
          suffixIcon: IconButton(
            icon: Icon(
              _obscurePassword
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
              color: Colors.grey,
              size: 20,
            ),
            onPressed: () {
              setState(() {
                _obscurePassword = !_obscurePassword;
              });
            },
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return AppLocalizations.of(
                    context,
                  )?.translate('passwordRequired') ??
                  'يرجى إدخال كلمة المرور';
            }
            if (value.length < 6) {
              return AppLocalizations.of(
                    context,
                  )?.translate('passwordLength') ??
                  'كلمة المرور يجب أن تكون 6 أحرف على الأقل';
            }
            return null;
          },
        ),

        SizedBox(height: 10),

        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Checkbox(
                  value: _rememberMe,
                  onChanged: (val) =>
                      setState(() => _rememberMe = val ?? false),
                  activeColor: HomePalette.of(context).green,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                Text(
                  AppLocalizations.of(context)?.translate('rememberMe') ??
                      'تذكرني',
                  style: TextStyle(
                    fontSize: 12,
                    color: HomePalette.of(context).secondary,
                  ),
                ),
              ],
            ),
            TextButton(
              key: const ValueKey('login-forgot-password'),
              onPressed: () => Navigator.pushNamed(context, '/forgotPassword'),
              style: TextButton.styleFrom(
                minimumSize: const Size(48, 48),
                foregroundColor: HomePalette.of(context).green,
              ),
              child: Text(
                AppLocalizations.of(context)?.translate('forgotPassword') ??
                    'نسيت كلمة المرور؟',
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),

        SizedBox(height: 16),

        // Buttons Row (Login + Google)
        Row(
          children: [
            // Login Button
            Expanded(
              flex: 2,
              child: ElevatedButton(
                key: const ValueKey('login-submit'),
                onPressed: _isLoading ? null : _login,
                style: ElevatedButton.styleFrom(
                  backgroundColor: HomePalette.of(context).button,
                  foregroundColor: HomePalette.of(context).buttonInk,
                  minimumSize: const Size(48, 48),
                  padding: EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  elevation: 0,
                ),
                child: _isLoading
                    ? SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            HomePalette.of(context).buttonInk,
                          ),
                        ),
                      )
                    : Text(
                        AppLocalizations.of(context)?.translate('login') ??
                            'تسجيل الدخول',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),

            SizedBox(width: 12),

            // Google Sign In Button
            Expanded(
              flex: 2,
              child: OutlinedButton(
                key: const ValueKey('login-google'),
                onPressed: _isLoading ? null : _handleGoogleSignIn,
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                  side: BorderSide(color: Colors.grey[300]!, width: 1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  backgroundColor: Colors.white,
                  minimumSize: const Size(48, 48),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      'assets/images/google_logo.png',
                      height: 18,
                      width: 18,
                      errorBuilder: (context, error, stackTrace) {
                        return Icon(
                          Icons.g_mobiledata,
                          size: 22,
                          color: Colors.red,
                        );
                      },
                    ),
                    SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Google',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),

        SizedBox(height: 12),

        // Sign Up Link
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              (AppLocalizations.of(context)?.translate('noAccount') ??
                      'ليس لديك حساب؟') +
                  ' ',
              style: TextStyle(
                color: Theme.of(context).textTheme.bodyMedium?.color,
                fontSize: 14,
              ),
            ),
            TextButton(
              key: const ValueKey('login-signup'),
              onPressed: () {
                Navigator.pushNamed(context, '/signup');
              },
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(48, 48),
              ),
              child: Text(
                AppLocalizations.of(context)?.translate('signup') ??
                    'إنشاء حساب',
                style: TextStyle(
                  color: HomePalette.of(context).green,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _buildRoundedTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    bool obscureText = false,
    TextInputType? keyboardType,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: HomePalette.of(context).secondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          style: TextStyle(
            fontSize: 15,
            color: HomePalette.of(context).ink,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: Theme.of(context).hintColor,
              fontWeight: FontWeight.w400,
            ),
            suffixIcon: suffixIcon,
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            filled: true,
            fillColor: HomePalette.of(context).panel,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(25),
              borderSide: BorderSide(
                color: HomePalette.of(context).border,
                width: 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(25),
              borderSide: BorderSide(
                color: HomePalette.of(context).green,
                width: 1.5,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(25),
              borderSide: BorderSide(color: Colors.red, width: 1),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(25),
              borderSide: BorderSide(color: Colors.red, width: 1.5),
            ),
          ),
          validator: validator,
        ),
      ],
    );
  }
}
