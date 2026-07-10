import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../constants/colors.dart';
import '../constants/strings.dart';
import '../models/question.dart';
import '../services/database_service.dart';

class TestScreen extends StatefulWidget {
  const TestScreen({super.key});

  @override
  State<TestScreen> createState() => _TestScreenState();
}

class _TestScreenState extends State<TestScreen> {
  List<Question> _questions = [];
  int _currentQuestionIndex = 0;
  int? _selectedAnswerIndex;
  List<int> _userAnswers = [];
  bool _isLoading = true;
  bool _testCompleted = false;
  int _correctAnswers = 0;

  bool _isAnswerChecked = false;

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  Future<void> _loadQuestions() async {
    try {
      final questions = await DatabaseService.getTrialQuestions();

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
            content: Text('خطأ في تحميل الأسئلة'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _selectAnswer(int answerIndex) {
    if (_isAnswerChecked) return; // Prevent changing answer after checking
    setState(() {
      _selectedAnswerIndex = answerIndex;
      _userAnswers[_currentQuestionIndex] = answerIndex;
    });
  }

  void _checkAnswer() {
    if (_selectedAnswerIndex != null) {
      setState(() {
        _isAnswerChecked = true;
      });
    }
  }

  void _nextQuestion() {
    if (_currentQuestionIndex < _questions.length - 1) {
      setState(() {
        _currentQuestionIndex++;
        _selectedAnswerIndex = _userAnswers[_currentQuestionIndex] != -1
            ? _userAnswers[_currentQuestionIndex]
            : null;
        _isAnswerChecked = false; // Reset for next question
      });
    } else {
      _finishTest();
    }
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
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Container(
          decoration: BoxDecoration(color: Theme.of(context).primaryColor),
          child: SafeArea(
            child: Column(
              children: [
                _buildAppBar(context, 'الاختبار التجريبي'),
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(
                          color: AppColors.white,
                          strokeWidth: 3,
                        ),
                        SizedBox(height: 24.h),
                        Text(
                          'جاري تحميل الأسئلة...',
                          style: TextStyle(
                            fontSize: 18.sp,
                            color: AppColors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
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
              colors: [AppColors.primary, AppColors.primaryDark],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                _buildAppBar(context, 'الاختبار التجريبي'),
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 80.r,
                          color: AppColors.white,
                        ),
                        SizedBox(height: 24.h),
                        Text(
                          'لا توجد أسئلة متاحة',
                          style: TextStyle(
                            fontSize: 20.sp,
                            color: AppColors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 32.h),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.white,
                            foregroundColor: AppColors.primary,
                            padding: EdgeInsets.symmetric(
                              horizontal: 40.w,
                              vertical: 16.h,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                          ),
                          child: Text(
                            'العودة',
                            style: TextStyle(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final currentQuestion = _questions[_currentQuestionIndex];

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF063311), Color(0xFF0D4D2B), Color(0xFF1B5E20)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildAppBar(
                context,
                'الاختبار التجريبي',
                trailing: Container(
                  margin: EdgeInsets.only(left: 16.w),
                  padding: EdgeInsets.symmetric(
                    horizontal: 16.w,
                    vertical: 8.h,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.secondary,
                    borderRadius: BorderRadius.circular(20.r),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.secondary.withOpacity(0.3),
                        blurRadius: 8.r,
                        offset: Offset(0, 4.h),
                      ),
                    ],
                  ),
                  child: Text(
                    '${_currentQuestionIndex + 1}/${_questions.length}',
                    style: TextStyle(
                      color: AppColors.white,
                      fontSize: 15.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(20.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Progress Bar
                      Container(
                        height: 6.h,
                        decoration: BoxDecoration(
                          color: AppColors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(3.r),
                        ),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerRight,
                          widthFactor:
                              (_currentQuestionIndex + 1) / _questions.length,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.primaryLight,
                                  AppColors.secondary,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(3.r),
                            ),
                          ),
                        ),
                      ),

                      SizedBox(height: 24.h),

                      // Question Card
                      Container(
                        padding: EdgeInsets.all(24.w),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(20.r),
                          boxShadow: [
                            BoxShadow(
                              color: Theme.of(context).shadowColor,
                              blurRadius: 20.r,
                              offset: Offset(0, 10.h),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 12.w,
                                vertical: 6.h,
                              ),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    AppColors.primary,
                                    AppColors.primaryDark,
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(8.r),
                              ),
                              child: Text(
                                'السؤال ${_currentQuestionIndex + 1}',
                                style: TextStyle(
                                  fontSize: 13.sp,
                                  color: AppColors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            SizedBox(height: 20.h),
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

                      SizedBox(height: 28.h),

                      // Answer Options Label
                      Padding(
                        padding: EdgeInsets.only(right: 4.w, bottom: 16.h),
                        child: Text(
                          'اختر الإجابة الصحيحة:',
                          style: TextStyle(
                            fontSize: 16.sp,
                            color: AppColors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),

                      ...List.generate(
                        currentQuestion.options.length,
                        (index) => _buildAnswerOption(
                          index: index,
                          text: currentQuestion.options[index],
                          isSelected: _selectedAnswerIndex == index,
                          isCorrect:
                              _isAnswerChecked &&
                              index == currentQuestion.correctAnswerIndex,
                          isWrong:
                              _isAnswerChecked &&
                              _selectedAnswerIndex == index &&
                              index != currentQuestion.correctAnswerIndex,
                          onTap: () => _selectAnswer(index),
                        ),
                      ),

                      // Justification Card
                      if (_isAnswerChecked) ...[
                        SizedBox(height: 24.h),
                        Container(
                          padding: EdgeInsets.all(16.w),
                          decoration: BoxDecoration(
                            color:
                                _selectedAnswerIndex ==
                                    currentQuestion.correctAnswerIndex
                                ? AppColors.success.withOpacity(0.1)
                                : AppColors.error.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16.r),
                            border: Border.all(
                              color:
                                  _selectedAnswerIndex ==
                                      currentQuestion.correctAnswerIndex
                                  ? AppColors.success
                                  : AppColors.error,
                              width: 1.w,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    _selectedAnswerIndex ==
                                            currentQuestion.correctAnswerIndex
                                        ? Icons.check_circle_rounded
                                        : Icons.cancel_rounded,
                                    color:
                                        _selectedAnswerIndex ==
                                            currentQuestion.correctAnswerIndex
                                        ? AppColors.success
                                        : AppColors.error,
                                    size: 24.r,
                                  ),
                                  SizedBox(width: 8.w),
                                  Text(
                                    _selectedAnswerIndex ==
                                            currentQuestion.correctAnswerIndex
                                        ? 'إجابة صحيحة!'
                                        : 'إجابة خاطئة',
                                    style: TextStyle(
                                      fontSize: 16.sp,
                                      fontWeight: FontWeight.bold,
                                      color:
                                          _selectedAnswerIndex ==
                                              currentQuestion.correctAnswerIndex
                                          ? AppColors.success
                                          : AppColors.error,
                                    ),
                                  ),
                                ],
                              ),
                              if (_selectedAnswerIndex !=
                                  currentQuestion.correctAnswerIndex) ...[
                                SizedBox(height: 8.h),
                                Text(
                                  'الإجابة الصحيحة: ${currentQuestion.options[currentQuestion.correctAnswerIndex]}',
                                  style: TextStyle(
                                    fontSize: 14.sp,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                              if (currentQuestion
                                  .answerJustification
                                  .isNotEmpty) ...[
                                SizedBox(height: 8.h),
                                Divider(color: AppColors.grey.withOpacity(0.3)),
                                SizedBox(height: 8.h),
                                Text(
                                  'التبرير:',
                                  style: TextStyle(
                                    fontSize: 14.sp,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                SizedBox(height: 4.h),
                                Text(
                                  currentQuestion.answerJustification,
                                  style: TextStyle(
                                    fontSize: 14.sp,
                                    color: Theme.of(
                                      context,
                                    ).textTheme.bodyMedium?.color,
                                    height: 1.4,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],

                      SizedBox(height: 32.h),

                      // Navigation Buttons
                      Row(
                        children: [
                          if (_currentQuestionIndex > 0 && !_isAnswerChecked)
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () {
                                  setState(() {
                                    _currentQuestionIndex--;
                                    _selectedAnswerIndex =
                                        _userAnswers[_currentQuestionIndex] !=
                                            -1
                                        ? _userAnswers[_currentQuestionIndex]
                                        : null;
                                    _isAnswerChecked =
                                        false; // Reset when going back (optional, or keep state)
                                  });
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.white.withOpacity(
                                    0.2,
                                  ),
                                  foregroundColor: AppColors.white,
                                  padding: EdgeInsets.symmetric(vertical: 16.h),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14.r),
                                    side: BorderSide(
                                      color: AppColors.white.withOpacity(0.5),
                                      width: 1.5.w,
                                    ),
                                  ),
                                  elevation: 0,
                                ),
                                child: Text(
                                  'السابق',
                                  style: TextStyle(
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          if (_currentQuestionIndex > 0 && !_isAnswerChecked)
                            SizedBox(width: 12.w),
                          Expanded(
                            flex: 1,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: _selectedAnswerIndex != null
                                    ? LinearGradient(
                                        colors: [
                                          AppColors.primaryLight,
                                          AppColors.primary,
                                        ],
                                      )
                                    : null,
                                borderRadius: BorderRadius.circular(14.r),
                                boxShadow: _selectedAnswerIndex != null
                                    ? [
                                        BoxShadow(
                                          color: AppColors.primaryLight
                                              .withOpacity(0.4),
                                          blurRadius: 12.r,
                                          offset: Offset(0, 6.h),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: ElevatedButton(
                                onPressed: _selectedAnswerIndex != null
                                    ? (_isAnswerChecked
                                          ? _nextQuestion
                                          : _checkAnswer)
                                    : null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _selectedAnswerIndex != null
                                      ? Colors.transparent
                                      : AppColors.white.withOpacity(0.3),
                                  foregroundColor: AppColors.white,
                                  shadowColor: Colors.transparent,
                                  padding: EdgeInsets.symmetric(vertical: 16.h),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14.r),
                                  ),
                                  elevation: 0,
                                ),
                                child: Text(
                                  _isAnswerChecked
                                      ? (_currentQuestionIndex ==
                                                _questions.length - 1
                                            ? 'إنهاء الاختبار'
                                            : 'التالي')
                                      : 'تحقق',
                                  style: TextStyle(
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.bold,
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
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, String title, {Widget? trailing}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
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
                Icons.arrow_forward,
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
              title,
              style: TextStyle(
                fontSize: 20.sp,
                fontWeight: FontWeight.bold,
                color: AppColors.white,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          if (trailing != null) trailing else SizedBox(width: 48.w),
        ],
      ),
    );
  }

  Widget _buildAnswerOption({
    required int index,
    required String text,
    required bool isSelected,
    bool isCorrect = false,
    bool isWrong = false,
    required VoidCallback onTap,
  }) {
    Color backgroundColor;
    Color borderColor;

    if (isCorrect) {
      backgroundColor = AppColors.success.withOpacity(0.1);
      borderColor = AppColors.success;
    } else if (isWrong) {
      backgroundColor = AppColors.error.withOpacity(0.1);
      borderColor = AppColors.error;
    } else if (isSelected) {
      backgroundColor = Theme.of(context).cardColor;
      borderColor = AppColors.primaryLight;
    } else {
      backgroundColor = Theme.of(context).cardColor;
      borderColor = Colors.transparent;
    }

    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16.r),
          child: Container(
            padding: EdgeInsets.all(18.w),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(color: borderColor, width: 2.5.w),
              boxShadow: [
                BoxShadow(
                  color: isSelected || isCorrect || isWrong
                      ? (isCorrect
                            ? AppColors.success.withOpacity(0.2)
                            : (isWrong
                                  ? AppColors.error.withOpacity(0.2)
                                  : AppColors.primaryLight.withOpacity(0.3)))
                      : AppColors.shadow.withOpacity(0.05),
                  blurRadius: isSelected || isCorrect || isWrong ? 12.r : 8.r,
                  offset: Offset(
                    0,
                    isSelected || isCorrect || isWrong ? 6.h : 4.h,
                  ),
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
                    gradient: isSelected && !isCorrect && !isWrong
                        ? LinearGradient(
                            colors: [AppColors.primaryLight, AppColors.primary],
                          )
                        : null,
                    color: isCorrect
                        ? AppColors.success
                        : (isWrong
                              ? AppColors.error
                              : (isSelected
                                    ? null
                                    : AppColors.grey.withOpacity(0.15))),
                    border: Border.all(
                      color: isSelected || isCorrect || isWrong
                          ? Colors.transparent
                          : AppColors.grey.withOpacity(0.3),
                      width: 2.w,
                    ),
                  ),
                  child: isCorrect
                      ? Icon(Icons.check, size: 18.r, color: AppColors.white)
                      : (isWrong
                            ? Icon(
                                Icons.close,
                                size: 18.r,
                                color: AppColors.white,
                              )
                            : (isSelected
                                  ? Icon(
                                      Icons.check,
                                      size: 18.r,
                                      color: AppColors.white,
                                    )
                                  : null)),
                ),
                SizedBox(width: 14.w),
                Expanded(
                  child: Text(
                    text,
                    style: TextStyle(
                      fontSize: 15.sp,
                      color: isCorrect
                          ? AppColors.success
                          : (isWrong
                                ? AppColors.error
                                : (isSelected
                                      ? Theme.of(
                                          context,
                                        ).textTheme.bodyLarge?.color
                                      : Theme.of(
                                          context,
                                        ).textTheme.bodyMedium?.color)),
                      fontWeight: isSelected || isCorrect || isWrong
                          ? FontWeight.w600
                          : FontWeight.w500,
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

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF063311), Color(0xFF0D4D2B), Color(0xFF1B5E20)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildAppBar(context, 'نتيجة الاختبار'),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(20.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Score Card
                      Container(
                        padding: EdgeInsets.symmetric(
                          vertical: 32.h,
                          horizontal: 24.w,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(24.r),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.shadow.withOpacity(0.15),
                              blurRadius: 30.r,
                              offset: Offset(0, 15.h),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Container(
                              width: 100.w,
                              height: 100.w,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    AppColors.secondary,
                                    AppColors.secondaryLight,
                                  ],
                                ),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.secondary.withOpacity(0.4),
                                    blurRadius: 20.r,
                                    offset: Offset(0, 10.h),
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.emoji_events,
                                size: 56.r,
                                color: AppColors.white,
                              ),
                            ),
                            SizedBox(height: 24.h),
                            Text(
                              AppStrings.testCompleted,
                              style: TextStyle(
                                fontSize: 22.sp,
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: 16.h),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 24.w,
                                vertical: 12.h,
                              ),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    AppColors.primary,
                                    AppColors.primaryDark,
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(12.r),
                              ),
                              child: Text(
                                '${AppStrings.yourScore}: $percentage%',
                                style: TextStyle(
                                  fontSize: 20.sp,
                                  color: AppColors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            SizedBox(height: 24.h),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _buildStatItem(
                                  'صحيحة',
                                  '$_correctAnswers',
                                  AppColors.success,
                                ),
                                Container(
                                  width: 1.w,
                                  height: 40.h,
                                  color: AppColors.grey.withOpacity(0.2),
                                ),
                                _buildStatItem(
                                  'خاطئة',
                                  '${_questions.length - _correctAnswers}',
                                  AppColors.error,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      if (wrongIndexes.isNotEmpty) ...[
                        SizedBox(height: 24.h),
                        Container(
                          padding: EdgeInsets.all(20.w),
                          decoration: BoxDecoration(
                            color: AppColors.white,
                            borderRadius: BorderRadius.circular(20.r),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.shadow.withOpacity(0.08),
                                blurRadius: 15.r,
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
                                    width: 4.w,
                                    height: 24.h,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          AppColors.primary,
                                          AppColors.primaryDark,
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(2.r),
                                    ),
                                  ),
                                  SizedBox(width: 12.w),
                                  Expanded(
                                    child: Text(
                                      'الأسئلة الخاطئة والإجابات الصحيحة',
                                      style: TextStyle(
                                        fontSize: 16.sp,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 16.h),
                              ...wrongIndexes
                                  .map((i) => _wrongItem(i))
                                  .toList(),
                            ],
                          ),
                        ),
                      ],

                      SizedBox(height: 24.h),

                      // Finish Button
                      Container(
                        height: 56.h,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [AppColors.primaryLight, AppColors.primary],
                          ),
                          borderRadius: BorderRadius.circular(16.r),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primaryLight.withOpacity(0.4),
                              blurRadius: 15.r,
                              offset: Offset(0, 8.h),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: () => Navigator.popUntil(
                            context,
                            ModalRoute.withName('/home'),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16.r),
                            ),
                          ),
                          child: Text(
                            'إنهاء',
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
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
        SizedBox(height: 4.h),
        Text(
          label,
          style: TextStyle(
            fontSize: 14.sp,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _wrongItem(int index) {
    final q = _questions[index];
    final userIndex = _userAnswers[index];
    final correctIndex = q.correctAnswerIndex;
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.lightGrey,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(
          color: AppColors.border.withOpacity(0.1),
          width: 1.w,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'س ${index + 1}: ' + q.questionText,
            style: TextStyle(
              fontSize: 14.sp,
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
          SizedBox(height: 10.h),
          Container(
            padding: EdgeInsets.all(10.w),
            decoration: BoxDecoration(
              color: AppColors.error.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Row(
              children: [
                Icon(Icons.close, size: 16.r, color: AppColors.error),
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
              color: AppColors.success.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Row(
              children: [
                Icon(Icons.check, size: 16.r, color: AppColors.success),
                SizedBox(width: 8.w),
                Expanded(
                  child: Text(
                    'الإجابة الصحيحة: ' + q.options[correctIndex],
                    style: TextStyle(
                      fontSize: 13.sp,
                      color: AppColors.success,
                      fontWeight: FontWeight.w600,
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
