class User {
  final String id;
  final String fullName;
  final String email;
  final String? phoneNumber; // Added phone number field
  final String password;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? subscriptionPlanId; // New field for subscription plan ID
  final DateTime?
  subscriptionEndDate; // ADDED BACK: Field for subscription end date
  final List<Map<String, dynamic>> additionalSubscriptions;
  final List<Map<String, dynamic>> purchasedTests; // Added purchased tests
  final String?
  activeSubscriptionId; // Tracks which subscription is currently active

  User({
    required this.id,
    required this.fullName,
    required this.email,
    this.phoneNumber,
    required this.password,
    required this.createdAt,
    required this.updatedAt,
    this.subscriptionPlanId,
    this.subscriptionEndDate,
    this.additionalSubscriptions = const [],
    this.purchasedTests = const [],
    this.activeSubscriptionId,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: (json['_id'] ?? json['id']).toString(),
      fullName: json['name'] ?? json['full_name'],
      email: json['email'] ?? '',
      phoneNumber: json['phoneNumber'] ?? json['phone_number'] ?? json['phone'],
      password:
          json['password'] ?? '', // Password is not always sent from server
      createdAt: DateTime.parse(json['createdAt'] ?? json['created_at']),
      updatedAt: DateTime.parse(
        json['updatedAt'] ?? json['updated_at'] ?? json['createdAt'],
      ),
      subscriptionPlanId:
          json['subscription_plan_id'] ?? json['subscriptionPlanId'],
      subscriptionEndDate: json['subscription_end_date'] != null
          ? DateTime.parse(json['subscription_end_date'])
          : (json['subscriptionEndDate'] != null
                ? DateTime.parse(json['subscriptionEndDate'])
                : null),
      additionalSubscriptions: json['additionalSubscriptions'] != null
          ? List<Map<String, dynamic>>.from(json['additionalSubscriptions'])
          : [],
      purchasedTests: json['purchasedTests'] != null
          ? List<Map<String, dynamic>>.from(json['purchasedTests'])
          : [],
      activeSubscriptionId:
          json['active_subscription_id'] ?? json['activeSubscriptionId'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'full_name': fullName, // Keep for local compatibility
      'email': email,
      'phone_number': phoneNumber,
      'password': password,
      'created_at': createdAt.toIso8601String(), // Keep for local compatibility
      'updated_at': updatedAt.toIso8601String(), // Keep for local compatibility
      'subscription_plan_id': subscriptionPlanId,
      'subscription_end_date': subscriptionEndDate?.toIso8601String(),
      'additionalSubscriptions': additionalSubscriptions,
      'purchasedTests': purchasedTests,
      'active_subscription_id': activeSubscriptionId,
    };
  }

  User copyWith({
    String? id,
    String? fullName,
    String? email,
    String? phoneNumber,
    String? password,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? subscriptionPlanId,
    DateTime? subscriptionEndDate,
    List<Map<String, dynamic>>? additionalSubscriptions,
    List<Map<String, dynamic>>? purchasedTests,
    String? activeSubscriptionId,
  }) {
    return User(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      password: password ?? this.password,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      subscriptionPlanId: subscriptionPlanId ?? this.subscriptionPlanId,
      subscriptionEndDate: subscriptionEndDate ?? this.subscriptionEndDate,
      additionalSubscriptions:
          additionalSubscriptions ?? this.additionalSubscriptions,
      purchasedTests: purchasedTests ?? this.purchasedTests,
      activeSubscriptionId: activeSubscriptionId ?? this.activeSubscriptionId,
    );
  }
}
