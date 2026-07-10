import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../l10n/app_localizations.dart';
import '../constants/colors.dart';
import '../models/payment_plan.dart';
import 'segmented_test_screen.dart';
import 'standard_test_screen.dart';
import '../services/database_service.dart';
import '../utils/responsive_layout.dart';
import 'custom_tab_screen.dart';

class ExamListScreen extends StatefulWidget {
  final String planId;
  final String planName;
  final int totalQuestions;
  final bool isAdditionalTest;
  final PaymentPlan? plan; // Added plan object for dynamic colors

  const ExamListScreen({
    super.key,
    required this.planId,
    required this.planName,
    required this.totalQuestions,
    this.isAdditionalTest = false,
    this.plan, // Optional plan parameter
  });

  @override
  State<ExamListScreen> createState() => _ExamListScreenState();
}

class _ExamListScreenState extends State<ExamListScreen> {
  Map<int, Map<String, dynamic>> _examResults = {};
  bool _isLoading = true;

  final List<Map<String, String>> _standards = [
    {
      'name': 'المعيار 1: الالتزام بالقيم الإسلامية الوسطية',
      'file': 'Standard_1_Commitment_to_Values',
      'id': '1',
    },
    {
      'name': 'المعيار 2: التطوير المهني المستمر',
      'file': 'Standard_2_Continuous_Professional_Development',
      'id': '2',
    },
    {
      'name': 'المعيار 3: التفاعل المهني مع التربويين والمجتمع',
      'file': 'Standard_3_Professional_Interaction',
      'id': '3',
    },
    {
      'name': 'المعيار 4: المهارات اللغوية والكمية',
      'file': 'Standard_4_Linguistic_and_Quantitative_Skills',
      'id': '4',
    },
    {
      'name': 'المعيار 5: المعرفة بالمتعلم وكيفية تعلمه',
      'file': 'Standard_5_Knowledge_of_the_Learner',
      'id': '5',
    },
    {
      'name': 'المعيار 6: المعرفة بمحتوى التخصص وطرق تدريسه',
      'file': 'Standard_6_Knowledge_of_Specialization_Content',
      'id': '6',
    },
    {
      'name': 'المعيار 7: المعرفة بطرق التدريس العامة',
      'file': 'Standard_7_General_Teaching_Methods',
      'id': '7',
    },
    {
      'name': 'المعيار 8: التخطيط للتدريس وتنفيذه',
      'file': 'Standard_8_Planning_and_Implementation',
      'id': '8',
    },
    {
      'name': 'المعيار 9: تهيئة بيئات تعلم تفاعلية وداعمة',
      'file': 'Standard_9_Creating_Learning_Environments',
      'id': '9',
    },
    {
      'name': 'المعيار 10: التقويم',
      'file': 'Standard_10_Assessment',
      'id': '10',
    },
  ];

  bool _isGoldPlan() {
    return widget.planId == '69004770459269c2b71977b9' ||
        widget.planName.contains('Gold') ||
        widget.planName.contains('الذهبية');
  }

  PaymentPlan? _currentPlan;

  @override
  void initState() {
    super.initState();
    _currentPlan = widget.plan;
    _loadExamResults();
    _refreshPlanDetails(); // Fetch fresh data on load
  }

  Future<void> _refreshPlanDetails() async {
    try {
      final plans = await DatabaseService.getPaymentPlans();
      final freshPlan = plans.firstWhere(
        (p) => p.id == widget.planId,
        orElse: () => widget.plan ?? plans.first, // Fallback
      );

      if (mounted) {
        setState(() {
          _currentPlan = freshPlan;
        });
      }
    } catch (e) {
      print('Error refreshing plan details: $e');
    }
  }

