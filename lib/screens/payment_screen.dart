import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../constants/colors.dart';
import '../models/payment_plan.dart';
import '../models/user.dart';
import '../services/database_service.dart';
import '../services/mongodb_question_service.dart';
import '../widgets/shimmer_loading.dart';

import '../l10n/app_localizations.dart';

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  List<PaymentPlan> _plans = [];
  PaymentPlan? _selectedPlan;
  bool _isLoading = true;
  User? _currentUser;

  @override
  void initState() {
    super.initState();
    _loadPlansAndUser();
  }

  Future<void> _loadPlansAndUser() async {
    await DatabaseService.refreshCurrentUser();
    final plans = await DatabaseService.getPaymentPlans();
    final user = await DatabaseService.getCurrentUser();

    // Fetch additional tests
    final additionalTests = await MongoQuestionService.getAdditionalTests();

    // Map additional tests to PaymentPlan
    final testPlans = additionalTests.map((t) {
      return PaymentPlan(
        id: t['id'],
        name: t['nameAr'] ?? t['name'],
        nameEn: t['nameEn'] ?? '',
        description: t['descriptionAr'] ?? t['description'] ?? '',
        descriptionEn: t['descriptionEn'] ?? '',
        questionCount:
            (t['examQuestionCount'] != null &&
                (t['examQuestionCount'] as num) > 0)
            ? (t['examQuestionCount'] as num).toInt()
            : (t['questionCount'] ?? 0),
        price: (t['price'] as num?)?.toDouble() ?? 0.0,
        currency: 'ر.س',
        isActive: t['isActive'] ?? true,
      );
    }).toList();

    if (!mounted) return;

    // Show ALL active plans from database + additional tests
    final activePlans = plans.where((plan) => plan.isActive).toList();
    activePlans.addAll(testPlans);

    setState(() {
      _plans = activePlans;
      _currentUser = user;
      _isLoading = false;
    });
  }

  void _proceed() async {
    if (_selectedPlan == null) return;

    if (_currentUser != null &&
        _hasActiveSubscriptionForPlan(_selectedPlan!.id)) {
      // User has active subscription to this plan - go to exam
      if (_selectedPlan!.name.contains('إضافي') ||
          _selectedPlan!.name.contains('Additional')) {
        Navigator.pushNamed(
          context,
          '/additionalTest',
          arguments: {
            'testId': _selectedPlan!.id,
            'title': _selectedPlan!.getName(context),
            'questionCount':
                _selectedPlan!.questionCount, // Added questionCount
          },
        );
      } else {
        Navigator.pushNamed(
          context,
          '/examList',
          arguments: {
            'planId': _selectedPlan!.id,
            'planName': _selectedPlan!.name,
            'totalQuestions': _selectedPlan!.questionCount,
          },
        );
      }
    } else {
      // User does not have this plan - proceed to payment
      Navigator.pushNamed(context, '/paymentDetails', arguments: _selectedPlan);
    }
  }

  bool _hasActiveSubscriptionForPlan(String planId) {
    if (_currentUser?.subscriptionPlanId == null) {
      print('DEBUG: No subscriptionPlanId');
      return false;
    }

    print('DEBUG: User Plan ID: ${_currentUser?.subscriptionPlanId}');
    print('DEBUG: Selected Plan ID: $planId');

    // Check if IDs match (Main Plan)
    // Lifetime Access - no expiry check
    final isMainMatch = _currentUser!.subscriptionPlanId == planId;
    if (isMainMatch) {
      print('DEBUG: Main Plan ID match (Lifetime)');
      return true;
    }

    // Check Additional Subscriptions
    if (_currentUser!.additionalSubscriptions.isNotEmpty) {
      for (var sub in _currentUser!.additionalSubscriptions) {
        // Handle planId as Map or String
        var subPlanId = sub['planId'];
        String subPlanIdStr = subPlanId is Map
            ? (subPlanId['_id'] ?? subPlanId['id']).toString()
            : subPlanId.toString();

        // Check only if IDs match and is active
        if (subPlanIdStr == planId && sub['isActive'] == true) {
          print('DEBUG: Additional Plan Match found (Lifetime)');
          return true;
        }
      }
    }

    // Check Purchased Tests (One-Time)
    if (_currentUser!.purchasedTests.isNotEmpty) {
      for (var test in _currentUser!.purchasedTests) {
        if (test['testId'] == planId) {
          print('DEBUG: Purchased Test Match found!');
          return true;
        }
      }
    }

    print('DEBUG: No matching active subscription found');
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.primary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          AppLocalizations.of(context)?.translate('payment') ?? 'صفحة الدفع',
          style: TextStyle(
            color: AppColors.primary,
            fontSize: 20.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: AppColors.primary),
            onPressed: () {
              setState(() {
                _isLoading = true;
              });
              _loadPlansAndUser();
            },
          ),
        ],
      ),
      body: _isLoading
          ? Padding(
              padding: EdgeInsets.all(20.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(height: 60.h),
                  ShimmerLoading.planCardShimmer(),
                  ShimmerLoading.planCardShimmer(),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: EdgeInsets.all(20.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  Text(
                    AppLocalizations.of(context)?.translate('selectPlan') ??
                        'اختر الخطة',
                    style: TextStyle(
                      fontSize: 24.sp,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    AppLocalizations.of(context)?.translate('fullAccess') ??
                        'احصل على وصول كامل لجميع المميزات',
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: Theme.of(context).textTheme.bodyMedium?.color,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  SizedBox(height: 30.h),

                  // Plans
                  ..._plans.map((plan) => _buildPlanCard(plan)),

                  SizedBox(height: 30.h),

                  // Proceed Button
                  Container(
                    height: 56.h,
                    decoration: BoxDecoration(
                      gradient: _selectedPlan != null
                          ? LinearGradient(
                              colors: [
                                AppColors.primary,
                                AppColors.primaryDark,
                              ],
                            )
                          : null,
                      color: _selectedPlan == null
                          ? AppColors.grey.withOpacity(0.3)
                          : null,
                      borderRadius: BorderRadius.circular(16.r),
                      boxShadow: _selectedPlan != null
                          ? [
                              BoxShadow(
                                color: AppColors.primary.withOpacity(0.3),
                                blurRadius: 12,
                                offset: Offset(0, 6.h),
                              ),
                            ]
                          : [],
                    ),
                    child: TextButton(
                      onPressed: _selectedPlan == null ? null : _proceed,
                      style: TextButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16.r),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            (_selectedPlan != null &&
                                    _currentUser != null &&
                                    _hasActiveSubscriptionForPlan(
                                      _selectedPlan!.id,
                                    ))
                                ? (AppLocalizations.of(
                                        context,
                                      )?.translate('enterExam') ??
                                      'دخول الاختبار')
                                : (AppLocalizations.of(
                                        context,
                                      )?.translate('proceedToPayment') ??
                                      'المتابعة للدفع'),
                            style: TextStyle(
                              fontSize: 18.sp,
                              fontWeight: FontWeight.bold,
                              color: _selectedPlan != null
                                  ? AppColors.white
                                  : AppColors.grey,
                            ),
                          ),
                          SizedBox(width: 8.w),
                          Icon(
                            Icons.arrow_forward,
                            color: _selectedPlan != null
                                ? AppColors.white
                                : AppColors.grey,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildPlanCard(PaymentPlan plan) {
    final isSelected = _selectedPlan?.id == plan.id;
    final nameLower = plan.name.toLowerCase();

    // Dynamic colors from plan object
    Color accentColor = plan.getPrimaryColor();
    List<Color> gradientColors = [
      plan.getPrimaryColor(),
      plan.getPrimaryColor().withOpacity(0.8),
    ];
    IconData planIcon = Icons.card_membership;

    // Use specific icons if wanted, but rely on backend colors
    if (nameLower.contains('silver') || nameLower.contains('فضي')) {
      planIcon = Icons.star;
    } else if (nameLower.contains('gold') || nameLower.contains('ذهبي')) {
      planIcon = Icons.stars;
    }

    return Container(
      margin: EdgeInsets.only(bottom: 16.h),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => setState(() => _selectedPlan = plan),
          borderRadius: BorderRadius.circular(20.r),
          child: Container(
            padding: EdgeInsets.all(20.w),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(20.r),
              border: Border.all(
                color: isSelected ? AppColors.primary : AppColors.border,
                width: isSelected ? 2.5.w : 1.w,
              ),
              boxShadow: [
                BoxShadow(
                  color: isSelected
                      ? AppColors.primary.withOpacity(0.15)
                      : Colors.black.withOpacity(0.05),
                  blurRadius: isSelected ? 15 : 8,
                  offset: Offset(0, isSelected ? 6 : 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Icon
                    Container(
                      padding: EdgeInsets.all(12.w),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: gradientColors),
                        borderRadius: BorderRadius.circular(14.r),
                        boxShadow: [
                          BoxShadow(
                            color: accentColor.withOpacity(0.3),
                            blurRadius: 8,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(planIcon, color: AppColors.white, size: 24.r),
                    ),
                    SizedBox(width: 12.w),
                    // Plan Name
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            plan.getName(context),
                            style: TextStyle(
                              fontSize: 20.sp,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(
                                context,
                              ).textTheme.bodyLarge?.color,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Selection Indicator
                    if (isSelected)
                      Container(
                        padding: EdgeInsets.all(6.w),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.check,
                          color: AppColors.white,
                          size: 18.r,
                        ),
                      ),
                  ],
                ),

                SizedBox(height: 16.h),

                // Description
                Text(
                  plan.getDescription(context),
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: Theme.of(context).textTheme.bodyMedium?.color,
                  ),
                ),

                SizedBox(height: 16.h),

                // Features
                Row(
                  children: [
                    Icon(
                      Icons.quiz_outlined,
                      size: 18.r,
                      color: AppColors.primary,
                    ),
                    SizedBox(width: 8.w),
                    Text(
                      '${plan.questionCount} ${AppLocalizations.of(context)?.translate('question') ?? 'سؤال'}',
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 12.h),

                // Price
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16.w,
                        vertical: 8.h,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.secondary.withOpacity(0.15),
                            AppColors.secondaryLight.withOpacity(0.15),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12.r),
                        border: Border.all(
                          color: AppColors.secondary.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${plan.price.toStringAsFixed(0)}',
                            style: TextStyle(
                              fontSize: 24.sp,
                              fontWeight: FontWeight.bold,
                              color: AppColors.secondary,
                            ),
                          ),
                          SizedBox(width: 4.w),
                          Text(
                            AppLocalizations.of(
                                  context,
                                )?.translate('currency') ??
                                plan.currency,
                            style: TextStyle(
                              fontSize: 14.sp,
                              color: AppColors.secondaryDark,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
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
