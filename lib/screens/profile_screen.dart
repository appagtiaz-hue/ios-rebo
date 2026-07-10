import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../constants/colors.dart';
import '../models/user.dart';
import '../models/payment_plan.dart';
import '../services/database_service.dart';
import '../services/subscription_service.dart'; // Added subscription service
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import '../services/theme_service.dart';
import '../services/localization_service.dart';
import '../services/auth_service.dart';
import '../l10n/app_localizations.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  User? currentUser;
  PaymentPlan? myPlan;
  List<Map<String, dynamic>> _activeSubscriptions = [];
  bool _isLoadingSubscriptions = false;

  @override
  void initState() {
    super.initState();
    _loadProfileImage();
    _loadLocalName();
    _loadUserData();
  }

  String? _localName;

  Future<void> _loadLocalName() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _localName = prefs.getString('local_user_name');
    });
  }

  Future<void> _updateLocalName(String newName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('local_user_name', newName);
    setState(() {
      _localName = newName;
    });
  }

  void _showEditNameDialog() {
    final TextEditingController _nameController = TextEditingController(
      text: _localName ?? currentUser?.fullName ?? '',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: Text(
          AppLocalizations.of(context)?.translate('editNameTitle') ??
              'تعديل الاسم',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        content: TextField(
          controller: _nameController,
          style: Theme.of(context).textTheme.bodyLarge,
          decoration: InputDecoration(
            hintText:
                AppLocalizations.of(context)?.translate('newNameHint') ??
                'الاسم الجديد',
            hintStyle: Theme.of(context).textTheme.bodyMedium,
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              AppLocalizations.of(context)?.translate('cancel') ?? 'إلغاء',
            ),
          ),
          ElevatedButton(
            onPressed: () {
              if (_nameController.text.isNotEmpty) {
                _updateLocalName(_nameController.text);
                Navigator.pop(context);
              }
            },
            child: Text(
              AppLocalizations.of(context)?.translate('save') ?? 'حفظ',
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  void _showLanguageDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return ValueListenableBuilder<Locale>(
          valueListenable: LocalizationService.locale,
          builder: (context, currentLocale, _) {
            return AlertDialog(
              backgroundColor: Theme.of(context).cardColor,
              title: Text(
                AppLocalizations.of(context)?.translate('language') ?? 'اللغة',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RadioListTile<String>(
                    title: Text(
                      AppLocalizations.of(context)?.translate('arabic') ??
                          'العربية',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    value: 'ar',
                    groupValue: currentLocale.languageCode,
                    activeColor: AppColors.primary,
                    onChanged: (val) {
                      if (val != null) {
                        LocalizationService.setLocale(
                          Locale(val, val == 'ar' ? 'SA' : 'US'),
                        );
                        Navigator.pop(context);
                      }
                    },
                  ),
                  RadioListTile<String>(
                    title: Text(
                      AppLocalizations.of(context)?.translate('english') ??
                          'English',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    value: 'en',
                    groupValue: currentLocale.languageCode,
                    activeColor: AppColors.primary,
                    onChanged: (val) {
                      if (val != null) {
                        LocalizationService.setLocale(
                          Locale(val, val == 'ar' ? 'SA' : 'US'),
                        );
                        Navigator.pop(context);
                      }
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showThemeDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return ValueListenableBuilder<ThemeMode>(
          valueListenable: ThemeService.themeMode,
          builder: (context, currentMode, _) {
            return AlertDialog(
              backgroundColor: Theme.of(context).cardColor,
              title: Text(
                AppLocalizations.of(context)?.translate('appearance') ??
                    'المظهر',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RadioListTile<ThemeMode>(
                    title: Text(
                      AppLocalizations.of(context)?.translate('systemTheme') ??
                          'النظام',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    value: ThemeMode.system,
                    groupValue: currentMode,
                    activeColor: AppColors.primary,
                    onChanged: (val) {
                      if (val != null) ThemeService.setThemeMode(val);
                      Navigator.pop(context);
                    },
                  ),
                  RadioListTile<ThemeMode>(
                    title: Text(
                      AppLocalizations.of(context)?.translate('lightTheme') ??
                          'فاتح',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    value: ThemeMode.light,
                    groupValue: currentMode,
                    activeColor: AppColors.primary,
                    onChanged: (val) {
                      if (val != null) ThemeService.setThemeMode(val);
                      Navigator.pop(context);
                    },
                  ),
                  RadioListTile<ThemeMode>(
                    title: Text(
                      AppLocalizations.of(context)?.translate('darkTheme') ??
                          'داكن',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    value: ThemeMode.dark,
                    groupValue: currentMode,
                    activeColor: AppColors.primary,
                    onChanged: (val) {
                      if (val != null) ThemeService.setThemeMode(val);
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  File? _profileImage;
  final ImagePicker _picker = ImagePicker();

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

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image == null) return;

      // فتح شاشة الـ Crop بعد اختيار الصورة
      final CroppedFile? croppedFile = await ImageCropper().cropImage(
        sourcePath: image.path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1), // مربع دائماً
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'اضبط الصورة',
            toolbarColor: const Color(0xFF0D4D2B),
            toolbarWidgetColor: Colors.white,
            activeControlsWidgetColor: const Color(0xFFF6C41C),
            backgroundColor: Colors.black,
            dimmedLayerColor: Colors.black54,
            cropFrameColor: const Color(0xFFF6C41C),
            cropGridColor: Colors.white30,
            statusBarColor: const Color(0xFF063311),
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: false,
            hideBottomControls: false,
          ),
        ],
      );

      if (croppedFile != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('profile_image_path', croppedFile.path);
        setState(() {
          _profileImage = File(croppedFile.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ أثناء اختيار الصورة'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _removeImage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('profile_image_path');
      setState(() {
        _profileImage = null;
      });
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

  void _confirmRemoveImage() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: Text(
          AppLocalizations.of(context)?.translate('removeImage') ?? 'إزالة الصورة',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        content: Text(
          AppLocalizations.of(context)?.translate('confirmRemoveImage') ?? 'هل أنت متأكد من إزالة الصورة الشخصية؟',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              AppLocalizations.of(context)?.translate('cancel') ?? 'إلغاء',
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _removeImage();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: Text(
              AppLocalizations.of(context)?.translate('delete') ?? 'حذف',
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _loadUserData() async {
    final user = await DatabaseService.getCurrentUser();
    final allPlans = await DatabaseService.getPaymentPlans();
    PaymentPlan? plan;
    if (user?.subscriptionPlanId != null) {
      try {
        plan = allPlans.firstWhere(
          (p) =>
              p.id == user!.subscriptionPlanId ||
              p.id.toString() == user.subscriptionPlanId.toString(),
        );
      } catch (e) {
        try {
          final planId = user!.subscriptionPlanId;
          String? flutterPlanId;
          if (planId == '69004751c54bee180c5d50a4') {
            flutterPlanId = 'silver';
          } else if (planId == '69004770459269c2b71977b9') {
            flutterPlanId = 'gold';
          }
          if (flutterPlanId != null) {
            plan = allPlans.firstWhere((p) => p.id == flutterPlanId);
          }
        } catch (e2) {
          plan = null;
        }
      }
    }

    if (!mounted) return;
    setState(() {
      currentUser = user;
      myPlan = plan;
    });

    if (user != null) {
      _loadActiveSubscriptions();
    }
  }

  Future<void> _loadActiveSubscriptions() async {
    if (currentUser == null) return;
    setState(() => _isLoadingSubscriptions = true);
    final subs = await SubscriptionService.getActiveSubscriptions(
      currentUser!.id,
    );

    // Debug: Check if planObject exists
    print('🔍 DEBUG: Loaded ${subs.length} subscriptions');
    for (var sub in subs) {
      print('  - Plan: ${sub['planName']}');
      print('    Has planObject: ${sub['planObject'] != null}');
      if (sub['planObject'] != null) {
        print('    planObject.name: ${sub['planObject']['name']}');
        print('    planObject.nameEn: ${sub['planObject']['nameEn']}');
      }
    }

    if (mounted) {
      setState(() {
        _activeSubscriptions = subs;
        _isLoadingSubscriptions = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        toolbarHeight: 0,
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF063311), // Very Dark Green
              Color(0xFF0D4D2B), // Dark Green
              Color(0xFF1B5E20), // Standard Dark Green
            ],
          ),
        ),
        child: Column(
          children: [
            // Header Section - 45%
            Expanded(
              flex: 45,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Back Button
                    Align(
                      alignment: Alignment.topRight,
                      child: IconButton(
                        icon: Icon(Icons.arrow_back, color: AppColors.white),
                        onPressed: () => Navigator.pop(context),
                        padding: EdgeInsets.zero,
                        constraints: BoxConstraints(),
                      ),
                    ),

                    // Avatar
                    // Avatar
                    Stack(
                      children: [
                        GestureDetector(
                          onTap: _pickImage,
                          child: Container(
                            width: 90.r,
                            height: 90.r,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.white,
                              border: Border.all(
                                color: AppColors.white,
                                width: 2.w,
                              ),
                              image: _profileImage != null
                                  ? DecorationImage(
                                      image: FileImage(_profileImage!),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                            ),
                            child: _profileImage == null
                                ? Icon(
                                    Icons.person,
                                    size: 50.r,
                                    color: AppColors.primary,
                                  )
                                : null,
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: _pickImage,
                            child: Container(
                              padding: EdgeInsets.all(6.w),
                              decoration: BoxDecoration(
                                color: AppColors.secondary,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColors.white,
                                  width: 2.w,
                                ),
                              ),
                              child: Icon(
                                Icons.camera_alt_rounded,
                                size: 16.r,
                                color: AppColors.white,
                              ),
                            ),
                          ),
                        ),
                        if (_profileImage != null)
                          Positioned(
                            top: 0,
                            left: 0,
                            child: GestureDetector(
                              onTap: _confirmRemoveImage,
                              child: Container(
                                padding: EdgeInsets.all(4.w),
                                decoration: BoxDecoration(
                                  color: AppColors.error,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: AppColors.white,
                                    width: 1.5.w,
                                  ),
                                ),
                                child: Icon(
                                  Icons.close_rounded,
                                  size: 14.r,
                                  color: AppColors.white,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),

                    SizedBox(height: 10.h),

                    // User Name
                    // User Name with Edit
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Balancing hidden icon
                        Opacity(
                          opacity: 0.0,
                          child: Padding(
                            padding: EdgeInsets.only(right: 8.w),
                            child: Icon(Icons.edit_rounded, size: 20.r),
                          ),
                        ),
                        Flexible(
                          child: Text(
                            _localName ??
                                currentUser?.fullName ??
                                (AppLocalizations.of(
                                      context,
                                    )?.translate('userDefault') ??
                                    'مستخدم'),
                            style: TextStyle(
                              fontSize: 18.sp,
                              fontWeight: FontWeight.bold,
                              color: AppColors.white,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.only(left: 8.w),
                          child: GestureDetector(
                            onTap: _showEditNameDialog,
                            child: Icon(
                              Icons.edit_rounded,
                              color: AppColors.white.withOpacity(0.8),
                              size: 20.r,
                            ),
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 4.h),

                    // Email
                    Text(
                      currentUser?.email ?? '',
                      style: TextStyle(
                        fontSize: 13.sp,
                        color: AppColors.white.withOpacity(0.9),
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),

                    SizedBox(height: 10.h),

                    // Statistics Button
                    Container(
                      width: 140.w,
                      height: 36.h,
                      decoration: BoxDecoration(
                        color: AppColors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(18.r),
                        border: Border.all(
                          color: AppColors.white.withOpacity(0.5),
                          width: 1.5.w,
                        ),
                      ),
                      child: TextButton(
                        onPressed: () {
                          Navigator.pushNamed(context, '/statistics');
                        },
                        style: TextButton.styleFrom(padding: EdgeInsets.zero),
                        child: Text(
                          AppLocalizations.of(
                                context,
                              )?.translate('statistics') ??
                              'الإحصائيات',
                          style: TextStyle(
                            color: AppColors.white,
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      height: 30.h,
                    ), // Push visible content up relative to center
                  ],
                ),
              ),
            ),
            // Content Section - 55% White (Floating on top)
            Expanded(
              flex: 55,
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(30.r),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: Offset(0, -2),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: 16.h),

                      // Account Section
                      _buildSectionHeader(
                        AppLocalizations.of(
                              context,
                            )?.translate('accountSection') ??
                            'الحساب',
                      ),

                      // Show loading indicator
                      if (_isLoadingSubscriptions)
                        Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      // Show "No Active Plan" if list is empty
                      else if (_activeSubscriptions.isEmpty)
                        _buildListTile(
                          icon: Icons.workspace_premium,
                          title:
                              AppLocalizations.of(
                                context,
                              )?.translate('noActivePlan') ??
                              'لا توجد خطة مفعلة',
                          subtitle:
                              AppLocalizations.of(
                                context,
                              )?.translate('subscribeToAccess') ??
                              'اشترك الآن للوصول إلى المحتوى',
                          trailing: Icon(
                            Icons.arrow_forward_ios,
                            color: AppColors.textLight,
                            size: 16.r,
                          ),
                          onTap: () => Navigator.pushNamed(context, '/payment'),
                          hasArrow: true,
                        )
                      // Show list of active subscriptions
                      else
                        ..._activeSubscriptions.map((sub) {
                          final planName = sub['planName'] ?? 'غير محدد';
                          // Handle planId safely (if backend sends object or string)
                          final rawPlanId = sub['planId'];
                          final String planId = rawPlanId is Map
                              ? (rawPlanId['_id'] ?? rawPlanId['id']).toString()
                              : rawPlanId.toString();

                          final questionCount = sub['questionCount'] ?? 0;

                          return Container(
                            margin: EdgeInsets.symmetric(
                              horizontal: 16.w,
                              vertical: 4.h,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(context).cardColor,
                              borderRadius: BorderRadius.circular(20.r),
                              border: Border.all(
                                color: AppColors.primary.withOpacity(0.1),
                                width: 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.03),
                                  blurRadius: 5,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                ListTile(
                                  leading: Container(
                                    padding: EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: AppColors.secondary.withOpacity(
                                        0.1,
                                      ),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.star,
                                      color: AppColors.secondary,
                                    ),
                                  ),
                                  title: Text(
                                    // Use localized name from plan object
                                    sub['planObject'] != null
                                        ? PaymentPlan.fromJson(
                                            sub['planObject'],
                                          ).getName(context)
                                        : planName,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14.sp,
                                      color: Theme.of(
                                        context,
                                      ).textTheme.bodyLarge?.color,
                                    ),
                                  ),
                                  // Expiration date removed as per request
                                  trailing: Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.success.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      AppLocalizations.of(
                                            context,
                                          )?.translate('active') ??
                                          'نشط',
                                      style: TextStyle(
                                        color: AppColors.success,
                                        fontSize: 10.sp,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                                Divider(height: 1),
                                InkWell(
                                  onTap: () {
                                    if (planName.contains('إضافي') ||
                                        planName.contains('Additional') ||
                                        planName.contains('مواقف') ||
                                        planName.contains('Situational')) {
                                      Navigator.pushNamed(
                                        context,
                                        '/additionalTest',
                                        arguments: {
                                          'testId': planId,
                                          'title': planName,
                                        },
                                      );
                                    } else {
                                      Navigator.pushNamed(
                                        context,
                                        '/examList',
                                        arguments: {
                                          'planId': planId,
                                          'planName': planName,
                                          'totalQuestions': questionCount,
                                        },
                                      );
                                    }
                                  },
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(
                                      vertical: 12.h,
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.quiz,
                                          size: 18.sp,
                                          color: AppColors.primary,
                                        ),
                                        SizedBox(width: 8.w),
                                        Text(
                                          '${AppLocalizations.of(context)?.translate('enterExam') ?? 'دخول الاختبار'} ($questionCount ${AppLocalizations.of(context)?.translate('question') ?? 'سؤال'})',
                                          style: TextStyle(
                                            color: AppColors.primary,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13.sp,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),

                      _buildListTile(
                        icon: Icons.sync,
                        title:
                            AppLocalizations.of(
                              context,
                            )?.translate('updateData') ??
                            'تحديث البيانات',
                        subtitle:
                            AppLocalizations.of(
                              context,
                            )?.translate('syncWithServer') ??
                            'مزامنة مع الخادم',
                        onTap: () async {
                          showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder: (context) => Center(
                              child: Container(
                                padding: EdgeInsets.all(24.w),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).cardColor,
                                  borderRadius: BorderRadius.circular(16.r),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    CircularProgressIndicator(
                                      color: AppColors.primary,
                                    ),
                                    SizedBox(height: 12.h),
                                    Text(
                                      AppLocalizations.of(
                                            context,
                                          )?.translate('updatingData') ??
                                          'جاري تحديث البيانات...',
                                      style: TextStyle(
                                        fontSize: 16.sp,
                                        fontWeight: FontWeight.w600,
                                        color: Theme.of(
                                          context,
                                        ).textTheme.bodyLarge?.color,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );

                          await DatabaseService.syncOfflineContentIfOnline();
                          await _loadUserData();

                          if (mounted) Navigator.pop(context);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Row(
                                  children: [
                                    Icon(
                                      Icons.check_circle,
                                      color: AppColors.white,
                                    ),
                                    SizedBox(width: 12.w),
                                    Text(
                                      AppLocalizations.of(
                                            context,
                                          )?.translate('dataUpdatedSuccess') ??
                                          'تم تحديث البيانات بنجاح!',
                                    ),
                                  ],
                                ),
                                backgroundColor: AppColors.success,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12.r),
                                ),
                              ),
                            );
                          }
                        },
                      ),

                      SizedBox(height: 16.h),

                      // Account Settings
                      _buildSectionHeader(
                        AppLocalizations.of(context)?.translate('settings') ??
                            'الإعدادات',
                      ),
                      _buildListTile(
                        icon: Icons.palette_outlined,
                        title:
                            AppLocalizations.of(
                              context,
                            )?.translate('appearance') ??
                            'المظهر',
                        subtitle:
                            AppLocalizations.of(
                              context,
                            )?.translate('chooseTheme') ??
                            'اختر مظهر التطبيق (فاتح/داكن)',
                        onTap: _showThemeDialog,
                        hasArrow: true,
                        iconColor: AppColors.secondary,
                      ),
                      _buildListTile(
                        icon: Icons.language,
                        title:
                            AppLocalizations.of(
                              context,
                            )?.translate('language') ??
                            'اللغة',
                        subtitle: LocalizationService.isArabic()
                            ? 'العربية'
                            : 'English',
                        onTap: _showLanguageDialog,
                        hasArrow: true,
                        iconColor: AppColors.primary,
                      ),

                      SizedBox(height: 16.h),

                      // Account Actions
                      _buildSectionHeader(
                        AppLocalizations.of(
                              context,
                            )?.translate('accountActions') ??
                            'إجراءات الحساب',
                      ),
                      _buildListTile(
                        icon: Icons.logout,
                        title:
                            AppLocalizations.of(context)?.translate('logout') ??
                            'تسجيل الخروج',
                        subtitle: null,
                        iconColor: AppColors.error,
                        titleColor: AppColors.error,
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              backgroundColor: Theme.of(context).cardColor,
                              title: Text(
                                AppLocalizations.of(
                                      context,
                                    )?.translate('confirmLogout') ??
                                    'هل أنت متأكد من تسجيل الخروج؟',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: Text(
                                    AppLocalizations.of(
                                          context,
                                        )?.translate('cancel') ??
                                        'إلغاء',
                                  ),
                                ),
                                ElevatedButton(
                                  onPressed: () async {
                                    Navigator.pop(
                                      context,
                                    ); // Close dialog first
                                    // Clear JWT and Google session
                                    await AuthService.logout();
                                    final prefs =
                                        await SharedPreferences.getInstance();
                                    await prefs.clear();
                                    await DatabaseService.logout();
                                    if (mounted) {
                                      Navigator.pushNamedAndRemoveUntil(
                                        context,
                                        '/login',
                                        (route) => false,
                                      );
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.error,
                                    foregroundColor: Colors.white,
                                  ),
                                  child: Text(
                                    AppLocalizations.of(
                                          context,
                                        )?.translate('confirm') ??
                                        'تأكيد',
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),

                      SizedBox(height: 32.h),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: EdgeInsets.fromLTRB(24.w, 4.h, 24.w, 4.h), // Reduced padding
      child: Text(
        title,
        style: TextStyle(
          fontSize: 11.sp, // Reduced font size
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildListTile({
    required IconData icon,
    required String title,
    String? subtitle,
    VoidCallback? onTap,
    bool hasArrow = true,
    Widget? trailing,
    Color? iconColor,
    Color? titleColor,
  }) {
    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: 16.w,
        vertical: 2.h,
      ), // Reduced margin
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20.r),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 16.w,
              vertical: 8.h,
            ), // Reduced vertical padding
            child: Row(
              children: [
                // Icon
                Container(
                  width: 32.r, // Reduced icon container size
                  height: 32.r,
                  decoration: BoxDecoration(
                    color: (iconColor ?? AppColors.primary).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Icon(
                    icon,
                    size: 16.r, // Reduced icon size
                    color: iconColor ?? AppColors.primary,
                  ),
                ),

                SizedBox(width: 10.w),

                // Text
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 13.sp, // Reduced title font size
                          fontWeight: FontWeight.w600,
                          color:
                              titleColor ??
                              Theme.of(context).textTheme.bodyLarge?.color,
                        ),
                      ),
                      if (subtitle != null) ...[
                        SizedBox(height: 2.h),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 10.sp, // Reduced subtitle font size
                            color: Theme.of(
                              context,
                            ).textTheme.bodyMedium?.color,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // Trailing
                if (trailing != null)
                  trailing
                else if (hasArrow && onTap != null)
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 16.r,
                    color: AppColors.textLight,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
