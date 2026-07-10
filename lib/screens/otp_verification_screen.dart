import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'dart:async';
import '../constants/colors.dart';
import '../services/auth_service.dart';
import '../l10n/app_localizations.dart';

class OTPVerificationScreen extends StatefulWidget {
  final String email;
  final String type; // 'signup' or 'reset'
  final String? password; // For signup only
  final String? name; // For signup only

  const OTPVerificationScreen({
    super.key,
    required this.email,
    required this.type,
    this.password,
    this.name,
  });

  @override
  State<OTPVerificationScreen> createState() => _OTPVerificationScreenState();
}

class _OTPVerificationScreenState extends State<OTPVerificationScreen> {
  final List<TextEditingController> _controllers = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  bool _isLoading = false;
  int _countdown = 60;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    _timer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    setState(() {
      _countdown = 60;
    });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown > 0) {
        setState(() {
          _countdown--;
        });
      } else {
        timer.cancel();
      }
    });
  }

  String _getOTP() {
    return _controllers.map((c) => c.text).join();
  }

  Future<void> _verifyOTP() async {
    final otp = _getOTP();
    if (otp.length != 6) {
      _showError(
        AppLocalizations.of(context)?.translate('otpRequired') ??
            'يرجى إدخال رمز التحقق المكون من 6 أرقام',
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      Map<String, dynamic> result;

      if (widget.type == 'signup') {
        // Verify signup OTP
        result = await AuthService.verifySignupOTP(
          email: widget.email,
          otp: otp,
        );

        if (result['success'] == true && mounted) {
          // Save user data and navigate to login
          _showSuccess(
            AppLocalizations.of(context)?.translate('accountActivated') ??
                'تم تفعيل حسابك بنجاح!',
          );
          await Future.delayed(const Duration(seconds: 2));
          if (mounted) {
            Navigator.pushNamedAndRemoveUntil(
              context,
              '/login',
              (route) => false,
            );
          }
        } else {
          _showError(
            result['error'] ??
                AppLocalizations.of(context)?.translate('otpInvalid') ??
                'رمز التحقق غير صحيح',
          );
        }
      } else {
        // Verify reset OTP
        result = await AuthService.verifyResetOTP(
          email: widget.email,
          otp: otp,
        );

        if (result['success'] == true && mounted) {
          // Navigate to new password screen
          Navigator.pushReplacementNamed(
            context,
            '/newPassword',
            arguments: {'email': widget.email, 'otp': otp},
          );
        } else {
          _showError(result['error'] ?? 'رمز التحقق غير صحيح');
        }
      }
    } catch (e) {
      _showError(
        AppLocalizations.of(context)?.translate('unexpectedError') ??
            'حدث خطأ غير متوقع',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _resendOTP() async {
    if (_countdown > 0) {
      _showError(
        '${AppLocalizations.of(context)?.translate('waitBeforeResend') ?? 'يرجى الانتظار'} $_countdown ${AppLocalizations.of(context)?.translate('seconds') ?? 'ثانية'} ${AppLocalizations.of(context)?.translate('beforeResending') ?? 'قبل إعادة الإرسال'}',
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      Map<String, dynamic> result;

      if (widget.type == 'signup') {
        result = await AuthService.resendSignupOTP(email: widget.email);
      } else {
        result = await AuthService.requestPasswordReset(email: widget.email);
      }

      if (result['success'] == true) {
        _showSuccess(
          AppLocalizations.of(context)?.translate('otpResent') ??
              'تم إعادة إرسال رمز التحقق',
        );
        _startCountdown();
        // Clear OTP fields
        for (var controller in _controllers) {
          controller.clear();
        }
        _focusNodes[0].requestFocus();
      } else {
        _showError(
          result['error'] ??
              AppLocalizations.of(context)?.translate('otpResendFailed') ??
              'فشل في إعادة إرسال الرمز',
        );
      }
    } catch (e) {
      _showError(
        AppLocalizations.of(context)?.translate('connectionError') ??
            'حدث خطأ في الاتصال بالخادم',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_rounded,
            color: Theme.of(context).textTheme.bodyLarge?.color,
            size: 24.r,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          AppLocalizations.of(context)?.translate('verifyEmailTitle') ??
              'تحقق من البريد الإلكتروني',
          style: TextStyle(
            color: Theme.of(context).textTheme.bodyLarge?.color,
            fontSize: 20.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).primaryColor.withOpacity(0.05),
              Theme.of(context).scaffoldBackgroundColor,
              AppColors.secondary.withOpacity(0.05),
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 20.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(height: 20.h),

                // Icon
                Center(
                  child: Container(
                    width: 100.w,
                    height: 100.h,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [AppColors.primaryLight, AppColors.primary],
                      ),
                      borderRadius: BorderRadius.circular(25.r),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.3),
                          blurRadius: 20.r,
                          offset: Offset(0, 10.h),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.email_rounded,
                      size: 50.r,
                      color: Colors.white,
                    ),
                  ),
                ),

                SizedBox(height: 30.h),

                // Title
                Text(
                  AppLocalizations.of(context)?.translate('enterOtp') ??
                      'أدخل رمز التحقق',
                  style: TextStyle(
                    fontSize: 26.sp,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                  textAlign: TextAlign.center,
                ),

                SizedBox(height: 12.h),

                // Description
                Text(
                  '${AppLocalizations.of(context)?.translate('otpSentTo') ?? 'تم إرسال رمز التحقق المكون من 6 أرقام إلى'}\n${widget.email}',
                  style: TextStyle(
                    fontSize: 15.sp,
                    color: Theme.of(context).textTheme.bodyMedium?.color,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),

                SizedBox(height: 40.h),

                // OTP Input Fields
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(6, (index) {
                      return Container(
                        width: 40.w,
                        height: 50.h,
                        margin: EdgeInsets.symmetric(horizontal: 4.w),
                        child: TextFormField(
                          controller: _controllers[index],
                          focusNode: _focusNodes[index],
                          textAlign: TextAlign.center,
                          keyboardType: TextInputType.number,
                          maxLength: 1,
                          style: TextStyle(
                            fontSize: 28.sp,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).textTheme.bodyLarge?.color,
                          ),
                          decoration: InputDecoration(
                            counterText: '',
                            filled: true,
                            fillColor: Theme.of(context).cardColor,
                            contentPadding: EdgeInsets.zero,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12.r),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12.r),
                              borderSide: BorderSide(
                                color: Theme.of(context).dividerColor,
                                width: 1.5.w,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12.r),
                              borderSide: BorderSide(
                                color: AppColors.primary,
                                width: 2.w,
                              ),
                            ),
                          ),
                          onChanged: (value) {
                            if (value.isNotEmpty && index < 5) {
                              _focusNodes[index + 1].requestFocus();
                            } else if (value.isEmpty && index > 0) {
                              _focusNodes[index - 1].requestFocus();
                            }
                            // Auto-submit when all 6 digits are entered
                            if (index == 5 && value.isNotEmpty) {
                              _verifyOTP();
                            }
                          },
                        ),
                      );
                    }),
                  ),
                ),

                SizedBox(height: 40.h),

                // Verify Button
                ElevatedButton(
                  onPressed: _isLoading ? null : _verifyOTP,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: EdgeInsets.symmetric(vertical: 18.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20.r),
                    ),
                  ),
                  child: _isLoading
                      ? SizedBox(
                          height: 24.h,
                          width: 24.w,
                          child: const CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          AppLocalizations.of(context)?.translate('verify') ??
                              'تحقق',
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                ),

                SizedBox(height: 20.h),

                // Resend OTP
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      AppLocalizations.of(
                            context,
                          )?.translate('didNotReceiveCode') ??
                          'لم تستلم الرمز؟ ',
                      style: TextStyle(
                        color: Theme.of(context).textTheme.bodyMedium?.color,
                        fontSize: 14.sp,
                      ),
                    ),
                    TextButton(
                      onPressed: _countdown > 0 || _isLoading
                          ? null
                          : _resendOTP,
                      child: Text(
                        _countdown > 0
                            ? '${AppLocalizations.of(context)?.translate('resendAfter') ?? 'إعادة الإرسال بعد'} $_countdown ${AppLocalizations.of(context)?.translate('seconds') ?? 'ثانية'}'
                            : (AppLocalizations.of(
                                    context,
                                  )?.translate('resend') ??
                                  'إعادة الإرسال'),
                        style: TextStyle(
                          color: _countdown > 0
                              ? Theme.of(context).textTheme.bodyMedium?.color
                              : AppColors.primary,
                          fontSize: 14.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
