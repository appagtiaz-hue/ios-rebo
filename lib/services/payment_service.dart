import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/payment_plan.dart';
import '../models/user.dart';

class PaymentService {
  static const String _paymentHistoryKey = 'payment_history';
  static const String _userTestsKey = 'user_tests';
  static const String _userPlansKey = 'user_plans';

  // Simulate payment processing with validation
  static Future<PaymentResult> processPayment({
    required User user,
    required PaymentPlan plan,
    required String cardNumber,
    required String cardHolderName,
    required String expiryDate,
    required String cvv,
  }) async {
    try {
      // Validate card details
      if (!_validateCardDetails(cardNumber, cardHolderName, expiryDate, cvv)) {
        return PaymentResult(
          success: false,
          message: 'بيانات البطاقة غير صحيحة',
          transactionId: null,
        );
      }

      // Simulate payment processing delay
      await Future.delayed(const Duration(seconds: 2));

      // Simulate payment success/failure (90% success rate for demo)
      final random = Random();
      final isSuccess = random.nextDouble() > 0.1; // 90% success rate

      if (isSuccess) {
        // Generate transaction ID
        final transactionId = _generateTransactionId();

        // Save payment history
        await _savePaymentHistory(user, plan, transactionId);

        // Grant user access to the plan (Local & Server)
        await _grantPlanAccess(user, plan);

        return PaymentResult(
          success: true,
          message: 'تم الدفع بنجاح! يمكنك الآن الوصول إلى الاختبار',
          transactionId: transactionId,
        );
      } else {
        return PaymentResult(
          success: false,
          message: 'فشل في معالجة الدفع. يرجى المحاولة مرة أخرى',
          transactionId: null,
        );
      }
    } catch (e) {
      return PaymentResult(
        success: false,
        message: 'حدث خطأ أثناء معالجة الدفع: $e',
        transactionId: null,
      );
    }
  }

  // Persist MyFatoorah success result using existing history and plan access logic
  static Future<PaymentResult> processMyFatoorahResult({
    required User user,
    required PaymentPlan plan,
    required String transactionId,
  }) async {
    try {
      await _savePaymentHistory(user, plan, transactionId);
      await _grantPlanAccess(user, plan);
      return PaymentResult(
        success: true,
        message:
            'تم الدفع عبر MyFatoorah بنجاح! يمكنك الآن الوصول إلى الاختبار',
        transactionId: transactionId,
      );
    } catch (e) {
      return PaymentResult(
        success: false,
        message: 'حدث خطأ أثناء حفظ عملية الدفع: $e',
        transactionId: null,
      );
    }
  }

  // Validate card details
  static bool _validateCardDetails(
    String cardNumber,
    String cardHolderName,
    String expiryDate,
    String cvv,
  ) {
    // Basic validation
    if (cardNumber.length < 13 || cardNumber.length > 19) {
      return false;
    }

    if (cardHolderName.trim().isEmpty) {
      return false;
    }

    if (cvv.length < 3 || cvv.length > 4) {
      return false;
    }

    // Validate expiry date format (MM/YY)
    if (!RegExp(r'^\d{2}/\d{2}$').hasMatch(expiryDate)) {
      return false;
    }

    // Check if card is expired
    final parts = expiryDate.split('/');
    final month = int.tryParse(parts[0]);
    final year = int.tryParse(parts[1]);

    if (month == null || year == null || month < 1 || month > 12) {
      return false;
    }

    final now = DateTime.now();
    final currentYear = now.year % 100;
    final currentMonth = now.month;

    if (year < currentYear || (year == currentYear && month < currentMonth)) {
      return false;
    }

    // Luhn algorithm for card number validation
    return _isValidLuhn(cardNumber);
  }

  // Luhn algorithm implementation
  static bool _isValidLuhn(String cardNumber) {
    int sum = 0;
    bool isEven = false;

    // Loop through values starting from the rightmost side
    for (int i = cardNumber.length - 1; i >= 0; i--) {
      int digit = int.parse(cardNumber[i]);

      if (isEven) {
        digit *= 2;
        if (digit > 9) {
          digit -= 9;
        }
      }

      sum += digit;
      isEven = !isEven;
    }

    return (sum % 10) == 0;
  }

