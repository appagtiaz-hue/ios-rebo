// PaidTestScreen: Modern gradient design with new color scheme
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../constants/colors.dart';
import '../models/question.dart';
import '../services/mongodb_question_service.dart';
import '../services/database_service.dart';
// import '../models/payment_plan.dart'; // Apparently unused or exported by database_service

class PaidTestScreen extends StatefulWidget {
  const PaidTestScreen({super.key});

  @override
  State<PaidTestScreen> createState() => _PaidTestScreenState();
}

class _PaidTestScreenState extends State<PaidTestScreen> {
  List<Question> _questions = [];
  int _currentQuestionIndex = 0;
  int? _selectedAnswerIndex;
  List<int> _userAnswers = [];
  bool _isLoading = true;
  bool _testCompleted = false;
  int _questionCount = 0;
  String _planName = '';
  // Dynamic Colors
  Color _primaryColor = AppColors.primary;
  Color _secondaryColor = AppColors.secondary;
  List<Color> _gradientColors = [
    const Color(0xFF063311),
    const Color(0xFF0D4D2B),
    const Color(0xFF1B5E20),
  ];

  Future<void> _loadPlanColors() async {
    final user = await DatabaseService.getCurrentUser();
    final planId = user?.subscriptionPlanId;
    if (planId != null) {
      final plan = await DatabaseService.getPlanById(planId);
      if (plan != null && mounted) {
        setState(() {
          _primaryColor = plan.getPrimaryColor();
          _secondaryColor = plan.getSecondaryColor();
          _gradientColors = plan.getGradient();
        });
      }
    }
  }

