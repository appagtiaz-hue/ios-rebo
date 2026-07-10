import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../constants/colors.dart';
import '../l10n/app_localizations.dart';
import '../models/question.dart';
import '../services/mongodb_question_service.dart';
import '../services/database_service.dart';
import '../models/payment_plan.dart';
import '../utils/network_helper.dart';

class StandardTestScreen extends StatefulWidget {
  final String collectionName;
  final String standardName;
  final String? planId;
  final PaymentPlan? plan;

  const StandardTestScreen({
    super.key,
    required this.collectionName,
    required this.standardName,
    this.planId,
    this.plan,
  });

  @override
  State<StandardTestScreen> createState() => _StandardTestScreenState();
}

class _StandardTestScreenState extends State<StandardTestScreen> {
  List<Question> _questions = [];
  int _currentQuestionIndex = 0;
  int? _selectedAnswerIndex;
  List<int> _userAnswers = [];
  bool _isLoading = true;
  bool _testCompleted = false;
  int _correctAnswers = 0;

  PaymentPlan? _fetchedPlan;

  Color get _primaryColor =>
      widget.plan?.getPrimaryColor() ??
      _fetchedPlan?.getPrimaryColor() ??
      AppColors.primary;
  Color get _secondaryColor =>
      widget.plan?.getSecondaryColor() ??
      _fetchedPlan?.getSecondaryColor() ??
      AppColors.secondary;
  List<Color> get _gradient =>
      widget.plan?.getGradient() ??
      _fetchedPlan?.getGradient() ??
      [AppColors.primary, AppColors.primaryDark, AppColors.secondary];

  @override
  void initState() {
    super.initState();
    super.initState();
    _loadPlanColors();
    _loadQuestions();
  }

  Future<void> _loadPlanColors() async {
    if (widget.plan == null && widget.planId != null) {
      final plan = await DatabaseService.getPlanById(widget.planId);
      if (plan != null && mounted) {
        setState(() {
          _fetchedPlan = plan;
        });
      }
    }
  }

