import 'dart:convert';
import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import '../services/content_cache.dart';
import '../services/database_service.dart';
import '../services/network_service.dart';
import '../theme/home_palette.dart';
import '../widgets/statistics_content.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key, this.onBack, this.user, this.statistics});
  final VoidCallback? onBack;
  final User? user;
  final Map<String, dynamic>? statistics;

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  int _completedTests = 0;
  int _totalPoints = 0;
  int _level = 1;
  int _progress = 0;
  bool _isLoading = true;
  bool _unavailable = false;
  bool _fetching = false;

  @override
  void initState() {
    super.initState();
    if (widget.onBack != null) {
      _useHomeData();
    } else {
      ContentCache.changes.addListener(_loadStatistics);
      _loadStatistics();
    }
  }

  @override
  void didUpdateWidget(covariant StatisticsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.onBack == null && widget.onBack != null) {
      ContentCache.changes.removeListener(_loadStatistics);
    } else if (oldWidget.onBack != null && widget.onBack == null) {
      ContentCache.changes.addListener(_loadStatistics);
      _loadStatistics();
    }
    if (widget.onBack != null) _useHomeData();
  }

  int _number(dynamic value, {int minimum = 0}) {
    final parsed = value is num && value.isFinite ? value.toInt() : minimum;
    return parsed < minimum ? minimum : parsed;
  }

  void _applyData(Map<String, dynamic> data) {
    _completedTests = _number(data['completedTests']);
    _totalPoints = _number(data['totalPoints']);
    _level = _number(data['level'], minimum: 1);
    _progress = _number(data['progress']).clamp(0, 100);
    _unavailable = false;
    _isLoading = false;
  }

  void _useHomeData() {
    final data = widget.statistics;
    if (data != null) {
      _applyData(data);
    } else {
      _completedTests = 0;
      _totalPoints = 0;
      _level = 1;
      _progress = 0;
      _unavailable = false;
      _isLoading = widget.user != null;
    }
  }

  @override
  void dispose() {
    ContentCache.changes.removeListener(_loadStatistics);
    super.dispose();
  }

  Future<void> _loadStatistics() async {
    if (_fetching || widget.onBack != null) return;
    _fetching = true;
    try {
      final user = await DatabaseService.getCurrentUser();
      if (!mounted || widget.onBack != null) return;
      if (user == null) throw StateError('No current account');
      final response = await ContentCache.get(
        Uri.parse(
          '${NetworkService.baseUrl}/mobile/api/users/${user.id}/statistics',
        ),
        headers: await AuthService.authHeaders(),
        cacheFirst: true,
        userData: true,
      );
      if (!mounted || widget.onBack != null) return;
      if (response.statusCode != 200)
        throw StateError('Statistics unavailable');
      final data = jsonDecode(response.body);
      if (data is! Map ||
          data['success'] != true ||
          data['data'] is! Map<String, dynamic>) {
        throw const FormatException('Invalid statistics');
      }
      setState(() => _applyData(data['data'] as Map<String, dynamic>));
    } catch (_) {
      if (mounted && widget.onBack == null) {
        setState(() {
          _isLoading = false;
          _unavailable = true;
        });
      }
    } finally {
      _fetching = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = HomePalette.of(context);
    final text = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: p.background,
      body: SafeArea(
        bottom: widget.onBack == null,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 24, 8),
              child: Row(
                children: [
                  IconButton(
                    key: const ValueKey('stats-back'),
                    tooltip: MaterialLocalizations.of(
                      context,
                    ).backButtonTooltip,
                    onPressed: widget.onBack ?? () => Navigator.pop(context),
                    color: p.ink,
                    icon: const Icon(Icons.arrow_back),
                    constraints: const BoxConstraints(
                      minWidth: 48,
                      minHeight: 48,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      text.translate('statsTitle'),
                      style: TextStyle(
                        color: p.ink,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _isLoading
                  ? Center(
                      child: Semantics(
                        liveRegion: true,
                        child: Text(
                          text.translate('statsLoading'),
                          style: TextStyle(color: p.secondary, fontSize: 15),
                        ),
                      ),
                    )
                  : _unavailable
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              text.translate('statsUnavailable'),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: p.secondary,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 12),
                            IconButton(
                              key: const ValueKey('stats-retry'),
                              tooltip: text.translate('statsRetry'),
                              icon: Icon(Icons.refresh, color: p.green),
                              onPressed: () {
                                setState(() => _isLoading = true);
                                _loadStatistics();
                              },
                            ),
                          ],
                        ),
                      ),
                    )
                  : SingleChildScrollView(
                      key: const PageStorageKey('statistics-scroll'),
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 600),
                          child: StatisticsContent(
                            completedTests: _completedTests,
                            totalPoints: _totalPoints,
                            level: _level,
                            progress: _progress,
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
}
