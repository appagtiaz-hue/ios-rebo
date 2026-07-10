import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../constants/colors.dart';
import '../models/question.dart';
import '../services/mongodb_question_service.dart';
import '../services/database_service.dart';

class SilverTestScreen extends StatefulWidget {
  const SilverTestScreen({super.key});

  @override
  State<SilverTestScreen> createState() => _SilverTestScreenState();
}

class _SilverTestScreenState extends State<SilverTestScreen> {
  List<Question> _questions = [];
  int _currentQuestionIndex = 0;
  int? _selectedAnswerIndex;
  List<int> _userAnswers = [];
  bool _isLoading = true;
  bool _testCompleted = false;
  int _correctAnswers = 0;

  // ألوان جديدة
  Color _primaryColor = AppColors.primary;
  Color _secondaryColor = AppColors.secondary;
  // List<Color> _gradientColors = [AppColors.primary, AppColors.secondary]; // Unused for now
  // bool _isLoadingColors = true; // Unused for now

  @override
  void initState() {
    super.initState();
    _loadSilverQuestions();
  }

  // Load Silver Questions (1000 سؤال)
  Future<void> _loadSilverQuestions() async {
    try {
      final user = await DatabaseService.getCurrentUser();
      final String? serverPlanId = user?.subscriptionPlanId;

      // Load Plan Colors
      if (serverPlanId != null) {
        final plan = await DatabaseService.getPlanById(serverPlanId);
        if (plan != null) {
          if (mounted) {
            setState(() {
              _primaryColor = plan.getPrimaryColor();
              _secondaryColor = plan.getSecondaryColor();
              // _gradientColors = plan.getGradient();
              // _isLoadingColors = false;
            });
          }
        }
      }

      if (serverPlanId == null) {
        throw Exception('No active plan selected');
      }

      final questions = await MongoQuestionService.getRandomQuestions(
        1000,
        planId: serverPlanId,
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

      // Shuffle للأسئلة نفسها
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
            content: Text('خطأ في تحميل أسئلة سيلفير'),
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
                        color: AppColors.textPrimary,
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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
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
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: _primaryColor),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            'الخطة الفضية - 1000 سؤال',
            style: TextStyle(fontWeight: FontWeight.bold, color: _primaryColor),
          ),
          backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
          elevation: 0,
          iconTheme: IconThemeData(color: _primaryColor),
        ),
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(_primaryColor),
            strokeWidth: 3.w,
          ),
        ),
      );
    }

    if (_testCompleted) {
      return _buildResultsScreen();
    }

    if (_questions.isEmpty) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: _primaryColor),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            'الخطة الفضية - 1000 سؤال',
            style: TextStyle(fontWeight: FontWeight.bold, color: _primaryColor),
          ),
          backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
          elevation: 0,
          iconTheme: IconThemeData(color: _primaryColor),
        ),
        body: Center(child: Text('لا توجد أسئلة متاحة')),
      );
    }

    final currentQuestion = _questions[_currentQuestionIndex];
    final progress = (_currentQuestionIndex + 1) / _questions.length;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: _primaryColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'الخطة الفضية',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: _primaryColor,
            fontSize: 20.sp,
          ),
        ),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: 0,
        iconTheme: IconThemeData(color: _primaryColor),
        actions: [
          Container(
            margin: EdgeInsets.only(right: 16.w),
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_primaryColor, _secondaryColor],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(25.r),
              boxShadow: [
                BoxShadow(
                  color: _primaryColor.withValues(alpha: 0.3),
                  blurRadius: 8.r,
                  offset: Offset(0, 4.h),
                ),
              ],
            ),
            child: Text(
              '${_currentQuestionIndex + 1}/${_questions.length}',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Progress Bar
          Container(
            height: 6.h,
            margin: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
            decoration: BoxDecoration(
              color: AppColors.grey.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: progress,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_secondaryColor, _primaryColor],
                  ),
                  borderRadius: BorderRadius.circular(10.r),
                  boxShadow: [
                    BoxShadow(
                      color: _secondaryColor.withValues(alpha: 0.4),
                      blurRadius: 8.r,
                      offset: Offset(0, 2.h),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(24.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Question Card
                  Container(
                    padding: EdgeInsets.all(28.w),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Theme.of(context).cardColor,
                          Theme.of(context).cardColor,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24.r),
                      boxShadow: [
                        BoxShadow(
                          color: _primaryColor.withOpacity(0.08),
                          blurRadius: 30.r,
                          offset: Offset(0, 15.h),
                        ),
                      ],
                      border: Border.all(
                        color: _primaryColor.withOpacity(0.1),
                        width: 1.5.w,
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
                                  colors: [_secondaryColor, _primaryColor],
                                ),
                                borderRadius: BorderRadius.circular(20.r),
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
                        SizedBox(height: 20.h),
                        Text(
                          currentQuestion.questionText,
                          style: TextStyle(
                            fontSize: 19.sp,
                            color: Theme.of(context).textTheme.bodyLarge?.color,
                            fontWeight: FontWeight.w600,
                            height: 1.6,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 32.h),

                  // Options Label
                  Row(
                    children: [
                      Container(
                        width: 4.w,
                        height: 20.h,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [_primaryColor, _secondaryColor],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                          borderRadius: BorderRadius.circular(2.r),
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Text(
                        'اختر الإجابة الصحيحة:',
                        style: TextStyle(
                          fontSize: 16.sp,
                          color: Theme.of(context).textTheme.bodyLarge?.color,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 20.h),

                  // Answer Options
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

                  // Navigation Buttons
                  Row(
                    children: [
                      if (_currentQuestionIndex > 0)
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16.r),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.secondary.withOpacity(0.15),
                                  blurRadius: 12.r,
                                  offset: Offset(0, 6.h),
                                ),
                              ],
                            ),
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
                                padding: EdgeInsets.symmetric(vertical: 18.h),
                                side: BorderSide(
                                  color: _secondaryColor,
                                  width: 2.w,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16.r),
                                ),
                                backgroundColor: AppColors.white,
                              ),
                              child: Text(
                                'السابق',
                                style: TextStyle(
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.bold,
                                  color: _secondaryColor,
                                ),
                              ),
                            ),
                          ),
                        ),
                      if (_currentQuestionIndex > 0) SizedBox(width: 16.w),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16.r),
                            gradient: _selectedAnswerIndex != null
                                ? LinearGradient(
                                    colors: [_primaryColor, _secondaryColor],
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                  )
                                : null,
                            boxShadow: _selectedAnswerIndex != null
                                ? [
                                    BoxShadow(
                                      color: _primaryColor.withValues(
                                        alpha: 0.4,
                                      ),
                                      blurRadius: 16.r,
                                      offset: Offset(0, 8.h),
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
                              disabledBackgroundColor: AppColors.grey,
                              shadowColor: Colors.transparent,
                              padding: EdgeInsets.symmetric(vertical: 18.h),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16.r),
                              ),
                            ),
                            child: Text(
                              _currentQuestionIndex == _questions.length - 1
                                  ? 'إنهاء الاختبار'
                                  : 'التالي',
                              style: TextStyle(
                                fontSize: 16.sp,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
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
      _secondaryColor,
      _primaryColor,
      AppColors.error,
      AppColors.warning,
    ];
    final currentColor = optionColors[index % optionColors.length];

    return Container(
      margin: EdgeInsets.only(bottom: 16.h),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20.r),
          child: AnimatedContainer(
            duration: Duration(milliseconds: 200),
            padding: EdgeInsets.all(20.w),
            decoration: BoxDecoration(
              gradient: isSelected
                  ? LinearGradient(
                      colors: [
                        currentColor,
                        currentColor.withValues(alpha: 0.8),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : LinearGradient(
                      colors: [
                        Theme.of(context).cardColor,
                        Theme.of(context).cardColor,
                      ],
                    ),
              borderRadius: BorderRadius.circular(20.r),
              border: Border.all(
                color: isSelected
                    ? currentColor
                    : currentColor.withOpacity(0.2),
                width: 2.5.w,
              ),
              boxShadow: [
                BoxShadow(
                  color: isSelected
                      ? currentColor.withOpacity(0.3)
                      : AppColors.grey.withOpacity(0.08),
                  blurRadius: isSelected ? 16.r : 12.r,
                  offset: Offset(0, isSelected ? 8.h : 4.h),
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
                    color: isSelected
                        ? AppColors.white
                        : currentColor.withValues(alpha: 0.1),
                    border: Border.all(
                      color: isSelected
                          ? currentColor
                          : currentColor.withValues(alpha: 0.5),
                      width: 2.5.w,
                    ),
                  ),
                  child: isSelected
                      ? Icon(
                          Icons.check_rounded,
                          size: 18.r,
                          color: currentColor,
                        )
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
    final percentage = (_correctAnswers / _questions.length * 100).round();
    final wrongIndexes = <int>[];
    for (int i = 0; i < _questions.length; i++) {
      if (_userAnswers[i] != _questions[i].correctAnswerIndex)
        wrongIndexes.add(i);
    }

    String resultMessage;
    IconData resultIcon;

    if (percentage >= 90) {
      resultMessage = 'ممتاز! أداء رائع 🌟';
      resultIcon = Icons.emoji_events;
    } else if (percentage >= 70) {
      resultMessage = 'جيد جداً! استمر 💪';
      resultIcon = Icons.thumb_up;
    } else if (percentage >= 50) {
      resultMessage = 'جيد، يمكنك التحسين 📚';
      resultIcon = Icons.trending_up;
    } else {
      resultMessage = 'حاول مرة أخرى 🎯';
      resultIcon = Icons.refresh;
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: _primaryColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'نتيجة الاختبار',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
            fontSize: 20.sp,
          ),
        ),
        backgroundColor: AppColors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: _primaryColor),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(24.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Result Card
            Container(
              padding: EdgeInsets.all(40.w),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [_primaryColor, _secondaryColor],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(28.r),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.4),
                    blurRadius: 30.r,
                    offset: Offset(0, 15.h),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    padding: EdgeInsets.all(20.w),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(resultIcon, size: 64.r, color: AppColors.white),
                  ),
                  SizedBox(height: 24.h),
                  Text(
                    resultMessage,
                    style: TextStyle(
                      fontSize: 24.sp,
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 16.h),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 32.w,
                      vertical: 16.h,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(50.r),
                    ),
                    child: Text(
                      '$percentage%',
                      style: TextStyle(
                        fontSize: 48.sp,
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  SizedBox(height: 16.h),
                  Text(
                    '$_correctAnswers من ${_questions.length} إجابة صحيحة',
                    style: TextStyle(
                      fontSize: 16.sp,
                      color: Colors.black87,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 24.h),

            // Wrong Answers Section
            if (wrongIndexes.isNotEmpty)
              Container(
                padding: EdgeInsets.all(24.w),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(24.r),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.grey.withOpacity(0.1),
                      blurRadius: 20.r,
                      offset: Offset(0, 10.h),
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
                                AppColors.error,
                                AppColors.error.withOpacity(0.7),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                          child: Icon(
                            Icons.error_outline,
                            color: AppColors.white,
                            size: 24.r,
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Text(
                          'الأسئلة الخاطئة',
                          style: TextStyle(
                            fontSize: 18.sp,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 20.h),
                    ...wrongIndexes.map((i) => _wrongItem(i)).toList(),
                  ],
                ),
              ),
            SizedBox(height: 24.h),

            // Finish Button
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16.r),
                gradient: LinearGradient(
                  colors: [AppColors.secondary, AppColors.primary],
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.secondary.withOpacity(0.4),
                    blurRadius: 20.r,
                    offset: Offset(0, 10.h),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: () =>
                    Navigator.popUntil(context, ModalRoute.withName('/home')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  padding: EdgeInsets.symmetric(vertical: 18.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16.r),
                  ),
                ),
                child: Text(
                  'العودة للرئيسية',
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
    );
  }

  Widget _wrongItem(int index) {
    final q = _questions[index];
    final userIndex = _userAnswers[index];
    final correctIndex = q.correctAnswerIndex;

    return Container(
      margin: EdgeInsets.only(bottom: 16.h),
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.error.withOpacity(0.05),
            AppColors.error.withOpacity(0.02),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: AppColors.error,
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Text(
                  'س ${index + 1}',
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: AppColors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              SizedBox(width: 12.w),
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
          SizedBox(height: 16.h),
          Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: AppColors.error.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(
                color: AppColors.error.withOpacity(0.3),
                width: 1.w,
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.close, color: AppColors.error, size: 20.r),
                SizedBox(width: 8.w),
                Expanded(
                  child: Text(
                    'إجابتك: ' +
                        (userIndex >= 0
                            ? q.options[userIndex]
                            : 'لم يتم الاختيار'),
                    style: TextStyle(
                      fontSize: 14.sp,
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
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: AppColors.secondary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(
                color: AppColors.secondary.withOpacity(0.3),
                width: 1.w,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.check_circle,
                  color: AppColors.secondary,
                  size: 20.r,
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: Text(
                    'الإجابة الصحيحة: ' + q.options[correctIndex],
                    style: TextStyle(
                      fontSize: 14.sp,
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
}
