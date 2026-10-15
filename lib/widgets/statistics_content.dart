import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../theme/home_palette.dart';

class StatisticsContent extends StatelessWidget {
  const StatisticsContent({
    super.key,
    required this.completedTests,
    required this.totalPoints,
    required this.level,
    required this.progress,
  });

  final int completedTests;
  final int totalPoints;
  final int level;
  final int progress;

  @override
  Widget build(BuildContext context) {
    final p = HomePalette.of(context);
    final text = AppLocalizations.of(context)!;
    final points = totalPoints % 200;
    final remaining = 200 - points;
    final safeProgress = progress.clamp(0, 100);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          text.translate('statsRecordedSummary'),
          style: TextStyle(color: p.secondary, fontSize: 14),
        ),
        const SizedBox(height: 20),
        LayoutBuilder(
          builder: (context, constraints) {
            final stacked =
                constraints.maxWidth < 340 &&
                MediaQuery.textScalerOf(context).scale(14) > 20;
            final cards = [
              _metric(
                context,
                icon: Icons.assignment_outlined,
                label: text.translate('statsCompletedLabel'),
                value: completedTests,
                valueKey: 'stats-tests',
                accent: p.green,
              ),
              _metric(
                context,
                icon: Icons.star_outline_rounded,
                label: text.translate('totalPoints'),
                value: totalPoints,
                valueKey: 'stats-points',
                accent: p.gold,
              ),
            ];
            if (stacked) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [cards[0], const SizedBox(height: 12), cards[1]],
              );
            }
            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: cards[0]),
                  const SizedBox(width: 12),
                  Expanded(child: cards[1]),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 28),
        Text(
          text.translate('statsYourLevel'),
          style: TextStyle(
            color: p.ink,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 20),
        Center(
          child: Semantics(
            label: '${text.translate('level')} $level',
            value: '$safeProgress% ${text.translate('progressToNextLevel')}',
            child: ExcludeSemantics(
              child: SizedBox(
                key: const ValueKey('stats-level-ring'),
                width: 164,
                height: 164,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned.fill(
                      child: CircularProgressIndicator(
                        value: safeProgress / 100,
                        strokeWidth: 10,
                        strokeCap: StrokeCap.round,
                        color: p.green,
                        backgroundColor: p.border,
                      ),
                    ),
                    if (safeProgress > 0)
                      Positioned.fill(
                        child: Transform.rotate(
                          angle: safeProgress / 100 * 2 * math.pi,
                          child: Align(
                            alignment: Alignment.topCenter,
                            child: SizedBox(
                              width: 10,
                              height: 10,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: p.goldBorder,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              text.translate('level'),
                              style: TextStyle(
                                color: p.secondary,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$level',
                              key: const ValueKey('stats-level'),
                              style: TextStyle(
                                color: p.ink,
                                fontSize: 40,
                                fontWeight: FontWeight.w700,
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
        const SizedBox(height: 20),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 4,
          children: [
            Text(
              text.translate('progressToNextLevel'),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: p.ink,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              '$safeProgress%',
              key: const ValueKey('stats-progress'),
              textDirection: TextDirection.ltr,
              style: TextStyle(
                color: p.green,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Semantics(
          label: text
              .translate('statsProgressDescription')
              .replaceAll('{points}', '$points'),
          child: ExcludeSemantics(
            child: Wrap(
              key: const ValueKey('stats-points-progress'),
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              textDirection: TextDirection.ltr,
              spacing: 6,
              children: [
                Text(
                  '$points / 200',
                  textDirection: TextDirection.ltr,
                  style: TextStyle(color: p.secondary, fontSize: 13),
                ),
                Text(
                  text.translate('statsPointsUnit'),
                  style: TextStyle(color: p.secondary, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Divider(height: 1, color: p.border),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.track_changes_rounded, color: p.green, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      text
                          .translate('statsRemaining')
                          .replaceAll('{points}', '$remaining')
                          .replaceAll('{level}', '${level + 1}'),
                      key: const ValueKey('stats-remaining'),
                      style: TextStyle(
                        color: p.ink,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      text.translate('statsLevelRule'),
                      style: TextStyle(
                        color: p.secondary,
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Divider(height: 1, color: p.border),
        const SizedBox(height: 12),
        Text(
          text.translate('statsRecordedNote'),
          style: TextStyle(color: p.secondary, fontSize: 12, height: 1.5),
        ),
      ],
    );
  }

  Widget _metric(
    BuildContext context, {
    required IconData icon,
    required String label,
    required int value,
    required String valueKey,
    required Color accent,
  }) {
    final p = HomePalette.of(context);
    return MergeSemantics(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: p.panel,
          border: Border.all(color: p.border),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            ExcludeSemantics(child: Icon(icon, color: accent, size: 26)),
            const SizedBox(height: 10),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '$value',
                  key: ValueKey(valueKey),
                  textDirection: TextDirection.ltr,
                  style: TextStyle(
                    color: accent,
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(color: p.secondary, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
