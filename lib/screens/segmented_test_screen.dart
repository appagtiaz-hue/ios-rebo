import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../constants/colors.dart';
import '../l10n/app_localizations.dart';
import '../models/question.dart';
import '../models/payment_plan.dart';
import '../services/mongodb_question_service.dart';
import '../services/database_service.dart';
import '../utils/network_helper.dart';

class SegmentedTestScreen extends StatefulWidget {
  final int examNumber;
  final int startQuestion;
  final int endQuestion;
  final String planName;
  final String planId;
  final PaymentPlan? plan; // Add plan for dynamic theming

  const SegmentedTestScreen({
    super.key,
    required this.examNumber,
    required this.startQuestion,
    required this.endQuestion,
    required this.planName,
    required this.planId,
    this.plan, // Optional plan parameter
  });

  @override
  State<SegmentedTestScreen> createState() => _SegmentedTestScreenState();
}

class _SegmentedTestScreenState extends State<SegmentedTestScreen> {
  // Theme colors from plan
  // Theme colors from plan
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

  List<Question> _questions = [];
  int _currentQuestionIndex = 0;
  int? _selectedAnswerIndex;
  List<int> _userAnswers = [];
  bool _isLoading = true;
  bool _testCompleted = false;
  int _correctAnswers = 0;

  @override
  void initState() {
    super.initState();
    _loadPlanColors();
    _loadQuestions();
  }

