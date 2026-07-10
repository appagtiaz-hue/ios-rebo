// ملف تكوين للاختبار
// يمكن استخدامه لتغيير إعدادات الاختبار بسهولة

class TestConfig {
  // عنوان السيرفر للاختبار
  static const String serverUrl = 'http://192.168.8.172:5000';
  static const int serverPort = 5000;

  // Network Configuration
  // =====================
  // IMPORTANT: Update these values to match your server's actual IP address
  //
  // To find your server's IP address:
  // 1. On Windows: Run 'ipconfig' in Command Prompt
  // 2. On Mac/Linux: Run 'ifconfig' in Terminal
  // 3. Look for the IPv4 address on your network interface
  //
  // Common scenarios:
  // - Android Emulator: Use '10.0.2.2' to access host machine
  // - Physical Device: Use your computer's actual IP address (e.g., '192.168.1.12')
  // - iOS Simulator: Use 'localhost' or '127.0.0.1'
  //
  // Make sure:
  // - Your device and server are on the same network
  // - Firewall allows connections on port 5000
  // - Server is running and accessible
  static const String localIP = '192.168.8.172';

  // عنوان ngrok (إذا كنت تستخدمه)
  static const String ngrokUrl = 'https://your-ngrok-url.ngrok-free.app';

  // استخدام ngrok أم لا
  static const bool useNgrok = false;
  // تفعيل رسائل التصحيح
  static const bool enableDebugLogs = true;

  // timeout للطلبات (بالثواني) - زودت للنت البطيء
  static const int requestTimeout = 60;

  // تفعيل النظام الهجين
  static const bool enableHybridMode = true;

  // عدد الأسئلة المتوقع
  static const int expectedQuestionsCount = 1063;

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
      'questionCount': 1000,
    },
    {
      'id': 'gold',
      'name': 'الخطة الذهبية',
      'price': 100.0,
      'questionCount': 1200,
    },
  ];
}
