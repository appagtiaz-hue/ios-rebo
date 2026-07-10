import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../constants/colors.dart';
import '../models/question.dart';
import '../models/payment_plan.dart';
import '../services/database_service.dart';

class TestReportScreen extends StatelessWidget {
  final List<Question> questions;
  final List<int> userAnswers;
  final PaymentPlan? plan;
  final String? planId;

  const TestReportScreen({
    super.key,
    required this.questions,
    required this.userAnswers,
    this.plan,
    this.planId,
  });

  @override
  Widget build(BuildContext context) {
    return _TestReportContent(
      questions: questions,
      userAnswers: userAnswers,
      plan: plan,
      planId: planId,
    );
  }
}

class _TestReportContent extends StatefulWidget {
  final List<Question> questions;
  final List<int> userAnswers;
  final PaymentPlan? plan;
  final String? planId;

  const _TestReportContent({
    required this.questions,
    required this.userAnswers,
    this.plan,
    this.planId,
  });

  @override
  State<_TestReportContent> createState() => _TestReportContentState();
}

class _TestReportContentState extends State<_TestReportContent> {
  PaymentPlan? _fetchedPlan;

  @override
  void initState() {
    super.initState();
    if (widget.plan == null && widget.planId != null) {
      _loadPlan();
    }
  }

  Future<void> _loadPlan() async {
    final plan = await DatabaseService.getPlanById(widget.planId);
    if (plan != null && mounted) {
      setState(() {
        _fetchedPlan = plan;
      });
    }
  }

  Color get _primaryColor =>
      widget.plan?.getPrimaryColor() ??
      _fetchedPlan?.getPrimaryColor() ??
      AppColors.primary;

  List<Color> get _gradient =>
      widget.plan?.getGradient() ??
      _fetchedPlan?.getGradient() ??
      [AppColors.primary, AppColors.primaryDark];

  @override
  Widget build(BuildContext context) {
    int correctCount = 0;
    for (int i = 0; i < widget.questions.length; i++) {
      if (widget.userAnswers[i] == widget.questions[i].correctAnswerIndex) {
        correctCount++;
      }
    }
    final score = (correctCount / widget.questions.length * 100).round();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.close, color: AppColors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'تقرير الاختبار',
          style: TextStyle(
            color: AppColors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20.sp,
          ),
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: _gradient,
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
        ),
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.white),
      ),
      body: Column(
        children: [
          // Score Summary
          Container(
            padding: EdgeInsets.all(20.w),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              boxShadow: [
                BoxShadow(
                  color: AppColors.grey.withOpacity(0.1),
                  blurRadius: 10.r,
                  offset: Offset(0, 5.h),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSummaryItem(
                  context,
                  'النتيجة',
                  '$score%',
                  score >= 50 ? AppColors.success : AppColors.error,
                ),
                _buildSummaryItem(
                  context,
                  'صحيحة',
                  '$correctCount',
                  AppColors.success,
                ),
                _buildSummaryItem(
                  context,
                  'خاطئة',
                  '${widget.questions.length - correctCount}',
                  AppColors.error,
                ),
              ],
            ),
          ),

          // Questions List
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.all(16.w),
              itemCount: widget.questions.length,
              itemBuilder: (context, index) {
                final question = widget.questions[index];
                final userAnswer = widget.userAnswers[index];
                final isCorrect = userAnswer == question.correctAnswerIndex;

                return Card(
                  margin: EdgeInsets.only(bottom: 16.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16.r),
                    side: BorderSide(
                      color: isCorrect
                          ? AppColors.success.withOpacity(0.5)
                          : AppColors.error.withOpacity(0.5),
                      width: 1.5.w,
                    ),
                  ),
                  elevation: 2.r,
                  shadowColor: AppColors.shadow,
                  color: AppColors.white,
                  child: Padding(
                    padding: EdgeInsets.all(16.w),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: EdgeInsets.all(10.w),
                              decoration: BoxDecoration(
                                color: isCorrect
                                    ? AppColors.success.withOpacity(0.1)
                                    : AppColors.error.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                '${index + 1}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isCorrect
                                      ? AppColors.success
                                      : AppColors.error,
                                  fontSize: 16.sp,
                                ),
                              ),
                            ),
                            SizedBox(width: 12.w),
                            Expanded(
                              child: Text(
                                question.questionText,
                                style: TextStyle(
                                  fontSize: 18.sp,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                  height: 1.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 20.h),

                        // Options
                        ...List.generate(question.options.length, (optIndex) {
                          final isSelected = userAnswer == optIndex;
                          final isCorrectOption =
                              question.correctAnswerIndex == optIndex;

                          Color? backgroundColor;
                          Color? textColor = Colors.black;
                          IconData? icon;
                          Color iconColor = Colors.transparent;
                          FontWeight fontWeight = FontWeight.normal;

                          if (isCorrectOption) {
                            backgroundColor = AppColors.success.withOpacity(
                              0.15,
                            );
                            textColor = AppColors.success;
                            icon = Icons.check_circle;
                            iconColor = AppColors.success;
                            fontWeight = FontWeight.bold;
                          } else if (isSelected && !isCorrect) {
                            backgroundColor = AppColors.error.withOpacity(0.15);
                            textColor = AppColors.error;
                            icon = Icons.cancel;
                            iconColor = AppColors.error;
                            fontWeight = FontWeight.bold;
                          }

                          return Container(
                            margin: EdgeInsets.only(bottom: 10.h),
                            padding: EdgeInsets.symmetric(
                              horizontal: 16.w,
                              vertical: 12.h,
                            ),
                            decoration: BoxDecoration(
                              color: backgroundColor ?? AppColors.background,
                              borderRadius: BorderRadius.circular(10.r),
                              border: Border.all(
                                color: backgroundColor != null
                                    ? Colors.transparent
                                    : AppColors.border,
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    question.options[optIndex],
                                    style: TextStyle(
                                      color: textColor,
                                      fontSize: 16.sp,
                                      fontWeight: fontWeight,
                                    ),
                                  ),
                                ),
                                if (icon != null)
                                  Icon(icon, color: iconColor, size: 22.r),
                              ],
                            ),
                          );
                        }),

                        if (question.answerJustification.isNotEmpty) ...[
                          SizedBox(height: 16.h),
                          Container(
                            width: double.infinity,
                            padding: EdgeInsets.all(16.w),
                            decoration: BoxDecoration(
                              color: _primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12.r),
                              border: Border.all(
                                color: _primaryColor.withOpacity(0.3),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.info_outline,
                                      color: _primaryColor,
                                      size: 20.sp,
                                    ),
                                    SizedBox(width: 8.w),
                                    Text(
                                      'توضيح الإجابة:',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: _primaryColor,
                                        fontSize: 14.sp,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 8.h),
                                Text(
                                  question.answerJustification,
                                  style: TextStyle(
                                    color: Colors.black87,
                                    fontSize: 14.sp,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(
    BuildContext context,
    String label,
    String value,
    Color color,
  ) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24.sp,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 14.sp,
            color: Theme.of(context).textTheme.bodyMedium?.color,
          ),
        ),
      ],
    );
  }
}
