import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../models/payment_plan.dart';
import '../models/user.dart';
import '../services/database_service.dart';
import '../services/in_app_purchase_service.dart';
import '../constants/colors.dart';
import '../l10n/app_localizations.dart';

class PaymentDetailsScreen extends StatefulWidget {
  final PaymentPlan selectedPlan;

  const PaymentDetailsScreen({Key? key, required this.selectedPlan})
    : super(key: key);

  @override
  State<PaymentDetailsScreen> createState() => _PaymentDetailsScreenState();
}

class _PaymentDetailsScreenState extends State<PaymentDetailsScreen> {
  // Dynamic theme colors from plan
  Color get _primaryColor => widget.selectedPlan.getPrimaryColor();
  Color get _secondaryColor => widget.selectedPlan.getSecondaryColor();
  List<Color> get _gradient => widget.selectedPlan.getGradient();

  User? _currentUser;
  bool _isProcessing = false;
  bool get _isGooglePlayBillingPlatform => Platform.isAndroid;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
    // Set callbacks for IAP
    InAppPurchaseService.instance.setCallbacks(
      onStatus: (message, isError) {
        if (!mounted) return;
        setState(
          () => _isProcessing =
              !isError &&
              message != 'Purchase verified!' &&
              message != 'Store Error: Purchase failed: null',
        ); // Stop processing only on error or final success

        if (isError) {
          _showErrorDialog('Purchase Status', message);
          setState(() => _isProcessing = false);
        } else if (message == 'Purchase verified!') {
          // Handle success (already handled by onSuccess but good to have feedback)
        }
      },
      onSuccess: (transactionId, productId) {
        if (!mounted) return;
        setState(() => _isProcessing = false);

        // Security/Logic Check: Only process as current plan success if the product IDs match
        final bool isCurrentPlan = productId == _resolveGooglePlayProductId();

        if (isCurrentPlan) {
          _handlePaymentSuccess(transactionId);
        } else {
          // It was a different plan. We should still sync from server to updated local state
          DatabaseService.refreshCurrentUser().then((_) {
            if (mounted) {
              _loadCurrentUser();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('تمت استعادة مشترياتك الأخرى بنجاح'),
                  backgroundColor: AppColors.secondary,
                ),
              );
            }
          });
        }
      },
    );
  }

  Future<void> _loadCurrentUser() async {
    final user = await DatabaseService.getCurrentUser();
    if (mounted) {
      setState(() {
        _currentUser = user;
      });
    }
  }

  Future<void> _restorePurchase() async {
    if (!_isGooglePlayBillingPlatform) {
      _showErrorDialog('iOS', 'المشتريات غير متاحة حالياً على iOS');
      return;
    }

    setState(() => _isProcessing = true);
    try {
      await InAppPurchaseService.instance.restorePurchases();
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        _showErrorDialog('Restore Error', e.toString());
      }
    }
  }

  Future<void> _handlePaymentSuccess(String transactionId) async {
    print('\n🎉 ========== PAYMENT SUCCESS HANDLER ==========');
    print('📝 Transaction ID: $transactionId');
    print('👤 Current User: ${_currentUser?.email ?? "NULL"}');
    print('📦 Selected Plan ID: ${widget.selectedPlan.id}');
    print('📦 Selected Plan Name: ${widget.selectedPlan.name}');

    // Show immediate success message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 8.w),
            SizedBox(width: 8.w),
            Text(
              AppLocalizations.of(
                    context,
                  )?.translate('paymentSuccessMessage') ??
                  'تم الدفع بنجاح! جاري تفعيل الخطة...',
            ),
          ],
        ),
        backgroundColor: AppColors.success,
        duration: Duration(seconds: 2),
      ),
    );

    print('🌐 Syncing authoritative user state from server...');
    await DatabaseService.refreshCurrentUser();
    final refreshedUser = await DatabaseService.getCurrentUser();

    if (refreshedUser != null) {
      print('✅ Local database updated from server');
      if (mounted) {
        setState(() {
          _currentUser = refreshedUser;
        });
      }
    } else {
      print('⚠️ Failed to refresh user from server.');
      // Do NOT fallback to local update using widget.selectedPlan.id as it's unsafe.
      // Instead, show a warning that verification requires sync.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تم تفعيل الخطة في السيرفر، يرجى إعادة تشغيل التطبيق للمزامنة',
          ),
        ),
      );
    }

    print('🎊 Showing success dialog');
    _showSuccessDialog(
      AppLocalizations.of(context)?.translate('paymentSuccess') ??
          'تم الدفع بنجاح',
      transactionId,
    );
    print('==============================================\n');
  }

  void _showSuccessDialog(String message, String transactionId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.r),
        ),
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8.w),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_circle,
                color: AppColors.success,
                size: 28.r,
              ),
            ),
            SizedBox(width: 12.w),
            Text(
              AppLocalizations.of(context)?.translate('paymentSuccess') ??
                  'تم الدفع بنجاح!',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
                fontSize: 18.sp,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message, style: TextStyle(fontSize: 15.sp)),
            SizedBox(height: 16.h),
            if (transactionId.isNotEmpty)
              Container(
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12.sp),
                ),
                child: Text(
                  '${AppLocalizations.of(context)?.translate('transactionId') ?? 'رقم العملية'}: $transactionId',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.secondary,
                    fontSize: 14.sp,
                  ),
                ),
              ),
            SizedBox(height: 16.h),
            Text(
              AppLocalizations.of(
                    context,
                  )?.translate('accessPaidTestMessage') ??
                  'يمكنك الآن الوصول إلى الاختبار المدفوع',
              style: TextStyle(color: Colors.grey[600], fontSize: 14.sp),
            ),
          ],
        ),
        actions: [
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.primaryDark],
              ),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _navigateToTest();
              },
              child: Text(
                AppLocalizations.of(context)?.translate('startTest') ??
                    'ابدأ الاختبار',
                style: TextStyle(
                  color: AppColors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16.sp,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Theme.of(context).cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.sp),
          ),
          title: Row(
            children: [
              Container(
                padding: EdgeInsets.all(8.w),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.error, color: AppColors.error, size: 28.r),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: AppColors.error,
                    fontWeight: FontWeight.bold,
                    fontSize: 16.sp,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: 200.h, maxWidth: 300.w),
            child: SingleChildScrollView(
              child: Text(
                message,
                softWrap: true,
                textAlign: Directionality.of(context) == TextDirection.rtl
                    ? TextAlign.right
                    : TextAlign.left,
                style: TextStyle(fontSize: 14.sp),
              ),
            ),
          ),
          actions: [
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryDark],
                ),
                borderRadius: BorderRadius.circular(12.sp),
              ),
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  AppLocalizations.of(context)?.translate('ok') ?? 'حسناً',
                  style: TextStyle(color: AppColors.white, fontSize: 16.sp),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _navigateToTest() {
    Navigator.pushReplacementNamed(
      context,
      '/examList',
      arguments: {
        'planId': widget.selectedPlan.id,
        'planName': widget.selectedPlan.name,
        'totalQuestions': _getDisplayQuestions(widget.selectedPlan),
        'plan': widget.selectedPlan, // Pass plan for theming
      },
    );
  }

  Widget _buildSummaryRow(
    String label,
    String value,
    Color valueColor, {
    bool isTotal = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 16.sp : 14.sp,
              color: Theme.of(context).textTheme.bodyMedium?.color,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        SizedBox(width: 8.w),
        Text(
          value,
          style: TextStyle(
            fontSize: isTotal ? 18.sp : 14.sp,
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  double _getDisplayPrice(PaymentPlan plan) {
    if (plan.id == 'silver') {
      return 100.0;
    } else if (plan.id == 'gold') {
      return 150.0;
    }
    return plan.price;
  }

  int _getDisplayQuestions(PaymentPlan plan) {
    if (plan.id == 'silver') {
      return 1000;
    } else if (plan.id == 'gold') {
      return 2500;
    }
    return plan.questionCount;
  }

  String _paymentButtonText() {
    if (!_isGooglePlayBillingPlatform) {
      return 'المشتريات غير متاحة على iOS';
    }
    return AppLocalizations.of(context)?.translate('subscribeGooglePlay') ??
        'اشترك عبر Google Play';
  }

  String _securePaymentNotice() {
    if (!_isGooglePlayBillingPlatform) {
      return 'المشتريات غير متاحة حالياً على iOS';
    }
    return AppLocalizations.of(context)?.translate('securePaymentNotice') ??
        'سيتم إتمام الدفع عبر Google Play';
  }

  String _resolveGooglePlayProductId() {
    final configuredId = widget.selectedPlan.googlePlayProductId ?? '';
    if (configuredId.isNotEmpty) return configuredId;

    final planId = widget.selectedPlan.id.toLowerCase();
    final planName = widget.selectedPlan.name.toLowerCase();
    if (planId == 'silver' || planName.contains('silver')) {
      return 'agtiaz_silver';
    }
    if (planId == 'gold' || planName.contains('gold')) {
      return 'agtiaz_gold';
    }
    return 'agtiaz_premium';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: _gradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Back Button
              Padding(
                padding: EdgeInsets.all(16.w),
                child: Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(16.r),
                      ),
                      child: IconButton(
                        icon: Icon(Icons.arrow_back, color: AppColors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                    SizedBox(width: 16.w),
                    Text(
                      AppLocalizations.of(
                            context,
                          )?.translate('paymentDetails') ??
                          'تفاصيل الدفع',
                      style: TextStyle(
                        color: AppColors.white,
                        fontSize: 20.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              // Scrollable Content
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(30.r),
                      topRight: Radius.circular(30.r),
                    ),
                  ),
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(24.w),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Plan Summary Card
                        Container(
                          padding: EdgeInsets.all(20.w),
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(20.r),
                            border: Border.all(
                              color: Theme.of(context).dividerColor,
                            ),
                          ),
                          child: Column(
                            children: [
                              Text(
                                AppLocalizations.of(
                                      context,
                                    )?.translate('orderSummary') ??
                                    'ملخص الطلب',
                                style: TextStyle(
                                  fontSize: 18.sp,
                                  fontWeight: FontWeight.bold,
                                  color: _primaryColor,
                                ),
                              ),
                              SizedBox(height: 16.h),
                              _buildSummaryRow(
                                AppLocalizations.of(
                                      context,
                                    )?.translate('planName') ??
                                    'اسم الخطة',
                                widget.selectedPlan.getName(context),
                                Theme.of(context).textTheme.bodyLarge!.color!,
                              ),
                              Divider(height: 24.h),
                              _buildSummaryRow(
                                AppLocalizations.of(
                                      context,
                                    )?.translate('questionCount') ??
                                    'عدد الأسئلة',
                                '${_getDisplayQuestions(widget.selectedPlan)} ${AppLocalizations.of(context)?.translate('question') ?? 'سؤال'}',
                                Theme.of(context).textTheme.bodyMedium!.color!,
                              ),
                              Divider(height: 24.h),
                              _buildSummaryRow(
                                AppLocalizations.of(
                                      context,
                                    )?.translate('total') ??
                                    'الإجمالي',
                                '${_getDisplayPrice(widget.selectedPlan).toStringAsFixed(0)} ${AppLocalizations.of(context)?.translate('currency') ?? widget.selectedPlan.currency}',
                                _primaryColor,
                                isTotal: true,
                              ),
                            ],
                          ),
                        ),

                        SizedBox(height: 32.h),

                        // Pay Button (Google Play)
                        Container(
                          width: double.infinity,
                          height: 56.h,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                _primaryColor,
                                _primaryColor.withOpacity(0.8),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(16.r),
                            boxShadow: [
                              BoxShadow(
                                color: _primaryColor.withOpacity(0.3),
                                blurRadius: 15.r,
                                offset: Offset(0, 8.h),
                              ),
                            ],
                          ),
                          child: ElevatedButton.icon(
                            onPressed: _isProcessing
                                ? null
                                : () async {
                                    if (!_isGooglePlayBillingPlatform) {
                                      _showErrorDialog(
                                        'iOS',
                                        'المشتريات غير متاحة حالياً على iOS',
                                      );
                                      return;
                                    }
                                    setState(() => _isProcessing = true);
                                    try {
                                      final playId =
                                          _resolveGooglePlayProductId();

                                      final products =
                                          await InAppPurchaseService.instance
                                              .loadProducts([playId]);

                                      if (products.isNotEmpty) {
                                        await InAppPurchaseService.instance
                                            .buyProduct(products.first);
                                        // Flow continues in callbacks
                                      } else {
                                        setState(() => _isProcessing = false);
                                        _showErrorDialog(
                                          AppLocalizations.of(
                                                context,
                                              )?.translate('storeError') ??
                                              'خطأ في المتجر',
                                          AppLocalizations.of(
                                                context,
                                              )?.translate(
                                                'productNotFound',
                                              ) ??
                                              'المنتج غير موجود في متجر Google Play',
                                        );
                                      }
                                    } catch (e) {
                                      setState(() => _isProcessing = false);
                                      _showErrorDialog('Error', e.toString());
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16.r),
                              ),
                            ),
                            icon: _isProcessing
                                ? SizedBox(
                                    width: 24.w,
                                    height: 24.w,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5.w,
                                      valueColor:
                                          const AlwaysStoppedAnimation<Color>(
                                            Colors.white,
                                          ),
                                    ),
                                  )
                                : Icon(
                                    _isGooglePlayBillingPlatform
                                        ? Icons.android
                                        : Icons.phone_iphone,
                                    color: Colors.white,
                                    size: 24.r,
                                  ),
                            label: Text(
                              _isProcessing
                                  ? (AppLocalizations.of(
                                          context,
                                        )?.translate('processing') ??
                                        'جاري المعالجة...')
                                  : _paymentButtonText(),
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16.sp,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),

                        SizedBox(height: 16.h),
                        TextButton(
                          onPressed: _isProcessing ? null : _restorePurchase,
                          child: Text(
                            AppLocalizations.of(
                                  context,
                                )?.translate('restorePurchase') ??
                                'استعادة المشتريات (Restore Purchase)',
                            style: TextStyle(
                              color: _primaryColor,
                              fontWeight: FontWeight.bold,
                              decoration: TextDecoration.underline,
                              fontSize: 16.sp,
                            ),
                          ),
                        ),

                        SizedBox(height: 24.h),

                        // Security Notice
                        Container(
                          padding: EdgeInsets.all(16.w),
                          decoration: BoxDecoration(
                            color: _secondaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16.r),
                            border: Border.all(
                              color: _secondaryColor.withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.lock_outline,
                                color: _secondaryColor,
                                size: 24.r,
                              ),
                              SizedBox(width: 12.w),
                              Expanded(
                                child: Text(
                                  _securePaymentNotice(),
                                  style: TextStyle(
                                    fontSize: 13.sp,
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
