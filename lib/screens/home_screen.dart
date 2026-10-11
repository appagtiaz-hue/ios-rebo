import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../constants/colors.dart';
import '../models/user.dart';
import '../models/payment_plan.dart';
import '../services/database_service.dart';
import '../services/pull_refresh_limiter.dart';
import '../services/content_cache.dart';
import '../services/network_service.dart';
import 'dart:async';
import '../services/subscription_service.dart'; // Added subscription service
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import '../l10n/app_localizations.dart';
import '../widgets/home_learning_content.dart';
import '../widgets/premium_tab_label.dart';
import '../widgets/app_bottom_navigation.dart';
import 'profile_screen.dart';
import 'statistics_screen.dart';
import 'test_library_screen.dart';

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
  late Future<List<PaymentPlan>> _plansFuture;
  Future<void>? _refreshInFlight;
  Timer? _contentVersionTimer;
  int _selectedDestination = 0;
  bool _subscriptionsLoading = true;
  double _tabSwipeDistance = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _plansFuture = DatabaseService.getPaymentPlans();
    ContentCache.changes.addListener(_onContentChanged);
    _contentVersionTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
        unawaited(
          ContentCache.checkForChanges(Uri.parse(NetworkService.baseUrl)),
        );
      }
    });
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
    _contentVersionTimer?.cancel();
    ContentCache.changes.removeListener(_onContentChanged);
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

  Future<void> _loadCurrentUser({bool loadSubscriptions = true}) async {
    final user = await DatabaseService.getCurrentUser();
    if (mounted) {
      setState(() {
        _currentUser = user;
      });
    }

    if (user != null && loadSubscriptions) {
      await _loadActiveSubscriptions();
    } else if (user == null && mounted) {
      setState(() => _subscriptionsLoading = false);
    }
  }

  Future<void> _loadActiveSubscriptions() async {
    if (_currentUser == null) {
      if (mounted) setState(() => _subscriptionsLoading = false);
      return;
    }
    final subs = await SubscriptionService.getActiveSubscriptions(
      _currentUser!.id,
    );

    // Load full plan details for each subscription
    final List<Map<String, dynamic>> subsWithPlans = [];
    final allPlans = await _plansFuture;

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
        _subscriptionsLoading = false;
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

  Future<void> _refreshFromPull() {
    if (_currentUser == null) return Future<void>.value();
    if (_refreshInFlight != null) return _refreshInFlight!;
    if (!PullRefreshLimiter.home.tryAcquire()) return Future<void>.value();
    return _refreshUserData();
  }

  Future<void> _refreshUserData() {
    if (_refreshInFlight != null) return _refreshInFlight!;
    late final Future<void> refresh;
    refresh = _performRefresh().whenComplete(() {
      if (identical(_refreshInFlight, refresh)) _refreshInFlight = null;
    });
    _refreshInFlight = refresh;
    return refresh;
  }

  Future<void> _performRefresh() async {
    if (_currentUser != null) {
      await ContentCache.checkForChanges(
        Uri.parse(NetworkService.baseUrl),
        force: true,
      );
      await DatabaseService.refreshCurrentUser();
      _plansFuture = DatabaseService.getPaymentPlans();
      await _loadCurrentUser(loadSubscriptions: false);
      await _loadUserStatistics();
      await _loadProfileImage();
      await _loadLocalName();
      await _loadActiveSubscriptions(); // Added refresh for subscriptions
    }
  }

  void _onContentChanged() {
    if (!mounted) return;
    setState(() => _plansFuture = DatabaseService.getPaymentPlans());
    if (_refreshInFlight == null) {
      unawaited(_loadActiveSubscriptions());
      unawaited(_loadUserStatistics());
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
    return PopScope(
      canPop: _selectedDestination == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _selectDestination(0);
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: IndexedStack(
          index: _selectedDestination,
          children: [
            TickerMode(
              enabled: _selectedDestination == 0,
              child: _buildHomeScroll(),
            ),
            TestLibraryScreen(
              subscriptions: _activeSubscriptions,
              loading: _subscriptionsLoading,
              onStartTrial: _startTrial,
              onOpenSubscription: _openSubscription,
              onBrowsePlans: _browsePlans,
            ),
            // Build network-backed destinations only when selected.
            if (_selectedDestination == 2)
              StatisticsScreen(
                onBack: () => _selectDestination(0),
                user: _currentUser,
                statistics: _userStats,
              )
            else
              const SizedBox.shrink(),
            if (_selectedDestination == 3)
              SafeArea(
                child: ProfileScreen(
                  onBack: () => _selectDestination(0),
                  user: _currentUser,
                  subscriptions: _activeSubscriptions,
                ),
              )
            else
              const SizedBox.shrink(),
          ],
        ),
        bottomNavigationBar: AppBottomNavigation(
          selectedIndex: _selectedDestination,
          onSelect: _selectDestination,
        ),
      ),
    );
  }

  SliverAppBar _buildHomeHeader() {
    final compact = MediaQuery.orientationOf(context) == Orientation.landscape;
    return SliverAppBar(
      automaticallyImplyLeading: false,
      toolbarHeight: 0,
      expandedHeight: compact ? null : 260.h,
      floating: false,
      pinned: true,
      elevation: 0,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      flexibleSpace: compact
          ? null
          : FlexibleSpaceBar(
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
                        // User details.
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
                                value: '${_userStats?['completedTests'] ?? 0}',
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
        preferredSize: Size.fromHeight(48 + 16.h + 8.w),
        child: Container(
          color: Theme.of(context).scaffoldBackgroundColor,
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
          child: Container(
            padding: EdgeInsets.all(4.w),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16.r),
            ),
            child: TabBar(
              controller: _tabController,
              labelColor: _tabController.index == 0
                  ? Colors.white
                  : const Color(0xFF1C1C1C),
              unselectedLabelColor: Theme.of(
                context,
              ).colorScheme.onSurfaceVariant,
              indicator: BoxDecoration(
                color: _tabController.index == 0
                    ? AppColors.primary
                    : const Color(0xFFE8B83F),
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
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: _tabController.index == 0
                    ? Colors.white
                    : const Color(0xFF1C1C1C),
              ),
              unselectedLabelStyle: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              tabs: [
                Tab(
                  text:
                      AppLocalizations.of(context)?.translate('free') ??
                      'مجاني',
                ),
                Tab(
                  child: PremiumTabLabel(
                    selected: _tabController.index == 1,
                    label:
                        AppLocalizations.of(context)?.translate('premium') ??
                        'مميز',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _selectDestination(int index) {
    if (index == _selectedDestination) return;
    final leavingAccount = _selectedDestination == 3;
    setState(() => _selectedDestination = index);
    if (leavingAccount) {
      unawaited(_loadProfileImage());
      unawaited(_loadLocalName());
    }
  }

  Future<void> _startTrial() async {
    await Navigator.pushNamed(context, '/test');
    if (mounted) await _refreshUserData();
  }

  Future<void> _browsePlans() async {
    await Navigator.pushNamed(context, '/payment');
    if (mounted) await _refreshUserData();
  }

  Future<void> _openSubscription(Map<String, dynamic> subscription) async {
    final name = subscription['planName']?.toString() ?? '';
    final additional = name.contains('إضافي') || name.contains('Additional');
    await Navigator.pushNamed(
      context,
      additional ? '/additionalTest' : '/examList',
      arguments: additional
          ? {
              'testId': subscription['planId'],
              'title': name,
              'questionCount': subscription['questionCount'] ?? 0,
            }
          : {
              'planId': subscription['planId'],
              'planName': name,
              'totalQuestions': subscription['questionCount'] ?? 0,
              'plan': subscription['planObject'] as PaymentPlan?,
            },
    );
    if (mounted) await _refreshUserData();
  }

  Widget _buildHomeScroll() {
    // A shared viewport keeps the header still when switching tabs.
    return RefreshIndicator(
      onRefresh: _refreshFromPull,
      color: AppColors.primary,
      child: CustomScrollView(
        key: const PageStorageKey('home-scroll'),
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          _buildHomeHeader(),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(16.w, 16.w, 16.w, 8),
            sliver: SliverToBoxAdapter(
              child: GestureDetector(
                key: const ValueKey('home-tab-content'),
                behavior: HitTestBehavior.opaque,
                onHorizontalDragStart: (_) => _tabSwipeDistance = 0,
                onHorizontalDragUpdate: (details) =>
                    _tabSwipeDistance += details.delta.dx,
                onHorizontalDragEnd: _switchHomeTab,
                child: _tabController.index == 0
                    ? _buildFreeTestsTab()
                    : _buildPremiumPlansTab(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _switchHomeTab(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    final distance = _tabSwipeDistance;
    _tabSwipeDistance = 0;
    if (distance.abs() < 48 && velocity.abs() < 300) return;
    final motion = velocity.abs() >= 300 ? velocity : distance;
    final forward = Directionality.of(context) == TextDirection.rtl
        ? motion > 0
        : motion < 0;
    final target = (_tabController.index + (forward ? 1 : -1)).clamp(0, 1);
    if (target != _tabController.index) _tabController.animateTo(target);
  }

  Widget _buildFreeTestsTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // New Plan Banner
        FutureBuilder<List<PaymentPlan>>(
          future: _plansFuture,
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
        HomeLearningContent(
          premium: false,
          onShowProgress: () => _selectDestination(2),
          onStartTrial: _startTrial,
          onExploreStandards: () => Navigator.pushNamed(context, '/standards'),
        ),
      ],
    );
  }

  Widget _buildPremiumPlansTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HomePlanBrowseAction(onBrowsePlans: _browsePlans),
        const SizedBox(height: 16),
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
                onTap: () => _openSubscription(sub),
              );
            }).toList(),
          ),
          SizedBox(height: 20.h),
          _buildSectionTitle(
            AppLocalizations.of(context)?.translate('otherPlans') ??
                'باقات أخرى',
          ),
          SizedBox(height: 12.h),
        ],

        HomeLearningContent(
          premium: true,
          onShowProgress: () => _selectDestination(2),
          onStartTrial: _startTrial,
          onExploreStandards: () => Navigator.pushNamed(context, '/standards'),
        ),
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
                                  'جديد ومميز',
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
