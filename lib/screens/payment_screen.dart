import 'dart:async';
import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../models/payment_plan.dart';
import '../models/user.dart';
import '../services/content_cache.dart';
import '../services/database_service.dart';
import '../services/mongodb_question_service.dart';
import '../theme/home_palette.dart';
import '../widgets/plan_catalog_content.dart';

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  List<PaymentPlan> _plans = [];
  final Set<String> _additionalTestIds = {};
  PaymentPlan? _selectedPlan;
  User? _currentUser;
  bool _isLoading = true;
  bool _hasError = false;
  bool _refreshingCatalog = false;
  bool _catalogUpdatePending = false;
  bool _navigating = false;

  @override
  void initState() {
    super.initState();
    ContentCache.changes.addListener(_onCatalogChanged);
    unawaited(_loadPlansAndUser());
  }

  @override
  void dispose() {
    ContentCache.changes.removeListener(_onCatalogChanged);
    super.dispose();
  }

  Future<void> _loadPlansAndUser() async {
    if (_refreshingCatalog) return;
    _refreshingCatalog = true;
    try {
      final plans = await DatabaseService.getPaymentPlans();
      final user = await DatabaseService.getCurrentUser();
      final additionalTests = await MongoQuestionService.getAdditionalTests();
      final testPlans = additionalTests
          .map(
            (t) => PaymentPlan(
              id: t['id'],
              name: t['nameAr'] ?? t['name'],
              nameEn: t['nameEn'] ?? '',
              description: t['descriptionAr'] ?? t['description'] ?? '',
              descriptionEn: t['descriptionEn'] ?? '',
              questionCount:
                  (t['examQuestionCount'] is num &&
                      (t['examQuestionCount'] as num) > 0)
                  ? (t['examQuestionCount'] as num).toInt()
                  : (t['questionCount'] as num?)?.toInt() ?? 0,
              price: (t['price'] as num?)?.toDouble() ?? 0,
              currency: 'ر.س',
              isActive: t['isActive'] ?? true,
              primaryColor: t['primaryColor'] ?? '#1B5E20',
              secondaryColor: t['secondaryColor'] ?? '#F6C41C',
            ),
          )
          .where((plan) => plan.isActive)
          .toList();
      if (!mounted) return;
      final activePlans = plans.where((plan) => plan.isActive).toList()
        ..addAll(testPlans);
      setState(() {
        _plans = activePlans;
        _additionalTestIds
          ..clear()
          ..addAll(testPlans.map((plan) => plan.id));
        if (_selectedPlan != null) {
          final matches = activePlans.where((p) => p.id == _selectedPlan!.id);
          _selectedPlan = matches.isEmpty ? null : matches.first;
        }
        _currentUser = user;
        _isLoading = false;
        _hasError = false;
      });
      await DatabaseService.refreshCurrentUser();
      final freshUser = await DatabaseService.getCurrentUser();
      if (mounted) setState(() => _currentUser = freshUser);
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = _plans.isEmpty;
        });
      }
    } finally {
      _refreshingCatalog = false;
      if (_catalogUpdatePending && mounted) {
        _catalogUpdatePending = false;
        unawaited(_loadPlansAndUser());
      }
    }
  }

  void _onCatalogChanged() {
    if (!mounted) return;
    if (_refreshingCatalog) {
      _catalogUpdatePending = true;
    } else {
      unawaited(_loadPlansAndUser());
    }
  }

  Future<void> _proceed() async {
    final plan = _selectedPlan;
    if (plan == null || _navigating) return;
    setState(() => _navigating = true);
    try {
      if (plan.price == 0 || _hasActiveSubscriptionForPlan(plan.id)) {
        if (_additionalTestIds.contains(plan.id)) {
          await Navigator.pushNamed(
            context,
            '/additionalTest',
            arguments: {
              'testId': plan.id,
              'title': plan.getName(context),
              'questionCount': plan.questionCount,
            },
          );
        } else {
          await Navigator.pushNamed(
            context,
            '/examList',
            arguments: {
              'planId': plan.id,
              'planName': plan.name,
              'totalQuestions': plan.questionCount,
            },
          );
        }
      } else {
        await Navigator.pushNamed(context, '/paymentDetails', arguments: plan);
      }
    } finally {
      if (mounted) setState(() => _navigating = false);
    }
  }

  bool _hasActiveSubscriptionForPlan(String planId) {
    final user = _currentUser;
    if (user == null) return false;
    if (user.subscriptionPlanId == planId) return true;
    for (final sub in user.additionalSubscriptions) {
      final id = sub['planId'];
      final value = id is Map ? (id['_id'] ?? id['id']) : id;
      if (value?.toString() == planId && sub['isActive'] == true) return true;
    }
    return user.purchasedTests.any((test) => test['testId'] == planId);
  }

  @override
  Widget build(BuildContext context) {
    final p = HomePalette.of(context);
    final text = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: p.background,
      appBar: AppBar(
        backgroundColor: p.background,
        surfaceTintColor: Colors.transparent,
        foregroundColor: p.ink,
        elevation: 0,
        leading: BackButton(onPressed: () => Navigator.pop(context)),
        title: Text(
          text.translate('catalogTitle'),
          style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
        ),
      ),
      body: PlanCatalogContent(
        plans: _plans,
        selectedPlan: _selectedPlan,
        isLoading: _isLoading,
        hasError: _hasError,
        isNavigating: _navigating,
        isOwned: _hasActiveSubscriptionForPlan,
        onSelect: (plan) => setState(() => _selectedPlan = plan),
        onProceed: _proceed,
        onRetry: () {
          setState(() {
            _isLoading = true;
            _hasError = false;
          });
          unawaited(_loadPlansAndUser());
        },
      ),
    );
  }
}
