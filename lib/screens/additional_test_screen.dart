import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../constants/colors.dart';
import '../models/question.dart';
import '../services/mongodb_question_service.dart';
import '../services/network_service.dart';

class AdditionalTestScreen extends StatefulWidget {
  final String testId;
  final String testName;
  final int questionCount; // Added field

  const AdditionalTestScreen({
    super.key,
    required this.testId,
    required this.testName,
    this.questionCount = 0, // Default to 0 (all questions)
  });

  @override
  State<AdditionalTestScreen> createState() => _AdditionalTestScreenState();
}

class _AdditionalTestScreenState extends State<AdditionalTestScreen>
    with TickerProviderStateMixin {
  List<Question> _questions = [];
  int _currentQuestionIndex = 0;
  int? _selectedAnswerIndex;
  List<int> _userAnswers = [];
  bool _isLoading = true;
  bool _testCompleted = false;
  int _correctAnswers = 0;

  // Animation controllers
  late AnimationController _progressController;
  late AnimationController _cardController;
  late Animation<double> _cardAnimation;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _loadQuestions();
  }

  void _initAnimations() {
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _cardController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _cardAnimation = CurvedAnimation(
      parent: _cardController,
      curve: Curves.easeOutBack,
    );

    _cardController.forward();
  }

  @override
  void dispose() {
    _progressController.dispose();
    _cardController.dispose();
    super.dispose();
  }

  Future<void> _loadQuestions() async {
    try {
      final isConnected = await NetworkService.isConnected();
      if (!isConnected) {
        if (mounted) {
          setState(() => _isLoading = false);
          _showNoInternetDialog();
        }
        return;
      }

      List<Question> questions;
      if (widget.questionCount > 0) {
        questions = await MongoQuestionService.getRandomAdditionalTestQuestions(
          widget.testId,
          widget.questionCount,
        );
      } else {
        questions = await MongoQuestionService.getAdditionalTestQuestions(
          widget.testId,
        );
      }

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
        _progressController.forward();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
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
      _showAnswerJustification(_questions[_currentQuestionIndex], isCorrect);
    } else {
      _moveToNextQuestion();
    }
  }

  void _moveToNextQuestion() {
    if (_currentQuestionIndex < _questions.length - 1) {
      _cardController.reset();
      setState(() {
        _currentQuestionIndex++;
        _selectedAnswerIndex = _userAnswers[_currentQuestionIndex] != -1
            ? _userAnswers[_currentQuestionIndex]
            : null;
      });
      _cardController.forward();
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
          borderRadius: BorderRadius.circular(28.r),
        ),
        backgroundColor: Theme.of(context).cardColor,
        title: Container(
          padding: EdgeInsets.all(12.w),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isCorrect
                  ? [AppColors.success, AppColors.success.withOpacity(0.8)]
                  : [AppColors.error, AppColors.error.withOpacity(0.8)],
            ),
            borderRadius: BorderRadius.circular(16.r),
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(8.w),
                decoration: BoxDecoration(
                  color: AppColors.white.withOpacity(0.2),
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
                    color: AppColors.white,
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(height: 8.h),
              Container(
                padding: EdgeInsets.all(16.w),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary.withOpacity(0.1),
                      AppColors.secondary.withOpacity(0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16.r),
                  border: Border.all(
                    color: AppColors.primary.withOpacity(0.3),
                    width: 1.5.w,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.lightbulb_rounded,
                          color: AppColors.secondary,
                          size: 20.r,
                        ),
                        SizedBox(width: 8.w),
                        Text(
                          'الإجابة الصحيحة:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14.sp,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12.h),
                    Text(
                      question.options[question.correctAnswerIndex],
                      style: TextStyle(
                        color: AppColors.primaryDark,
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (question.answerJustification.isNotEmpty) ...[
                SizedBox(height: 16.h),
                Container(
                  padding: EdgeInsets.all(16.w),
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(16.r),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            color: AppColors.secondary,
                            size: 20.r,
                          ),
                          SizedBox(width: 8.w),
                          Text(
                            'تبرير الإجابة:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14.sp,
                              color: AppColors.secondary,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12.h),
                      Text(
                        question.answerJustification,
                        style: TextStyle(
                          fontSize: 14.sp,
                          height: 1.6,
                          color: Theme.of(context).textTheme.bodyMedium?.color,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          Container(
            width: double.infinity,
            margin: EdgeInsets.symmetric(horizontal: 8.w),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary, AppColors.primaryDark],
              ),
              borderRadius: BorderRadius.circular(14.r),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.4),
                  blurRadius: 12.r,
                  offset: Offset(0, 4.h),
                ),
              ],
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
        actionsPadding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 16.h),
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
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF063311), Color(0xFF0D4D2B), Color(0xFF1B5E20)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: _isLoading
              ? _buildLoadingState()
              : _testCompleted
              ? _buildResultsScreen()
              : _questions.isEmpty
              ? _buildEmptyState()
              : _buildQuestionScreen(),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(24.w),
            decoration: BoxDecoration(
              color: AppColors.white.withOpacity(0.9),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.3),
                  blurRadius: 24.r,
                  offset: Offset(0, 8.h),
                ),
              ],
            ),
            child: CircularProgressIndicator(
              color: AppColors.primary,
              strokeWidth: 4.w,
            ),
          ),
          SizedBox(height: 24.h),
          Text(
            'جاري تحميل الأسئلة...',
            style: TextStyle(
              color: AppColors.white,
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Container(
        margin: EdgeInsets.all(32.w),
        padding: EdgeInsets.all(32.w),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(24.r),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).shadowColor,
              blurRadius: 24.r,
              offset: Offset(0, 8.h),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.quiz_outlined, size: 64.r, color: AppColors.grey),
            SizedBox(height: 16.h),
            Text(
              'لا توجد أسئلة متاحة',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 24.h),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: Icon(Icons.arrow_back),
              label: Text('العودة'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.white,
                padding: EdgeInsets.symmetric(horizontal: 32.w, vertical: 14.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionScreen() {
    final currentQuestion = _questions[_currentQuestionIndex];
    final progress = (_currentQuestionIndex + 1) / _questions.length;

    return Column(
      children: [
        // Custom App Bar
        _buildCustomAppBar(),

        // Progress Section
        _buildProgressSection(progress),

        // Question Content
        Expanded(
          child: ScaleTransition(
            scale: _cardAnimation,
            child: SingleChildScrollView(
              padding: EdgeInsets.all(20.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Question Card
                  _buildQuestionCard(currentQuestion),

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

                  SizedBox(height: 24.h),

                  // Navigation Buttons
                  _buildNavigationButtons(),

                  SizedBox(height: 20.h),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCustomAppBar() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              color: AppColors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: IconButton(
              icon: Icon(Icons.arrow_back, color: AppColors.white),
              onPressed: () => _showExitConfirmation(),
            ),
          ),
          SizedBox(width: 16.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'اختبار إضافي',
                  style: TextStyle(
                    color: AppColors.white.withOpacity(0.8),
                    fontSize: 12.sp,
                  ),
                ),
                Text(
                  widget.testName,
                  style: TextStyle(
                    color: AppColors.white,
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.secondary, AppColors.secondaryDark],
              ),
              borderRadius: BorderRadius.circular(20.r),
              boxShadow: [
                BoxShadow(
                  color: AppColors.secondary.withOpacity(0.4),
                  blurRadius: 8.r,
                  offset: Offset(0, 4.h),
                ),
              ],
            ),
            child: Text(
              '${_currentQuestionIndex + 1}/${_questions.length}',
              style: TextStyle(
                color: AppColors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14.sp,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressSection(double progress) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20.w),
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24.r),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor,
            blurRadius: 20.r,
            offset: Offset(0, 8.h),
          ),
        ],
      ),
      child: Row(
        children: [
          // Circular Progress
          SizedBox(
            width: 70.w,
            height: 70.w,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CircularProgressIndicator(
                  value: 1,
                  strokeWidth: 8.w,
                  backgroundColor: AppColors.lightGrey,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppColors.lightGrey,
                  ),
                ),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: progress),
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, _) => CircularProgressIndicator(
                    value: value,
                    strokeWidth: 8.w,
                    strokeCap: StrokeCap.round,
                    backgroundColor: Colors.transparent,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.secondary,
                    ),
                  ),
                ),
                Center(
                  child: Text(
                    '${(progress * 100).round()}%',
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 20.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'السؤال ${_currentQuestionIndex + 1}',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  'من أصل ${_questions.length} سؤال',
                  style: TextStyle(
                    color: Theme.of(context).textTheme.bodyMedium?.color,
                    fontSize: 14.sp,
                  ),
                ),
                SizedBox(height: 8.h),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10.r),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: AppColors.lightGrey,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.primary,
                    ),
                    minHeight: 6.h,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionCard(Question question) {
    return Container(
      margin: EdgeInsets.only(top: 20.h),
      padding: EdgeInsets.all(24.w),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(
          color: AppColors.secondary.withOpacity(0.3),
          width: 2.w,
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor,
            blurRadius: 24.r,
            offset: Offset(0, 12.h),
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
                      AppColors.primary.withOpacity(0.1),
                      AppColors.secondary.withOpacity(0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14.r),
                ),
                child: Icon(
                  Icons.quiz_rounded,
                  color: AppColors.primary,
                  size: 24.r,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Text(
                  'اختر الإجابة الصحيحة:',
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: AppColors.secondary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 20.h),
          Container(
            width: double.infinity,
            height: 2.h,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withOpacity(0.3),
                  AppColors.secondary.withOpacity(0.3),
                  AppColors.primary.withOpacity(0.3),
                ],
              ),
              borderRadius: BorderRadius.circular(1.r),
            ),
          ),
          SizedBox(height: 20.h),
          Text(
            question.questionText,
            style: TextStyle(
              fontSize: 17.sp,
              color: Theme.of(context).textTheme.bodyLarge?.color,
              fontWeight: FontWeight.w600,
              height: 1.7,
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
    final optionLabels = ['أ', 'ب', 'ج', 'د'];
    final optionLabel = index < optionLabels.length
        ? optionLabels[index]
        : '${index + 1}';

    return Container(
      margin: EdgeInsets.only(bottom: 14.h),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20.r),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            padding: EdgeInsets.all(18.w),
            decoration: BoxDecoration(
              gradient: isSelected
                  ? LinearGradient(
                      colors: [AppColors.primary, AppColors.primaryDark],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              color: isSelected ? null : Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(20.r),
              border: Border.all(
                color: isSelected ? AppColors.primary : AppColors.border,
                width: isSelected ? 2.w : 1.5.w,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.4),
                        blurRadius: 16.r,
                        offset: Offset(0, 8.h),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: AppColors.grey.withOpacity(0.08),
                        blurRadius: 8.r,
                        offset: Offset(0, 4.h),
                      ),
                    ],
            ),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 44.w,
                  height: 44.w,
                  decoration: BoxDecoration(
                    gradient: isSelected
                        ? LinearGradient(
                            colors: [
                              AppColors.secondary,
                              AppColors.secondaryDark,
                            ],
                          )
                        : LinearGradient(
                            colors: [
                              AppColors.primary.withOpacity(0.1),
                              AppColors.secondary.withOpacity(0.1),
                            ],
                          ),
                    borderRadius: BorderRadius.circular(14.r),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.secondary
                          : AppColors.primary.withOpacity(0.3),
                      width: 2.w,
                    ),
                  ),
                  child: Center(
                    child: isSelected
                        ? Icon(
                            Icons.check_rounded,
                            size: 24.r,
                            color: AppColors.white,
                          )
                        : Text(
                            optionLabel,
                            style: TextStyle(
                              fontSize: 18.sp,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                  ),
                ),
                SizedBox(width: 16.w),
                Expanded(
                  child: Text(
                    text,
                    style: TextStyle(
                      fontSize: 15.sp,
                      color: isSelected
                          ? AppColors.white
                          : AppColors.textPrimary,
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

  Widget _buildNavigationButtons() {
    return Row(
      children: [
        if (_currentQuestionIndex > 0)
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16.r),
                border: Border.all(color: AppColors.primary, width: 2.w),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    _cardController.reset();
                    setState(() {
                      _currentQuestionIndex--;
                      _selectedAnswerIndex =
                          _userAnswers[_currentQuestionIndex] != -1
                          ? _userAnswers[_currentQuestionIndex]
                          : null;
                    });
                    _cardController.forward();
                  },
                  borderRadius: BorderRadius.circular(16.r),
                  child: Container(
                    padding: EdgeInsets.symmetric(vertical: 16.h),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.arrow_back_rounded,
                          color: AppColors.primary,
                          size: 20.r,
                        ),
                        SizedBox(width: 8.w),
                        Text(
                          'السابق',
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
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
                    ? [AppColors.secondary, AppColors.secondaryDark]
                    : [AppColors.grey, AppColors.grey],
              ),
              borderRadius: BorderRadius.circular(16.r),
              boxShadow: _selectedAnswerIndex != null
                  ? [
                      BoxShadow(
                        color: AppColors.secondary.withOpacity(0.4),
                        blurRadius: 12.r,
                        offset: Offset(0, 6.h),
                      ),
                    ]
                  : [],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _selectedAnswerIndex != null ? _nextQuestion : null,
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
    );
  }

  Widget _buildResultsScreen() {
    final percentage = (_correctAnswers / _questions.length * 100).round();
    final wrongIndexes = <int>[];
    for (int i = 0; i < _questions.length; i++) {
      if (_userAnswers[i] != _questions[i].correctAnswerIndex) {
        wrongIndexes.add(i);
      }
    }

    Color resultColor = percentage >= 80
        ? AppColors.success
        : percentage >= 60
        ? AppColors.warning
        : AppColors.error;

    String resultMessage = percentage >= 80
        ? 'ممتاز! أداء رائع 🌟'
        : percentage >= 60
        ? 'جيد! يمكنك التحسن 💪'
        : 'استمر في المحاولة 📚';

    return SingleChildScrollView(
      padding: EdgeInsets.all(20.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: EdgeInsets.symmetric(vertical: 16.h),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close, color: AppColors.white),
                ),
                Expanded(
                  child: Text(
                    'نتيجة الاختبار',
                    style: TextStyle(
                      color: AppColors.white,
                      fontSize: 22.sp,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                SizedBox(width: 48.w),
              ],
            ),
          ),

          SizedBox(height: 20.h),

          // Result Card
          Container(
            padding: EdgeInsets.all(32.w),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(32.r),
              boxShadow: [
                BoxShadow(
                  color: resultColor.withOpacity(0.3),
                  blurRadius: 32.r,
                  offset: Offset(0, 16.h),
                ),
              ],
            ),
            child: Column(
              children: [
                // Score Circle
                Container(
                  width: 160.w,
                  height: 160.w,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CircularProgressIndicator(
                        value: 1,
                        strokeWidth: 12.w,
                        backgroundColor: AppColors.lightGrey,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.lightGrey,
                        ),
                      ),
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: percentage / 100),
                        duration: const Duration(milliseconds: 1500),
                        curve: Curves.easeOutCubic,
                        builder: (context, value, _) =>
                            CircularProgressIndicator(
                              value: value,
                              strokeWidth: 12.w,
                              strokeCap: StrokeCap.round,
                              backgroundColor: Colors.transparent,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                resultColor,
                              ),
                            ),
                      ),
                      Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '$percentage%',
                              style: TextStyle(
                                fontSize: 42.sp,
                                fontWeight: FontWeight.bold,
                                color: resultColor,
                              ),
                            ),
                            Text(
                              '$_correctAnswers/${_questions.length}',
                              style: TextStyle(
                                fontSize: 16.sp,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 24.h),

                Text(
                  resultMessage,
                  style: TextStyle(
                    fontSize: 22.sp,
                    fontWeight: FontWeight.bold,
                    color: resultColor,
                  ),
                  textAlign: TextAlign.center,
                ),

                SizedBox(height: 24.h),

                // Stats Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildStatItem(
                      icon: Icons.check_circle_rounded,
                      label: 'صحيحة',
                      value: '$_correctAnswers',
                      color: AppColors.success,
                    ),
                    Container(
                      width: 1.w,
                      height: 50.h,
                      color: AppColors.border,
                    ),
                    _buildStatItem(
                      icon: Icons.cancel_rounded,
                      label: 'خاطئة',
                      value: '${wrongIndexes.length}',
                      color: AppColors.error,
                    ),
                    Container(
                      width: 1.w,
                      height: 50.h,
                      color: AppColors.border,
                    ),
                    _buildStatItem(
                      icon: Icons.quiz_rounded,
                      label: 'المجموع',
                      value: '${_questions.length}',
                      color: AppColors.primary,
                    ),
                  ],
                ),
              ],
            ),
          ),

          SizedBox(height: 24.h),

          // Wrong Answers Section
          if (wrongIndexes.isNotEmpty) ...[
            Container(
              padding: EdgeInsets.all(20.w),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(24.r),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.error_outline_rounded,
                        color: AppColors.error,
                        size: 24.r,
                      ),
                      SizedBox(width: 12.w),
                      Text(
                        'الإجابات الخاطئة',
                        style: TextStyle(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16.h),
                  ...wrongIndexes.map((index) => _buildWrongItem(index)),
                ],
              ),
            ),
          ],

          SizedBox(height: 24.h),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16.r),
                    border: Border.all(color: AppColors.primary, width: 2.w),
                  ),
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'العودة',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 16.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 16.w),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.primary, AppColors.primaryDark],
                    ),
                    borderRadius: BorderRadius.circular(16.r),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.4),
                        blurRadius: 12.r,
                        offset: Offset(0, 6.h),
                      ),
                    ],
                  ),
                  child: TextButton(
                    onPressed: () {
                      setState(() {
                        _currentQuestionIndex = 0;
                        _selectedAnswerIndex = null;
                        _userAnswers = List.filled(_questions.length, -1);
                        _correctAnswers = 0;
                        _testCompleted = false;
                      });
                      _cardController.forward();
                    },
                    child: Text(
                      'إعادة الاختبار',
                      style: TextStyle(
                        color: AppColors.white,
                        fontSize: 16.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          SizedBox(height: 40.h),
        ],
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
        Icon(icon, color: color, size: 28.r),
        SizedBox(height: 8.h),
        Text(
          value,
          style: TextStyle(
            fontSize: 22.sp,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 12.sp, color: Colors.black54),
        ),
      ],
    );
  }

  Widget _buildWrongItem(int index) {
    final question = _questions[index];
    final userAnswer = _userAnswers[index];
    final userAnswerText = userAnswer >= 0
        ? question.options[userAnswer]
        : 'لم تجب';
    final correctAnswerText = question.options[question.correctAnswerIndex];

    return Container(
      margin: EdgeInsets.only(bottom: 16.h),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.error.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.error.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Text(
                  'سؤال ${index + 1}',
                  style: TextStyle(
                    color: AppColors.error,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Text(
            question.questionText,
            style: TextStyle(
              fontSize: 14.sp,
              color: Colors.black,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 12.h),
          Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: AppColors.error.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: Row(
              children: [
                Icon(Icons.close, color: AppColors.error, size: 18.r),
                SizedBox(width: 8.w),
                Expanded(
                  child: Text(
                    'إجابتك: $userAnswerText',
                    style: TextStyle(color: AppColors.error, fontSize: 13.sp),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 8.h),
          Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: Row(
              children: [
                Icon(Icons.check, color: AppColors.success, size: 18.r),
                SizedBox(width: 8.w),
                Expanded(
                  child: Text(
                    'الصحيحة: $correctAnswerText',
                    style: TextStyle(color: AppColors.success, fontSize: 13.sp),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showExitConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.r),
        ),
        title: Row(
          children: [
            Icon(Icons.warning_rounded, color: AppColors.warning, size: 28.r),
            SizedBox(width: 12.w),
            Text('تأكيد الخروج', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'هل أنت متأكد من الخروج من الاختبار؟\nسيتم فقدان تقدمك الحالي.',
          style: TextStyle(color: AppColors.textSecondary, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('استمرار', style: TextStyle(color: AppColors.primary)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10.r),
              ),
            ),
            child: Text('خروج', style: TextStyle(color: AppColors.white)),
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
              'لا يوجد اتصال',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          'يرجى التحقق من اتصالك بالإنترنت والمحاولة مرة أخرى.',
          style: TextStyle(color: AppColors.textSecondary, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: Text('العودة', style: TextStyle(color: AppColors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() => _isLoading = true);
              _loadQuestions();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10.r),
              ),
            ),
            child: Text(
              'إعادة المحاولة',
              style: TextStyle(color: AppColors.white),
            ),
          ),
        ],
      ),
    );
  }
}
