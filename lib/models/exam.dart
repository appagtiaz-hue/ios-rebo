class Exam {
  final String id;
  final String title;
  final String? description;
  final String subjectId;
  final String teacherId;
  final int duration; // in minutes
  final int totalQuestions;
  final int totalPoints;
  final DateTime examDate;
  final DateTime startTime;
  final DateTime endTime;
  final bool isActive;
  final int totalStudents;
  final double averageScore;
  final DateTime createdAt;
  final DateTime updatedAt;

  Exam({
    required this.id,
    required this.title,
    this.description,
    required this.subjectId,
    required this.teacherId,
    required this.duration,
    required this.totalQuestions,
    required this.totalPoints,
    required this.examDate,
    required this.startTime,
    required this.endTime,
    required this.isActive,
    required this.totalStudents,
    required this.averageScore,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Exam.fromJson(Map<String, dynamic> json) {
    return Exam(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      subjectId: json['subject_id'],
      teacherId: json['teacher_id'],
      duration: json['duration'],
      totalQuestions: json['total_questions'],
      totalPoints: json['total_points'],
      examDate: DateTime.parse(json['exam_date']),
      startTime: DateTime.parse(json['start_time']),
      endTime: DateTime.parse(json['end_time']),
      isActive: json['is_active'] ?? false,
      totalStudents: json['total_students'] ?? 0,
      averageScore: (json['average_score'] ?? 0.0).toDouble(),
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'subject_id': subjectId,
      'teacher_id': teacherId,
      'duration': duration,
      'total_questions': totalQuestions,
      'total_points': totalPoints,
      'exam_date': examDate.toIso8601String(),
      'start_time': startTime.toIso8601String(),
      'end_time': endTime.toIso8601String(),
      'is_active': isActive,
      'total_students': totalStudents,
      'average_score': averageScore,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  Exam copyWith({
    String? id,
    String? title,
    String? description,
    String? subjectId,
    String? teacherId,
    int? duration,
    int? totalQuestions,
    int? totalPoints,
    DateTime? examDate,
    DateTime? startTime,
    DateTime? endTime,
    bool? isActive,
    int? totalStudents,
    double? averageScore,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Exam(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      subjectId: subjectId ?? this.subjectId,
      teacherId: teacherId ?? this.teacherId,
      duration: duration ?? this.duration,
      totalQuestions: totalQuestions ?? this.totalQuestions,
      totalPoints: totalPoints ?? this.totalPoints,
      examDate: examDate ?? this.examDate,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      isActive: isActive ?? this.isActive,
      totalStudents: totalStudents ?? this.totalStudents,
      averageScore: averageScore ?? this.averageScore,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
