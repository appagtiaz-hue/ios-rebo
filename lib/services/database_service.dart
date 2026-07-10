import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../models/user.dart';
import '../models/sync_queue_item.dart';
import 'network_service.dart';
import 'sync_queue_service.dart';
import 'test_config.dart';
import 'auth_service.dart';
import '../models/question.dart';
import '../models/payment_plan.dart';

/// A service for managing local and remote data.
class DatabaseService {
  static const String _usersKey = 'users';
  static const String _questionsKey = 'questions';
  static const String _paymentPlansKey = 'payment_plans';
  static const String _currentUserKey = 'current_user';
  static const String _offlinePlanContentKey =
      'offline_plan_content_'; // offline plan data

  // Initialize database with sample data
  static Future<void> initializeDatabase() async {
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey(_usersKey)) {
      await _initializeUsers();
    }
    // Always refresh questions from code to reflect latest edits in this file
    if (prefs.containsKey(_questionsKey)) {
      await prefs.remove(_questionsKey);
    }
  }

  // Users Management
  static Future<void> _initializeUsers() async {
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey(_usersKey)) {
      // Sample users for testing
      final sampleUsers = [
        {
          'id': '1',
          'full_name': 'أحمد محمد',
          'phone_number': '0501234567',
          'national_id': '1234567890',
          'password': '',
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
          'subscription_plan_id': null,
          'subscription_end_date': null,
        },
      ];
      await prefs.setString(_usersKey, jsonEncode(sampleUsers));
    }
  }

  static Future<void> _updateLocalUser(User user) async {
    final prefs = await SharedPreferences.getInstance();
    final safeUser = user.copyWith(password: '');
    final usersJson = prefs.getString(_usersKey);
    if (usersJson != null) {
      final List<dynamic> usersList = jsonDecode(usersJson);
      bool updated = false;
      for (int i = 0; i < usersList.length; i++) {
        if (usersList[i]['id'] == safeUser.id) {
          usersList[i] = safeUser.toJson();
          updated = true;
          break;
        }
      }
      if (!updated) {
        usersList.add(safeUser.toJson());
      }
      await prefs.setString(_usersKey, jsonEncode(usersList));
    } else {
      // إذا لم يكن هناك مستخدمون، أنشئ مفتاح جديد
      await prefs.setString(_usersKey, jsonEncode([safeUser.toJson()]));
    }
  }

  static Future<void> updateUser(User user) async {
    // Update local cache immediately for UI responsiveness
    await _updateLocalUser(user);

    // Try to update on server in the background
    try {
      // Note: The backend does not currently have a mobile endpoint for user updates.
      // This is a placeholder for when `PUT /mobile/api/users/:id` is implemented.
      final response = await http
          .put(
            Uri.parse('${NetworkService.baseUrl}/mobile/api/users/${user.id}'),
            headers: await AuthService.authHeaders(),
            body: jsonEncode(user.toJson()),
          )
          .timeout(Duration(seconds: TestConfig.requestTimeout));

      if (response.statusCode != 200) {
        // Server update failed, add to sync queue
        print(
          '⚠️ Server update failed (${response.statusCode}), adding to sync queue',
        );
        await SyncQueueService.addToQueue(
          operation: SyncOperation.update,
          endpoint: '${NetworkService.baseUrl}/mobile/api/users/${user.id}',
          payload: user.toJson(),
        );
      }
    } catch (e) {
      // Network error, add to sync queue
      print('⚠️ Network error on update, adding to sync queue: $e');
      await SyncQueueService.addToQueue(
        operation: SyncOperation.update,
        endpoint: '${NetworkService.baseUrl}/mobile/api/users/${user.id}',
        payload: user.toJson(),
      );
    }
  }

  static Future<List<User>> getUsers() async {
    final prefs = await SharedPreferences.getInstance();
    final usersJson = prefs.getString(_usersKey);
    List<User> localUsers = [];
    if (usersJson != null) {
      final List<dynamic> usersList = jsonDecode(usersJson);
      localUsers = usersList.map((json) => User.fromJson(json)).toList();
    }

    // Try to fetch current user from server if logged in
    final currentUser = await getCurrentUser();
    if (currentUser != null) {
      try {
        final response = await http
            .get(
              Uri.parse(
                '${TestConfig.serverUrl}/mobile/api/users/me/${Uri.encodeComponent(currentUser.email)}',
              ),
              headers: await AuthService.authHeaders(),
            )
            .timeout(Duration(seconds: TestConfig.requestTimeout));

        if (response.statusCode == 200) {
          final serverData = jsonDecode(response.body)['data'];
          final serverUser = User.fromJson(serverData);
          // Update this user in local cache
          await _updateLocalUser(serverUser);
          // Refresh local users list to include updated user
          final updatedUsersJson = prefs.getString(_usersKey);
          if (updatedUsersJson != null) {
            localUsers = List<dynamic>.from(
              jsonDecode(updatedUsersJson),
            ).map((json) => User.fromJson(json)).toList();
          }
        }
      } catch (e) {
        // Network error, rely on local data
      }
    }

    if (localUsers.isEmpty) {
      // Fallback: initialize default users and try again
      await _initializeUsers();
      final refreshedUsersJson = prefs.getString(_usersKey);
      if (refreshedUsersJson != null) {
        localUsers = List<dynamic>.from(
          jsonDecode(refreshedUsersJson),
        ).map((json) => User.fromJson(json)).toList();
      }
    }
    return localUsers;
  }

  static Future<User?> getUserByEmail(String email) async {
    // Try to fetch from server first
    try {
      final encodedEmail = Uri.encodeComponent(email);
      final response = await http
          .get(
            Uri.parse(
              '${TestConfig.serverUrl}/mobile/api/users/me/$encodedEmail',
            ),
            headers: await AuthService.authHeaders(),
          )
          .timeout(Duration(seconds: TestConfig.requestTimeout));

      if (response.statusCode == 200) {
        final serverData = jsonDecode(response.body)['data'];
        final serverUser = User.fromJson(serverData);
        await _updateLocalUser(serverUser); // Update local cache
        return serverUser;
      }
    } catch (e) {
      // Network error or user not found on server, fall back to local cache
    }

    // Fallback to local cache
    final localUsers = await getUsers();
    try {
      return localUsers.firstWhere((user) => user.email == email);
    } catch (e) {
      return null; // User not found locally either
    }
  }

  static Future<User?> createUser(User user) async {
    try {
      // Try to create on server
      final response = await http
          .post(
            Uri.parse('${TestConfig.serverUrl}/mobile/api/users/signup'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'name': user.fullName,
              'email': user.email,
              'password': user.password,
            }),
          )
          .timeout(Duration(seconds: TestConfig.requestTimeout));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final serverData = jsonDecode(response.body)['data'];
        final newUser = User.fromJson(serverData);
        await _updateLocalUser(newUser); // Add to local cache with server's ID
        return newUser;
      } else {
        // Server creation failed, add to sync queue
        print(
          '⚠️ Server creation failed (${response.statusCode}), adding to sync queue',
        );
        await _updateLocalUser(user); // Add to local cache anyway
        await SyncQueueService.addToQueue(
          operation: SyncOperation.create,
          endpoint: '${TestConfig.serverUrl}/mobile/api/users/signup',
          payload: {
            'name': user.fullName,
            'email': user.email,
            'password': user.password,
          },
        );
        return user;
      }
    } catch (e) {
      // Network error, add to sync queue
      print('⚠️ Network error on create, adding to sync queue: $e');
      await _updateLocalUser(user); // Add to local cache anyway
      await SyncQueueService.addToQueue(
        operation: SyncOperation.create,
        endpoint: '${TestConfig.serverUrl}/mobile/api/users/signup',
        payload: {
          'name': user.fullName,
          'email': user.email,
          'password': user.password,
        },
      );
      return user;
    }
  }

  static Future<void> setCurrentUser(User user) async {
    final prefs = await SharedPreferences.getInstance();
    final safeUser = user.copyWith(password: '');
    await prefs.setString(_currentUserKey, jsonEncode(safeUser.toJson()));
  }

  static Future<User?> getCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString(_currentUserKey);
    if (userJson != null) {
      return User.fromJson(jsonDecode(userJson));
    }
    return null;
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_currentUserKey);
  }

  // Questions Management
  static Future<void> _initializeQuestions() async {
    // This is a placeholder function to fix the undefined method error
    // TODO: Implement proper question initialization if needed
  }

  static Future<List<Question>> getQuestions() async {
    final prefs = await SharedPreferences.getInstance();
    final questionsJson = prefs.getString(_questionsKey);

    Future<List<Question>> _decodeQuestions(String jsonStr) async {
      final List<dynamic> rawList = jsonDecode(jsonStr);
      final List<Question> parsed = [];
      for (final dynamic item in rawList) {
        if (item is Map<String, dynamic>) {
          try {
            final String id = (item['id'] ?? '').toString();
            final String questionText = (item['question_text'] ?? '')
                .toString();
            final List<String> options = List<dynamic>.from(
              item['options'] ?? [],
            ).map((e) => e.toString()).toList();
            final dynamic cai = item['correct_answer_index'];
            final int correctIndex = cai is int
                ? cai
                : int.tryParse((cai ?? '').toString()) ?? 0;
            final String category = (item['category'] ?? '').toString();
            final String createdAtStr =
                (item['created_at'] ?? DateTime.now().toIso8601String())
                    .toString();
            final DateTime createdAt =
                DateTime.tryParse(createdAtStr) ?? DateTime.now();

            if (id.isEmpty || questionText.isEmpty || options.isEmpty) {
              continue;
            }

            parsed.add(
              Question(
                id: id,
                questionText: questionText,
                options: options,
                correctAnswerIndex: correctIndex,
                category: category,
                createdAt: createdAt,
              ),
            );
          } catch (_) {
            // Skip invalid item
            continue;
          }
        }
      }
      return parsed;
    }

    try {
      if (questionsJson != null) {
        final parsed = await _decodeQuestions(questionsJson);
        if (parsed.isNotEmpty) return parsed;
      }

      // Fallback: re-initialize questions from code and try again
      await prefs.remove(_questionsKey);
      await _initializeQuestions();
      final refreshedJson = prefs.getString(_questionsKey);
      if (refreshedJson != null) {
        return await _decodeQuestions(refreshedJson);
      }
    } catch (_) {
      // On any error, try to refresh once
      await prefs.remove(_questionsKey);
      await _initializeQuestions();
      final refreshedJson = prefs.getString(_questionsKey);
      if (refreshedJson != null) {
        return await _decodeQuestions(refreshedJson);
      }
    }
    return [];
  }

  static Future<List<Question>> getRandomQuestions(int count) async {
    final questions = await getQuestions();
    questions.shuffle();
    return questions.take(count).toList();
  }

  // Returns all questions
  static Future<List<Question>> getAllQuestions() async {
    return await getQuestions();
  }

  // Get questions by a fixed list of IDs
  static Future<List<Question>> getQuestionsByIds(List<String> ids) async {
    final all = await getQuestions();
    final Map<String, Question> byId = {for (final q in all) q.id: q};
    final List<Question> result = [];
    for (final id in ids) {
      final q = byId[id];
      if (q != null) result.add(q);
    }
    return result;
  }

  // Persist per-user fixed question IDs for a plan, then return the questions
  static Future<List<Question>> getFixedPlanQuestions({
    required String userId,
    required String planId,
    required int questionCount,
    bool useAllQuestionsIfZero = true,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final key = ' _planQuestionsKeyPrefix {userId}_ planId';
    final cachedJson = prefs.getString(key);
    if (cachedJson != null) {
      final List<dynamic> savedIds = jsonDecode(cachedJson);
      final ids = savedIds.map((e) => e.toString()).toList();
      return await getQuestionsByIds(ids);
    }

    // تعديل هنا: إذا كان questionCount <= 0 رجع كل الأسئلة من الداتا بيز
    final all = await getAllQuestions();
    List<Question> chosen;
    if (questionCount <= 0) {
      chosen = List<Question>.from(all);
    } else {
      final list = List<Question>.from(all);
      list.shuffle();
      chosen = list.take(questionCount).toList();
    }
    final ids = chosen.map((q) => q.id).toList();
    await prefs.setString(key, jsonEncode(ids));
    return chosen;
  }

  // Get fixed trial questions (IDs 1–5)
  static Future<List<Question>> getTrialQuestions() async {
    // Hardcoded questions for the trial test with justification
    return [
      Question(
        id: '1',
        questionText:
            'لاحظت أن طالب لديك يرفع جواله بشكل متكرر أثناء الشرح، والمحاولة المباشرة لإيقافه ما نفعت. إيش الإجراء الأفضل اللي تسويه كمعلم؟',
        options: [
          'تصادر الجوال على طول وتحوله للإدارة التعليمية فوراً',
          'تتجاهله عشان ما تعطل الحصة وتضيع وقت زملائه',
          'تتكلم معاه على انفراد بعد الحصة وتفهم سبب تكرار المخالفة وتحط خطة تعديل سلوك',
          'تطلب منه الخروج من الفصل لحين ما تخلص شرحك وتكمل الحصة بدونه',
        ],
        correctAnswerIndex: 2,
        category: 'موقف في الفصل',
        answerJustification:
            'التعامل التربوي الفعال يركز على فهم المشكلة والبحث عن جذورها وحلها بعيداً عن العقاب الفوري أو التشهير. الحديث المنفرد يحفظ كرامة الطالب ويحقق الهدف التعليمي.',
        createdAt: DateTime.now(),
      ),
      Question(
        id: '2',
        questionText:
            'ما الفرق الأدق بين استخدام كلمة \'نصَح\' وكلمة \'أرشد\' في المعنى؟',
        options: [
          '\'نصَح\' تتعلق بالقول فقط، و\'أرشد\' تتعلق بالفعل فقط.',
          '\'نصَح\' تُستخدم في كل الأمور، بينما \'أرشد\' تستخدم في أمور العقيدة فقط.',
          '\'نصَح\' تتعلق بالقول الذي فيه صلاح ونفع، و\'أرشد\' تتعلق بالدلالة على الطريق الصحيح أو الهدف المحدد.',
          'لا يوجد فرق جوهري بينهما ويمكن استخدامهما تبادلياً في كل السياقات.',
        ],
        correctAnswerIndex: 2,
        category: 'اللغة العربية (مرادفات)',
        answerJustification:
            'كلمة \'نصَح\' تطلق على الوعظ والإخلاص في القول، بينما \'أرشد\' تطلق على التوجيه والدلالة المادية أو المعنوية نحو الهدف المطلوب.',
        createdAt: DateTime.now(),
      ),
      Question(
        id: '3',
        questionText:
            'فصل فيه 40 طالب وطالبة، إذا كانت نسبة الذكور إلى الإناث هي 3:5، كم عدد الطالبات في الفصل؟',
        options: ['15 طالبة', '20 طالبة', '25 طالبة', '30 طالبة'],
        correctAnswerIndex: 2,
        category: 'الرياضيات (نسبة)',
        answerJustification:
            'المجموع الكلي لأجزاء النسبة هو 3 (ذكور) + 5 (إناث) = 8 أجزاء. قيمة الجزء الواحد = 40 طالب / 8 أجزاء = 5 طلاب لكل جزء. عدد الطالبات = 5 أجزاء × 5 طلاب/جزء = 25 طالبة.',
        createdAt: DateTime.now(),
      ),
      Question(
        id: '4',
        questionText:
            'ولي أمر طالب انتقد أسلوبك في تقييم أداء ابنه قدام زملائك المعلمين. إيش أفضل طريقة تتعامل فيها مع الموقف هذا؟',
        options: [
          'ترد عليه وتوضح صحة تقييمك أمام الجميع لترسيخ سلطتك كمعلم.',
          'تطلب منه مقابلة منفردة في وقت لاحق عشان تناقشون الموضوع بهدوء واحترافية.',
          'تتجاهل انتقاده وتستمر في عملك، وتطلب من الإدارة التعامل مع ولي الأمر.',
          'تعتذر منه فوراً وتعدّل درجات ابنه عشان ترضيه وتنهي النقاش.',
        ],
        correctAnswerIndex: 1,
        category: 'موقف مختلف (سلوكي)',
        answerJustification:
            'التصرف المهني يقتضي تجنب النقاشات الحساسة في العلن، وطلب لقاء منفرد يضمن التعامل باحترام مع ولي الأمر ويسمح بمناقشة المنهجية بعيداً عن الضغوط.',
        createdAt: DateTime.now(),
      ),
      Question(
        id: '5',
        questionText:
            'إيش هي النواتج الأساسية اللي تنتجها عملية البناء الضوئي (Photosynthesis) اللي تسويها النباتات؟',
        options: [
          'ثاني أكسيد الكربون والنيتروجين',
          'الماء وبخار الماء',
          'الأكسجين والجلوكوز (سكر)',
          'الكحول الإيثيلي والأمونيا',
        ],
        correctAnswerIndex: 2,
        category: 'سؤال علمي مشهور (أحياء)',
        answerJustification:
            'تستخدم النباتات ثاني أكسيد الكربون والماء والضوء لإنتاج الغذاء (الجلوكوز) الذي تحتاجه، وتطلق الأكسجين كناتج ثانوي ضروري للحياة على الأرض.',
        createdAt: DateTime.now(),
      ),
    ];
  }

  static Future<List<Question>> getSilverQuestions() async {
    // استدعي كل الأسئلة من SharedPreferences
    final allQuestions = await getQuestions();

    // خد أول 1000 سؤال
    final silverQuestions = allQuestions.take(1000).toList();

    return silverQuestions;
  }

  /// Fetches questions for a specific plan from the backend
  /// Returns a map containing 'questions' (List<dynamic>) and 'isPremium' (bool)
  static Future<Map<String, dynamic>> fetchPlanContent(String planId) async {
    try {
      print('🌐 Fetching plan content for $planId...');
      final response = await http
          .get(Uri.parse('${TestConfig.serverUrl}/api/plans/$planId/questions'))
          .timeout(Duration(seconds: TestConfig.requestTimeout));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body)['data'];
        final bool isPremium = data['isPremium'] ?? false;
        final List<dynamic> rawQuestions = data['questions'] ?? [];

        print(
          '✅ Fetched ${rawQuestions.length} questions. Premium: $isPremium',
        );

        // If premium, we parse as PremiumQuestion later
        // If not, we parse as Question later
        // For now, return the raw list and flag
        return {
          'questions': rawQuestions,
          'isPremium': isPremium,
          'success': true,
        };
      } else {
        print('❌ Failed to fetch plan content: ${response.statusCode}');
        return {'success': false, 'error': 'Failed to load questions'};
      }
    } catch (e) {
      print('❌ Error fetching plan content: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  // getAllQuestionsFromDB
  static Future<List<Question>> getAllQuestionsFromDB() async {
    // استدعي كل الأسئلة من SharedPreferences
    final allQuestions = await getQuestions();

    // رجع كل الأسئلة زي ما هي
    return allQuestions;
  }

  // gold questions (2500 questions)
  static Future<List<Question>> getGoldQuestions() async {
    // استدعي كل الأسئلة من SharedPreferences
    final allQuestions = await getQuestions();

    // خد أول 2500 سؤال
    final goldQuestions = allQuestions.take(2500).toList();

    return goldQuestions;
  }

  static Future<List<PaymentPlan>> getPaymentPlans() async {
    print('🔍 getPaymentPlans: Starting...');
    print('🔍 Server URL: ${TestConfig.serverUrl}/api/plans');

    List<PaymentPlan> localPlans = [];
    final prefs = await SharedPreferences.getInstance();
    try {
      final plansJson = prefs.getString(_paymentPlansKey);
      if (plansJson != null) {
        localPlans = List<dynamic>.from(
          jsonDecode(plansJson),
        ).map((json) => PaymentPlan.fromJson(json)).toList();
        print('📦 Found ${localPlans.length} cached plans');
      } else {
        print('📦 No cached plans found');
      }

      // Try to fetch from server
      print('🌐 Fetching plans from server...');
      final response = await http
          .get(Uri.parse('${TestConfig.serverUrl}/api/plans'))
          .timeout(Duration(seconds: TestConfig.requestTimeout));

      print('📥 Response status: ${response.statusCode}');
      print('📥 Response body: ${response.body}');

      if (response.statusCode == 200) {
        final serverData = jsonDecode(response.body)['data'];
        print('✅ Server returned ${serverData.length} plans');

        final List<PaymentPlan> serverPlans = List<dynamic>.from(
          serverData,
        ).map((json) => PaymentPlan.fromJson(json)).toList();

        print('✅ Parsed ${serverPlans.length} plans successfully');

        // Update local cache with server data
        await prefs.setString(
          _paymentPlansKey,
          jsonEncode(serverPlans.map((p) => p.toJson()).toList()),
        );
        print('💾 Cached plans to local storage');
        return serverPlans;
      } else {
        print(
          '⚠️ Server error ${response.statusCode}, returning ${localPlans.length} cached plans',
        );
        // Server error, return local plans
        return localPlans;
      }
    } catch (e, stackTrace) {
      print('❌ ERROR in getPaymentPlans: $e');
      print('❌ Stack trace: $stackTrace');
      // Network error, return local plans
      print('⚠️ Returning ${localPlans.length} cached plans due to error');
      return localPlans;
    }
  }

  // Get a specific plan by ID
  static Future<PaymentPlan?> getPlanById(String? planId) async {
    if (planId == null) return null;
    final plans = await getPaymentPlans();
    try {
      return plans.firstWhere((p) => p.id == planId);
    } catch (e) {
      return null;
    }
  }

  static Future<void> syncPendingUserUpdates() async {
    // Process all pending sync operations including user updates
    print('🔄 Syncing pending user updates...');
    await SyncQueueService.processPendingSync();
  }

  static Future<void> syncPendingPlans() async {
    // TODO: Implement plans sync logic
    // This is typically a read-only operation from the client.
    // We can simply call getPaymentPlans to refresh the cache.
    await getPaymentPlans();
  }

  static Future<void> syncPendingUserCreatesAndDeletes() async {
    // Process all pending sync operations including creates/deletes
    print('🔄 Syncing pending user creates and deletes...');
    await SyncQueueService.processPendingSync();
  }

  // Sync user data from server
  static Future<void> _syncUserFromServer(String email) async {
    try {
      final encodedEmail = Uri.encodeComponent(email);
      final response = await http
          .get(
            Uri.parse(
              '${TestConfig.serverUrl}/mobile/api/users/me/$encodedEmail',
            ),
            headers: await AuthService.authHeaders(),
          )
          .timeout(Duration(seconds: TestConfig.requestTimeout));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final userData = data['data'];
          final user = User.fromJson(userData);
          await _updateLocalUser(user);

          // Check if this is the current user and update session
          final currentUser = await getCurrentUser();
          if (currentUser != null && currentUser.email == user.email) {
            await setCurrentUser(user);
            print('✅ Current user session updated from server sync');
          }
        }
      }
    } catch (e) {
      print('Sync user error: $e');
    }
  }

  // Public method to refresh current user data from server
  static Future<void> refreshCurrentUser() async {
    final currentUser = await getCurrentUser();
    if (currentUser != null) {
      await _syncUserFromServer(currentUser.email);
    }
  }

  // Login user using API - requires internet connection
  static Future<LoginResult> loginUser(String email, String password) async {
    // Check network connectivity
    final isOnline = await NetworkService.isConnected();

    print('🔍 LOGIN DEBUG: Starting login process');
    print('🔍 Email: $email');
    print('🔍 Is Online: $isOnline');
    print('🔍 Server URL: ${TestConfig.serverUrl}/mobile/api/users/login');

    if (!isOnline) {
      print('❌ LOGIN: No internet connection');
      return LoginResult(
        success: false,
        error: 'يجب عليك الاتصال بالإنترنت لتسجيل الدخول',
      );
    }

    try {
      final requestBody = {'email': email, 'password': password};
      print('📤 Login request prepared');

      final response = await http
          .post(
            Uri.parse('${TestConfig.serverUrl}/mobile/api/users/login'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode(requestBody),
          )
          .timeout(Duration(seconds: TestConfig.requestTimeout));

      print('📥 Response Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          print('✅ LOGIN: Success!');
          if (data['token'] != null) {
            await AuthService.saveToken(data['token']);
          }
          final userData = data['data'];
          final user = User.fromJson(userData);

          // Also fetch fresh user data to get latest subscription info
          await _syncUserFromServer(user.email);

          final userWithSessionData = user.copyWith(password: '');
          await _updateLocalUser(userWithSessionData);

          return LoginResult(success: true, user: userWithSessionData);
        } else {
          print('❌ LOGIN: Server returned success=false');
          return LoginResult(
            success: false,
            error: data['error'] ?? 'فشل في تسجيل الدخول',
          );
        }
      } else {
        print('❌ LOGIN: HTTP ${response.statusCode}');
        try {
          final data = jsonDecode(response.body);
          return LoginResult(
            success: false,
            error: data['error'] ?? 'فشل في تسجيل الدخول',
          );
        } catch (e) {
          return LoginResult(success: false, error: 'فشل في تسجيل الدخول');
        }
      }
    } catch (e) {
      print('❌ LOGIN ERROR: $e');
      print('❌ Error Type: ${e.runtimeType}');
      return LoginResult(
        success: false,
        error: 'فشل في الاتصال بالخادم. تأكد من اتصالك بالإنترنت',
      );
    }
  }

  // Save offline plan content received from server
  static Future<void> saveOfflinePlanContent({
    required String userId,
    required String planId,
    required Map<String, dynamic> planContent,
  }) async {
    try {
      print('💾 SAVING OFFLINE PLAN CONTENT:');
      print('   User ID: $userId');
      print('   Plan ID: $planId');

      final prefs = await SharedPreferences.getInstance();
      final key = '${DatabaseService._offlinePlanContentKey}_${userId}_$planId';

      final questionCount = planContent['questions']?.length ?? 0;
      print('   Questions to save: $questionCount');
      print('   Storage Key: $key');

      await prefs.setString(key, jsonEncode(planContent));

      // Verify it was saved
      final saved = prefs.getString(key);
      if (saved != null) {
        final decoded = jsonDecode(saved);
        final savedQuestions = decoded['questions']?.length ?? 0;
        print('✅ SAVE SUCCESSFUL!');
        print('   Verified: $savedQuestions questions saved');
        print('   🎯 Plan ready for offline use!');
      } else {
        print('❌ SAVE FAILED! Data not found after save');
      }
    } catch (e) {
      print('❌ Error saving offline plan content: $e');
      print('   This means the plan will NOT work offline!');
    }
  }

  // Get offline plan content from local storage
  static Future<Map<String, dynamic>?> getOfflinePlanContent({
    required String userId,
    required String planId,
  }) async {
    try {
      print('🔍 LOADING OFFLINE PLAN CONTENT:');
      print('   User ID: $userId');
      print('   Plan ID: $planId');

      final prefs = await SharedPreferences.getInstance();
      final key = '${DatabaseService._offlinePlanContentKey}_${userId}_$planId';
      print('   Storage Key: $key');

      final jsonStr = prefs.getString(key);
      if (jsonStr != null) {
        final data = jsonDecode(jsonStr) as Map<String, dynamic>;
        final questionCount = data['questions']?.length ?? 0;
        print('✅ LOAD SUCCESSFUL!');
        print('   Found: $questionCount questions');
        print('   🎯 Plan loaded from offline storage');
        return data;
      } else {
        print('❌ LOAD FAILED!');
        print('   No offline data found for this plan');
        print('   ⚠️ User needs internet to download plan');
        return null;
      }
    } catch (e) {
      print('❌ Error loading offline plan content: $e');
      return null;
    }
  }

  // Get offline questions from saved plan content
  static Future<List<Question>> getOfflineQuestions({
    required String userId,
    required String planId,
  }) async {
    try {
      final planContent = await getOfflinePlanContent(
        userId: userId,
        planId: planId,
      );

      if (planContent != null && planContent['questions'] != null) {
        final List<dynamic> questionsData = planContent['questions'];
        final questions = questionsData
            .map((q) => Question.fromJson(q))
            .toList();
        if (TestConfig.enableDebugLogs) {
          print('✅ Loaded ${questions.length} questions from offline storage');
        }
        return questions;
      }
      return [];
    } catch (e) {
      print('❌ Error loading offline questions: $e');
      return [];
    }
  }

  // Delete offline plan content
  static Future<void> deleteOfflinePlanContent({
    required String userId,
    required String planId,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '_offlinePlanContentKey_${userId}_$planId';
      await prefs.remove(key);
      if (TestConfig.enableDebugLogs) {
        print(
          '✅ Offline plan content deleted for user: $userId, plan: $planId',
        );
      }
    } catch (e) {
      print('❌ Error deleting offline plan content: $e');
    }
  }

  // Sync offline content when user is online
  static Future<void> syncOfflineContentIfOnline() async {
    try {
      // Check if online
      final isOnline = await NetworkService.isConnected();
      if (!isOnline) {
        if (TestConfig.enableDebugLogs) {
          print('⚠️ Device is offline, skipping sync');
        }
        return;
      }

      // Get current user
      final user = await getCurrentUser();
      if (user == null) {
        if (TestConfig.enableDebugLogs) {
          print('⚠️ No current user, skipping sync');
        }
        return;
      }

      if (TestConfig.enableDebugLogs) {
        print('🔄 Starting full data sync for user: ${user.email}');
      }

      // Fetch fresh user data from server using phone number
      final userResponse = await http
          .get(
            Uri.parse(
              '${TestConfig.serverUrl}/mobile/api/users/me/${Uri.encodeComponent(user.email)}',
            ),
            headers: await AuthService.authHeaders(),
          )
          .timeout(
            Duration(seconds: TestConfig.requestTimeout),
            onTimeout: () {
              if (TestConfig.enableDebugLogs) {
                print('⚠️ Sync timeout - network too slow or disconnected');
              }
              throw Exception('Sync timeout');
            },
          );

      if (userResponse.statusCode != 200) {
        if (TestConfig.enableDebugLogs) {
          print('⚠️ Failed to fetch user data: ${userResponse.statusCode}');
        }
        return;
      }

      final userData = jsonDecode(userResponse.body);
      if (userData['success'] != true || userData['data'] == null) {
        if (TestConfig.enableDebugLogs) {
          print('⚠️ Invalid server response');
        }
        return;
      }

      // Parse updated user data
      final updatedUserData = userData['data'];
      final updatedUser = User.fromJson(updatedUserData);

      if (TestConfig.enableDebugLogs) {
        print('✅ Fetched latest user data from server');
        print('   Current Plan: ${updatedUser.subscriptionPlanId ?? "None"}');
      }

      // Update local user data (this replaces old data)
      await _updateLocalUser(updatedUser);
      await setCurrentUser(updatedUser);

      if (TestConfig.enableDebugLogs) {
        print('✅ Local user data updated');
      }

      if (TestConfig.enableDebugLogs) {
        print('✅ Full sync completed successfully!');
      }
    } on SocketException catch (e) {
      // Network error - device went offline during sync
      if (TestConfig.enableDebugLogs) {
        print('❌ Network error during sync: ${e.message}');
        print('⚠️ Device appears to have lost connection');
      }
    } on TimeoutException catch (e) {
      // Timeout - network too slow
      if (TestConfig.enableDebugLogs) {
        print('❌ Sync timeout: ${e.message}');
        print('⚠️ Network too slow or unstable');
      }
    } catch (e) {
      // Other errors
      if (TestConfig.enableDebugLogs) {
        print('❌ Error syncing data: $e');
      }
    }
  }

  // Get user statistics from server
  static Future<Map<String, dynamic>?> getUserStatistics(String userId) async {
    try {
      final response = await http
          .get(
            Uri.parse(
              '${TestConfig.serverUrl}/mobile/api/users/$userId/statistics',
            ),
            headers: await AuthService.authHeaders(),
          )
          .timeout(Duration(seconds: TestConfig.requestTimeout));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return data['data'] as Map<String, dynamic>;
        }
      }
      return null;
    } catch (e) {
      if (TestConfig.enableDebugLogs) {
        print('❌ Error fetching user statistics: $e');
      }
      return null;
    }
  }

  // Save test result
  static Future<bool> saveTestResult({
    required String userId,
    required int examNumber,
    required int score,
    required int totalQuestions,
    required int correctAnswers,
    required List<Map<String, dynamic>> mistakes,
    String? planId, // Add planId
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('${TestConfig.serverUrl}/mobile/api/users/test-result'),
            headers: await AuthService.authHeaders(),
            body: jsonEncode({
              'userId': userId,
              'examNumber': examNumber,
              'score': score,
              'totalQuestions': totalQuestions,
              'correctAnswers': correctAnswers,
              'mistakes': mistakes,
              if (planId != null) 'planId': planId, // Send planId
            }),
          )
          .timeout(Duration(seconds: TestConfig.requestTimeout));

      if (response.statusCode == 200) {
        return true;
      } else {
        if (TestConfig.enableDebugLogs) {
          print('❌ Failed to save test result: ${response.statusCode}');
        }
        return false;
      }
    } catch (e) {
      if (TestConfig.enableDebugLogs) {
        print('❌ Exception saving test result: $e');
      }
      return false;
    }
  }

  // Get exam results for user
  static Future<List<Map<String, dynamic>>> getExamResults(
    String userId, {
    String? planId, // Add optional planId
  }) async {
    try {
      // Build URL with query parameters
      String url =
          '${TestConfig.serverUrl}/mobile/api/users/$userId/exam-results';
      if (planId != null) {
        url += '?planId=$planId';
      }

      final response = await http
          .get(Uri.parse(url), headers: await AuthService.authHeaders())
          .timeout(Duration(seconds: TestConfig.requestTimeout));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return List<Map<String, dynamic>>.from(data['data']);
        }
      }
      return [];
    } catch (e) {
      if (TestConfig.enableDebugLogs) {
        print('❌ Error fetching exam results: $e');
      }
      return [];
    }
  }

  // Methods for password reset moved below (lines 985-1060)

  // Check if email exists in database
  static Future<bool> checkEmailExists(String email) async {
    try {
      print('🔍 Checking if email exists: $email');

      final response = await http
          .post(
            Uri.parse(
              '${NetworkService.baseUrl}/mobile/api/users/check-email-exists',
            ),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'email': email}),
          )
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              throw TimeoutException('Connection timeout');
            },
          );

      print('📥 Response status: ${response.statusCode}');
      print('📥 Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final exists = data['exists'] ?? false;
        print(exists ? '✅ Email exists' : '❌ Email does not exist');
        return exists;
      }

      return false;
    } catch (e) {
      print('❌ Error checking email: $e');
      return false;
    }
  }

  // Update password after Firebase reset
  static Future<bool> updatePassword({
    required String email,
    required String newPassword,
  }) async {
    try {
      print('🔄 Updating password for: $email');

      final response = await http
          .post(
            Uri.parse(
              '${NetworkService.baseUrl}/mobile/api/users/update-password',
            ),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'email': email, 'newPassword': newPassword}),
          )
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              throw TimeoutException('Connection timeout');
            },
          );

      print('📥 Response status: ${response.statusCode}');
      print('📥 Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final success = data['success'] ?? false;
        print(
          success
              ? '✅ Password updated successfully'
              : '❌ Password update failed',
        );
        return success;
      }

      print('❌ Server returned status: ${response.statusCode}');
      return false;
    } catch (e) {
      print('❌ Error updating password: $e');
      return false;
    }
  }

  // Get all active subscriptions for a user
  static Future<List<Map<String, dynamic>>> getActiveSubscriptions(
    String userId,
  ) async {
    try {
      print('🔍 Fetching active subscriptions for user: $userId');

      final response = await http
          .get(
            Uri.parse(
              '${TestConfig.serverUrl}/mobile/api/subscriptions/active?userId=$userId',
            ),
            headers: await AuthService.authHeaders(),
          )
          .timeout(Duration(seconds: TestConfig.requestTimeout));

      print('📥 Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final List<dynamic> subscriptions =
              data['data']['subscriptions'] ?? [];
          print('✅ Found ${subscriptions.length} active subscriptions');
          return subscriptions.cast<Map<String, dynamic>>();
        }
      }

      print('⚠️ No active subscriptions found');
      return [];
    } catch (e) {
      print('❌ Error fetching active subscriptions: $e');
      return [];
    }
  }

  // Switch active subscription
  static Future<bool> switchActiveSubscription(
    String userId,
    String planId,
  ) async {
    try {
      print('🔄 Switching active subscription to plan: $planId');

      final response = await http
          .post(
            Uri.parse(
              '${TestConfig.serverUrl}/mobile/api/subscriptions/switch',
            ),
            headers: await AuthService.authHeaders(),
            body: jsonEncode({'userId': userId, 'planId': planId}),
          )
          .timeout(Duration(seconds: TestConfig.requestTimeout));

      print('📥 Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          print('✅ Subscription switched successfully');

          // Refresh current user data
          await refreshCurrentUser();

          return true;
        }
      }

      print('❌ Failed to switch subscription');
      return false;
    } catch (e) {
      print('❌ Error switching subscription: $e');
      return false;
    }
  }
}

// Login result class
class LoginResult {
  final bool success;
  final User? user;
  final String? error;

  LoginResult({required this.success, this.user, this.error});
}
