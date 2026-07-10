import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../constants/colors.dart';

class AppGuide extends StatelessWidget {
  const AppGuide({super.key});

  static void show(BuildContext context) {
    showDialog(context: context, builder: (context) => const AppGuide());
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
      child: Container(
        padding: EdgeInsets.all(24.w),
        constraints: BoxConstraints(maxHeight: 0.8.sh, maxWidth: 0.9.sw),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(Icons.help_outline, color: AppColors.primary, size: 28.r),
                SizedBox(width: 12.w),
                Text(
                  'دليل التطبيق',
                  style: TextStyle(
                    fontSize: 20.sp,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            SizedBox(height: 20.h),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSpecItem(
                      icon: Icons.quiz,
                      title: 'الأسئلة',
                      description:
                          'أكثر من 1000 سؤال متنوع في مواضيع مختلفة، مع إجابات مفصلة.',
                    ),
                    _buildSpecItem(
                      icon: Icons.offline_pin,
                      title: 'الوضع دون اتصال',
                      description:
                          'دعم كامل للعمل دون إنترنت باستخدام قاعدة بيانات محلية.',
                    ),
                    _buildSpecItem(
                      icon: Icons.payment,
                      title: 'الدفع الآمن',
                      description:
                          'تكامل مع MyFatoorah للدفع الآمن، ندعم MADA وSTC Pay وطرق دفع متعددة.',
                    ),
                    _buildSpecItem(
                      icon: Icons.subscriptions,
                      title: 'الاشتراكات',
                      description:
                          'صلاحية الاشتراك 30 يومًا، مع خيارات متعددة (فضي، ذهبي، بريميوم).',
                    ),
                    _buildSpecItem(
                      icon: Icons.privacy_tip,
                      title: 'الخصوصية',
                      description:
                          'لا نشارك بياناتك مع أي طرف ثالث، جميع البيانات محلية.',
                    ),
                    _buildSpecItem(
                      icon: Icons.access_time,
                      title: 'الاختبارات',
                      description:
                          'اختبارات تجريبية مجانية (5 أسئلة)، ومدفوعة حسب الخطة.',
                    ),
                    _buildSpecItem(
                      icon: Icons.analytics,
                      title: 'النتائج',
                      description: 'تحليل مفصل للنتائج مع إجابات خاطئة وصحيحة.',
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 24.h),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('فهمت', style: TextStyle(fontSize: 16.sp)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpecItem({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 16.h),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(8.w),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Icon(icon, color: AppColors.primary, size: 20.r),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
