import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../models/home_practice_state.dart';
import '../models/professional_standard.dart';
import '../theme/home_palette.dart';

class HomeLearningContent extends StatelessWidget {
  const HomeLearningContent({
    super.key,
    required this.premium,
    required this.onShowProgress,
    required this.onStartTrial,
    required this.onExploreStandards,
    required this.onOpenDomain,
    required this.onBrowsePlans,
    required this.onSelectPremium,
    required this.onContinuePractice,
    this.practiceMode = HomePracticeMode.browsePlans,
    this.planName,
  });
  final bool premium;
  final VoidCallback onShowProgress;
  final VoidCallback onStartTrial;
  final VoidCallback onExploreStandards;
  final ValueChanged<ProfessionalDomain> onOpenDomain;
  final VoidCallback onBrowsePlans;
  final VoidCallback onSelectPremium;
  final VoidCallback onContinuePractice;
  final HomePracticeMode practiceMode;
  final String? planName;

  String _text(BuildContext context, String key) =>
      AppLocalizations.of(context)!.translate(key);

  @override
  Widget build(BuildContext context) =>
      premium ? _premium(context) : _free(context);

  Widget _free(BuildContext context) {
    final colors = HomePalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _panel(
          context,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.assignment_outlined,
                    size: 36,
                    color: colors.green,
                  ),
                  const Spacer(),
                  const ExcludeSemantics(
                    child: SizedBox(
                      width: 112,
                      height: 68,
                      child: _AnswerSheet(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _title(context, 'homeFreeHeading'),
              const SizedBox(height: 8),
              _body(context, _text(context, 'homeFreeDescription')),
              const SizedBox(height: 20),
              _primary(
                context,
                'homeStartTest',
                onStartTrial,
                'home-start-trial',
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _heading(context, 'homePracticeUnderstand'),
        const SizedBox(height: 12),
        _feature(
          context,
          Icons.menu_book_outlined,
          'homeExplanationTitle',
          'homeExplanationDescription',
          colors.green,
        ),
        _feature(
          context,
          Icons.adjust,
          'homeMistakesTitle',
          'homeMistakesDescription',
          colors.gold,
        ),
        const SizedBox(height: 12),
        Divider(height: 1, color: colors.border),
        _rowAction(
          context,
          'homeResultsTitle',
          onShowProgress,
          'home-show-progress',
          icon: Icons.bar_chart_rounded,
          subtitle: 'homeResultsDescription',
        ),
        const SizedBox(height: 8),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: _link(
            context,
            'homeExplorePremium',
            onSelectPremium,
            'home-select-premium',
            gold: true,
          ),
        ),
      ],
    );
  }

  Widget _premium(BuildContext context) {
    final colors = HomePalette.of(context);
    final continuing = practiceMode == HomePracticeMode.continuePlan;
    final choosing = practiceMode == HomePracticeMode.choosePlan;
    final loading = practiceMode == HomePracticeMode.loading;
    final primaryLabel = switch (practiceMode) {
      HomePracticeMode.loading => 'homePlansLoading',
      HomePracticeMode.browsePlans => 'homeBrowsePlans',
      HomePracticeMode.continuePlan => 'homeContinueTraining',
      HomePracticeMode.choosePlan => 'homeChooseTrainingPlan',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _panel(
          context,
          premium: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.goldSoft,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    child: Text(
                      _text(context, 'premium'),
                      style: TextStyle(
                        color: colors.gold,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _title(
                context,
                continuing
                    ? 'homeContinueHeading'
                    : choosing
                    ? 'homeChooseTrainingHeading'
                    : 'homePremiumHeading',
              ),
              const SizedBox(height: 8),
              _body(
                context,
                continuing
                    ? _text(
                        context,
                        'homeCurrentPlan',
                      ).replaceAll('{plan}', planName ?? '')
                    : _text(context, 'homePremiumDescription'),
              ),
              const SizedBox(height: 18),
              _included(context, 'homeFullPractice'),
              const SizedBox(height: 10),
              _included(context, 'homePracticeByStandard'),
              const SizedBox(height: 20),
              _primary(
                context,
                primaryLabel,
                loading
                    ? null
                    : practiceMode == HomePracticeMode.browsePlans
                    ? onBrowsePlans
                    : onContinuePractice,
                practiceMode == HomePracticeMode.browsePlans
                    ? 'home-browse-plans'
                    : 'home-continue-training',
              ),
              if (practiceMode != HomePracticeMode.browsePlans) ...[
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.center,
                  child: _link(
                    context,
                    'homeBrowsePlans',
                    onBrowsePlans,
                    'home-browse-plans',
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 24),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          children: [
            _heading(context, 'homeThreeDomains'),
            _link(
              context,
              'homeShowStandards',
              onExploreStandards,
              'home-explore-standards',
              gold: true,
            ),
          ],
        ),
        for (final domain in ProfessionalDomain.values) ...[
          _rowAction(
            context,
            domain.titleKey,
            () => onOpenDomain(domain),
            'home-domain-${domain.name}',
            domainNumber: domain.index + 1,
          ),
          if (domain != ProfessionalDomain.values.last)
            Divider(height: 1, color: colors.border),
        ],
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline, size: 16, color: colors.secondary),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                _text(context, 'homePlanContentNote'),
                style: TextStyle(
                  color: colors.secondary,
                  fontSize: 12,
                  height: 1.6,
                  letterSpacing: 0,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _panel(
    BuildContext context, {
    required Widget child,
    bool premium = false,
  }) {
    final colors = HomePalette.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: premium ? colors.background : colors.panel,
        borderRadius: BorderRadius.circular(12),
        border: premium ? Border.all(color: colors.goldBorder) : null,
      ),
      child: Padding(padding: const EdgeInsets.all(20), child: child),
    );
  }

  Widget _title(BuildContext context, String key) => Text(
    _text(context, key),
    style: TextStyle(
      fontSize: 22,
      height: 1.4,
      letterSpacing: 0,
      fontWeight: FontWeight.w700,
      color: HomePalette.of(context).ink,
    ),
  );
  Widget _heading(BuildContext context, String key) => Text(
    _text(context, key),
    style: TextStyle(
      fontSize: 18,
      height: 1.4,
      letterSpacing: 0,
      fontWeight: FontWeight.w700,
      color: HomePalette.of(context).ink,
    ),
  );
  Widget _body(BuildContext context, String value) => Text(
    value,
    style: TextStyle(
      fontSize: 14,
      height: 1.6,
      letterSpacing: 0,
      color: HomePalette.of(context).secondary,
    ),
  );

  Widget _feature(
    BuildContext context,
    IconData icon,
    String title,
    String caption,
    Color color,
  ) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 29, color: color),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _text(context, title),
                style: TextStyle(
                  fontSize: 15,
                  height: 1.5,
                  color: HomePalette.of(context).ink,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 2),
              _body(context, _text(context, caption)),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _included(BuildContext context, String key) {
    final colors = HomePalette.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: colors.goldSoft,
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.check, size: 18, color: colors.ink),
        ),
        const SizedBox(width: 12),
        Expanded(child: _body(context, _text(context, key))),
      ],
    );
  }

  Widget _primary(
    BuildContext context,
    String label,
    VoidCallback? callback,
    String key,
  ) {
    final colors = HomePalette.of(context);
    return FilledButton(
      key: ValueKey(key),
      onPressed: callback,
      style: FilledButton.styleFrom(
        backgroundColor: colors.button,
        foregroundColor: colors.buttonInk,
        disabledBackgroundColor: colors.greenSoft,
        disabledForegroundColor: colors.secondary,
        minimumSize: const Size(48, 52),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        elevation: 0,
        textStyle: TextStyle(
          fontSize: 14,
          letterSpacing: 0,
          fontWeight: FontWeight.w700,
          fontFamily: Theme.of(context).textTheme.bodyMedium?.fontFamily,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: Text(_text(context, label), textAlign: TextAlign.center),
          ),
          if (callback != null) ...[
            const SizedBox(width: 10),
            const Icon(Icons.arrow_forward, size: 20),
          ],
        ],
      ),
    );
  }

  Widget _link(
    BuildContext context,
    String label,
    VoidCallback callback,
    String key, {
    bool gold = false,
  }) => TextButton(
    key: ValueKey(key),
    onPressed: callback,
    style: TextButton.styleFrom(
      foregroundColor: gold
          ? HomePalette.of(context).gold
          : HomePalette.of(context).green,
      minimumSize: const Size(48, 48),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
      textStyle: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
        fontFamily: Theme.of(context).textTheme.bodyMedium?.fontFamily,
      ),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(child: Text(_text(context, label))),
        const SizedBox(width: 8),
        const Icon(Icons.arrow_forward, size: 18),
      ],
    ),
  );

  Widget _rowAction(
    BuildContext context,
    String label,
    VoidCallback callback,
    String key, {
    IconData? icon,
    String? subtitle,
    int? domainNumber,
  }) {
    final colors = HomePalette.of(context);
    return TextButton(
      key: ValueKey(key),
      onPressed: callback,
      style: TextButton.styleFrom(
        foregroundColor: colors.ink,
        minimumSize: const Size(48, 64),
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Row(
        children: [
          if (icon != null) Icon(icon, size: 28, color: colors.green),
          if (domainNumber != null)
            ExcludeSemantics(
              child: Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: domainNumber == 3 ? colors.goldSoft : colors.greenSoft,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  Localizations.localeOf(context).languageCode == 'ar'
                      ? const ['١', '٢', '٣'][domainNumber - 1]
                      : '$domainNumber',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: colors.ink,
                    letterSpacing: 0,
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
                  _text(context, label),
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0,
                    color: colors.ink,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 3),
                  _body(context, _text(context, subtitle)),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right, size: 20),
        ],
      ),
    );
  }
}

class _AnswerSheet extends StatelessWidget {
  const _AnswerSheet();
  @override
  Widget build(BuildContext context) {
    final colors = HomePalette.of(context);
    return Transform.rotate(
      angle: Directionality.of(context) == TextDirection.rtl ? -.12 : .12,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: colors.green.withValues(alpha: .3)),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(
              3,
              (row) => Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(
                  3,
                  (column) => Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: row == 1 && column == 1 ? colors.green : null,
                      border: Border.all(
                        color: colors.green.withValues(alpha: .5),
                      ),
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
}