  Future<void> _loadExamResults() async {
    try {
      final user = await DatabaseService.getCurrentUser();
      if (user != null) {
        final results = await DatabaseService.getExamResults(
          user.id,
          planId: widget.planId, // Filter by planId
        );

        // Process results to map by examNumber
        // If multiple results for same exam, keep the one with highest score
        final Map<int, Map<String, dynamic>> processedResults = {};

        for (var result in results) {
          final examNumber = result['examNumber'] as int;
          final score = result['score'] as int;

          if (!processedResults.containsKey(examNumber) ||
              score > (processedResults[examNumber]!['score'] as int)) {
            processedResults[examNumber] = result;
          }
        }

        if (mounted) {
          setState(() {
            _examResults = processedResults;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      print('Error loading exam results: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    List<PlanTab> tabs = [];

    if (_currentPlan?.tabs.isNotEmpty ?? false) {
      tabs = _currentPlan!.tabs;
      tabs.sort((a, b) => a.order.compareTo(b.order));
    } else {
      // Fallback
      String dividedTitle =
          AppLocalizations.of(context)?.translate('dividedTests') ??
          'الاختبارات المقسمة';
      tabs.add(
        PlanTab(
          id: 'default',
          name: dividedTitle,
          nameEn: 'Divided Tests',
          type: 'divided',
          isDefault: true,
        ),
      );

      if (_isGoldPlan()) {
        String standardTitle =
            AppLocalizations.of(context)?.translate('standardQuestions') ??
            'أسئلة المعايير';
        tabs.add(
          PlanTab(
            id: 'standards',
            name: standardTitle,
            nameEn: 'Standard Questions',
            type: 'standards',
            isDefault: false,
          ),
        );
      }
    }

    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: AppColors.white),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            widget.planName,
            style: TextStyle(
              color: AppColors.white,
              fontWeight: FontWeight.bold,
              fontSize: 20.sp,
            ),
          ),
          actions: [
            IconButton(
              icon: Icon(Icons.refresh, color: AppColors.white),
              onPressed: _refreshPlanDetails,
            ),
          ],
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _currentPlan != null
                    ? _currentPlan!.getGradient()
                    : [Color(0xFF063311), Color(0xFF0D4D2B), Color(0xFF1B5E20)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          bottom: TabBar(
            indicatorColor:
                _currentPlan?.getSecondaryColor() ?? AppColors.secondary,
            indicatorWeight: 4.h,
            labelColor: AppColors.white,
            unselectedLabelColor: AppColors.white.withOpacity(0.6),
            labelStyle: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.bold,
              fontFamily: 'Cairo',
            ),
            isScrollable: tabs.length > 2,
            tabs: tabs.map((tab) => Tab(text: tab.getName(context))).toList(),
          ),
          elevation: 0,
          iconTheme: IconThemeData(color: AppColors.white),
        ),
        body: RefreshIndicator(
          onRefresh: _refreshPlanDetails,
          child: TabBarView(
            children: tabs.map((tab) {
              if (tab.type == 'divided') {
                return _buildDividedExamsTab();
              } else if (tab.type == 'standards' && tab.sections.isEmpty) {
                return _buildLegacyStandardsTab();
              } else {
                return CustomTabScreen(
                  tab: tab,
                  planId: widget.planId,
                  plan: _currentPlan,
                );
              }
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildStandardCard(
    BuildContext context,
    Map<String, String> standard,
  ) {
    return Container(
      margin: EdgeInsets.only(bottom: 16.h),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10.r,
            offset: Offset(0, 4.h),
          ),
        ],
        border: Border.all(
          color: AppColors.secondary.withOpacity(0.2),
          width: 1.w,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => StandardTestScreen(
                  collectionName: standard['file']!,
                  standardName: standard['name']!,
                  planId: widget.planId,
                  plan: widget.plan,
                ),
              ),
            );
          },
          borderRadius: BorderRadius.circular(16.r),
          child: Padding(
            padding: EdgeInsets.all(16.w),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(12.w),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.secondary.withOpacity(0.1),
                        AppColors.secondary.withOpacity(0.2),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Text(
                    standard['id']!,
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.bold,
                      color: AppColors.secondary,
                    ),
                  ),
                ),
                SizedBox(width: 16.w),
                Expanded(
                  child: Text(
                    standard['name']!,
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                      height: 1.4,
                    ),
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: AppColors.grey,
                  size: 18.r,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDividedExamsTab() {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    // Calculate number of exams
    // Use plan.questionCount if available for more accuracy, otherwise widget.totalQuestions
    final int totalQs = _currentPlan?.questionCount ?? widget.totalQuestions;
    final int questionsPerExam = 50;
    final int numberOfExams = (totalQs / questionsPerExam).ceil();

    final primaryColor = _currentPlan?.getPrimaryColor() ?? AppColors.primary;

    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(20.w),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10.r,
                offset: Offset(0, 5.h),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.grid_view_rounded,
                  color: primaryColor,
                  size: 24.r,
                ),
              ),
              SizedBox(width: 16.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.of(context)?.translate('chooseExam') ??
                          'اختر الامتحان',
                      style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      '${AppLocalizations.of(context)?.translate('curriculumDivided') ?? 'تم تقسيم المنهج إلى'} $numberOfExams ${AppLocalizations.of(context)?.translate('exam') ?? 'امتحان'}',
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: Theme.of(context).textTheme.bodyMedium?.color,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: EdgeInsets.all(20.w),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: ResponsiveHelper.getValue(
                context,
                mobile: 2,
                tablet: 3,
                desktop: 4,
              ),
              crossAxisSpacing: 16.w,
              mainAxisSpacing: 16.h,
              childAspectRatio: 0.85,
            ),
            itemCount: numberOfExams,
            itemBuilder: (context, index) {
              final examNumber = index + 1;
              final startQuestion = index * questionsPerExam + 1;
              final endQuestion = (index + 1) * questionsPerExam;
              final actualEndQuestion = endQuestion > totalQs
                  ? totalQs
                  : endQuestion;

              return _buildExamCard(
                context,
                examNumber,
                startQuestion,
                actualEndQuestion,
                _examResults[examNumber],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildLegacyStandardsTab() {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(20.w),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10.r,
                offset: Offset(0, 5.h),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.library_books_rounded,
                  color: AppColors.secondary,
                  size: 24.r,
                ),
              ),
              SizedBox(width: 16.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.of(
                            context,
                          )?.translate('chooseStandard') ??
                          'اختر المعيار',
                      style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      AppLocalizations.of(
                            context,
                          )?.translate('classifiedQuestions') ??
                          'أسئلة مصنفة حسب المعايير التربوية',
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: Theme.of(context).textTheme.bodyMedium?.color,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.all(20.w),
            itemCount: _standards.length,
            itemBuilder: (context, index) {
              final standard = _standards[index];
              return _buildStandardCard(context, standard);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildExamCard(
    BuildContext context,
    int examNumber,
    int startQuestion,
    int endQuestion,
    Map<String, dynamic>? result,
  ) {
    bool isCompleted = result != null;
    int score = isCompleted ? (result['score'] as int) : 0;
    Color scoreColor = score >= 80
        ? AppColors.success
        : score >= 60
        ? AppColors.warning
        : AppColors.error;

    // Dynamic plan colors - USE _currentPlan
    final primaryColor = _currentPlan?.getPrimaryColor() ?? AppColors.primary;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10.r,
            offset: Offset(0, 4.h),
          ),
        ],
        border: Border.all(
          color: isCompleted
              ? scoreColor.withOpacity(0.5)
              : primaryColor.withOpacity(0.2),
          width: 1.5.w,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => SegmentedTestScreen(
                  examNumber: examNumber,
                  startQuestion: startQuestion,
                  endQuestion: endQuestion,
                  planName: widget.planName,
                  planId: widget.planId,
                  plan: _currentPlan,
                ),
              ),
            ).then((_) => _loadExamResults());
          },
          borderRadius: BorderRadius.circular(16.r),
          child: Padding(
            padding: EdgeInsets.all(16.w),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: EdgeInsets.all(12.w),
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? scoreColor.withOpacity(0.1)
                        : primaryColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isCompleted
                        ? Icons.check_circle_rounded
                        : Icons.edit_document,
                    color: isCompleted ? scoreColor : primaryColor,
                    size: 28.r,
                  ),
                ),
                SizedBox(height: 12.h),
                Text(
                  '${AppLocalizations.of(context)?.translate('exam') ?? 'امتحان'} $examNumber',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                ),
                if (isCompleted) ...[
                  SizedBox(height: 8.h),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 8.w,
                      vertical: 4.h,
                    ),
                    decoration: BoxDecoration(
                      color: scoreColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Text(
                      '$score%',
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.bold,
                        color: scoreColor,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
