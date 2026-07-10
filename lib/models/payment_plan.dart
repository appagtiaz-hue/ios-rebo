import 'package:flutter/material.dart';

// Tab Section Model
class PlanSection {
  final String id;
  final String name;
  final String nameEn;
  final String? questionCollectionName;
  final int questionsCount;

  PlanSection({
    required this.id,
    required this.name,
    required this.nameEn,
    this.questionCollectionName,
    this.questionsCount = 0,
  });

  factory PlanSection.fromJson(Map<String, dynamic> json) {
    return PlanSection(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      nameEn: json['nameEn'] ?? '',
      questionCollectionName: json['questionCollectionName'],
      questionsCount: json['questionsCount'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'nameEn': nameEn,
      'questionCollectionName': questionCollectionName,
      'questionsCount': questionsCount,
    };
  }
}

// Plan Tab Model
class PlanTab {
  final String id;
  final String name;
  final String nameEn;
  final String type; // 'divided', 'standards', 'situational', 'custom'
  final String icon;
  final bool isDefault;
  final int order;
  final List<PlanSection> sections;

  PlanTab({
    required this.id,
    required this.name,
    required this.nameEn,
    required this.type,
    this.icon = 'quiz',
    this.isDefault = false,
    this.order = 0,
    this.sections = const [],
  });

  factory PlanTab.fromJson(Map<String, dynamic> json) {
    return PlanTab(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      nameEn: json['nameEn'] ?? '',
      type: json['type'] ?? 'custom',
      icon: json['icon'] ?? 'quiz',
      isDefault: json['isDefault'] ?? false,
      order: json['order'] ?? 0,
      sections:
          (json['sections'] as List<dynamic>?)
              ?.map((s) => PlanSection.fromJson(s as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'nameEn': nameEn,
      'type': type,
      'icon': icon,
      'isDefault': isDefault,
      'order': order,
      'sections': sections.map((s) => s.toJson()).toList(),
    };
  }

  String getName(BuildContext context) {
    bool isEnglish = Localizations.localeOf(context).languageCode == 'en';
    if (isEnglish && nameEn.isNotEmpty) {
      return nameEn;
    }
    return name;
  }
}

class PaymentPlan {
  final String id;
  final String name;
  final String nameEn;
  final String description;
  final String descriptionEn;
  final int questionCount;
  final double price;
  final String currency;
  final bool isActive;
  final DateTime? createdAt;
  final String primaryColor;
  final String secondaryColor;
  final String? googlePlayProductId;
  final List<PlanTab> tabs;

  PaymentPlan({
    required this.id,
    required this.name,
    required this.nameEn,
    required this.description,
    required this.descriptionEn,
    required this.questionCount,
    required this.price,
    required this.currency,
    required this.isActive,
    this.createdAt,
    this.primaryColor = '#1B5E20',
    this.secondaryColor = '#F6C41C',
    this.googlePlayProductId,
    this.tabs = const [],
  });

  factory PaymentPlan.fromJson(Map<String, dynamic> json) {
    return PaymentPlan(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      name: json['name'] ?? '',
      nameEn: json['nameEn'] ?? '',
      description: json['description'] ?? '',
      descriptionEn: json['descriptionEn'] ?? '',
      questionCount: json['question_count'] ?? 0,
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      currency: json['currency'] ?? 'ريال سعودي',
      isActive: json['is_active'] ?? true,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'])
          : null,
      primaryColor: json['primaryColor'] ?? '#1B5E20',
      secondaryColor: json['secondaryColor'] ?? '#F6C41C',
      googlePlayProductId: json['googlePlayProductId'],
      tabs:
          (json['tabs'] as List<dynamic>?)
              ?.map((tab) => PlanTab.fromJson(tab as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'nameEn': nameEn,
      'description': description,
      'descriptionEn': descriptionEn,
      'question_count': questionCount,
      'price': price,
      'currency': currency,
      'is_active': isActive,
      'createdAt': createdAt?.toIso8601String(),
      'primaryColor': primaryColor,
      'secondaryColor': secondaryColor,
      'googlePlayProductId': googlePlayProductId,
      'tabs': tabs.map((tab) => tab.toJson()).toList(),
    };
  }

  PaymentPlan copyWith({
    String? id,
    String? name,
    String? nameEn,
    String? description,
    String? descriptionEn,
    int? questionCount,
    double? price,
    String? currency,
    bool? isActive,
    DateTime? createdAt,
    String? primaryColor,
    String? secondaryColor,
    String? googlePlayProductId,
    List<PlanTab>? tabs,
  }) {
    return PaymentPlan(
      id: id ?? this.id,
      name: name ?? this.name,
      nameEn: nameEn ?? this.nameEn,
      description: description ?? this.description,
      descriptionEn: descriptionEn ?? this.descriptionEn,
      questionCount: questionCount ?? this.questionCount,
      price: price ?? this.price,
      currency: currency ?? this.currency,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      primaryColor: primaryColor ?? this.primaryColor,
      secondaryColor: secondaryColor ?? this.secondaryColor,
      googlePlayProductId: googlePlayProductId ?? this.googlePlayProductId,
      tabs: tabs ?? this.tabs,
    );
  }

  // Helper methods to get localized content
  String getName(BuildContext context) {
    bool isEnglish = Localizations.localeOf(context).languageCode == 'en';
    if (isEnglish && nameEn.isNotEmpty) {
      return nameEn;
    }
    return name;
  }

  String getDescription(BuildContext context) {
    bool isEnglish = Localizations.localeOf(context).languageCode == 'en';
    if (isEnglish && descriptionEn.isNotEmpty) {
      return descriptionEn;
    }
    return description;
  }

  // Helper to get primary color as Flutter Color
  Color getPrimaryColor() {
    try {
      return Color(int.parse(primaryColor.replaceFirst('#', '0xFF')));
    } catch (e) {
      return const Color(0xFF1B5E20); // Default dark green
    }
  }

  // Helper to get secondary color as Flutter Color
  Color getSecondaryColor() {
    try {
      return Color(int.parse(secondaryColor.replaceFirst('#', '0xFF')));
    } catch (e) {
      return const Color(0xFFF6C41C); // Default gold
    }
  }

  // Get gradient for this plan
  List<Color> getGradient() {
    return [
      getPrimaryColor(),
      getPrimaryColor().withOpacity(0.8),
      getSecondaryColor().withOpacity(0.6),
    ];
  }
}
