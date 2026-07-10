import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../constants/colors.dart';
import '../models/question.dart';
import '../services/mongodb_question_service.dart';
import '../services/network_service.dart';
import '../services/database_service.dart';
// import '../models/payment_plan.dart';

class GoldTestScreen extends StatefulWidget {
  const GoldTestScreen({super.key});

  @override
  State<GoldTestScreen> createState() => _GoldTestScreenState();
}

class _GoldTestScreenState extends State<GoldTestScreen> {
  List<Question> _questions = [];
  int _currentQuestionIndex = 0;
  int? _selectedAnswerIndex;
  List<int> _userAnswers = [];
  bool _isLoading = true;
  bool _testCompleted = false;
  int _correctAnswers = 0;

  // الألوان الجديدة
  // Colors are now used directly from AppColors

  @override
  void initState() {
    super.initState();
    _loadPlanColors();
    _loadGoldQuestions();
  }

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

  Future<void> _loadGoldQuestions() async {
    try {
      // Check internet connection first
      final isConnected = await NetworkService.isConnected();
      if (!isConnected) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          _showNoInternetDialog();
        }
        return;
      }

      final user = await DatabaseService.getCurrentUser();
      final planId = user?.subscriptionPlanId;
      if (planId == null) {
        throw Exception('No active plan selected');
      }

