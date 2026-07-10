class Student {
  final String id;
  final String name;
  final String studentId;
  final String email;
  final String phone;
  final String? avatar;
  final String className;
  final String? parentPhone;
  final String? parentEmail;
  final DateTime createdAt;
  final DateTime updatedAt;

  Student({
    required this.id,
    required this.name,
    required this.studentId,
    required this.email,
    required this.phone,
    this.avatar,
    required this.className,
    this.parentPhone,
    this.parentEmail,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Student.fromJson(Map<String, dynamic> json) {
    return Student(
      id: json['id'],
      name: json['name'],
      studentId: json['student_id'],
      email: json['email'],
      phone: json['phone'],
      avatar: json['avatar'],
      className: json['class_name'],
      parentPhone: json['parent_phone'],
      parentEmail: json['parent_email'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'student_id': studentId,
      'email': email,
      'phone': phone,
      'avatar': avatar,
      'class_name': className,
      'parent_phone': parentPhone,
      'parent_email': parentEmail,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  Student copyWith({
    String? id,
    String? name,
    String? studentId,
    String? email,
    String? phone,
    String? avatar,
    String? className,
    String? parentPhone,
    String? parentEmail,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Student(
      id: id ?? this.id,
      name: name ?? this.name,
      studentId: studentId ?? this.studentId,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      avatar: avatar ?? this.avatar,
      className: className ?? this.className,
      parentPhone: parentPhone ?? this.parentPhone,
      parentEmail: parentEmail ?? this.parentEmail,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
