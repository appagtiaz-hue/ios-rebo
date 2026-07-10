class PremiumQuestion {
  final int id;
  final String questionText;
  final List<String> options;
  final int correctAnswerIndex;
  final String category;
  final String difficulty; // easy, medium, hard
  final String explanation;
  final String answerJustification;
  final List<String> tags;
  final bool isPremium;

  PremiumQuestion({
    required this.id,
    required this.questionText,
    required this.options,
    required this.correctAnswerIndex,
    required this.category,
    this.difficulty = 'medium',
    this.explanation = '',
    this.answerJustification = '',
    this.tags = const [],
    this.isPremium = true,
  });

  factory PremiumQuestion.fromJson(Map<String, dynamic> json) {
    return PremiumQuestion(
      id: json['id'] ?? 0,
      questionText: json['question_text'] ?? '',
      options: List<String>.from(json['options'] ?? []),
      correctAnswerIndex: json['correct_answer_index'] ?? 0,
      category: json['category'] ?? '',
      difficulty: json['difficulty'] ?? 'medium',
      explanation: json['explanation'] ?? '',
      answerJustification: json['answer_justification'] ?? '',
      tags: List<String>.from(json['tags'] ?? []),
      isPremium: json['isPremium'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'question_text': questionText,
      'options': options,
      'correct_answer_index': correctAnswerIndex,
      'category': category,
      'difficulty': difficulty,
      'explanation': explanation,
      'answer_justification': answerJustification,
      'tags': tags,
      'isPremium': isPremium,
    };
  }

  // Helper methods
  int get difficultyStars {
    switch (difficulty.toLowerCase()) {
      case 'easy':
        return 1;
      case 'medium':
        return 2;
      case 'hard':
        return 3;
      default:
        return 2;
    }
  }

  String get difficultyLabel {
    switch (difficulty.toLowerCase()) {
      case 'easy':
        return 'سهل';
      case 'medium':
        return 'متوسط';
      case 'hard':
        return 'صعب';
      default:
        return 'متوسط';
    }
  }
}
