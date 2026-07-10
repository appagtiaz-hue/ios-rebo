class Question {
  final String id;
  final String questionText;
  final List<String> options;
  final int correctAnswerIndex;
  final String category;
  final String answerJustification;
  final DateTime createdAt;

  Question({
    required this.id,
    required this.questionText,
    required this.options,
    required this.correctAnswerIndex,
    required this.category,
    this.answerJustification = '',
    required this.createdAt,
  });

  factory Question.fromJson(Map<String, dynamic> json) {
    return Question(
      id: json['id']?.toString() ?? '',
      questionText: json['question_text'] ?? '',
      options: (json['options'] as List<dynamic>? ?? []).cast<String>(),
      correctAnswerIndex: (() {
        final val = json['correct_answer_index'];
        if (val is int) return val;
        if (val is String) return int.tryParse(val) ?? 0;
        if (val is Map) {
          if (val.containsKey(' numberInt'))
            return int.tryParse(val['\$numberInt']) ?? 0;
          if (val.containsKey(' numberLong'))
            return int.tryParse(val['\$numberLong']) ?? 0;
        }
        return 0;
      })(),
      category: json['category'] ?? '',
      answerJustification: json['answer_justification'] ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at']) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'question_text': questionText,
      'options': options,
      'correct_answer_index': correctAnswerIndex,
      'category': category,
      'answer_justification': answerJustification,
      'created_at': createdAt.toIso8601String(),
    };
  }

  Question copyWith({
    String? id,
    String? questionText,
    List<String>? options,
    int? correctAnswerIndex,
    String? category,
    String? answerJustification,
    DateTime? createdAt,
  }) {
    return Question(
      id: id ?? this.id,
      questionText: questionText ?? this.questionText,
      options: options ?? this.options,
      correctAnswerIndex: correctAnswerIndex ?? this.correctAnswerIndex,
      category: category ?? this.category,
      answerJustification: answerJustification ?? this.answerJustification,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
