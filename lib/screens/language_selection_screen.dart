import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../l10n/app_localizations.dart';
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
  late String _selected;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _selected = LocalizationService.locale.value.languageCode == 'en'
        ? 'en'
        : 'ar';
  }

  String _text(String language, String key) =>
      AppLocalizations(Locale(language)).translate(key);

  Future<void> _continue() async {
    if (_submitting) return;
    final code = _selected;
    setState(() => _submitting = true);
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
          SnackBar(content: Text(_text(code, 'languageSaveError'))),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
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
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Directionality(
                    textDirection: TextDirection.rtl,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: Semantics(
                            label: 'اجتياز Agtiaz',
                            image: true,
                            child: const AgtiazBrandLogo(size: 88),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          _text('ar', 'languageWelcome'),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: p.ink,
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _text('en', 'languageWelcome'),
                          textAlign: TextAlign.center,
                          textDirection: TextDirection.ltr,
                          style: TextStyle(color: p.secondary, fontSize: 14),
                        ),
                        const SizedBox(height: 36),
                        Text(
                          _text('ar', 'languageChoose'),
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            color: p.ink,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _text('en', 'languageChoose'),
                          textAlign: TextAlign.right,
                          textDirection: TextDirection.ltr,
                          style: TextStyle(color: p.secondary, fontSize: 13),
                        ),
                        const SizedBox(height: 20),
                        _option(
                          context,
                          code: 'ar',
                          title: 'العربية',
                          subtitle: 'Arabic',
                          glyph: 'ع',
                        ),
                        const SizedBox(height: 12),
                        _option(
                          context,
                          code: 'en',
                          title: 'English',
                          subtitle: 'الإنجليزية',
                          glyph: 'A',
                        ),
                        const SizedBox(height: 28),
                        Directionality(
                          textDirection: _selected == 'ar'
                              ? TextDirection.rtl
                              : TextDirection.ltr,
                          child: FilledButton(
                            key: const ValueKey('language-continue'),
                            onPressed: _submitting ? null : _continue,
                            style: FilledButton.styleFrom(
                              backgroundColor: p.button,
                              foregroundColor: p.buttonInk,
                              disabledBackgroundColor: p.greenSoft,
                              disabledForegroundColor: p.ink,
                              minimumSize: const Size.fromHeight(52),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 14,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Flexible(
                                  child: Text(
                                    _text(_selected, 'continue'),
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: _submitting
                                      ? CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: p.ink,
                                        )
                                      : Icon(
                                          textDirection: TextDirection.ltr,
                                          _selected == 'ar'
                                              ? Icons.arrow_back
                                              : Icons.arrow_forward,
                                          size: 22,
                                        ),
                                ),
                              ],
                            ),
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
    final selected = code == _selected;
    final accent = code == 'ar' ? p.green : p.gold;
    return Semantics(
      checked: selected,
      inMutuallyExclusiveGroup: true,
      child: Material(
        color: selected ? p.greenSoft : p.panel,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: selected ? p.green : p.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: ValueKey('language-option-$code'),
          onTap: _submitting ? null : () => setState(() => _selected = code),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 76),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  SizedBox(
                    width: 40,
                    child: ExcludeSemantics(
                      child: Text(
                        glyph,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: accent,
                          fontSize: 27,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          textDirection: code == 'ar'
                              ? TextDirection.rtl
                              : TextDirection.ltr,
                          style: TextStyle(
                            color: p.ink,
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          textDirection: code == 'ar'
                              ? TextDirection.ltr
                              : TextDirection.rtl,
                          style: TextStyle(color: p.secondary, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  ExcludeSemantics(
                    child: Icon(
                      selected
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                      color: selected ? p.green : p.secondary,
                      size: 24,
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
}
