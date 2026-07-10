import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:http/http.dart' as http;

import 'dart:convert';
import '../constants/colors.dart';
import '../models/user.dart';
import '../services/database_service.dart';
import '../services/network_service.dart';
import '../services/auth_service.dart';
import '../l10n/app_localizations.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({Key? key}) : super(key: key);

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  int _completedTests = 0;
  int _totalPoints = 0;
  int _level = 1;
  int _progress = 0;
  bool _isLoading = true;
  User? _currentUser;

  @override
  void initState() {
    super.initState();
    _loadStatistics();
  }

  Future<void> _loadStatistics() async {
    try {
      final user = await DatabaseService.getCurrentUser();
      if (user == null) return;

      setState(() {
        _currentUser = user;
      });

      // final prefs = await SharedPreferences.getInstance();
      // final baseUrl = prefs.getString('base_url') ?? 'http://10.0.2.2:3000';
      final baseUrl = NetworkService.baseUrl;

      final response = await http.get(
        Uri.parse('$baseUrl/mobile/api/users/${user.id}/statistics'),
        headers: await AuthService.authHeaders(),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && mounted) {
          setState(() {
            _completedTests = data['data']['completedTests'] ?? 0;
            _totalPoints = data['data']['totalPoints'] ?? 0;
            _level = data['data']['level'] ?? 1;
            _progress = data['data']['progress'] ?? 0;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      print('Error loading statistics: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Container(
        decoration: BoxDecoration(color: Theme.of(context).primaryColor),
        child: SafeArea(
          child: Column(
            children: [
              // Custom AppBar
              Padding(
                padding: EdgeInsets.all(16.w),
                child: Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12.r),
                        border: Border.all(
                          color: AppColors.white.withOpacity(0.3),
                          width: 1.w,
                        ),
                      ),
                      child: IconButton(
                        icon: Icon(
                          Icons.arrow_back,
                          color: AppColors.white,
                          size: 22.r,
                        ),
                        onPressed: () => Navigator.pop(context),
                        padding: EdgeInsets.all(8.w),
                        constraints: BoxConstraints(),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        AppLocalizations.of(context)?.translate('performanceStatistics') ?? 'إحصائيات الأداء',
                        style: TextStyle(
                          color: AppColors.white,
                          fontSize: 22.sp,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    SizedBox(width: 40.w), // Balance the back button
                  ],
                ),
              ),

              // Content
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(30.r),
                      topRight: Radius.circular(30.r),
                    ),
                  ),
                  child: _isLoading
                      ? Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primary,
                          ),
                        )
                      : SingleChildScrollView(
                          padding: EdgeInsets.all(24.w),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Welcome Text
                              Text(
                                '${AppLocalizations.of(context)?.translate('hello') ?? "مرحباً"} ${_currentUser?.fullName ?? ""}!',
                                style: TextStyle(
                                  fontSize: 24.sp,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(
                                    context,
                                  ).textTheme.bodyLarge?.color,
                                ),
                              ),
                              SizedBox(height: 8.h),
                              Text(
                                AppLocalizations.of(context)?.translate('performanceSummary') ?? 'إليك ملخص أدائك',
                                style: TextStyle(
                                  fontSize: 14.sp,
                                  color: Theme.of(
                                    context,
                                  ).textTheme.bodyMedium?.color,
                                ),
                              ),
                              SizedBox(height: 32.h),

                              // Statistics Grid
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildStatCard(
                                      icon: Icons.quiz,
                                      title: AppLocalizations.of(context)?.translate('completedTests') ?? 'الاختبارات المكتملة',
                                      value: '$_completedTests',
                                      gradient: [
                                        AppColors.primary,
                                        AppColors.primaryDark,
                                      ],
                                    ),
                                  ),
                                  SizedBox(width: 16.w),
                                  Expanded(
                                    child: _buildStatCard(
                                      icon: Icons.emoji_events,
                                      title: AppLocalizations.of(context)?.translate('totalPoints') ?? 'إجمالي النقاط',
                                      value: '$_totalPoints',
                                      gradient: [
                                        AppColors.secondary,
                                        AppColors.secondaryDark,
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 24.h),

                              // Level Card
                              Container(
                                padding: EdgeInsets.all(24.w),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      AppColors.planGoldStart.withOpacity(0.2),
                                      AppColors.planGoldEnd.withOpacity(0.2),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(20.r),
                                  border: Border.all(
                                    color: AppColors.planGoldStart.withOpacity(
                                      0.4,
                                    ),
                                    width: 2.w,
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: EdgeInsets.all(16.w),
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [
                                                AppColors.planGoldStart,
                                                AppColors.planGoldEnd,
                                              ],
                                            ),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            Icons.star,
                                            color: AppColors.white,
                                            size: 28.r,
                                          ),
                                        ),
                                        SizedBox(width: 20.w),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                AppLocalizations.of(context)?.translate('currentLevel') ?? 'المستوى الحالي',
                                                style: TextStyle(
                                                  fontSize: 14.sp,
                                                  color: Theme.of(
                                                    context,
                                                  ).textTheme.bodyMedium?.color,
                                                ),
                                              ),
                                              SizedBox(height: 4.h),
                                              Text(
                                                '${AppLocalizations.of(context)?.translate('level') ?? 'المستوى'} $_level',
                                                style: TextStyle(
                                                  fontSize: 24.sp,
                                                  fontWeight: FontWeight.bold,
                                                  color: Theme.of(
                                                    context,
                                                  ).textTheme.bodyLarge?.color,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Container(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 16.w,
                                            vertical: 8.h,
                                          ),
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [
                                                AppColors.planGoldStart,
                                                AppColors.planGoldEnd,
                                              ],
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              20.r,
                                            ),
                                          ),
                                          child: Text(
                                            '$_progress%',
                                            style: TextStyle(
                                              fontSize: 18.sp,
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.white,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 20.h),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          AppLocalizations.of(context)?.translate('progressToNextLevel') ?? 'التقدم للمستوى التالي',
                                          style: TextStyle(
                                            fontSize: 13.sp,
                                            color: Theme.of(
                                              context,
                                            ).textTheme.bodyMedium?.color,
                                          ),
                                        ),
                                        SizedBox(height: 12.h),
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            10.r,
                                          ),
                                          child: LinearProgressIndicator(
                                            value: _progress / 100,
                                            backgroundColor:
                                                AppColors.lightGrey,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                  AppColors.planGoldStart,
                                                ),
                                            minHeight: 10.h,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),

                              SizedBox(height: 24.h),

                              // Info Card
                              Container(
                                padding: EdgeInsets.all(20.w),
                                decoration: BoxDecoration(
                                  color: AppColors.info.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(16.r),
                                  border: Border.all(
                                    color: AppColors.info.withOpacity(0.3),
                                    width: 1.5.w,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.info_outline,
                                      color: AppColors.info,
                                      size: 24.r,
                                    ),
                                    SizedBox(width: 12.w),
                                    Expanded(
                                      child: Text(
                                        AppLocalizations.of(context)?.translate('pointsToNextLevelMessage') ?? 'كل 200 نقطة = مستوى جديد\nأكمل المزيد من الاختبارات لزيادة نقاطك!',
                                        style: TextStyle(
                                          fontSize: 13.sp,
                                          color: Theme.of(
                                            context,
                                          ).textTheme.bodyMedium?.color,
                                          height: 1.5,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
    required List<Color> gradient,
  }) {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: gradient[0].withOpacity(0.3), width: 2.w),
        boxShadow: [
          BoxShadow(
            color: gradient[0].withOpacity(0.15),
            blurRadius: 12.r,
            offset: Offset(0, 6.h),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(14.w),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: gradient),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.white, size: 24.r),
          ),
          SizedBox(height: 16.h),
          Text(
            value,
            style: TextStyle(
              fontSize: 28.sp,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).textTheme.bodyLarge?.color,
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            title,
            style: TextStyle(
              fontSize: 12.sp,
              color: Theme.of(context).textTheme.bodyMedium?.color,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
