import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/question.dart';
import 'test_config.dart';
import 'network_service.dart';
import 'auth_service.dart';

class MongoQuestionService {
  static String get baseUrl => NetworkService.baseUrl;

  // Fetch all questions from MongoDB
  static Future<List<Question>> getAllQuestions() async {
    // Check network connectivity
    final isOnline = await NetworkService.isConnected();

    // If online, fetch from server
    if (isOnline) {
      try {
        final url = Uri.parse('$baseUrl/api/questions');
        final headers = await AuthService.authHeaders();
        final response = await http
            .get(url, headers: headers)
            .timeout(Duration(seconds: TestConfig.requestTimeout));

        if (response.statusCode == 200) {
          final jsonData = jsonDecode(response.body);
          if (jsonData['success'] == true && jsonData['data'] != null) {
            final List<dynamic> questionsData = jsonData['data'];
            return questionsData.map((q) => Question.fromJson(q)).toList();
          }
        }

        if (TestConfig.enableDebugLogs) {
          print('❌ Error fetching questions: ${response.statusCode}');
        }
        return [];
      } catch (e) {
        if (TestConfig.enableDebugLogs) {
          print('❌ Exception fetching all questions: $e');
        }
        return [];
      }
    }

    // If offline, return empty
    if (TestConfig.enableDebugLogs) {
      print('⚠️ No internet connection');
    }
    return [];
  }

  // Fetch random questions from MongoDB
  static Future<List<Question>> getRandomQuestions(
    int count, {
    String? planId,
  }) async {
    // Check network connectivity
    final isOnline = await NetworkService.isConnected();

    // If online, fetch from server
    if (isOnline) {
      try {
        final query = planId != null
            ? '?planId=${Uri.encodeComponent(planId)}'
            : '';
        final url = Uri.parse('$baseUrl/api/questions/random/$count$query');
        final headers = await AuthService.authHeaders();
        final response = await http
            .get(url, headers: headers)
            .timeout(Duration(seconds: TestConfig.requestTimeout));

        if (response.statusCode == 200) {
          final jsonData = jsonDecode(response.body);
          if (jsonData['success'] == true && jsonData['data'] != null) {
            final List<dynamic> questionsData = jsonData['data'];
            return questionsData.map((q) => Question.fromJson(q)).toList();
          }
        }

        if (TestConfig.enableDebugLogs) {
          print('❌ Error fetching random questions: ${response.statusCode}');
        }
        return [];
      } catch (e) {
        if (TestConfig.enableDebugLogs) {
          print('❌ Exception fetching random questions: $e');
        }
        return [];
      }
    }

    // If offline, return empty
    if (TestConfig.enableDebugLogs) {
      print('⚠️ No internet connection');
    }
    return [];
  }

