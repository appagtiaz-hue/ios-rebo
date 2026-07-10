import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../constants/colors.dart';
import '../services/database_service.dart';

class SubscriptionManagerWidget extends StatefulWidget {
  final String userId;
  final VoidCallback? onSubscriptionChanged;

  const SubscriptionManagerWidget({
    super.key,
    required this.userId,
    this.onSubscriptionChanged,
  });

  @override
  State<SubscriptionManagerWidget> createState() =>
      _SubscriptionManagerWidgetState();
}

class _SubscriptionManagerWidgetState extends State<SubscriptionManagerWidget> {
  List<Map<String, dynamic>> _subscriptions = [];
  bool _isLoading = true;
  bool _isSwitching = false;

  @override
  void initState() {
    super.initState();
    _loadSubscriptions();
  }

  Future<void> _loadSubscriptions() async {
    setState(() => _isLoading = true);
    final subs = await DatabaseService.getActiveSubscriptions(widget.userId);
    if (mounted) {
      setState(() {
        _subscriptions = subs;
        _isLoading = false;
      });
    }
  }

  Future<void> _switchSubscription(String planId) async {
    setState(() => _isSwitching = true);

    final success = await DatabaseService.switchActiveSubscription(
      widget.userId,
      planId,
    );

    if (mounted) {
      setState(() => _isSwitching = false);

      if (success) {
        // Reload subscriptions to update UI
        await _loadSubscriptions();

        // Notify parent widget
        widget.onSubscriptionChanged?.call();

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم التبديل بنجاح ✅'),
            backgroundColor: AppColors.primary,
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل التبديل، يرجى المحاولة مرة أخرى'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    if (_subscriptions.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(32.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.workspace_premium_outlined,
                size: 64.r,
                color: AppColors.grey,
              ),
              SizedBox(height: 16.h),
              Text(
                'لا توجد اشتراكات نشطة',
                style: TextStyle(
                  fontSize: 18.sp,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header
        Padding(
          padding: EdgeInsets.all(16.w),
          child: Row(
            children: [
              Icon(Icons.card_membership, color: AppColors.primary, size: 24.r),
              SizedBox(width: 12.w),
              Text(
                'اشتراكاتك النشطة',
                style: TextStyle(
                  fontSize: 20.sp,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),

        // Subscriptions List
        ..._subscriptions.map((sub) => _buildSubscriptionCard(sub)),

        SizedBox(height: 8.h),
      ],
    );
  }

  Widget _buildSubscriptionCard(Map<String, dynamic> subscription) {
    final planName = subscription['planName'] ?? 'خطة غير معروفة';
    final isActive = subscription['isCurrentlyActive'] == true;
    final endDate = subscription['endDate'] != null
        ? DateTime.tryParse(subscription['endDate'].toString())
        : null;
    final formattedDate = endDate != null
        ? '${endDate.year}/${endDate.month}/${endDate.day}'
        : 'غير محدد';

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: isActive ? AppColors.primary : AppColors.border,
          width: isActive ? 2.5.w : 1.w,
        ),
        boxShadow: [
          BoxShadow(
            color: isActive
                ? AppColors.primary.withOpacity(0.15)
                : Colors.black.withOpacity(0.05),
            blurRadius: isActive ? 12 : 6,
            offset: Offset(0, isActive ? 4 : 2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Row(
          children: [
            // Plan Icon
            Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryDark],
                ),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Icon(
                Icons.workspace_premium,
                color: AppColors.white,
                size: 24.r,
              ),
            ),

            SizedBox(width: 12.w),

            // Plan Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          planName,
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      if (isActive) ...[
                        SizedBox(width: 8.w),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8.w,
                            vertical: 4.h,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                          child: Text(
                            'نشط',
                            style: TextStyle(
                              fontSize: 10.sp,
                              fontWeight: FontWeight.bold,
                              color: AppColors.white,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  SizedBox(height: 4.h),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 14.r,
                        color: AppColors.textSecondary,
                      ),
                      SizedBox(width: 4.w),
                      Text(
                        'ينتهي في: $formattedDate',
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Switch Button
            if (!isActive)
              TextButton(
                onPressed: _isSwitching
                    ? null
                    : () => _switchSubscription(subscription['planId']),
                style: TextButton.styleFrom(
                  backgroundColor: AppColors.primary.withOpacity(0.1),
                  foregroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  padding: EdgeInsets.symmetric(
                    horizontal: 12.w,
                    vertical: 8.h,
                  ),
                ),
                child: _isSwitching
                    ? SizedBox(
                        width: 16.w,
                        height: 16.h,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primary,
                        ),
                      )
                    : Text(
                        'تبديل',
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
          ],
        ),
      ),
    );
  }
}
