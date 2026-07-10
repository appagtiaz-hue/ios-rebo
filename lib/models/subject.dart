class Subject {
  final String id;
  final String name;
  final String code;
  final String? description;
  final String teacherId;
  final String className;
  final int totalStudents;
  final int totalExams;
  final double averageScore;
  final DateTime createdAt;
  final DateTime updatedAt;

  Subject({
    required this.id,
    required this.name,
    required this.code,
    this.description,
    required this.teacherId,
    required this.className,
    required this.totalStudents,
    required this.totalExams,
    required this.averageScore,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Subject.fromJson(Map<String, dynamic> json) {
    return Subject(
      id: json['id'],
      name: json['name'],
      code: json['code'],
      description: json['description'],
      teacherId: json['teacher_id'],
      className: json['class_name'],
      totalStudents: json['total_students'] ?? 0,
      totalExams: json['total_exams'] ?? 0,
      averageScore: (json['average_score'] ?? 0.0).toDouble(),
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'code': code,
      'description': description,
      'teacher_id': teacherId,
      'class_name': className,
      'total_students': totalStudents,
      'total_exams': totalExams,
      'average_score': averageScore,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  Subject copyWith({
    String? id,
    String? name,
    String? code,
    String? description,
    String? teacherId,
    String? className,
    int? totalStudents,
    int? totalExams,
    double? averageScore,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Subject(
      id: id ?? this.id,
      name: name ?? this.name,
      code: code ?? this.code,
      description: description ?? this.description,
      teacherId: teacherId ?? this.teacherId,
      className: className ?? this.className,
      totalStudents: totalStudents ?? this.totalStudents,
      totalExams: totalExams ?? this.totalExams,
      averageScore: averageScore ?? this.averageScore,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