  // Generate unique transaction ID
  static String _generateTransactionId() {
    final random = Random();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final randomPart = random.nextInt(10000);
    return 'TXN_${timestamp}_$randomPart';
  }

  // Save payment history
  static Future<void> _savePaymentHistory(
    User user,
    PaymentPlan plan,
    String transactionId,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final historyKey = '${_paymentHistoryKey}_${user.id}';

    final existingHistory = prefs.getString(historyKey);
    List<Map<String, dynamic>> history = [];

    if (existingHistory != null) {
      history = List<Map<String, dynamic>>.from(jsonDecode(existingHistory));
    }

    history.add({
      'transaction_id': transactionId,
      'plan_id': plan.id,
      'plan_name': plan.name,
      'amount': plan.price,
      'currency': plan.currency,
      'date': DateTime.now().toIso8601String(),
      'status': 'completed',
    });

    await prefs.setString(historyKey, jsonEncode(history));
  }

  // Grant user access to the plan
  static Future<void> _grantPlanAccess(
    User user,
    PaymentPlan plan,
  ) async {
    // Update Local Cache (legacy demo flow)
    final prefs = await SharedPreferences.getInstance();
    final testsKey = '${_userTestsKey}_${user.id}';

    final existingTests = prefs.getString(testsKey);
    List<Map<String, dynamic>> tests = [];

    if (existingTests != null) {
      tests = List<Map<String, dynamic>>.from(jsonDecode(existingTests));
    }

    tests.add({
      'plan_id': plan.id,
      'plan_name': plan.name,
      'question_count': plan.questionCount,
      'purchased_date': DateTime.now().toIso8601String(),
      'is_used': false,
    });

    await prefs.setString(testsKey, jsonEncode(tests));

    // Persist perpetual access to the plan for the user
    final plansKey = '${_userPlansKey}_${user.id}';
    final existingPlansJson = prefs.getString(plansKey);
    List<String> plans = [];
    if (existingPlansJson != null) {
      plans = List<String>.from(jsonDecode(existingPlansJson));
    }
    if (!plans.contains(plan.id)) {
      plans.add(plan.id);
      await prefs.setString(plansKey, jsonEncode(plans));
    }
  }

  // Get user's available tests
  static Future<List<Map<String, dynamic>>> getUserTests(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final testsKey = '${_userTestsKey}_$userId';

    final testsJson = prefs.getString(testsKey);
    if (testsJson != null) {
      return List<Map<String, dynamic>>.from(jsonDecode(testsJson));
    }

    return [];
  }

  // Get user's payment history
  static Future<List<Map<String, dynamic>>> getPaymentHistory(
    String userId,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final historyKey = '${_paymentHistoryKey}_$userId';

    final historyJson = prefs.getString(historyKey);
    if (historyJson != null) {
      return List<Map<String, dynamic>>.from(jsonDecode(historyJson));
    }

    return [];
  }

  // Check if user has access to a specific plan
  static Future<bool> hasPlanAccess(String userId, String planId) async {
    final prefs = await SharedPreferences.getInstance();
    final plansKey = '${_userPlansKey}_${userId}';
    final plansJson = prefs.getString(plansKey);
    if (plansJson != null) {
      final List<dynamic> plans = jsonDecode(plansJson);
      return plans.map((e) => e.toString()).contains(planId);
    }
    return false;
  }

  // Mark test as used
  static Future<void> markTestAsUsed(String userId, String planId) async {
    final prefs = await SharedPreferences.getInstance();
    final testsKey = '${_userTestsKey}_$userId';

    final testsJson = prefs.getString(testsKey);
    if (testsJson != null) {
      List<Map<String, dynamic>> tests = List<Map<String, dynamic>>.from(
        jsonDecode(testsJson),
      );

      for (int i = 0; i < tests.length; i++) {
        if (tests[i]['plan_id'] == planId && tests[i]['is_used'] == false) {
          tests[i]['is_used'] = true;
          tests[i]['used_date'] = DateTime.now().toIso8601String();
          break;
        }
      }

      await prefs.setString(testsKey, jsonEncode(tests));
    }
  }
}

class PaymentResult {
  final bool success;
  final String message;
  final String? transactionId;

  PaymentResult({
    required this.success,
    required this.message,
    this.transactionId,
  });
}
