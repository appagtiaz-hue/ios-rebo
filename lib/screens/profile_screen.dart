import 'package:flutter/material.dart';
import '../theme/home_palette.dart';
import '../widgets/profile_content.dart';
import '../constants/colors.dart';
import '../models/user.dart';
import '../models/payment_plan.dart';
import '../services/database_service.dart';
import '../services/subscription_service.dart'; // Added subscription service
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/theme_service.dart';
import '../services/localization_service.dart';
import '../services/auth_service.dart';
import '../l10n/app_localizations.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, this.onBack, this.user, this.subscriptions});
  final VoidCallback? onBack;
  final User? user;
  final List<Map<String, dynamic>>? subscriptions;

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
    if (widget.subscriptions != null) {
      _useHomeData();
    } else {
      _loadUserData();
    }
  }

  @override
  void didUpdateWidget(covariant ProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.subscriptions != null) _useHomeData();
  }

  void _useHomeData() {
    currentUser = widget.user;
    _activeSubscriptions = [
      for (final subscription in widget.subscriptions!)
        {
          ...subscription,
          'planObject': (subscription['planObject'] as PaymentPlan?)?.toJson(),
        },
    ];
  }

  String? _localName;

  Future<void> _loadLocalName() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _localName = prefs.getString('local_user_name');
    });
  }

  Future<void> _updateLocalName(String newName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('local_user_name', newName);
    if (!mounted) return;
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
        scrollable: true,
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
              scrollable: true,
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
              scrollable: true,
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
        if (!mounted) return;
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
      if (!mounted) return;
      setState(() {
        _profileImage = null;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)?.translate('unexpectedError') ??
                  'حدث خطأ غير متوقع',
            ),
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
          AppLocalizations.of(context)?.translate('removeImage') ??
              'إزالة الصورة',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        scrollable: true,
        content: Text(
          AppLocalizations.of(context)?.translate('confirmRemoveImage') ??
              'هل أنت متأكد من إزالة الصورة الشخصية؟',
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

  void _showContactDialog(BuildContext context) {
    final strings =
        AppLocalizations.of(context) ?? AppLocalizations(const Locale('ar'));
    final p = HomePalette.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: p.background,
        insetPadding: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        scrollable: true,
        title: Row(
          children: [
            Icon(Icons.support_agent_rounded, color: p.green),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                strings.translate('contactUs'),
                style: TextStyle(
                  color: p.ink,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            IconButton(
              tooltip: MaterialLocalizations.of(context).closeButtonLabel,
              onPressed: () => Navigator.pop(context),
              icon: Icon(Icons.close_rounded, color: p.secondary),
            ),
          ],
        ),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ProfileActionRow(
                icon: Icons.chat_outlined,
                title: strings.translate('whatsapp'),
                subtitle: '+966537583811',
                subtitleDirection: TextDirection.ltr,
                onTap: () => _launchUrl(
                  Uri.https('wa.me', '/966537583811', {
                    'text': strings.translate('supportWhatsappMessage'),
                  }),
                ),
              ),
              Divider(height: 1, color: p.border),
              ProfileActionRow(
                icon: Icons.email_outlined,
                title: strings.translate('email'),
                subtitle: 'agtiazsupp@gmail.com',
                subtitleDirection: TextDirection.ltr,
                color: p.gold,
                onTap: () => _launchUrl(
                  Uri(scheme: 'mailto', path: 'agtiazsupp@gmail.com'),
                ),
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
              content: Text(
                AppLocalizations.of(context)?.translate('cannotOpenLink') ??
                    'لا يمكن فتح الرابط',
              ),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)?.translate('unexpectedError') ??
                  'حدث خطأ غير متوقع',
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _showPhotoActions() {
    final strings =
        AppLocalizations.of(context) ?? AppLocalizations(const Locale('ar'));
    final p = HomePalette.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: p.background,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ProfileActionRow(
                key: const ValueKey('profile-pick-photo'),
                icon: Icons.photo_library_outlined,
                title: strings.translate('profileEditPhoto'),
                showArrow: false,
                onTap: () {
                  Navigator.pop(context);
                  _pickImage();
                },
              ),
              if (_profileImage != null)
                ProfileActionRow(
                  key: const ValueKey('profile-remove-photo'),
                  icon: Icons.delete_outline_rounded,
                  title: strings.translate('removeImage'),
                  showArrow: false,
                  onTap: () {
                    Navigator.pop(context);
                    _confirmRemoveImage();
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _openSubscription(Map<String, dynamic> sub) {
    final planName = sub['planName'] ?? 'غير محدد';
    final rawPlanId = sub['planId'];
    final String planId = rawPlanId is Map
        ? (rawPlanId['_id'] ?? rawPlanId['id']).toString()
        : rawPlanId.toString();
    if (planName.contains('إضافي') ||
        planName.contains('Additional') ||
        planName.contains('مواقف') ||
        planName.contains('Situational')) {
      Navigator.pushNamed(
        context,
        '/additionalTest',
        arguments: {'testId': planId, 'title': planName},
      );
    } else {
      Navigator.pushNamed(
        context,
        '/examList',
        arguments: {
          'planId': planId,
          'planName': planName,
          'totalQuestions': sub['questionCount'] ?? 0,
        },
      );
    }
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: Text(
          AppLocalizations.of(context)?.translate('confirmLogout') ??
              'هل أنت متأكد من تسجيل الخروج؟',
        ),
        scrollable: true,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              AppLocalizations.of(context)?.translate('cancel') ?? 'إلغاء',
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(context);
              await AuthService.logout();
              final prefs = await SharedPreferences.getInstance();
              await prefs.clear();
              await DatabaseService.logout();
              if (mounted) {
                Navigator.pushNamedAndRemoveUntil(
                  this.context,
                  '/login',
                  (route) => false,
                );
              }
            },
            child: Text(
              AppLocalizations.of(context)?.translate('confirm') ?? 'تأكيد',
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: HomePalette.of(context).background,
    body: ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeService.themeMode,
      builder: (context, themeMode, _) => ValueListenableBuilder<Locale>(
        valueListenable: LocalizationService.locale,
        builder: (context, locale, _) => ProfileContent(
          name: _localName ?? currentUser?.fullName ?? '',
          email: currentUser?.email ?? '',
          photo: _profileImage != null ? FileImage(_profileImage!) : null,
          subscriptions: _activeSubscriptions,
          loadingSubscriptions: _isLoadingSubscriptions,
          themeMode: themeMode,
          language: locale.languageCode,
          onBack: widget.onBack ?? () => Navigator.maybePop(context),
          onEditName: _showEditNameDialog,
          onEditPhoto: _showPhotoActions,
          onStatistics: () => Navigator.pushNamed(context, '/statistics'),
          onBrowsePlans: () => Navigator.pushNamed(context, '/payment'),
          onOpenSubscription: _openSubscription,
          onTheme: _showThemeDialog,
          onLanguage: _showLanguageDialog,
          onSupport: () => _showContactDialog(context),
          onLogout: _confirmLogout,
        ),
      ),
    ),
  );
}