  Future<void> _loadQuestions() async {
    try {
      // Check internet connection first
      final isConnected = await NetworkHelper.checkConnection(
        context,
        onRetry: () {
          setState(() {
            _isLoading = true;
          });
          _loadQuestions();
        },
      );

      if (!isConnected) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
        return;
      }

      final questions = await MongoQuestionService.getQuestionsByStandard(
        widget.collectionName,
        planId: widget.planId,
      );

      // Shuffle options and questions if desired
      final List<Question> processedQuestions = [];

      for (var q in questions) {
        // Validation to prevent crash if index is out of bounds
        if (q.correctAnswerIndex < 0 ||
            q.correctAnswerIndex >= q.options.length) {
          processedQuestions.add(q);
          continue;
        }

        // Store correct answer text
        final correctAnswer = q.options[q.correctAnswerIndex];

        // Create a copy of options and shuffle
        final shuffledOptions = List<String>.from(q.options)..shuffle();

        // Find new index
        final newIndex = shuffledOptions.indexOf(correctAnswer);

        // Add updated question
        processedQuestions.add(
          q.copyWith(options: shuffledOptions, correctAnswerIndex: newIndex),
        );
      }
      processedQuestions.shuffle();

      if (mounted) {
        setState(() {
          _questions = processedQuestions;
          _userAnswers = List.filled(processedQuestions.length, -1);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(
                    context,
                  )?.translate('errorLoadingQuestions') ??
                  'خطأ في تحميل الأسئلة',
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _selectAnswer(int answerIndex) {
    setState(() {
      _selectedAnswerIndex = answerIndex;
      _userAnswers[_currentQuestionIndex] = answerIndex;
    });
  }

  void _nextQuestion() {
    if (_selectedAnswerIndex != null) {
      final bool isCorrect =
          _selectedAnswerIndex ==
          _questions[_currentQuestionIndex].correctAnswerIndex;

      _showAnswerJustification(_questions[_currentQuestionIndex], isCorrect);
    } else {
      _moveToNextQuestion();
    }
  }

  void _moveToNextQuestion() {
    if (_currentQuestionIndex < _questions.length - 1) {
      setState(() {
        _currentQuestionIndex++;
        _selectedAnswerIndex = _userAnswers[_currentQuestionIndex] != -1
            ? _userAnswers[_currentQuestionIndex]
            : null;
      });
    } else {
      _finishTest();
    }
  }

  void _showAnswerJustification(Question question, bool isCorrect) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24.r),
        ),
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8.w),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isCorrect
                      ? [
                          AppColors.success,
                          AppColors.success.withValues(alpha: 0.7),
                        ]
                      : [
                          AppColors.error,
                          AppColors.error.withValues(alpha: 0.7),
                        ],
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isCorrect ? Icons.check_circle : Icons.cancel,
                color: AppColors.white,
                size: 28.r,
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Text(
                isCorrect
                    ? (AppLocalizations.of(
                            context,
                          )?.translate('correctAnswer') ??
                          'إجابة صحيحة! ✅')
                    : (AppLocalizations.of(context)?.translate('wrongAnswer') ??
                          'إجابة خاطئة ❌'),
                style: TextStyle(
                  color: isCorrect ? AppColors.success : AppColors.error,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.all(16.w),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(
                    color: AppColors.success.withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'الإجابة الصحيحة:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13.sp,
                        color: AppColors.success,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      question.options[question.correctAnswerIndex],
                      style: TextStyle(
                        color: AppColors.success,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (question.answerJustification.isNotEmpty) ...[
                SizedBox(height: 16.h),
                Divider(color: AppColors.border),
                SizedBox(height: 16.h),
                Text(
                  'تبرير الإجابة:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13.sp,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 8.h),
                Container(
                  padding: EdgeInsets.all(16.w),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Text(
                    question.answerJustification,
                    style: TextStyle(
                      fontSize: 12.sp,
                      height: 1.6,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: _gradient),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: TextButton(
              onPressed: () {
                Navigator.pop(context);
                _moveToNextQuestion();
              },
              child: Text(
                AppLocalizations.of(context)?.translate('continue') ?? 'متابعة',
                style: TextStyle(
                  color: AppColors.white,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
        actionsPadding: EdgeInsets.fromLTRB(24.w, 0, 24.w, 20.h),
      ),
    );
  }

  void _finishTest() {
    int correct = 0;
    for (int i = 0; i < _questions.length; i++) {
      if (_userAnswers[i] == _questions[i].correctAnswerIndex) {
        correct++;
      }
    }

    setState(() {
      _correctAnswers = correct;
      _testCompleted = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.standardName,
          style: TextStyle(
            color: AppColors.white,
            fontSize: 16.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: _gradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.white),
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: _primaryColor,
                strokeWidth: 3,
              ),
            )
          : _testCompleted
          ? _buildResultsScreen()
          : _questions.isEmpty
          ? Center(
              child: Text(
                AppLocalizations.of(
                      context,
                    )?.translate('noQuestionsAvailable') ??
                    'لا توجد أسئلة متاحة',
                style: TextStyle(
                  color: Theme.of(context).textTheme.bodyMedium?.color,
                  fontSize: 14.sp,
                ),
              ),
            )
          : _buildQuestionScreen(),
    );
  }

  Widget _buildQuestionScreen() {
    final currentQuestion = _questions[_currentQuestionIndex];
    final progress = (_currentQuestionIndex + 1) / _questions.length;

    return SingleChildScrollView(
      padding: EdgeInsets.all(20.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Progress Card
          Container(
            padding: EdgeInsets.all(20.w),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  _primaryColor.withValues(alpha: 0.1),
                  _secondaryColor.withValues(alpha: 0.1),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20.r),
              border: Border.all(
                color: _primaryColor.withValues(alpha: 0.3),
                width: 1.5,
              ),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16.w,
                        vertical: 8.h,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            _primaryColor,
                            _primaryColor.withOpacity(0.8),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20.r),
                      ),
                      child: Text(
                        '${AppLocalizations.of(context)?.translate('questionCount') ?? 'سؤال'} ${_currentQuestionIndex + 1}/${_questions.length}',
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.bold,
                          color: AppColors.white,
                        ),
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16.w,
                        vertical: 8.h,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20.r),
                        border: Border.all(
                          color: AppColors.warning,
                          width: 1.5,
                        ),
                      ),
                      child: Text(
                        '${(progress * 100).round()}%',
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.bold,
                          color: AppColors.warning,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16.h),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10.r),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: AppColors.lightGrey,
                    valueColor: AlwaysStoppedAnimation<Color>(_secondaryColor),
                    minHeight: 8.h,
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 28.h),

          // Question Card
          Container(
            padding: EdgeInsets.all(24.w),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(24.r),
              boxShadow: [
                BoxShadow(
                  color: _primaryColor.withOpacity(0.15),
                  blurRadius: 20,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(8.w),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.error.withOpacity(0.2),
                            AppColors.warning.withOpacity(0.2),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      child: Icon(
                        Icons.help_outline_rounded,
                        color: AppColors.error,
                        size: 24.r,
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Text(
                        AppLocalizations.of(
                              context,
                            )?.translate('chooseCorrectAnswer') ??
                            'اختر الإجابة الصحيحة:',
                        style: TextStyle(
                          fontSize: 14.sp,
                          color: _primaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 20.h),
                Text(
                  currentQuestion.questionText,
                  style: TextStyle(
                    fontSize: 15.sp,
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                    fontWeight: FontWeight.w600,
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 24.h),

          // Options
          ...List.generate(
            currentQuestion.options.length,
            (index) => _buildAnswerOption(
              index: index,
              text: currentQuestion.options[index],
              isSelected: _selectedAnswerIndex == index,
              onTap: () => _selectAnswer(index),
            ),
          ),

          SizedBox(height: 32.h),

          // Navigation Buttons
          Row(
            children: [
              if (_currentQuestionIndex > 0)
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16.r),
                      border: Border.all(color: _primaryColor, width: 2),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            _currentQuestionIndex--;
                            _selectedAnswerIndex =
                                _userAnswers[_currentQuestionIndex] != -1
                                ? _userAnswers[_currentQuestionIndex]
                                : null;
                          });
                        },
                        borderRadius: BorderRadius.circular(16.r),
                        child: Container(
                          padding: EdgeInsets.symmetric(vertical: 16.h),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.arrow_back_rounded,
                                color: _primaryColor,
                                size: 20.r,
                              ),
                              SizedBox(width: 8.w),
                              Text(
                                AppLocalizations.of(
                                      context,
                                    )?.translate('previous') ??
                                    'السابق',
                                style: TextStyle(
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.bold,
                                  color: _primaryColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              if (_currentQuestionIndex > 0) SizedBox(width: 16.w),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: _selectedAnswerIndex != null
                          ? [_secondaryColor, _secondaryColor.withOpacity(0.8)]
                          : [AppColors.grey, AppColors.grey],
                    ),
                    borderRadius: BorderRadius.circular(16.r),
                    boxShadow: _selectedAnswerIndex != null
                        ? [
                            BoxShadow(
                              color: _secondaryColor.withOpacity(0.4),
                              blurRadius: 12,
                              offset: Offset(0, 6),
                            ),
                          ]
                        : [],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _selectedAnswerIndex != null
                          ? _nextQuestion
                          : null,
                      borderRadius: BorderRadius.circular(16.r),
                      child: Container(
                        padding: EdgeInsets.symmetric(vertical: 16.h),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _currentQuestionIndex == _questions.length - 1
                                  ? (AppLocalizations.of(
                                          context,
                                        )?.translate('finishTest') ??
                                        'إنهاء الاختبار')
                                  : (AppLocalizations.of(
                                          context,
                                        )?.translate('next') ??
                                        'التالي'),
                              style: TextStyle(
                                fontSize: 14.sp,
                                fontWeight: FontWeight.bold,
                                color: AppColors.white,
                              ),
                            ),
                            SizedBox(width: 8.w),
                            Icon(
                              _currentQuestionIndex == _questions.length - 1
                                  ? Icons.check_circle_outline_rounded
                                  : Icons.arrow_forward_rounded,
                              color: AppColors.white,
                              size: 20.r,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAnswerOption({
    required int index,
    required String text,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final optionColors = [
      _primaryColor,
      _secondaryColor,
      AppColors.error,
      AppColors.warning,
    ];
    final optionColor = optionColors[index % optionColors.length];

    return Container(
      margin: EdgeInsets.only(bottom: 14.h),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18.r),
          child: AnimatedContainer(
            duration: Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            padding: EdgeInsets.all(18.w),
            decoration: BoxDecoration(
              gradient: isSelected
                  ? LinearGradient(
                      colors: [optionColor, optionColor.withValues(alpha: 0.8)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              color: isSelected ? null : Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(18.r),
              border: Border.all(
                color: isSelected
                    ? optionColor
                    : Theme.of(context).dividerColor.withOpacity(0.1),
                width: isSelected ? 2.5 : 1.5,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: optionColor.withOpacity(0.4),
                        blurRadius: 16,
                        offset: Offset(0, 8),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8,
                        offset: Offset(0, 4),
                      ),
                    ],
            ),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: Duration(milliseconds: 300),
                  width: 28.w,
                  height: 28.w,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: isSelected
                        ? LinearGradient(
                            colors: [
                              AppColors.white,
                              AppColors.white.withValues(alpha: 0.9),
                            ],
                          )
                        : null,
                    color: isSelected ? null : optionColor.withOpacity(0.1),
                    border: Border.all(
                      color: isSelected ? AppColors.white : optionColor,
                      width: 2.5,
                    ),
                  ),
                  child: isSelected
                      ? Icon(
                          Icons.check_rounded,
                          size: 18.r,
                          color: optionColor,
                        )
                      : null,
                ),
                SizedBox(width: 14.w),
                Expanded(
                  child: Text(
                    text,
                    style: TextStyle(
                      fontSize: 13.sp,
                      color: isSelected
                          ? AppColors.white
                          : Theme.of(context).textTheme.bodyLarge?.color,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.w500,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResultsScreen() {
    final percentage = (_correctAnswers / _questions.length * 100).round();

    Color resultColor = percentage >= 80
        ? _secondaryColor
        : percentage >= 60
        ? AppColors.warning
        : AppColors.error;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          AppLocalizations.of(context)?.translate('testResult') ??
              'نتيجة الاختبار',
          style: TextStyle(color: AppColors.white, fontWeight: FontWeight.bold),
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
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Result Card
            Container(
              padding: EdgeInsets.all(32.w),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [resultColor, resultColor.withOpacity(0.7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(28.r),
                boxShadow: [
                  BoxShadow(
                    color: resultColor.withOpacity(0.4),
                    blurRadius: 24.r,
                    offset: Offset(0, 12.h),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    padding: EdgeInsets.all(20.w),
                    decoration: BoxDecoration(
                      color: AppColors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.emoji_events_rounded,
                      size: 72.r,
                      color: AppColors.white,
                    ),
                  ),
                  SizedBox(height: 24.h),
                  Text(
                    AppLocalizations.of(context)?.translate('testCompleted') ??
                        'تم إكمال الاختبار!',
                    style: TextStyle(
                      fontSize: 22.sp,
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 12.h),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 24.w,
                      vertical: 12.h,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.white.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(20.r),
                    ),
                    child: Text(
                      'نسبتك: $percentage%',
                      style: TextStyle(
                        fontSize: 28.sp,
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 40.h),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.white,
                padding: EdgeInsets.symmetric(vertical: 16.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16.r),
                ),
                elevation: 4,
                shadowColor: AppColors.primary.withOpacity(0.4),
              ),
              child: Text(
                'العودة للقائمة',
                style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
