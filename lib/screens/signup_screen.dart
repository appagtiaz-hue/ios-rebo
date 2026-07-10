import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../services/auth_service.dart';
import '../constants/colors.dart';
import '../l10n/app_localizations.dart';
import 'otp_verification_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _signup() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await AuthService.signup(
        name: _fullNameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (result['success'] == true && mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => OTPVerificationScreen(
              type: 'signup',
              email: _emailController.text.trim(),
              password: _passwordController.text,
              name: _fullNameController.text.trim(),
            ),
          ),
        );
      } else {
        throw Exception(
          result['error'] ??
              AppLocalizations.of(context)?.translate('signupError') ??
              'فشل في إنشاء الحساب',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${AppLocalizations.of(context)?.translate('signupErrorPrefix') ?? 'خطأ في إنشاء الحساب'}: $e',
            ),
            backgroundColor: Color(0xFFFF5252),
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
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Stack(
        children: [
          // Top Section (Dark Green Header)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 0.25.sh,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primaryDark, AppColors.primary],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 16.w,
                    vertical: 16.h,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40.r,
                        height: 40.r,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.white.withOpacity(0.2),
                        ),
                        child: IconButton(
                          icon: Icon(
                            Icons.arrow_back,
                            color: Colors.white,
                            size: 20.r,
                          ),
                          padding: EdgeInsets.zero,
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                      SizedBox(width: 16.w),
                      Text(
                        AppLocalizations.of(
                              context,
                            )?.translate('createNewAccount') ??
                            'إنشاء حساب جديد',
                        style: TextStyle(
                          fontSize: 22.sp,
                          fontWeight: FontWeight.bold,
                          color: AppColors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Bottom Section (White Card)
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              height: 0.78.sh,
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(40.r),
                  topRight: Radius.circular(40.r),
                ),
              ),
              padding: EdgeInsets.only(left: 32.w, right: 32.w, top: 32.h),
              child: SingleChildScrollView(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Name
                      _buildRoundedTextField(
                        controller: _fullNameController,
                        label:
                            AppLocalizations.of(
                              context,
                            )?.translate('fullName') ??
                            'الاسم الكامل',
                        hint:
                            AppLocalizations.of(
                              context,
                            )?.translate('enterFullNameHelper') ??
                            'أدخل اسمك الكامل',
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return AppLocalizations.of(
                                  context,
                                )?.translate('enterFullName') ??
                                'يرجى إدخال الاسم الكامل';
                          }
                          if (value.length < 3) {
                            return AppLocalizations.of(
                                  context,
                                )?.translate('fullNameLength') ??
                                'الاسم يجب أن يكون 3 أحرف على الأقل';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 20.h),

                      // Email
                      _buildRoundedTextField(
                        controller: _emailController,
                        label:
                            AppLocalizations.of(context)?.translate('email') ??
                            'البريد الإلكتروني',
                        hint: 'example@gmail.com',
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return AppLocalizations.of(
                                  context,
                                )?.translate('emailRequired') ??
                                'يرجى إدخال البريد الإلكتروني';
                          }
                          if (!value.contains('@')) {
                            return AppLocalizations.of(
                                  context,
                                )?.translate('invalidEmail') ??
                                'البريد الإلكتروني غير صحيح';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 20.h),

                      // Password
                      _buildRoundedTextField(
                        controller: _passwordController,
                        label:
                            AppLocalizations.of(
                              context,
                            )?.translate('password') ??
                            'كلمة المرور',
                        obscureText: _obscurePassword,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            color: Colors.grey,
                            size: 20.r,
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
                      SizedBox(height: 20.h),

                      // Confirm Password
                      _buildRoundedTextField(
                        controller: _confirmPasswordController,
                        label:
                            AppLocalizations.of(
                              context,
                            )?.translate('confirmPassword') ??
                            'تأكيد كلمة المرور',
                        obscureText: _obscureConfirmPassword,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureConfirmPassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            color: Colors.grey,
                            size: 20.r,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscureConfirmPassword =
                                  !_obscureConfirmPassword;
                            });
                          },
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return AppLocalizations.of(
                                  context,
                                )?.translate('enterConfirmPassword') ??
                                'يرجى تأكيد كلمة المرور';
                          }
                          if (value != _passwordController.text) {
                            return AppLocalizations.of(
                                  context,
                                )?.translate('passwordMismatch') ??
                                'كلمة المرور غير متطابقة';
                          }
                          return null;
                        },
                      ),

                      SizedBox(height: 32.h),

                      // Sign Up Button
                      ElevatedButton(
                        onPressed: _isLoading ? null : _signup,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.white,
                          padding: EdgeInsets.symmetric(vertical: 16.h),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30.r),
                          ),
                          elevation: 0,
                        ),
                        child: _isLoading
                            ? SizedBox(
                                height: 20.h,
                                width: 20.w,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : Text(
                                AppLocalizations.of(
                                      context,
                                    )?.translate('signup') ??
                                    'إنشاء حساب',
                                style: TextStyle(
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),

                      SizedBox(height: 24.h),

                      // Login Link
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            (AppLocalizations.of(
                                      context,
                                    )?.translate('alreadyHaveAccount') ??
                                    'لديك حساب بالفعل؟') +
                                ' ',
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).textTheme.bodyMedium?.color,
                              fontSize: 14.sp,
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.pop(context);
                            },
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: Size(0, 0),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text(
                              AppLocalizations.of(
                                    context,
                                  )?.translate('login') ??
                                  'تسجيل الدخول',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontSize: 14.sp,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 20.h),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

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
            fontSize: 13.sp,
            color: Theme.of(context).textTheme.bodyMedium?.color,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 8.h),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          style: TextStyle(
            fontSize: 15.sp,
            color: Theme.of(context).textTheme.bodyLarge?.color,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: Theme.of(context).hintColor,
              fontWeight: FontWeight.w400,
            ),
            suffixIcon: suffixIcon,
            contentPadding: EdgeInsets.symmetric(
              horizontal: 16.w,
              vertical: 14.h,
            ),
            filled: true,
            fillColor:
                Theme.of(context).inputDecorationTheme.fillColor ??
                Theme.of(context).scaffoldBackgroundColor,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(25.r),
              borderSide: BorderSide(
                color: Theme.of(context).dividerColor,
                width: 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(25.r),
              borderSide: BorderSide(
                color: Theme.of(context).primaryColor,
                width: 1.5,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(25.r),
              borderSide: BorderSide(color: Colors.red, width: 1),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(25.r),
              borderSide: BorderSide(color: Colors.red, width: 1.5),
            ),
          ),
          validator: validator,
        ),
      ],
    );
  }
}