      final questions = await MongoQuestionService.getRandomQuestions(
        2500,
        planId: planId,
      );

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
            content: Text('خطأ في تحميل أسئلة جولد'),
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
                    width: 1.5.w,
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
                      fontSize: 14.sp,
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
              gradient: LinearGradient(
                colors: [_primaryColor, _secondaryColor],
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
    int correct = 0;
    for (int i = 0; i < _questions.length; i++) {
      if (_userAnswers[i] == _questions[i].correctAnswerIndex) correct++;
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
          'الخطة الذهبية - 2500 سؤال',
          style: TextStyle(
            color: AppColors.white,
            fontSize: 20.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: _gradientColors,
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
                strokeWidth: 3.w,
              ),
            )
          : _testCompleted
          ? _buildResultsScreen()
          : _questions.isEmpty
          ? Center(
              child: Text(
                'لا توجد أسئلة متاحة',
                style: TextStyle(
                  color: Theme.of(context).textTheme.bodyMedium?.color,
                  fontSize: 16.sp,
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
                width: 1.5.w,
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
                        'سؤال ${_currentQuestionIndex + 1}/${_questions.length}',
                        style: TextStyle(
                          fontSize: 14.sp,
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
                          width: 1.5.w,
                        ),
                      ),
                      child: Text(
                        '${(progress * 100).round()}%',
                        style: TextStyle(
                          fontSize: 14.sp,
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
                  blurRadius: 20.r,
                  offset: Offset(0, 8.h),
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
                        'اختر الإجابة الصحيحة:',
                        style: TextStyle(
                          fontSize: 16.sp,
                          color: Theme.of(context).textTheme.bodyLarge?.color,
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
                    fontSize: 17.sp,
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
                      border: Border.all(color: _primaryColor, width: 2.w),
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
                                'السابق',
                                style: TextStyle(
                                  fontSize: 16.sp,
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
                              blurRadius: 12.r,
                              offset: Offset(0, 6.h),
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
                                  ? 'إنهاء الاختبار'
                                  : 'التالي',
                              style: TextStyle(
                                fontSize: 16.sp,
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
                color: isSelected ? optionColor : AppColors.border,
                width: isSelected ? 2.5.w : 1.5.w,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: optionColor.withOpacity(0.4),
                        blurRadius: 16.r,
                        offset: Offset(0, 8.h),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8.r,
                        offset: Offset(0, 4.h),
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
                      width: 2.5.w,
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
                      fontSize: 15.sp,
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
    final wrongIndexes = <int>[];
    for (int i = 0; i < _questions.length; i++) {
      if (_userAnswers[i] != _questions[i].correctAnswerIndex)
        wrongIndexes.add(i);
    }

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
          'نتيجة الاختبار - الخطة الذهبية',
          style: TextStyle(color: AppColors.white, fontWeight: FontWeight.bold),
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [_primaryColor, _primaryColor.withOpacity(0.8)],
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
                    'تم إكمال الاختبار!',
                    style: TextStyle(
                      fontSize: 26.sp,
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
                        fontSize: 32.sp,
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  SizedBox(height: 20.h),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildStatItem(
                        icon: Icons.check_circle_rounded,
                        label: 'صحيحة',
                        value: '$_correctAnswers',
                        color: AppColors.white,
                      ),
                      Container(
                        width: 2.w,
                        height: 40.h,
                        color: AppColors.white.withOpacity(0.3),
                      ),
                      _buildStatItem(
                        icon: Icons.cancel_rounded,
                        label: 'خاطئة',
                        value: '${wrongIndexes.length}',
                        color: AppColors.white,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            SizedBox(height: 24.h),

            // Wrong Answers Section
            if (wrongIndexes.isNotEmpty)
              Container(
                padding: EdgeInsets.all(20.w),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(24.r),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.grey.withOpacity(0.1),
                      blurRadius: 16.r,
                      offset: Offset(0, 8.h),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(10.w),
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
                            Icons.error_outline_rounded,
                            color: AppColors.error,
                            size: 24.r,
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: Text(
                            'الأسئلة الخاطئة والإجابات الصحيحة',
                            style: TextStyle(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryDark,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16.h),
                    ...wrongIndexes.map((i) => _wrongItem(i)).toList(),
                  ],
                ),
              ),

            SizedBox(height: 24.h),

            // Finish Button
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryDark],
                ),
                borderRadius: BorderRadius.circular(16.r),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.4),
                    blurRadius: 16.r,
                    offset: Offset(0, 8.h),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () =>
                      Navigator.popUntil(context, ModalRoute.withName('/home')),
                  borderRadius: BorderRadius.circular(16.r),
                  child: Container(
                    padding: EdgeInsets.symmetric(vertical: 18.h),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.home_rounded,
                          color: AppColors.white,
                          size: 24.r,
                        ),
                        SizedBox(width: 12.w),
                        Text(
                          'العودة للرئيسية',
                          style: TextStyle(
                            fontSize: 18.sp,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: Colors.black, size: 28.r),
        SizedBox(height: 8.h),
        Text(
          value,
          style: TextStyle(
            fontSize: 24.sp,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 13.sp, color: Colors.black87),
        ),
      ],
    );
  }

  Widget _wrongItem(int index) {
    final q = _questions[index];
    final userIndex = _userAnswers[index];
    final correctIndex = q.correctAnswerIndex;

    return Container(
      margin: EdgeInsets.only(bottom: 14.h),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.error.withOpacity(0.05),
            AppColors.warning.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: AppColors.error.withOpacity(0.2),
          width: 1.5.w,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Text(
                  'س ${index + 1}',
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: AppColors.error,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Text(
                  q.questionText,
                  style: TextStyle(
                    fontSize: 15.sp,
                    color: Colors.black,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Container(
            padding: EdgeInsets.all(10.w),
            decoration: BoxDecoration(
              color: AppColors.error.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: Row(
              children: [
                Icon(Icons.close_rounded, color: AppColors.error, size: 18.r),
                SizedBox(width: 8.w),
                Expanded(
                  child: Text(
                    'إجابتك: ' +
                        (userIndex >= 0
                            ? q.options[userIndex]
                            : 'لم يتم الاختيار'),
                    style: TextStyle(
                      fontSize: 13.sp,
                      color: AppColors.error,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 8.h),
          Container(
            padding: EdgeInsets.all(10.w),
            decoration: BoxDecoration(
              color: AppColors.secondary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.secondary,
                  size: 18.r,
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: Text(
                    'الإجابة الصحيحة: ' + q.options[correctIndex],
                    style: TextStyle(
                      fontSize: 13.sp,
                      color: AppColors.secondary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showNoInternetDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.r),
        ),
        title: Row(
          children: [
            Icon(Icons.wifi_off_rounded, color: AppColors.error, size: 28.r),
            SizedBox(width: 12.w),
            Text(
              'لا يوجد اتصال بالإنترنت',
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
                color: AppColors.error,
              ),
            ),
          ],
        ),
        content: Text(
          'يرجى الاتصال بالإنترنت لتحميل الأسئلة',
          style: TextStyle(fontSize: 15.sp),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop(); // Go back to previous screen
            },
            child: Text(
              'العودة',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              setState(() {
                _isLoading = true;
              });
              _loadGoldQuestions(); // Retry loading
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
            ),
            child: Text(
              'إعادة المحاولة',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
