import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../constants/colors.dart';
import '../models/payment_plan.dart';
import 'standard_test_screen.dart';

class CustomTabScreen extends StatelessWidget {
  final PlanTab tab;
  final String planId;
  final PaymentPlan? plan;

  const CustomTabScreen({
    super.key,
    required this.tab,
    required this.planId,
    this.plan,
  });

  @override
  Widget build(BuildContext context) {
    if (tab.sections.isEmpty) {
      return Center(
        child: Text(
          'No sections available',
          style: TextStyle(
            color: Theme.of(context).textTheme.bodyMedium?.color,
            fontSize: 16.sp,
          ),
        ),
      );
    }

    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(20.w),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10.r,
                offset: Offset(0, 5.h),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: (plan?.getPrimaryColor() ?? AppColors.primary)
                      .withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _getIconForTab(tab.icon),
                  color: plan?.getPrimaryColor() ?? AppColors.primary,
                  size: 24.r,
                ),
              ),
              SizedBox(width: 16.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tab.getName(context),
                      style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      '${tab.sections.length} Sections', // You might want to localize this
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: Theme.of(context).textTheme.bodyMedium?.color,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.all(20.w),
            itemCount: tab.sections.length,
            itemBuilder: (context, index) {
              final section = tab.sections[index];
              return _buildSectionCard(context, section);
            },
          ),
        ),
      ],
    );
  }

  IconData _getIconForTab(String iconName) {
    switch (iconName) {
      case 'fa-star':
        return Icons.star_rounded;
      case 'fa-lightbulb':
        return Icons.lightbulb_rounded;
      case 'fa-book':
        return Icons.menu_book_rounded;
      case 'fa-th':
        return Icons.grid_view_rounded;
      default:
        return Icons.folder_rounded;
    }
  }

  Widget _buildSectionCard(BuildContext context, PlanSection section) {
    final sectionName =
        Localizations.localeOf(context).languageCode == 'en' &&
            section.nameEn.isNotEmpty
        ? section.nameEn
        : section.name;

    return Container(
      margin: EdgeInsets.only(bottom: 16.h),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10.r,
            offset: Offset(0, 4.h),
          ),
        ],
        border: Border.all(
          color: (plan?.getPrimaryColor() ?? AppColors.primary).withOpacity(
            0.2,
          ),
          width: 1.w,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            if (section.questionCollectionName != null &&
                section.questionCollectionName!.isNotEmpty) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => StandardTestScreen(
                    collectionName: section.questionCollectionName!,
                    standardName: sectionName,
                    planId: planId,
                    plan: plan,
                  ),
                ),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('No questions initialized for this section'),
                ),
              );
            }
          },
          borderRadius: BorderRadius.circular(16.r),
          child: Padding(
            padding: EdgeInsets.all(16.w),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(12.w),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        (plan?.getPrimaryColor() ?? AppColors.primary)
                            .withOpacity(0.1),
                        (plan?.getPrimaryColor() ?? AppColors.primary)
                            .withOpacity(0.2),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Icon(
                    Icons.quiz_rounded,
                    color: plan?.getPrimaryColor() ?? AppColors.primary,
                    size: 24.r,
                  ),
                ),
                SizedBox(width: 16.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        sectionName,
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).textTheme.bodyLarge?.color,
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        '${section.questionsCount} Questions', // Localize if needed
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: Theme.of(context).textTheme.bodyMedium?.color,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: AppColors.grey,
                  size: 18.r,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
