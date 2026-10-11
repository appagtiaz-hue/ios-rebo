import 'package:flutter/material.dart';
import '../constants/colors.dart';
import '../l10n/app_localizations.dart';
import '../models/professional_standard.dart';
import 'standards_overview.dart';

class HomeLearningContent extends StatelessWidget {
  const HomeLearningContent({
    super.key,
    required this.premium,
    required this.onShowProgress,
    required this.onStartTrial,
    required this.onExploreStandards,
  });

  final bool premium;
  final VoidCallback onShowProgress;
  final VoidCallback onStartTrial;
  final VoidCallback onExploreStandards;

  @override
  Widget build(BuildContext context) =>
      premium ? _premiumContent(context) : _freeContent(context);

  Widget _freeContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _band(
          context,
          const Color(0xFF008B61),
          Padding(
            padding: const EdgeInsets.all(12),
            child: _responsiveRow(
              context,
              Row(
                children: [
                  const Icon(
                    Icons.assignment_turned_in_outlined,
                    size: 38,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _copy(context, 'homeTrialTitle', 'homeTrialCaption'),
                  ),
                ],
              ),
              _action(context, 'homeTryNow', onStartTrial, 'home-start-trial'),
            ),
          ),
        ),
        const SizedBox(height: 22),
        _heading(context, 'homePracticeUnderstand'),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _feature(
                context,
                title: 'homeExplainShort',
                caption: 'homeExplainCaption',
                color: const Color(0xFF008B61),
                correct: true,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _feature(
                context,
                title: 'homeReviewShort',
                caption: 'homeReviewCaption',
                color: const Color(0xFFD63D65),
                correct: false,
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        _heading(context, 'homeYourResults'),
        const SizedBox(height: 10),
        _band(
          context,
          const Color(0xFF2378E8),
          Padding(
            padding: const EdgeInsets.all(12),
            child: _responsiveRow(
              context,
              Row(
                children: [
                  const Icon(Icons.bar_chart_rounded, size: 42),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _text(context, 'homeTrackLevel'),
                      style: const TextStyle(fontSize: 13, letterSpacing: 0),
                    ),
                  ),
                ],
              ),
              _action(
                context,
                'homeViewResults',
                onShowProgress,
                'home-show-progress',
                outlined: true,
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        _practiceSteps(context),
      ],
    );
  }

  Widget _premiumContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _band(
          context,
          const Color(0xFF008B61),
          Padding(
            padding: const EdgeInsets.all(12),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final intro = Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _copy(context, 'homePlansReady', 'homePlansReadyCaption'),
                    const SizedBox(height: 10),
                    _action(
                      context,
                      'homeExploreStandards',
                      onExploreStandards,
                      'home-explore-standards',
                    ),
                  ],
                );
                final ring = StandardsOverview(onExplore: onExploreStandards);
                if (constraints.maxWidth < 320 ||
                    MediaQuery.textScalerOf(context).scale(14) > 19) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Align(alignment: Alignment.center, child: ring),
                      const SizedBox(height: 12),
                      intro,
                    ],
                  );
                }
                return Row(
                  children: [
                    ring,
                    const SizedBox(width: 12),
                    Expanded(child: intro),
                  ],
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            for (final domain in ProfessionalDomain.values)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: standardDomainColor(domain),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      _text(context, domain.titleKey),
                      style: const TextStyle(fontSize: 10, letterSpacing: 0),
                    ),
                  ),
                ],
              ),
          ],
        ),
        const SizedBox(height: 22),
        _heading(context, 'homeChoosePlan'),
        const SizedBox(height: 10),
        _band(
          context,
          const Color(0xFF2378E8),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Expanded(
                  child: _copy(
                    context,
                    'homeAgtiazPlans',
                    'homeCheckPlanContent',
                  ),
                ),
                const SizedBox(width: 12),
                const SizedBox(
                  width: 90,
                  child: _QuestionPreview(correct: true),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _format(
                context,
                'homeComprehensive',
                'homeComprehensiveCaption',
                Icons.description_outlined,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _format(
                context,
                'homeStandardsInPlan',
                'homeStandardsInPlanCaption',
                Icons.layers_outlined,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.info_outline, size: 16),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                _text(context, 'homeContentDependsOnPlan'),
                style: const TextStyle(fontSize: 12, letterSpacing: 0),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _responsiveRow(BuildContext context, Widget copy, Widget action) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 310 ||
            MediaQuery.textScalerOf(context).scale(14) > 19) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [copy, const SizedBox(height: 10), action],
          );
        }
        return Row(
          children: [
            Expanded(child: copy),
            const SizedBox(width: 10),
            action,
          ],
        );
      },
    );
  }

  Widget _feature(
    BuildContext context, {
    required String title,
    required String caption,
    required Color color,
    required bool correct,
  }) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _copy(context, title, caption, titleColor: color, titleSize: 15),
            const SizedBox(height: 12),
            _QuestionPreview(correct: correct),
          ],
        ),
      ),
    );
  }

  Widget _format(
    BuildContext context,
    String title,
    String caption,
    IconData icon,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 22, color: const Color(0xFF2378E8)),
        const SizedBox(width: 6),
        Expanded(child: _copy(context, title, caption, titleSize: 13)),
      ],
    );
  }

  Widget _practiceSteps(BuildContext context) {
    return Row(
      key: const ValueKey('home-practice-steps'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final step in const [
          ('homeSolve', Icons.edit_outlined, Color(0xFFD49A22)),
          ('homeReview', Icons.description_outlined, Color(0xFFD63D65)),
          ('homeFollow', Icons.bar_chart_rounded, Color(0xFF2378E8)),
        ])
          Expanded(
            child: Column(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: step.$3.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(step.$2, size: 24, color: step.$3),
                ),
                const SizedBox(height: 6),
                Text(
                  _text(context, step.$1),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, letterSpacing: 0),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _action(
    BuildContext context,
    String label,
    VoidCallback callback,
    String key, {
    bool outlined = false,
  }) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Flexible(
          child: Text(_text(context, label), textAlign: TextAlign.center),
        ),
        const SizedBox(width: 4),
        const Icon(Icons.arrow_forward_ios, size: 12),
      ],
    );
    final style = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      textStyle: WidgetStatePropertyAll(
        TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          fontFamily: Theme.of(context).textTheme.bodyMedium?.fontFamily,
          letterSpacing: 0,
        ),
      ),
    );
    if (outlined) {
      return OutlinedButton(
        key: ValueKey(key),
        onPressed: callback,
        style: style.copyWith(
          foregroundColor: WidgetStatePropertyAll(
            dark ? const Color(0xFF81C99F) : AppColors.primary,
          ),
        ),
        child: content,
      );
    }
    return FilledButton(
      key: ValueKey(key),
      onPressed: callback,
      style: style.copyWith(
        backgroundColor: const WidgetStatePropertyAll(AppColors.primary),
        foregroundColor: const WidgetStatePropertyAll(Colors.white),
      ),
      child: content,
    );
  }

  Widget _band(BuildContext context, Color accent, Widget child) => ColoredBox(
    color: accent.withValues(
      alpha: Theme.of(context).brightness == Brightness.dark ? 0.12 : 0.05,
    ),
    child: child,
  );

  Widget _heading(BuildContext context, String key) => Text(
    _text(context, key),
    style: const TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w700,
      letterSpacing: 0,
    ),
  );

  Widget _copy(
    BuildContext context,
    String title,
    String caption, {
    Color? titleColor,
    double titleSize = 17,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        _text(context, title),
        style: TextStyle(
          fontSize: titleSize,
          height: 1.4,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
          color: titleColor == null
              ? null
              : Theme.of(context).brightness == Brightness.dark
              ? Color.lerp(titleColor, Colors.white, 0.35)
              : titleColor,
        ),
      ),
      const SizedBox(height: 4),
      Text(
        _text(context, caption),
        style: TextStyle(
          fontSize: 12,
          height: 1.6,
          letterSpacing: 0,
          color: Theme.of(context).textTheme.bodyMedium?.color,
        ),
      ),
    ],
  );

  String _text(BuildContext context, String key) =>
      AppLocalizations.of(context)!.translate(key);
}

