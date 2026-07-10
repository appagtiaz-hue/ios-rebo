import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../constants/colors.dart';
import '../models/premium_question.dart';

class PremiumExamScreen extends StatefulWidget {
  final List<PremiumQuestion> questions;
  final String planName;

  const PremiumExamScreen({
    Key? key,
    required this.questions,
    required this.planName,
  }) : super(key: key);

  @override
  State<PremiumExamScreen> createState() => _PremiumExamScreenState();
}

class _PremiumExamScreenState extends State<PremiumExamScreen>
    with SingleTickerProviderStateMixin {
  int _currentQuestionIndex = 0;
  Map<int, int> _selectedAnswers = {};
  Set<int> _bookmarkedQuestions = {};
  int _score = 0;
  late AnimationController _animationController;

  // Premium colors
  final Color _primaryColor = Color(0xFFFF6B35);
  final Color _secondaryColor = Color(0xFF004E89);
  final Color _accentColor = Color(0xFFFFD700);

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: Duration(milliseconds: 300),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  PremiumQuestion get _currentQuestion =>
      widget.questions[_currentQuestionIndex];

  bool get _isAnswered => _selectedAnswers.containsKey(_currentQuestionIndex);

  void _selectAnswer(int index) {
    if (_isAnswered) return;

    setState(() {
      _selectedAnswers[_currentQuestionIndex] = index;
      if (index == _currentQuestion.correctAnswerIndex) {
        _score++;
      }
    });

    _animationController.forward().then((_) {
      _animationController.reverse();
    });
  }

  void _nextQuestion() {
    if (_currentQuestionIndex < widget.questions.length - 1) {
      setState(() {
        _currentQuestionIndex++;
      });
    } else {
      _showResultDialog();
    }
  }

  void _previousQuestion() {
    if (_currentQuestionIndex > 0) {
      setState(() {
        _currentQuestionIndex--;
      });
    }
  }

  void _toggleBookmark() {
    setState(() {
      if (_bookmarkedQuestions.contains(_currentQuestionIndex)) {
        _bookmarkedQuestions.remove(_currentQuestionIndex);
      } else {
        _bookmarkedQuestions.add(_currentQuestionIndex);
      }
    });
  }

  void _showResultDialog() {
    final percentage = (_score / widget.questions.length * 100).round();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24.r),
        ),
        child: Container(
          padding: EdgeInsets.all(24.w),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [_primaryColor, _accentColor],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24.r),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                percentage >= 70
                    ? Icons.celebration_rounded
                    : Icons.info_outlined,
                size: 64.r,
                color: Colors.white,
              ),
              SizedBox(height: 16.h),
              Text(
                'نتيجتك',
                style: TextStyle(
                  fontSize: 24.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                '$_score / ${widget.questions.length}',
                style: TextStyle(
                  fontSize: 48.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Text(
                '$percentage%',
                style: TextStyle(
                  fontSize: 20.sp,
                  color: Colors.white.withOpacity(0.9),
                ),
              ),
              SizedBox(height: 24.h),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: _primaryColor,
                  padding: EdgeInsets.symmetric(
                    horizontal: 32.w,
                    vertical: 16.h,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16.r),
                  ),
                ),
                child: Text(
                  'إنهاء',
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.workspace_premium_rounded, color: _accentColor),
            SizedBox(width: 8.w),
            Expanded(
              child: Text(
                widget.planName,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF063311), Color(0xFF0D4D2B), Color(0xFF1B5E20)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _bookmarkedQuestions.contains(_currentQuestionIndex)
                  ? Icons.bookmark
                  : Icons.bookmark_border,
              color: Colors.white,
            ),
            onPressed: _toggleBookmark,
          ),
        ],
      ),
      body: Column(
        children: [
          // Progress Bar
          _buildProgressBar(),

          // Question Card
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(20.w),
              child: Column(
                children: [
                  _buildQuestionCard(),
                  SizedBox(height: 20.h),
                  if (_isAnswered && _currentQuestion.explanation.isNotEmpty)
                    _buildExplanationCard(),
                ],
              ),
            ),
          ),

          // Navigation Buttons
          _buildNavigationBar(),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    double progress = (_currentQuestionIndex + 1) / widget.questions.length;

    return Container(
      color: Theme.of(context).cardColor,
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'السؤال ${_currentQuestionIndex + 1} من ${widget.questions.length}',
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                ),
              ),
              Row(
                children: List.generate(
                  _currentQuestion.difficultyStars,
                  (index) => Icon(Icons.star, size: 16.r, color: _accentColor),
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          ClipRRect(
            borderRadius: BorderRadius.circular(8.r),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8.h,
              backgroundColor: AppColors.border,
              valueColor: AlwaysStoppedAnimation<Color>(_primaryColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionCard() {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.scale(
          scale: 1.0 + (_animationController.value * 0.02),
          child: child,
        );
      },
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Theme.of(context).cardColor, Theme.of(context).cardColor],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24.r),
          boxShadow: [
            BoxShadow(
              color: _primaryColor.withOpacity(0.15),
              blurRadius: 20,
              offset: Offset(0, 10.h),
            ),
          ],
          border: Border.all(color: _primaryColor.withOpacity(0.3), width: 2),
        ),
        padding: EdgeInsets.all(20.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Category Badge
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
              decoration: BoxDecoration(
                color: _secondaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Text(
                _currentQuestion.category,
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.bold,
                  color: _secondaryColor,
                ),
              ),
            ),

            SizedBox(height: 16.h),

            // Question Text
            Text(
              _currentQuestion.questionText,
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).textTheme.bodyLarge?.color,
                height: 1.5,
              ),
            ),

            SizedBox(height: 24.h),

            // Options
            ...List.generate(
              _currentQuestion.options.length,
              (index) => _buildOptionTile(index),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionTile(int index) {
    final isSelected = _selectedAnswers[_currentQuestionIndex] == index;
    final isCorrect = index == _currentQuestion.correctAnswerIndex;
    final showCorrect = _isAnswered && isCorrect;
    final showWrong = _isAnswered && isSelected && !isCorrect;

    Color borderColor = AppColors.border;
    Color backgroundColor = Theme.of(context).cardColor;

    if (showCorrect) {
      borderColor = Colors.green;
      backgroundColor = Colors.green.withOpacity(0.1);
    } else if (showWrong) {
      borderColor = Colors.red;
      backgroundColor = Colors.red.withOpacity(0.1);
    } else if (isSelected) {
      borderColor = _primaryColor;
      backgroundColor = _primaryColor.withOpacity(0.1);
    }

    return GestureDetector(
      onTap: () => _selectAnswer(index),
      child: Container(
        margin: EdgeInsets.only(bottom: 12.h),
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: borderColor, width: 2),
        ),
        child: Row(
          children: [
            Container(
              width: 24.r,
              height: 24.r,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: showCorrect
                    ? Colors.green
                    : showWrong
                    ? Colors.red
                    : isSelected
                    ? _primaryColor
                    : Colors.transparent,
                border: Border.all(
                  color: showCorrect
                      ? Colors.green
                      : showWrong
                      ? Colors.red
                      : AppColors.border,
                  width: 2,
                ),
              ),
              child: showCorrect || showWrong
                  ? Icon(
                      showCorrect ? Icons.check : Icons.close,
                      size: 16.r,
                      color: Colors.white,
                    )
                  : null,
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Text(
                _currentQuestion.options[index],
                style: TextStyle(
                  fontSize: 15.sp,
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExplanationCard() {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: _accentColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: _accentColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb, color: _accentColor, size: 20.r),
              SizedBox(width: 8.w),
              Text(
                'الشرح',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                  color: _secondaryColor,
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Text(
            _currentQuestion.explanation,
            style: TextStyle(
              fontSize: 14.sp,
              color: Theme.of(context).textTheme.bodyLarge?.color,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationBar() {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        children: [
          if (_currentQuestionIndex > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: _previousQuestion,
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 14.h),
                  side: BorderSide(color: _primaryColor),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
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
          if (_currentQuestionIndex > 0) SizedBox(width: 12.w),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: _isAnswered ? _nextQuestion : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                disabledBackgroundColor: AppColors.grey,
                padding: EdgeInsets.symmetric(vertical: 14.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
              ),
              child: Text(
                _currentQuestionIndex == widget.questions.length - 1
                    ? 'إنهاء'
                    : 'التالي',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
