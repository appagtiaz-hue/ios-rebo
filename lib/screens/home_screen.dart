import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../constants/colors.dart';
import '../models/user.dart';
import '../models/payment_plan.dart';
import '../services/database_service.dart';
import '../services/subscription_service.dart'; // Added subscription service
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import '../l10n/app_localizations.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  User? _currentUser;
  Map<String, dynamic>? _userStats;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadCurrentUser().then((_) => _loadUserStatistics());
    _loadProfileImage();
    _loadLocalName();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadProfileImage();
      _loadLocalName();
      _refreshUserData();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshUserData();
    }
  }

  Future<void> _loadCurrentUser() async {
    final user = await DatabaseService.getCurrentUser();
    if (mounted) {
      setState(() {
        _currentUser = user;
      });
    }

    if (user != null) {
      _loadActiveSubscriptions();
    }
  }

  Future<void> _loadActiveSubscriptions() async {
    if (_currentUser == null) return;
    final subs = await SubscriptionService.getActiveSubscriptions(
      _currentUser!.id,
    );

    // Load full plan details for each subscription
    final List<Map<String, dynamic>> subsWithPlans = [];
    final allPlans = await DatabaseService.getPaymentPlans();

    for (var sub in subs) {
      final plan = allPlans.firstWhere(
        (p) => p.id == sub['planId'],
        orElse: () => PaymentPlan(
          id: sub['planId'] ?? '',
          name: sub['planName'] ?? '',
          nameEn: '',
          description: '',
          descriptionEn: '',
          questionCount: sub['questionCount'] ?? 0,
          price: 0,
          currency: 'ريال سعودي',
          isActive: true,
        ),
      );
      subsWithPlans.add({...sub, 'planObject': plan});
    }

    if (mounted) {
      setState(() {
        _activeSubscriptions = subsWithPlans;
      });
    }
  }

  Future<void> _loadUserStatistics() async {
    if (_currentUser != null) {
      print('📊 Loading statistics for user: ${_currentUser!.id}');
      final stats = await DatabaseService.getUserStatistics(_currentUser!.id);
      print('📊 Received stats: $stats');
      if (mounted) {
        setState(() {
          _userStats = stats;
        });
      }
    } else {
      print('⚠️ Cannot load stats: Current user is null');
    }
  }

  Future<void> _refreshUserData() async {
    if (_currentUser != null) {
      await DatabaseService.refreshCurrentUser();
      await _loadCurrentUser();
      await _loadUserStatistics();
      await _loadProfileImage();
      await _loadLocalName();
      await _loadActiveSubscriptions(); // Added refresh for subscriptions
    }
  }

  File? _profileImage;
  String? _localName;
  // _userStats is declared at top
  List<Map<String, dynamic>> _activeSubscriptions =
      []; // Added for multiple subscriptions

  Future<void> _loadLocalName() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _localName = prefs.getString('local_user_name');
      });
    }
  }

  Future<void> _loadProfileImage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final imagePath = prefs.getString('profile_image_path');
      File? newImage;
      if (imagePath != null) {
        final file = File(imagePath);
        if (await file.exists()) {
          newImage = file;
        }
      }
      if (mounted) {
        setState(() {
          _profileImage = newImage;
        });
      }
    } catch (e) {
      print('Error loading profile image: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              expandedHeight: 260.h,
              floating: false,
              pinned: true,
              elevation: 0,
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color(0xFF063311), // Very Dark Green
                        Color(0xFF0D4D2B), // Dark Green
                        Color(0xFF1B5E20), // Standard Dark Green
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 12.h),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Top Row with user info and buttons
                          Row(
                            children: [
                              // User Avatar
                              Container(
                                width: 52.r,
                                height: 52.r,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Color(0xFFF6C41C),
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2.5.w,
                                  ),
                                  image: _profileImage != null
                                      ? DecorationImage(
                                          image: FileImage(_profileImage!),
                                          fit: BoxFit.cover,
                                        )
                                      : null,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.15),
                                      blurRadius: 8.r,
                                      offset: Offset(0, 3.h),
                                    ),
                                  ],
                                ),
                                child: _profileImage == null
                                    ? Center(
                                        child: Text(
                                          (_currentUser?.fullName.isNotEmpty ??
                                                  false)
                                              ? _currentUser!.fullName[0]
                                                    .toUpperCase()
                                              : 'م',
                                          style: TextStyle(
                                            fontSize: 24.sp,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF1B5E20),
                                          ),
                                        ),
                                      )
                                    : null,
                              ),
                              SizedBox(width: 12.w),
                              // User Name and Welcome
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      (AppLocalizations.of(
                                                context,
                                              )?.translate('welcomeBack') ??
                                              'مرحباً بعودتك!') +
                                          ' 👋',
                                      style: TextStyle(
                                        fontSize: 13.sp,
                                        color: Colors.white.withOpacity(0.9),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    SizedBox(height: 4.h),
                                    Text(
                                      _localName ??
                                          _currentUser?.fullName ??
                                          AppLocalizations.of(
                                            context,
                                          )?.translate('user') ??
                                          'المستخدم',
                                      style: TextStyle(
                                        fontSize: 18.sp,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              // Action Buttons
                              _buildActionButton(
                                icon: Icons.logout_rounded,
                                onTap: () async {
                                  await DatabaseService.logout();
                                  if (mounted) {
                                    Navigator.pushReplacementNamed(
                                      context,
                                      '/login',
                                    );
                                  }
                                },
                              ),
                              SizedBox(width: 8.w),
                              _buildActionButton(
                                icon: Icons.person_outline_rounded,
                                onTap: () => Navigator.pushNamed(
                                  context,
                                  '/profile',
                                ).then((_) => _refreshUserData()),
                              ),
                            ],
                          ),
                          SizedBox(height: 20.h),
                          // Stats Row
                          Container(
                            padding: EdgeInsets.symmetric(
                              vertical: 12.h,
                              horizontal: 16.w,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(16.r),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.2),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _buildStatItem(
                                  icon: Icons.quiz_rounded,
                                  value:
                                      '${_userStats?['completedTests'] ?? 0}',
                                  label:
                                      AppLocalizations.of(
                                        context,
                                      )?.translate('completed') ??
                                      'مكتمل',
                                ),
                                _buildDivider(),
                                _buildStatItem(
                                  icon: Icons.emoji_events_rounded,
                                  value: '${_userStats?['totalPoints'] ?? 0}',
                                  label:
                                      AppLocalizations.of(
                                        context,
                                      )?.translate('points') ??
                                      'نقطة',
                                ),
                                _buildDivider(),
                                _buildStatItem(
                                  icon: Icons.stars_rounded,
                                  value: '${_userStats?['level'] ?? 1}',
                                  label:
                                      AppLocalizations.of(
                                        context,
                                      )?.translate('level') ??
                                      'مستوى',
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              bottom: PreferredSize(
                preferredSize: Size.fromHeight(65.h),
                child: Container(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  padding: EdgeInsets.symmetric(
                    horizontal: 16.w,
                    vertical: 8.h,
                  ),
                  child: Container(
                    padding: EdgeInsets.all(4.w),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(16.r),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      labelColor: AppColors.primary,
                      unselectedLabelColor: AppColors.textSecondary,
                      indicator: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(12.r),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      indicatorSize: TabBarIndicatorSize.tab,
                      dividerColor: Colors.transparent,
                      labelStyle: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                      ),
                      unselectedLabelStyle: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w500,
                      ),
                      tabs: [
                        Tab(
                          text:
                              AppLocalizations.of(context)?.translate('free') ??
                              'مجاني',
                        ),
                        Tab(
                          text:
                              AppLocalizations.of(
                                context,
                              )?.translate('premium') ??
                              'مميز',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [_buildFreeTestsTab(), _buildPremiumPlansTab()],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showContactDialog(context),
        backgroundColor: AppColors.primary,
        child: Icon(
          Icons.support_agent_rounded,
          color: Colors.white,
          size: 24.r,
        ),
        elevation: 4,
        shape: CircleBorder(),
      ),
    );
  }

  void _showContactDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.symmetric(horizontal: 20.w),
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(24.r),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 20,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: EdgeInsets.all(20.w),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(24.r),
                    topRight: Radius.circular(24.r),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(10.w),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.support_agent_rounded,
                        color: AppColors.primary,
                        size: 24.r,
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Text(
                      AppLocalizations.of(context)?.translate('contactUs') ??
                          'تواصل معنا',
                      style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(
                        Icons.close_rounded,
                        color: Theme.of(context).textTheme.bodyMedium?.color,
                        size: 24.r,
                      ),
                    ),
                  ],
                ),
              ),

              Padding(
                padding: EdgeInsets.all(20.w),
                child: Column(
                  children: [
                    _buildContactOption(
                      icon: Icons.chat_rounded,
                      title:
                          AppLocalizations.of(context)?.translate('whatsapp') ??
                          'واتساب',
                      subtitle: '+966537583811',
                      color: Color(0xFF25D366), // WhatsApp Green
                      onTap: () async {
                        final Uri whatsappLaunchUri = Uri.https(
                          'wa.me',
                          '/966537583811',
                          {
                            'text':
                                AppLocalizations.of(
                                  context,
                                )?.translate('supportWhatsappMessage') ??
                                'السلام عليكم، أحتاج مساعدة من الدعم الفني.',
                          },
                        );
                        await _launchUrl(whatsappLaunchUri);
                      },
                    ),
                    SizedBox(height: 12.h),
                    _buildContactOption(
                      icon: Icons.email_outlined,
                      title:
                          AppLocalizations.of(context)?.translate('email') ??
                          'البريد الإلكتروني',
                      subtitle: 'agtiazsupp@gmail.com',
                      color: Color(0xFFEA4335), // Google Red
                      onTap: () async {
                        final Uri emailLaunchUri = Uri(
                          scheme: 'mailto',
                          path: 'agtiazsupp@gmail.com',
                        );
                        await _launchUrl(emailLaunchUri);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContactOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16.r),
        child: Container(
          padding: EdgeInsets.all(12.w),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(16.r),
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(10.w),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Icon(icon, color: color, size: 24.r),
              ),
              SizedBox(width: 16.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: Theme.of(context).textTheme.bodyMedium?.color,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16.r,
                color: Theme.of(context).textTheme.bodyMedium?.color,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _launchUrl(Uri url) async {
    try {
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context)?.translate('cannotOpenLink') ?? 'لا يمكن فتح الرابط'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)?.translate('unexpectedError') ?? 'حدث خطأ غير متوقع'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Widget _buildFreeTestsTab() {
    return RefreshIndicator(
      onRefresh: _refreshUserData,
      color: AppColors.primary,
      child: ListView(
        padding: EdgeInsets.all(16.w),
        children: [
          // New Plan Banner
          FutureBuilder<List<PaymentPlan>>(
            future: DatabaseService.getPaymentPlans(),
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                final newPlans = snapshot.data!.where((plan) {
                  if (plan.createdAt == null) return false;
                  final diff = DateTime.now().difference(plan.createdAt!);
                  return diff.inDays <= 7;
                }).toList();

                if (newPlans.isNotEmpty) {
                  return Column(
                    children: [
                      _buildNewPlanBanner(newPlans.first),
                      SizedBox(height: 16.h),
                    ],
                  );
                }
              }
              return SizedBox.shrink();
            },
          ),
          _buildMainTestCard(
            title:
                AppLocalizations.of(context)?.translate('startFreeTest') ??
                'ابدأ الاختبار المجاني',
            subtitle:
                AppLocalizations.of(context)?.translate('fiveQuestions') ??
                '5 أسئلة متنوعة',
            description:
                AppLocalizations.of(context)?.translate('testYourKnowledge') ??
                'اختبر معلوماتك واحصل على نتائج فورية',
            icon: Icons.quiz_rounded,
            gradient: [AppColors.primary, AppColors.primaryDark],
            badge: AppLocalizations.of(context)?.translate('free') ?? 'مجاني',
            onTap: () => Navigator.pushNamed(
              context,
              '/test',
            ).then((_) => _refreshUserData()),
          ),
          SizedBox(height: 20.h),
          _buildSectionTitle(
            AppLocalizations.of(context)?.translate('whyTestYourself') ??
                'لماذا تختبر نفسك؟',
          ),
          SizedBox(height: 12.h),
          _buildFeaturesList(),
          SizedBox(height: 20.h),
          _buildSectionTitle(
            AppLocalizations.of(context)?.translate('quickTips') ??
                'نصائح سريعة',
          ),
          SizedBox(height: 12.h),
          _buildTipsCard(),
          SizedBox(height: 20.h),
          _buildMotivationCard(),
        ],
      ),
    );
  }

  Widget _buildPremiumPlansTab() {
    return ListView(
      padding: EdgeInsets.all(16.w),
      children: [
        // Active Subscriptions Section
        if (_activeSubscriptions.isNotEmpty) ...[
          _buildSectionTitle(
            AppLocalizations.of(context)?.translate('myActiveSubscriptions') ??
                'اشتراكاتي النشطة',
          ),
          SizedBox(height: 12.h),
          Wrap(
            spacing: 12.w,
            runSpacing: 12.w,
            children: _activeSubscriptions.map((sub) {
              final planName = sub['planName'] ?? 'غير محدد';
              final questionCount = sub['questionCount'] ?? 0;
              final isMain = sub['isMain'] == true;
              final cardWidth = (MediaQuery.of(context).size.width - 44.w) / 2;

              final plan = sub['planObject'] as PaymentPlan?;

              return _buildSmallSubscriptionCard(
                width: cardWidth,
                // Use localized name from plan object
                title: plan != null ? plan.getName(context) : planName,
                subtitle: isMain
                    ? (AppLocalizations.of(context)?.translate('main') ??
                          'أساسي')
                    : (AppLocalizations.of(context)?.translate('additional') ??
                          'إضافي'),
                description:
                    '$questionCount ${AppLocalizations.of(context)?.translate('question') ?? 'سؤال'}',
                icon: Icons.check_circle_outline,
                gradient: plan != null
                    ? plan.getGradient()
                    : [Color(0xFFC0C0C0), Color(0xFF9E9E9E)],
                badge:
                    AppLocalizations.of(context)?.translate('active') ?? 'مفعل',
                onTap: () {
                  if (planName.contains('إضافي') ||
                      planName.contains('Additional')) {
                    Navigator.pushNamed(
                      context,
                      '/additionalTest',
                      arguments: {'testId': sub['planId'], 'title': planName},
                    );
                  } else {
                    final plan = sub['planObject'] as PaymentPlan?;
                    Navigator.pushNamed(
                      context,
                      '/examList',
                      arguments: {
                        'planId': sub['planId'],
                        'planName': planName,
                        'totalQuestions': questionCount,
                        'plan': plan, // Pass plan object
                      },
                    );
                  }
                },
              );
            }).toList(),
          ),
          SizedBox(height: 20.h),
          SizedBox(height: 20.h),
          _buildSectionTitle(
            AppLocalizations.of(context)?.translate('otherPlans') ??
                'باقات أخرى',
          ),
          SizedBox(height: 12.h),
        ],

        _buildMainTestCard(
          title:
              AppLocalizations.of(context)?.translate('browsePlans') ??
              'تصفح الباقات',
          subtitle:
              AppLocalizations.of(context)?.translate('diversePremiumPlans') ??
              'خطط مدفوعة متنوعة',
          description:
              AppLocalizations.of(context)?.translate('getUnlimitedAccess') ??
              'احصل على وصول غير محدود لجميع المميزات',
          icon: Icons.workspace_premium_rounded,
          gradient: [AppColors.secondary, AppColors.secondaryLight],
          badge: AppLocalizations.of(context)?.translate('premium') ?? 'مميز',
          onTap: () => Navigator.pushNamed(context, '/payment'),
        ),
        SizedBox(height: 20.h),
        _buildSectionTitle(
          AppLocalizations.of(context)?.translate('subscriptionFeatures') ??
              'مميزات الاشتراك',
        ),
        SizedBox(height: 12.h),
        _buildPremiumFeatureCard(
          icon: Icons.all_inclusive_rounded,
          title:
              AppLocalizations.of(context)?.translate('unlimitedTests') ??
              'اختبارات غير محدودة',
          description:
              AppLocalizations.of(context)?.translate('unlimitedTestsDesc') ??
              'وصول كامل لآلاف الأسئلة في جميع المجالات',
        ),
        SizedBox(height: 12.h),
        _buildPremiumFeatureCard(
          icon: Icons.analytics_rounded,
          title:
              AppLocalizations.of(context)?.translate('advancedAnalytics') ??
              'تحليلات متقدمة',
          description:
              AppLocalizations.of(
                context,
              )?.translate('advancedAnalyticsDesc') ??
              'تقارير مفصلة عن أدائك وتقدمك',
        ),
        SizedBox(height: 12.h),
        _buildPremiumFeatureCard(
          icon: Icons.workspace_premium_rounded,
          title:
              AppLocalizations.of(context)?.translate('noAds') ??
              'بدون إعلانات',
          description:
              AppLocalizations.of(context)?.translate('noAdsDesc') ??
              'تجربة خالية من الإعلانات المزعجة',
        ),
        SizedBox(height: 12.h),
        _buildPremiumFeatureCard(
          icon: Icons.support_agent_rounded,
          title:
              AppLocalizations.of(context)?.translate('premiumSupport') ??
              'دعم فني متميز',
          description:
              AppLocalizations.of(context)?.translate('premiumSupportDesc') ??
              'فريق دعم متخصص للإجابة على استفساراتك',
        ),
        SizedBox(height: 12.h),
        _buildPremiumFeatureCard(
          icon: Icons.update_rounded,
          title:
              AppLocalizations.of(context)?.translate('continuousUpdates') ??
              'تحديثات مستمرة',
          description:
              AppLocalizations.of(
                context,
              )?.translate('continuousUpdatesDesc') ??
              'أسئلة جديدة ومحتوى محدث باستمرار',
        ),
        SizedBox(height: 24.h),
        // Call to Action Button
        Container(
          width: double.infinity,
          height: 56.h,
          child: ElevatedButton(
            onPressed: () => Navigator.pushNamed(context, '/payment'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.secondary,
              foregroundColor: Colors.white,
              elevation: 4,
              shadowColor: AppColors.secondary.withOpacity(0.4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.r),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.rocket_launch_rounded, size: 24.r),
                SizedBox(width: 12.w),
                Text(
                  AppLocalizations.of(context)?.translate('subscribeNow') ??
                      'اشترك الآن',
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: 16.h),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 4.w),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 16.sp,
          fontWeight: FontWeight.bold,
          color: AppColors.primary,
        ),
      ),
    );
  }

  Widget _buildMainTestCard({
    required String title,
    required String subtitle,
    required String description,
    required IconData icon,
    required List<Color> gradient,
    required String badge,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24.r),
        boxShadow: [
          BoxShadow(
            color: gradient[0].withOpacity(0.3),
            blurRadius: 20.r,
            offset: Offset(0, 8.h),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24.r),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24.r),
          child: Ink(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: gradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24.r),
            ),
            child: Padding(
              padding: EdgeInsets.all(16.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(12.w),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.25),
                          borderRadius: BorderRadius.circular(20.r),
                        ),
                        child: Icon(icon, size: 30.r, color: Colors.white),
                      ),
                      SizedBox(width: 16.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    title,
                                    style: TextStyle(
                                      fontSize: 18.sp,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                SizedBox(width: 8.w),
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 10.w,
                                    vertical: 5.h,
                                  ),
                                  decoration: BoxDecoration(
                                    color: gradient[0] == AppColors.primary
                                        ? AppColors.secondary
                                        : AppColors.primary,
                                    borderRadius: BorderRadius.circular(10.r),
                                  ),
                                  child: Text(
                                    badge,
                                    style: TextStyle(
                                      fontSize: 10.sp,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 4.h),
                            Text(
                              subtitle,
                              style: TextStyle(
                                fontSize: 12.sp,
                                color: Colors.white.withOpacity(0.9),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16.h),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: Colors.white.withOpacity(0.85),
                      height: 1.4,
                    ),
                  ),
                  SizedBox(height: 20.h),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(vertical: 10.h),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16.r),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10.r,
                          offset: Offset(0, 4.h),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          AppLocalizations.of(context)?.translate('startNow') ??
                              'ابدأ الآن',
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.bold,
                            color: gradient[0],
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Icon(
                          Icons.arrow_forward_rounded,
                          size: 20.r,
                          color: gradient[0],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSmallSubscriptionCard({
    required double width,
    required String title,
    required String subtitle,
    required String description,
    required IconData icon,
    required List<Color> gradient,
    required String badge,
    required VoidCallback onTap,
  }) {
    return Container(
      width: width,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [
          BoxShadow(
            color: gradient[0].withOpacity(0.2),
            blurRadius: 10.r,
            offset: Offset(0, 4.h),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20.r),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20.r),
          child: Ink(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: gradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20.r),
            ),
            child: Padding(
              padding: EdgeInsets.all(12.w),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: EdgeInsets.all(8.w),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.25),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, size: 24.r, color: Colors.white),
                  ),
                  SizedBox(height: 10.h),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 4.h),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 8.w,
                      vertical: 4.h,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Text(
                      badge,
                      style: TextStyle(
                        fontSize: 10.sp,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        AppLocalizations.of(context)?.translate('enter') ??
                            'دخول',
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.bold,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_rounded,
                        size: 14.r,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeaturesList() {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            offset: Offset(0, 4.h),
            blurRadius: 10.r,
            color: Theme.of(context).shadowColor,
          ),
        ],
      ),
      child: Column(
        children: [
          _buildFeatureItem(
            icon: Icons.speed_rounded,
            title:
                AppLocalizations.of(context)?.translate('instantResults') ??
                'نتائج فورية',
            description:
                AppLocalizations.of(context)?.translate('instantResultsDesc') ??
                'احصل على النتائج مباشرة بعد الانتهاء',
            color: AppColors.primary,
          ),
          SizedBox(height: 12.h),
          _buildFeatureItem(
            icon: Icons.lightbulb_rounded,
            title:
                AppLocalizations.of(context)?.translate('learnFromMistakes') ??
                'تعلم من أخطائك',
            description:
                AppLocalizations.of(
                  context,
                )?.translate('learnFromMistakesDesc') ??
                'شرح مفصل لكل إجابة خاطئة',
            color: AppColors.secondary,
          ),
          SizedBox(height: 12.h),
          _buildFeatureItem(
            icon: Icons.bar_chart_rounded,
            title:
                AppLocalizations.of(context)?.translate('trackProgress') ??
                'تتبع تقدمك',
            description:
                AppLocalizations.of(context)?.translate('trackProgressDesc') ??
                'راقب تطورك عبر الوقت',
            color: AppColors.primaryDark,
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureItem({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(8.w),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: Icon(icon, size: 20.r, color: color),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              SizedBox(height: 2.h),
              Text(
                description,
                style: TextStyle(
                  fontSize: 12.sp,
                  color: Theme.of(context).textTheme.bodyMedium?.color,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTipsCard() {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.secondary.withOpacity(0.15),
            AppColors.secondary.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: AppColors.secondary.withOpacity(0.3),
          width: 1.5.w,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.tips_and_updates_rounded,
                color: AppColors.secondary,
                size: 24.r,
              ),
              SizedBox(width: 8.w),
              Text(
                AppLocalizations.of(context)?.translate('successTips') ??
                    'نصائح للنجاح',
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.bold,
                  color: AppColors.secondary,
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          _buildTipItem(
            AppLocalizations.of(context)?.translate('tipReadCarefully') ??
                'اقرأ السؤال بتمعن قبل الإجابة',
          ),
          _buildTipItem(
            AppLocalizations.of(context)?.translate('tipDontRush') ??
                'لا تستعجل في الإجابة',
          ),
          _buildTipItem(
            AppLocalizations.of(context)?.translate('tipReviewAnswers') ??
                'راجع إجاباتك قبل الإرسال',
          ),
        ],
      ),
    );
  }

  Widget _buildTipItem(String text) {
    return Padding(
      padding: EdgeInsets.only(bottom: 6.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: EdgeInsets.only(top: 6.h),
            width: 6.w,
            height: 6.w,
            decoration: BoxDecoration(
              color: AppColors.secondary,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12.sp,
                color: Theme.of(context).textTheme.bodyMedium?.color,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMotivationCard() {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withOpacity(0.1),
            AppColors.primaryDark.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.2),
          width: 1.5.w,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(14.r),
            ),
            child: Icon(
              Icons.auto_awesome_rounded,
              color: AppColors.primary,
              size: 24.r,
            ),
          ),
          SizedBox(width: 16.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context)?.translate('keepGoing') ??
                      'استمر في التقدم! 🚀',
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  AppLocalizations.of(
                        context,
                      )?.translate('motivationMessage') ??
                      'كل اختبار يقربك خطوة من هدفك',
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: Theme.of(context).textTheme.bodyMedium?.color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40.r,
        height: 40.r,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(10.r),
        ),
        child: Icon(icon, color: Colors.white, size: 20.r),
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Color(0xFFF6C41C), size: 22.r),
            SizedBox(width: 6.w),
            Text(
              value,
              style: TextStyle(
                fontSize: 22.sp,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
        SizedBox(height: 6.h),
        Text(
          label,
          style: TextStyle(
            fontSize: 14.sp,
            color: Colors.white.withOpacity(0.9),
          ),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Container(
      width: 1.5,
      height: 45.h,
      color: Colors.white.withOpacity(0.3),
    );
  }

  Widget _buildPremiumFeatureCard({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: AppColors.secondary.withOpacity(0.2),
          width: 1.5.w,
        ),
        boxShadow: [
          BoxShadow(
            offset: Offset(0, 4.h),
            blurRadius: 10.r,
            color: Theme.of(context).shadowColor,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: AppColors.secondary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Icon(icon, size: 20.r, color: AppColors.secondary),
          ),
          SizedBox(width: 16.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.bold,
                    color: AppColors.secondary,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: Theme.of(context).textTheme.bodyMedium?.color,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.check_circle_rounded,
            color: AppColors.secondary,
            size: 24.r,
          ),
        ],
      ),
    );
  }

  Widget _buildNewPlanBanner(PaymentPlan plan) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: plan.getGradient(),
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [
          BoxShadow(
            color: plan.getPrimaryColor().withOpacity(0.3),
            blurRadius: 15,
            offset: Offset(0, 8.h),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20.r),
        child: InkWell(
          onTap: () => Navigator.pushNamed(context, '/payment'),
          borderRadius: BorderRadius.circular(20.r),
          child: Padding(
            padding: EdgeInsets.all(16.w),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(12.w),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(16.r),
                  ),
                  child: Icon(
                    Icons.new_releases_rounded,
                    color: Colors.white,
                    size: 32.r,
                  ),
                ),
                SizedBox(width: 16.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              AppLocalizations.of(
                                    context,
                                  )?.translate('newAndFeatured') ??
                                  'جديد ومميز ✨',
                              style: TextStyle(
                                fontSize: 16.sp,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          SizedBox(width: 8.w),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 8.w,
                              vertical: 2.h,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(6.r),
                            ),
                            child: Text(
                              'NEW',
                              style: TextStyle(
                                fontSize: 10.sp,
                                fontWeight: FontWeight.bold,
                                color: plan.getPrimaryColor(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        plan.getName(context),
                        style: TextStyle(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        AppLocalizations.of(
                              context,
                            )?.translate('newPlanAvailable') ??
                            'خطة جديدة متاحة الآن!',
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_rounded,
                  color: Colors.white,
                  size: 24.r,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