class HomePlanBrowseAction extends StatelessWidget {
  const HomePlanBrowseAction({super.key, required this.onBrowsePlans});
  final VoidCallback onBrowsePlans;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context)!;
    const gold = Color(0xFFE8B83F);
    return LayoutBuilder(
      builder: (context, constraints) {
        final accentWidth = constraints.maxWidth >= 360 ? 48.0 : 28.0;
        Widget accent({required bool reversed}) {
          final parts = <Widget>[
            Expanded(
              child: Container(height: 1, color: gold.withValues(alpha: 0.5)),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.auto_awesome, size: 16, color: gold),
          ];
          return ExcludeSemantics(
            child: SizedBox(
              width: accentWidth,
              child: Row(
                textDirection: TextDirection.ltr,
                children: reversed ? parts.reversed.toList() : parts,
              ),
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            key: const ValueKey('home-browse-plans-row'),
            mainAxisAlignment: MainAxisAlignment.center,
            textDirection: TextDirection.ltr,
            children: [
              accent(reversed: false),
              const SizedBox(width: 8),
              Flexible(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 240),
                  child: FilledButton.icon(
                    key: const ValueKey('home-browse-plans'),
                    onPressed: onBrowsePlans,
                    icon: const Icon(Icons.layers_outlined, size: 18),
                    label: Text(
                      text.translate('homeBrowsePlans'),
                      textAlign: TextAlign.center,
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(168, 52),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      elevation: 4,
                      shadowColor: AppColors.primary.withValues(alpha: 0.35),
                      side: BorderSide(color: gold.withValues(alpha: 0.75)),
                      textStyle: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        fontFamily: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.fontFamily,
                        letterSpacing: 0,
                      ),
                      shape: const StadiumBorder(),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              accent(reversed: true),
            ],
          ),
        );
      },
    );
  }
}

class _QuestionPreview extends StatelessWidget {
  const _QuestionPreview({required this.correct});
  final bool correct;

  @override
  Widget build(BuildContext context) {
    final color = correct ? const Color(0xFF008B61) : const Color(0xFFD63D65);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return ExcludeSemantics(
      child: Column(
        children: [
          for (var i = 0; i < 3; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: i == 1
                      ? color.withValues(alpha: 0.12)
                      : Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 7,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        i == 1
                            ? correct
                                  ? Icons.check_circle
                                  : Icons.cancel
                            : Icons.radio_button_unchecked,
                        size: 14,
                        color: i == 1 ? color : Colors.grey,
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Container(
                          height: 4,
                          color: i == 1
                              ? color.withValues(alpha: 0.3)
                              : dark
                              ? Colors.white24
                              : const Color(0xFFE2E6EC),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
