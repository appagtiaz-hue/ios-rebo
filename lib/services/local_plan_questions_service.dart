import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/question.dart';

class LocalPlanQuestionsService {
  static String _key(String userId, String planId) =>
      'plan_questions_ userId _planId';

  // حفظ الأسئلة لخطة يوزر معين
  static Future<void> savePlanQuestions(
    String userId,
    String planId,
    List<Question> questions,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _key(userId, planId);
    await prefs.setString(
      key,
      jsonEncode(questions.map((q) => q.toJson()).toList()),
    );
  }

  // استرجاع الأسئلة المحلية لليوزر والخطة
  static Future<List<Question>> getPlanQuestions(
    String userId,
    String planId,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _key(userId, planId);
    final jsonStr = prefs.getString(key);
    if (jsonStr == null) return [];
    final List<dynamic> data = jsonDecode(jsonStr);
    return data.map((e) => Question.fromJson(e)).toList();
  }

  // حذف الأسئلة المحلية لخطة يوزر معين
  static Future<void> deletePlanQuestions(String userId, String planId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _key(userId, planId);
    await prefs.remove(key);
  }
}
