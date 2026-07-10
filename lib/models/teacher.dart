class Teacher {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String? avatar;
  final String? school;
  final String? department;
  final DateTime createdAt;
  final DateTime updatedAt;

  Teacher({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    this.avatar,
    this.school,
    this.department,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Teacher.fromJson(Map<String, dynamic> json) {
    return Teacher(
      id: json['id'],
      name: json['name'],
      email: json['email'],
      phone: json['phone'],
      avatar: json['avatar'],
      school: json['school'],
      department: json['department'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'avatar': avatar,
      'school': school,
      'department': department,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  Teacher copyWith({
    String? id,
    String? name,
    String? email,
    String? phone,
    String? avatar,
    String? school,
    String? department,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Teacher(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      avatar: avatar ?? this.avatar,
      school: school ?? this.school,
      department: department ?? this.department,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
