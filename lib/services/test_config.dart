// ملف تكوين للاختبار
// يمكن استخدامه لتغيير إعدادات الاختبار بسهولة

import '../config/environment.dart';

class TestConfig {
  // عنوان السيرفر للاختبار - يستخدم EnvironmentConfig للحصول على العنوان الصحيح
  static String get serverUrl => EnvironmentConfig.baseUrl;

  // عنوان ngrok (إذا كنت تستخدمه)
  static const String ngrokUrl = 'https://your-ngrok-url.ngrok-free.app';

  // استخدام ngrok أم لا
  static const bool useNgrok = false;

  // تفعيل رسائل التصحيح
  static const bool enableDebugLogs = true;

  // timeout للطلبات (بالثواني) - زودت للنت البطيء
  static const int requestTimeout = 60;

  // timeout للمزامنة (بالثواني) - وقت أطول للعمليات الثقيلة
  static const int syncTimeout = 120;

  // تفعيل النظام الهجين
  static const bool enableHybridMode = true;

  // عدد الأسئلة المتوقع
  static const int expectedQuestionsCount = 1063;

  // معلومات الشبكة - تستخدم من EnvironmentConfig
  static String get localIP =>
      EnvironmentConfig.baseUrl.replaceAll('http://', '').split(':')[0];
  static const int serverPort = 5000;

  // رسائل الاختبار
  static const Map<String, String> testMessages = {
    'serverConnected': '✅ تم الاتصال بالسيرفر بنجاح',
    'serverError': '❌ خطأ في الاتصال بالسيرفر',
    'usingCache': '📱 استخدام البيانات المحلية',
    'syncComplete': '🔄 تمت المزامنة بنجاح',
    'questionsLoaded': '📚 تم تحميل الأسئلة بنجاح',
    'userLoggedIn': '👤 تم تسجيل الدخول بنجاح',
  };

  // بيانات اختبار المستخدمين
  static const List<Map<String, String>> testUsers = [
    {
      'phoneNumber': '0501234567',
      'password': '123456',
      'name': 'مستخدم تجريبي 1',
    },
    {
      'phoneNumber': '0507654321',
      'password': '123456',
      'name': 'مستخدم تجريبي 2',
    },
  ];

  // خطط الدفع للاختبار
  static const List<Map<String, dynamic>> testPlans = [
    {
      'id': 'silver',
      'name': 'الخطة الفضية',
      'price': 50.0,
      'questionCount': 200,
    },
    {
      'id': 'gold',
      'name': 'الخطة الذهبية',
      'price': 100.0,
      'questionCount': 500,
    },
    {
      'id': 'premium',
      'name': 'الخطة البريميم',
      'price': 120.0,
      'questionCount': 0, // كل الأسئلة
    },
  ];
}