  // New color scheme
  // New color scheme
  // Colors are now used directly from AppColors

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_questions.isNotEmpty) return; // Prevent reloading on rotation/updates
    _loadPlanColors();

    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    _questionCount = (args?['questionCount'] as int?) ?? 20;
    _planName = (args?['planName'] as String?) ?? '';
    _loadQuestions();
  }

  Future<void> _loadQuestions() async {
    try {
      List<Question> loadedQuestions = [];
      final args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      final currentUser = await DatabaseService.getCurrentUser();
      final String? activePlanId =
          (args?['planId'] as String?) ?? currentUser?.subscriptionPlanId;

      // Check if it's a premium plan - get authorized plan questions
      if (_planName.toLowerCase().contains('premium') ||
          _planName.toLowerCase().contains('بريميم') ||
          _planName.toLowerCase().contains('premium')) {
        if (activePlanId != null) {
          final result = await MongoQuestionService.getQuestionsPage(
            1,
            _questionCount > 0 ? _questionCount : 2500,
            planId: activePlanId,
          );
          final all = result['questions'] as List<Question>;
          if (all.isNotEmpty) {
            loadedQuestions = all;
          }
        }
      }

      // Check if it's a segmented exam
      if (loadedQuestions.isEmpty) {
        final int? examIndex = args?['examIndex'];
        final int? totalPlanQuestions = args?['totalPlanQuestions'];
        final String? planId = activePlanId;

        if (examIndex != null && totalPlanQuestions != null && planId != null) {
          if (currentUser != null) {
            // Get ALL questions for the plan (fixed order)
            final allQuestions = await DatabaseService.getFixedPlanQuestions(
              userId: currentUser.id, // Use actual user ID
              planId: planId,
              questionCount: totalPlanQuestions,
            );

            // Slice the questions for this specific exam
            final startIndex = examIndex * _questionCount;
            final endIndex = (startIndex + _questionCount) > allQuestions.length
                ? allQuestions.length
                : (startIndex + _questionCount);

            if (startIndex < allQuestions.length) {
              loadedQuestions = allQuestions.sublist(startIndex, endIndex);
            }
          }
        }
      }

      // Fallback to random questions if not segmented or error
      if (loadedQuestions.isEmpty) {
        loadedQuestions = await MongoQuestionService.getRandomQuestions(
          _questionCount,
          planId: activePlanId,
        );
      }

      // Shuffle options for all loaded questions
      final List<Question> processedQuestions = [];
      for (var question in loadedQuestions) {
        // Create a modifiable list of options
        var options = List<String>.from(question.options);
        String correctAnswer = options[question.correctAnswerIndex];

        // Shuffle options
        options.shuffle();

        // Find new index of the correct answer
        int newCorrectIndex = options.indexOf(correctAnswer);

        if (newCorrectIndex != -1) {
          processedQuestions.add(
            question.copyWith(
              options: options,
              correctAnswerIndex: newCorrectIndex,
            ),
          );
        } else {
          // Fallback if something goes wrong (shouldn't happen)
          processedQuestions.add(question);
        }
      }

      // Shuffle the questions themselves if needed
      if (!(_planName.toLowerCase().contains('premium') ||
          _planName.toLowerCase().contains('بريميم') ||
          _planName.toLowerCase().contains('premium'))) {
        // Only shuffle question order if NOT premium/fixed (optional, depending on requirements)
        // StandardTestScreen shuffles questions too.
        // But Segmented exams usually have fixed order?
        // The previous code didn't shuffle questions except implicitly by "random questions" source.
        // I will leave question order as retrieved, but shuffle options.
        // Actually, usually we want to shuffle questions too for random tests.
        // But for Segmented (FixedPlanQuestions), we probably want to keep them in order?
        // The original code fell back to random questions which are random.
        // I will primarily stick to shuffling OPTIONS as requested.
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
            content: Text('خطأ في تحميل الأسئلة'),
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

      // عرض الـ popup مع تبرير الإجابة
      _showAnswerJustification(_questions[_currentQuestionIndex], isCorrect);
    } else {
      // إذا لم يختر إجابة، انتقل للسؤال التالي مباشرة
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
        backgroundColor: Theme.of(context).cardColor,
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
                isCorrect ? 'إجابة صحيحة! ✅' : 'إجابة خاطئة ❌',
                style: TextStyle(
                  color: isCorrect ? AppColors.success : AppColors.error,
                  fontSize: 18.sp,
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
                        fontSize: 15.sp,
                        color: AppColors.success,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      question.options[question.correctAnswerIndex],
                      style: TextStyle(
                        color: AppColors.success,
                        fontSize: 16.sp,
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
                    fontSize: 15.sp,
                    color: Theme.of(context).textTheme.bodyLarge?.color,
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
                      fontSize: 14.sp,
                      height: 1.6,
                      color: Theme.of(context).textTheme.bodyMedium?.color,
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
              gradient: LinearGradient(
                colors: [_primaryColor, _primaryColor.withOpacity(0.8)],
              ),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: TextButton(
              onPressed: () {
                Navigator.pop(context);
                _moveToNextQuestion();
              },
              child: Text(
                'متابعة',
                style: TextStyle(
                  color: AppColors.white,
                  fontSize: 16.sp,
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
    for (int i = 0; i < _questions.length; i++) {
      if (_userAnswers[i] == _questions[i].correctAnswerIndex) {
        // Count correct answers if needed
      }
    }
    setState(() {
      _testCompleted = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: _gradientColors,
            ),
          ),
          child: Center(
            child: CircularProgressIndicator(
              color: AppColors.white,
              strokeWidth: 3,
            ),
          ),
        ),
      );
    }

    if (_testCompleted) {
      return _buildResultsScreen();
    }

    if (_questions.isEmpty) {
      return Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: _gradientColors,
            ),
          ),
          child: Center(
            child: Text(
              'لا توجد أسئلة متاحة',
              style: TextStyle(color: AppColors.white, fontSize: 18.sp),
            ),
          ),
        ),
      );
    }

    final currentQuestion = _questions[_currentQuestionIndex];

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: _gradientColors,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Custom AppBar
              Padding(
                padding: EdgeInsets.all(16.w),
                child: Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12.r),
                        border: Border.all(
                          color: AppColors.white.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: IconButton(
                        icon: Icon(
                          Icons.arrow_back,
                          color: AppColors.white,
                          size: 22.r,
                        ),
                        onPressed: () => Navigator.pop(context),
                        padding: EdgeInsets.all(8.w),
                        constraints: BoxConstraints(),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        'اختبار $_planName',
                        style: TextStyle(
                          color: AppColors.white,
                          fontSize: 20.sp,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16.w,
                        vertical: 8.h,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            _secondaryColor,
                            _secondaryColor.withOpacity(0.8),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20.r),
                        boxShadow: [
                          BoxShadow(
                            color: _secondaryColor.withOpacity(0.3),
                            blurRadius: 8,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Text(
                        '${_currentQuestionIndex + 1}/${_questions.length}',
                        style: TextStyle(
                          color: AppColors.white,
                          fontSize: 14.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Progress bar
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 24.w),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10.r),
                  child: LinearProgressIndicator(
                    value: (_currentQuestionIndex + 1) / _questions.length,
                    backgroundColor: AppColors.white.withOpacity(0.3),
                    valueColor: AlwaysStoppedAnimation<Color>(_secondaryColor),
                    minHeight: 8.h,
                  ),
                ),
              ),

              SizedBox(height: 24.h),

              // Content
              Expanded(
                child: Container(
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
                        // Question card
                        Container(
                          padding: EdgeInsets.all(24.w),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                _primaryColor.withOpacity(0.1),
                                _secondaryColor.withOpacity(0.1),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(20.r),
                            border: Border.all(
                              color: _primaryColor.withOpacity(0.3),
                              width: 2,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 12.w,
                                      vertical: 6.h,
                                    ),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          _primaryColor,
                                          _secondaryColor,
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(12.r),
                                    ),
                                    child: Text(
                                      'السؤال ${_currentQuestionIndex + 1}',
                                      style: TextStyle(
                                        fontSize: 12.sp,
                                        color: AppColors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 16.h),
                              Text(
                                currentQuestion.questionText,
                                style: TextStyle(
                                  fontSize: 18.sp,
                                  color: Theme.of(
                                    context,
                                  ).textTheme.bodyLarge?.color,
                                  fontWeight: FontWeight.w600,
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),

                        SizedBox(height: 32.h),

                        Text(
                          'اختر الإجابة الصحيحة:',
                          style: TextStyle(
                            fontSize: 16.sp,
                            color: Theme.of(context).textTheme.bodyLarge?.color,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        SizedBox(height: 20.h),

                        // Answer options
                        ...List.generate(
                          currentQuestion.options.length,
                          (index) => _buildAnswerOption(
                            index: index,
                            text: currentQuestion.options[index],
                            isSelected: _selectedAnswerIndex == index,
                            onTap: () => _selectAnswer(index),
                          ),
                        ),

                        SizedBox(height: 40.h),

                        // Navigation buttons
                        Row(
                          children: [
                            if (_currentQuestionIndex > 0)
                              Expanded(
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16.r),
                                    border: Border.all(
                                      color: _primaryColor,
                                      width: 2,
                                    ),
                                  ),
                                  child: TextButton(
                                    onPressed: () {
                                      setState(() {
                                        _currentQuestionIndex--;
                                        _selectedAnswerIndex =
                                            _userAnswers[_currentQuestionIndex] !=
                                                -1
                                            ? _userAnswers[_currentQuestionIndex]
                                            : null;
                                      });
                                    },
                                    style: TextButton.styleFrom(
                                      padding: EdgeInsets.symmetric(
                                        vertical: 16.h,
                                      ),
                                    ),
                                    child: Text(
                                      'السابق',
                                      style: TextStyle(
                                        fontSize: 16.sp,
                                        fontWeight: FontWeight.bold,
                                        color: _primaryColor,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            if (_currentQuestionIndex > 0)
                              SizedBox(width: 16.w),
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: _selectedAnswerIndex != null
                                        ? [
                                            _primaryColor,
                                            _primaryColor.withOpacity(0.8),
                                          ]
                                        : [AppColors.grey, AppColors.grey],
                                  ),
                                  borderRadius: BorderRadius.circular(16.r),
                                  boxShadow: _selectedAnswerIndex != null
                                      ? [
                                          BoxShadow(
                                            color: _primaryColor.withOpacity(
                                              0.4,
                                            ),
                                            blurRadius: 12,
                                            offset: Offset(0, 6),
                                          ),
                                        ]
                                      : [],
                                ),
                                child: TextButton(
                                  onPressed: _selectedAnswerIndex != null
                                      ? _nextQuestion
                                      : null,
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.symmetric(
                                      vertical: 16.h,
                                    ),
                                  ),
                                  child: Text(
                                    _currentQuestionIndex ==
                                            _questions.length - 1
                                        ? 'إنهاء الاختبار'
                                        : 'التالي',
                                    style: TextStyle(
                                      fontSize: 16.sp,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.white,
                                    ),
                                  ),
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnswerOption({
    required int index,
    required String text,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final colors = [
      _secondaryColor,
      _secondaryColor.withOpacity(0.8),
      _primaryColor,
      _primaryColor.withOpacity(0.8),
    ];
    final borderColor = colors[index % colors.length];

    return Container(
      margin: EdgeInsets.only(bottom: 16.h),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16.r),
          child: Container(
            padding: EdgeInsets.all(20.w),
            decoration: BoxDecoration(
              gradient: isSelected
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [_primaryColor, _primaryColor.withOpacity(0.8)],
                    )
                  : null,
              color: isSelected ? null : Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(
                color: isSelected
                    ? Colors.transparent
                    : borderColor.withOpacity(0.4),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: isSelected
                      ? _primaryColor.withOpacity(0.3)
                      : borderColor.withOpacity(0.1),
                  blurRadius: isSelected ? 12 : 8,
                  offset: Offset(0, isSelected ? 6 : 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 28.w,
                  height: 28.w,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: isSelected
                        ? LinearGradient(
                            colors: [AppColors.white, AppColors.white],
                          )
                        : LinearGradient(
                            colors: [
                              borderColor.withOpacity(0.2),
                              borderColor.withOpacity(0.1),
                            ],
                          ),
                    border: Border.all(
                      color: isSelected ? AppColors.white : borderColor,
                      width: 2,
                    ),
                  ),
                  child: isSelected
                      ? Icon(Icons.check, size: 18.r, color: _primaryColor)
                      : null,
                ),
                SizedBox(width: 16.w),
                Expanded(
                  child: Text(
                    text,
                    style: TextStyle(
                      fontSize: 16.sp,
                      color: isSelected
                          ? AppColors.white
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
    final wrongIndexes = <int>[];
    int correctCount = 0;
    for (int i = 0; i < _questions.length; i++) {
      if (_userAnswers[i] == _questions[i].correctAnswerIndex) {
        correctCount++;
      } else {
        wrongIndexes.add(i);
      }
    }

    final percentage = (correctCount / _questions.length * 100).toStringAsFixed(
      1,
    );

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_primaryColor, _primaryColor.withOpacity(0.8)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.all(16.w),
                child: Text(
                  'نتيجة الاختبار',
                  style: TextStyle(
                    color: AppColors.white,
                    fontSize: 24.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(30.r),
                      topRight: Radius.circular(30.r),
                    ),
                  ),
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(24.w),
                    child: Column(
                      children: [
                        Container(
                          padding: EdgeInsets.all(32.w),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppColors.secondary.withOpacity(0.2),
                                AppColors.secondaryLight.withOpacity(0.2),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(20.r),
                          ),
                          child: Column(
                            children: [
                              Text(
                                'درجتك',
                                style: TextStyle(
                                  fontSize: 18.sp,
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              SizedBox(height: 16.h),
                              Text(
                                '$correctCount من ${_questions.length}',
                                style: TextStyle(
                                  fontSize: 48.sp,
                                  fontWeight: FontWeight.bold,
                                  foreground: Paint()
                                    ..shader =
                                        LinearGradient(
                                          colors: [
                                            AppColors.primary,
                                            AppColors.secondary,
                                          ],
                                        ).createShader(
                                          Rect.fromLTWH(0, 0, 200, 70),
                                        ),
                                ),
                              ),
                              Text(
                                '$percentage%',
                                style: TextStyle(
                                  fontSize: 24.sp,
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 32.h),

                        // Show Report Button
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: AppColors.white,
                            borderRadius: BorderRadius.circular(16.r),
                            border: Border.all(
                              color: AppColors.primary,
                              width: 2,
                            ),
                          ),
                          child: TextButton(
                            onPressed: () {
                              Navigator.pushNamed(
                                context,
                                '/testReport',
                                arguments: {
                                  'questions': _questions,
                                  'userAnswers': _userAnswers,
                                },
                              );
                            },
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.symmetric(vertical: 16.h),
                            ),
                            child: Text(
                              'عرض تقرير الإجابات',
                              style: TextStyle(
                                fontSize: 18.sp,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: 16.h),

                        // Back Button
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppColors.primary,
                                AppColors.primaryDark,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(16.r),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withOpacity(0.4),
                                blurRadius: 12,
                                offset: Offset(0, 6),
                              ),
                            ],
                          ),
                          child: TextButton(
                            onPressed: () {
                              Navigator.pop(context);
                            },
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.symmetric(vertical: 16.h),
                            ),
                            child: Text(
                              'العودة للقائمة',
                              style: TextStyle(
                                fontSize: 18.sp,
                                fontWeight: FontWeight.bold,
                                color: AppColors.white,
                              ),
                            ),
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
