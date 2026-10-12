import 'package:flutter/material.dart';

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
import '../widgets/home_greeting_header.dart';
import '../theme/home_palette.dart';
import '../models/home_practice_state.dart';
import '../models/professional_standard.dart';
import '../widgets/app_bottom_navigation.dart';
import 'profile_screen.dart';
import 'statistics_screen.dart';
import 'test_library_screen.dart';
import 'subscribed_plans_screen.dart';

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
  bool _choosingPlan = false;
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
        backgroundColor: _selectedDestination == 0
            ? HomePalette.of(context).background
            : Theme.of(context).scaffoldBackgroundColor,
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
    final colors = HomePalette.of(context);
    final text = AppLocalizations.of(context)!;
    return SliverAppBar(
      automaticallyImplyLeading: false,
      toolbarHeight: 0,
      pinned: true,
      backgroundColor: colors.background,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(74),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 632),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  border: Border.all(color: colors.border),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: TabBar(
                  controller: _tabController,
                  labelColor: _tabController.index == 0
                      ? colors.ink
                      : const Color(0xFF102019),
                  unselectedLabelColor: colors.secondary,
                  indicator: BoxDecoration(
                    color: _tabController.index == 0
                        ? colors.greenSoft
                        : const Color(0xFFF1D185),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  labelStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0,
                  ),
                  tabs: [
                    Tab(
                      key: const ValueKey('home-free-tab'),
                      text: text.translate('free'),
                    ),
                    Tab(
                      key: const ValueKey('home-premium-tab'),
                      text: text.translate('premium'),
                    ),
                  ],
                ),
              ),
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
    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: _refreshFromPull,
        color: AppColors.primary,
        child: CustomScrollView(
          key: const PageStorageKey('home-scroll'),
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 18),
              sliver: SliverToBoxAdapter(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 600),
                    child: HomeGreetingHeader(
                      name: (_localName?.trim().isNotEmpty ?? false)
                          ? _localName
                          : _currentUser?.fullName,
                      avatar: _profileImage == null
                          ? null
                          : FileImage(_profileImage!),
                      completedTests: (_userStats?['completedTests'] as num?)
                          ?.toInt(),
                    ),
                  ),
                ),
              ),
            ),
            _buildHomeHeader(),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              sliver: SliverToBoxAdapter(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 600),
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
              ),
            ),
          ],
        ),
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

  HomePracticeState get _practiceState => HomePracticeState.fromSubscriptions(
    loading: _subscriptionsLoading,
    subscriptions: _activeSubscriptions,
  );

  Future<void> _continueTraining() async {
    if (_choosingPlan) return;
    final state = _practiceState;
    if (state.mode == HomePracticeMode.loading) return;
    _choosingPlan = true;
    try {
      final selected = state.subscription;
      if (selected != null) {
        await _openSubscription(selected);
        return;
      }
      if (state.mode == HomePracticeMode.browsePlans) {
        await _browsePlans();
        return;
      }
      final choice = await Navigator.push<Map<String, dynamic>>(
        context,
        MaterialPageRoute(
          settings: const RouteSettings(name: '/subscribedPlans'),
          builder: (_) =>
              SubscribedPlansScreen(subscriptions: state.subscriptions),
        ),
      );
      if (mounted && choice != null) await _openSubscription(choice);
    } finally {
      _choosingPlan = false;
    }
  }

  void _openDomain(ProfessionalDomain domain) {
    Navigator.pushNamed(context, '/standards', arguments: domain);
  }

  Widget _learningContent({required bool premium}) {
    final state = _practiceState;
    final subscription = state.subscription;
    final plan = subscription?['planObject'];
    return HomeLearningContent(
      premium: premium,
      practiceMode: state.mode,
      planName: plan is PaymentPlan
          ? plan.getName(context)
          : subscription?['planName']?.toString(),
      onShowProgress: () => _selectDestination(2),
      onStartTrial: _startTrial,
      onExploreStandards: () => Navigator.pushNamed(context, '/standards'),
      onOpenDomain: _openDomain,
      onBrowsePlans: _browsePlans,
      onSelectPremium: () => _tabController.animateTo(1),
      onContinuePractice: _continueTraining,
    );
  }

  Widget _buildFreeTestsTab() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _learningContent(premium: false),
      FutureBuilder<List<PaymentPlan>>(
        future: _plansFuture,
        builder: (context, snapshot) {
          final newPlans =
              snapshot.data
                  ?.where(
                    (plan) =>
                        plan.isActive &&
                        plan.createdAt != null &&
                        DateTime.now().difference(plan.createdAt!).inDays <= 7,
                  )
                  .toList() ??
              [];
          if (newPlans.isEmpty) return const SizedBox.shrink();
          final plan = newPlans.first;
          final text = AppLocalizations.of(context)!;
          final colors = HomePalette.of(context);
          return Padding(
            padding: const EdgeInsets.only(top: 12),
            child: TextButton(
              key: const ValueKey('home-new-plan'),
              onPressed: _browsePlans,
              style: TextButton.styleFrom(
                foregroundColor: colors.gold,
                minimumSize: const Size(48, 64),
                alignment: AlignmentDirectional.centerStart,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.new_releases_outlined,
                    color: colors.gold,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          text
                              .translate('homeNewPlan')
                              .replaceAll('{plan}', plan.getName(context)),
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.5,
                            color: colors.ink,
                            letterSpacing: 0,
                          ),
                        ),
                        Text(
                          text.translate('homeDiscoverPlan'),
                          style: const TextStyle(
                            fontSize: 12,
                            height: 1.5,
                            letterSpacing: 0,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.chevron_right, size: 20),
                ],
              ),
            ),
          );
        },
      ),
    ],
  );

  Widget _buildPremiumPlansTab() => _learningContent(premium: true);
}
