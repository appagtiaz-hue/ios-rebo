import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../models/professional_standard.dart';

Color standardDomainColor(ProfessionalDomain domain, {bool dark = false}) {
  return switch (domain) {
    ProfessionalDomain.ethics =>
      dark ? const Color(0xFF64CFA0) : const Color(0xFF008B61),
    ProfessionalDomain.knowledge =>
      dark ? const Color(0xFF85B9FF) : const Color(0xFF2378E8),
    ProfessionalDomain.practice =>
      dark ? const Color(0xFFF1C462) : const Color(0xFFD49A22),
  };
}

class StandardsOverview extends StatelessWidget {
  const StandardsOverview({super.key, required this.onExplore});
  final VoidCallback onExplore;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context)!;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Semantics(
      button: true,
      label: text.translate('homeExploreStandards'),
      child: Tooltip(
        message: text.translate('homeExploreStandards'),
        child: InkWell(
          onTap: onExplore,
          customBorder: const CircleBorder(),
          child: ExcludeSemantics(
            child: SizedBox.square(
              dimension: 136,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  PieChart(
                    PieChartData(
                      startDegreeOffset: -90,
                      centerSpaceRadius: 30,
                      sectionsSpace: 2,
                      borderData: FlBorderData(show: false),
                      pieTouchData: PieTouchData(enabled: false),
                      sections: [
                        // Equal slices identify standards, not weights or scores.
                        for (final standard in professionalStandards)
                          PieChartSectionData(
                            value: 1,
                            radius: 36,
                            showTitle: false,
                            color: standardDomainColor(
                              standard.domain,
                              dark: dark,
                            ),
                          ),
                      ],
                    ),
                    duration: Duration.zero,
                  ),
                  SizedBox(
                    width: 54,
                    child: Text(
                      text.translate('standardsTitle'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0,
                      ),
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