  // Fetch trial questions (IDs 1-5)
  static Future<List<Question>> getTrialQuestions() async {
    try {
      final url = Uri.parse('$baseUrl/api/questions/trial');
      final response = await http
          .get(url)
          .timeout(Duration(seconds: TestConfig.requestTimeout));

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        if (jsonData['success'] == true && jsonData['data'] != null) {
          final List<dynamic> questionsData = jsonData['data'];
          return questionsData.map((q) => Question.fromJson(q)).toList();
        }
      }

      if (TestConfig.enableDebugLogs) {
        print('❌ Error fetching trial questions: ${response.statusCode}');
      }
      return [];
    } catch (e) {
      if (TestConfig.enableDebugLogs) {
        print('❌ Exception fetching trial questions: $e');
      }
      return [];
    }
  }

  // Fetch premium questions (all questions)
  static Future<List<Question>> getPremiumQuestions() async {
    return await getAllQuestions();
  }

  // Fetch questions by specific IDs
  static Future<List<Question>> getQuestionsByIds(List<String> ids) async {
    try {
      final url = Uri.parse('$baseUrl/api/questions/by-ids');
      final headers = await AuthService.authHeaders();
      final response = await http
          .post(
            url,
            headers: headers,
            body: jsonEncode({'ids': ids}),
          )
          .timeout(Duration(seconds: TestConfig.requestTimeout));

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        if (jsonData['success'] == true && jsonData['data'] != null) {
          final List<dynamic> questionsData = jsonData['data'];
          return questionsData.map((q) => Question.fromJson(q)).toList();
        }
      }

      if (TestConfig.enableDebugLogs) {
        print('❌ Error fetching questions by IDs: ${response.statusCode}');
      }
      return [];
    } catch (e) {
      if (TestConfig.enableDebugLogs) {
        print('❌ Exception fetching questions by IDs: $e');
      }
      return [];
    }
  }

  // Fetch questions by page
  static Future<Map<String, dynamic>> getQuestionsPage(
    int page,
    int limit, {
    String? planId,
  }) async {
    try {
      String urlString = '$baseUrl/api/questions/page/$page/$limit';
      if (planId != null) {
        urlString += '?planId=$planId';
      }

      final url = Uri.parse(urlString);
      final headers = await AuthService.authHeaders();
      final response = await http
          .get(url, headers: headers)
          .timeout(Duration(seconds: TestConfig.requestTimeout));

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        if (jsonData['success'] == true && jsonData['data'] != null) {
          final List<dynamic> questionsData = jsonData['data'];
          final questions = questionsData
              .map((q) => Question.fromJson(q))
              .toList();
          return {'questions': questions, 'pagination': jsonData['pagination']};
        }
      }

      if (TestConfig.enableDebugLogs) {
        print('❌ Error fetching questions page: ${response.statusCode}');
      }
      return {'questions': <Question>[], 'pagination': null};
    } catch (e) {
      if (TestConfig.enableDebugLogs) {
        print('❌ Exception fetching questions page: $e');
      }
      return {'questions': <Question>[], 'pagination': null};
    }
  }

  // Fetch questions by standard collection
  static Future<List<Question>> getQuestionsByStandard(
    String collectionName, {
    String? planId,
  }) async {
    try {
      String urlString = '$baseUrl/api/questions/standard/$collectionName';
      if (planId != null) {
        urlString += '?planId=$planId';
      }
      final url = Uri.parse(urlString);
      final headers = await AuthService.authHeaders();
      final response = await http
          .get(url, headers: headers)
          .timeout(Duration(seconds: TestConfig.requestTimeout));

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        if (jsonData['success'] == true && jsonData['data'] != null) {
          final List<dynamic> questionsData = jsonData['data'];
          return questionsData.map((q) => Question.fromJson(q)).toList();
        }
      }

      if (TestConfig.enableDebugLogs) {
        print('❌ Error fetching standard questions: ${response.statusCode}');
      }
      return [];
    } catch (e) {
      if (TestConfig.enableDebugLogs) {
        print('❌ Exception fetching standard questions: $e');
      }
      return [];
    }
  }

  // ============ ADDITIONAL TESTS METHODS ============

  // Fetch all available additional tests
  static Future<List<Map<String, dynamic>>> getAdditionalTests() async {
    try {
      final url = Uri.parse('$baseUrl/mobile/api/additional-tests');
      final response = await http
          .get(url)
          .timeout(Duration(seconds: TestConfig.requestTimeout));

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        if (jsonData['success'] == true && jsonData['data'] != null) {
          final List<dynamic> testsData = jsonData['data'];
          return testsData.cast<Map<String, dynamic>>();
        }
      }

      if (TestConfig.enableDebugLogs) {
        print('❌ Error fetching additional tests: ${response.statusCode}');
      }
      return [];
    } catch (e) {
      if (TestConfig.enableDebugLogs) {
        print('❌ Exception fetching additional tests: $e');
      }
      return [];
    }
  }

  // Fetch questions for a specific additional test
  static Future<List<Question>> getAdditionalTestQuestions(
    String testId,
  ) async {
    try {
      final url = Uri.parse(
        '$baseUrl/mobile/api/additional-tests/$testId/questions',
      );
      final headers = await AuthService.authHeaders();
      final response = await http
          .get(url, headers: headers)
          .timeout(Duration(seconds: TestConfig.requestTimeout));

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        if (jsonData['success'] == true && jsonData['data'] != null) {
          final List<dynamic> questionsData = jsonData['data'];
          return questionsData.map((q) => Question.fromJson(q)).toList();
        }
      }

      if (TestConfig.enableDebugLogs) {
        print(
          '❌ Error fetching additional test questions: ${response.statusCode}',
        );
      }
      return [];
    } catch (e) {
      if (TestConfig.enableDebugLogs) {
        print('❌ Exception fetching additional test questions: $e');
      }
      return [];
    }
  }

  // Fetch random questions from a specific additional test
  static Future<List<Question>> getRandomAdditionalTestQuestions(
    String testId,
    int count,
  ) async {
    try {
      final url = Uri.parse(
        '$baseUrl/mobile/api/additional-tests/$testId/questions/random/$count',
      );
      final headers = await AuthService.authHeaders();
      final response = await http
          .get(url, headers: headers)
          .timeout(Duration(seconds: TestConfig.requestTimeout));

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        if (jsonData['success'] == true && jsonData['data'] != null) {
          final List<dynamic> questionsData = jsonData['data'];
          return questionsData.map((q) => Question.fromJson(q)).toList();
        }
      }

      if (TestConfig.enableDebugLogs) {
        print(
          '❌ Error fetching random additional test questions: ${response.statusCode}',
        );
      }
      return [];
    } catch (e) {
      if (TestConfig.enableDebugLogs) {
        print('❌ Exception fetching random additional test questions: $e');
      }
      return [];
    }
  }
}