  Future<void> _loadPlanColors() async {
    if (widget.plan == null && widget.planId.isNotEmpty) {
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

      // Calculate page and limit
      // Page is examNumber, limit is 50
      final result = await MongoQuestionService.getQuestionsPage(
        widget.examNumber,
        50,
        planId: widget.planId,
      );

      final questions = result['questions'] as List<Question>;

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
                      AppLocalizations.of(
                            context,
                          )?.translate('correctAnswerLabel') ??
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
                    color: _primaryColor.withValues(alpha: 0.05),
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

  Future<void> _finishTest() async {
    int correct = 0;
    List<Map<String, dynamic>> mistakes = [];

    for (int i = 0; i < _questions.length; i++) {
      final question = _questions[i];
      final userAnswer = _userAnswers[i];

      if (userAnswer == question.correctAnswerIndex) {
        correct++;
      } else {
        mistakes.add({
          'questionId': question.id,
          'questionText': question.questionText,
          'userAnswer': userAnswer != -1
              ? question.options[userAnswer]
              : (AppLocalizations.of(context)?.translate('notAnswered') ??
                    'لم يتم الإجابة'),
          'correctAnswer': question.options[question.correctAnswerIndex],
          'justification': question.answerJustification,
        });
      }
    }

    setState(() {
      _correctAnswers = correct;
      _testCompleted = true;
      _isLoading = true; // Show loading while saving
    });

    // Save result to backend
    final user = await DatabaseService.getCurrentUser();
    if (user != null) {
      await DatabaseService.saveTestResult(
        userId: user.id,
        examNumber: widget.examNumber,
        score: (correct / _questions.length * 100).round(),
        totalQuestions: _questions.length,
        correctAnswers: correct,
        mistakes: mistakes,
        planId: widget.planId, // Pass planId
      );
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });

      Navigator.pushReplacementNamed(
        context,
        '/testReport',
        arguments: {
          'questions': _questions,
          'userAnswers': _userAnswers,
          'plan': _fetchedPlan ?? widget.plan,
          'planId': widget.planId,
        },
      );
    }
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
          '${widget.planName} - امتحان ${widget.examNumber}',
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
                color: AppColors.primary,
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
                  fontSize: 14.sp,
                  color: Theme.of(context).textTheme.bodyMedium?.color,
                ),
              ),
            )
          : _buildQuestionScreen(),
    );
  }

  Widget _buildQuestionScreen() {
    final currentQuestion = _questions[_currentQuestionIndex];
    final progress = (_currentQuestionIndex + 1) / _questions.length;

    return Column(
      children: [
        // 1. Sleek Top Progress Bar
        Container(
          color: Theme.of(context).cardColor,
          padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 12.h),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${AppLocalizations.of(context)?.translate('questionCount') ?? 'سؤال'} ${_currentQuestionIndex + 1} / ${_questions.length}',
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.bold,
                      color: _primaryColor,
                    ),
                  ),
                  Text(
                    '${(progress * 100).round()}%',
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.bold,
                      color: _secondaryColor,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 10.h),
              ClipRRect(
                borderRadius: BorderRadius.circular(4.r),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: _primaryColor.withOpacity(0.1),
                  valueColor: AlwaysStoppedAnimation<Color>(_primaryColor),
                  minHeight: 6.h,
                ),
              ),
            ],
          ),
        ),

        // 2. Scrollable Content (Question + Options)
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Question Text
                Container(
                  padding: EdgeInsets.all(20.w),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(20.r),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 15,
                        offset: Offset(0, 5),
                      ),
                    ],
                    border: Border.all(
                      color: _primaryColor.withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: EdgeInsets.all(8.w),
                            decoration: BoxDecoration(
                              color: _primaryColor.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.question_mark_rounded,
                              color: _primaryColor,
                              size: 20.r,
                            ),
                          ),
                          SizedBox(width: 12.w),
                          Expanded(
                            child: Text(
                              currentQuestion.questionText,
                              style: TextStyle(
                                fontSize: 16.sp,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(
                                  context,
                                ).textTheme.bodyLarge?.color,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 24.h),

                // Options List
                ...List.generate(
                  currentQuestion.options.length,
                  (index) => _buildAnswerOption(
                    index: index,
                    text: currentQuestion.options[index],
                    isSelected: _selectedAnswerIndex == index,
                    onTap: () => _selectAnswer(index),
                  ),
                ),

                SizedBox(height: 20.h),
              ],
            ),
          ),
        ),

        // 3. Bottom Navigation Bar
        Container(
          padding: EdgeInsets.all(20.w),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 20,
                offset: Offset(0, -5),
              ),
            ],
          ),
          child: SafeArea(
            child: Row(
              children: [
                // Previous Button
                if (_currentQuestionIndex > 0)
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        right: 12.w,
                      ), // Adjust based on RTL
                      child: OutlinedButton(
                        onPressed: () {
                          setState(() {
                            _currentQuestionIndex--;
                            _selectedAnswerIndex =
                                _userAnswers[_currentQuestionIndex] != -1
                                ? _userAnswers[_currentQuestionIndex]
                                : null;
                          });
                        },
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: _primaryColor, width: 2),
                          padding: EdgeInsets.symmetric(vertical: 14.h),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14.r),
                          ),
                        ),
                        child: Icon(
                          Icons.arrow_back_rounded,
                          color: _primaryColor,
                          size: 24.r,
                        ),
                      ),
                    ),
                  ),

                // Next/Finish Button
                Expanded(
                  flex: 2,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14.r),
                      gradient: LinearGradient(
                        colors: _selectedAnswerIndex != null
                            ? _gradient
                            : [Colors.grey.shade400, Colors.grey.shade500],
                      ),
                      boxShadow: _selectedAnswerIndex != null
                          ? [
                              BoxShadow(
                                color: _primaryColor.withOpacity(0.3),
                                blurRadius: 10,
                                offset: Offset(0, 5),
                              ),
                            ]
                          : [],
                    ),
                    child: ElevatedButton(
                      onPressed: _selectedAnswerIndex != null
                          ? _nextQuestion
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        padding: EdgeInsets.symmetric(vertical: 14.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14.r),
                        ),
                      ),
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
                              fontSize: 16.sp,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(width: 8.w),
                          Icon(
                            _currentQuestionIndex == _questions.length - 1
                                ? Icons.check_circle_outline_rounded
                                : Icons.arrow_forward_rounded,
                            color: Colors.white,
                            size: 20.r,
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
      ],
    );
  }

  Widget _buildAnswerOption({
    required int index,
    required String text,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16.r),
          child: AnimatedContainer(
            duration: Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
            decoration: BoxDecoration(
              color: isSelected
                  ? _primaryColor.withOpacity(0.05)
                  : Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(
                color: isSelected
                    ? _primaryColor
                    : Theme.of(context).dividerColor.withOpacity(0.2),
                width: isSelected ? 2 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: isSelected
                      ? _primaryColor.withOpacity(0.1)
                      : Colors.black.withOpacity(0.02),
                  blurRadius: 10,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 24.w,
                  height: 24.w,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected ? _primaryColor : Colors.transparent,
                    border: Border.all(
                      color: isSelected
                          ? _primaryColor
                          : Colors.grey.withOpacity(0.5),
                      width: 2,
                    ),
                  ),
                  child: isSelected
                      ? Icon(Icons.check, size: 14.r, color: Colors.white)
                      : null,
                ),
                SizedBox(width: 14.w),
                Expanded(
                  child: Text(
                    text,
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: isSelected
                          ? _primaryColor
                          : Theme.of(context).textTheme.bodyLarge?.color,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.w500,
                      height: 1.4,
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
        ? AppColors.secondary
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
          AppLocalizations.of(context)?.translate('examResult') ??
              'نتيجة الامتحان',
          style: TextStyle(color: AppColors.white, fontWeight: FontWeight.bold),
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.primary, AppColors.primaryDark],
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
                    blurRadius: 24,
                    offset: Offset(0, 12),
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
                    'تم إكمال الامتحان!',
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
                        fontSize: 20.sp,
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  SizedBox(height: 16.h),
                  Text(
                    'إجابات صحيحة: $_correctAnswers / ${_questions.length}',
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: Colors.black87,
                      fontWeight: FontWeight.w500,
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
                padding: EdgeInsets.symmetric(vertical: 16.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16.r),
                ),
                elevation: 4,
              ),
              child: Text(
                'العودة للقائمة',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                  color: AppColors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
