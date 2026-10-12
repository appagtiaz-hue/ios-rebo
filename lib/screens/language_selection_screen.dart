import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/localization_service.dart';
import '../theme/home_palette.dart';
import '../widgets/agtiaz_brand_logo.dart';

class LanguageSelectionScreen extends StatefulWidget {
  const LanguageSelectionScreen({super.key});
  @override
  State<LanguageSelectionScreen> createState() =>
      _LanguageSelectionScreenState();
}

class _LanguageSelectionScreenState extends State<LanguageSelectionScreen> {
  String? _selecting;

  Future<void> _selectLanguage(String code) async {
    if (_selecting != null) return;
    setState(() => _selecting = code);
    try {
      await LocalizationService.setLocale(Locale(code));
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('has_selected_language', true);
      if (mounted) {
        Navigator.pushReplacementNamed(
          context,
          code == 'ar' ? '/splashAr' : '/splashEn',
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'تعذّر حفظ اللغة. حاول مرة أخرى.\nCould not save your language. Try again.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _selecting = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = HomePalette.of(context);
    return Scaffold(
      backgroundColor: p.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: (constraints.maxHeight - 48).clamp(
                  0,
                  double.infinity,
                ),
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Center(child: AgtiazBrandLogo()),
                      const SizedBox(height: 28),
                      Text(
                        'اختر لغتك',
                        textAlign: TextAlign.center,
                        textDirection: TextDirection.rtl,
                        style: TextStyle(
                          color: p.ink,
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Choose your language',
                        textAlign: TextAlign.center,
                        textDirection: TextDirection.ltr,
                        style: TextStyle(color: p.secondary, fontSize: 15),
                      ),
                      const SizedBox(height: 32),
                      DecoratedBox(
                        key: const ValueKey('language-options-panel'),
                        decoration: BoxDecoration(
                          color: p.panel,
                          border: Border.all(color: p.border),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: [
                            _option(
                              context,
                              code: 'ar',
                              title: 'العربية',
                              subtitle: 'Arabic',
                              glyph: 'ع',
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                              ),
                              child: Divider(height: 1, color: p.border),
                            ),
                            _option(
                              context,
                              code: 'en',
                              title: 'English',
                              subtitle: 'الإنجليزية',
                              glyph: 'A',
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
        ),
      ),
    );
  }

  Widget _option(
    BuildContext context, {
    required String code,
    required String title,
    required String subtitle,
    required String glyph,
  }) {
    final p = HomePalette.of(context);
    final accent = code == 'ar' ? p.green : p.gold;
    return Directionality(
      textDirection: code == 'ar' ? TextDirection.rtl : TextDirection.ltr,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: ValueKey('language-option-$code'),
          borderRadius: BorderRadius.circular(8),
          onTap: _selecting != null ? null : () => _selectLanguage(code),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 92),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              child: Row(
                children: [
                  SizedBox(
                    width: 44,
                    height: 44,
                    child: Center(
                      child: Text(
                        glyph,
                        style: TextStyle(
                          color: accent,
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            color: p.ink,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: TextStyle(color: p.secondary, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  if (_selecting == code)
                    SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: accent,
                      ),
                    )
                  else
                    Icon(
                      code == 'ar'
                          ? Icons.chevron_left_rounded
                          : Icons.chevron_right_rounded,
                      color: accent,
                      size: 22,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
