import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../l10n/app_localizations.dart';
import '../models/payment_plan.dart';
import '../theme/home_palette.dart';

class PlanCatalogContent extends StatelessWidget {
  const PlanCatalogContent({
    super.key,
    required this.plans,
    required this.selectedPlan,
    required this.isOwned,
    required this.onSelect,
    required this.onProceed,
    required this.onRetry,
    this.isLoading = false,
    this.hasError = false,
    this.isNavigating = false,
  });

  final List<PaymentPlan> plans;
  final PaymentPlan? selectedPlan;
  final bool Function(String) isOwned;
  final ValueChanged<PaymentPlan> onSelect;
  final VoidCallback onProceed;
  final VoidCallback onRetry;
  final bool isLoading;
  final bool hasError;
  final bool isNavigating;

  @override
  Widget build(BuildContext context) {
    final p = HomePalette.of(context);
    final text = AppLocalizations.of(context)!;
    return SafeArea(
      top: false,
      child: Column(
        children: [
          Expanded(
            child: isLoading
                ? Center(
                    child: Semantics(
                      label: text.translate('catalogLoading'),
                      child: CircularProgressIndicator(color: p.green),
                    ),
                  )
                : hasError
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            text.translate('catalogError'),
                            textAlign: TextAlign.center,
                            style: TextStyle(color: p.secondary),
                          ),
                          const SizedBox(height: 12),
                          TextButton.icon(
                            key: const ValueKey('catalog-retry'),
                            onPressed: onRetry,
                            icon: const Icon(Icons.refresh),
                            label: Text(text.translate('statsRetry')),
                            style: TextButton.styleFrom(
                              foregroundColor: p.green,
                              minimumSize: const Size(48, 48),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView(
                    key: const PageStorageKey('plan-catalog-scroll'),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    children: [
                      Text(
                        text.translate('catalogSubtitle'),
                        style: TextStyle(fontSize: 15, color: p.secondary),
                      ),
                      const SizedBox(height: 20),
                      if (plans.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 32),
                          child: Text(
                            text.translate('catalogEmpty'),
                            textAlign: TextAlign.center,
                            style: TextStyle(color: p.secondary),
                          ),
                        ),
                      for (final plan in plans) ...[
                        _PlanCard(
                          plan: plan,
                          selected: selectedPlan?.id == plan.id,
                          owned: isOwned(plan.id),
                          onTap: () => onSelect(plan),
                        ),
                        const SizedBox(height: 12),
                      ],
                      Text(
                        text.translate('homePlanContentNote'),
                        style: TextStyle(fontSize: 12, color: p.secondary),
                      ),
                    ],
                  ),
          ),
          if (!isLoading && !hasError && plans.isNotEmpty) _actionBar(context),
        ],
      ),
    );
  }

  Widget _actionBar(BuildContext context) {
    final p = HomePalette.of(context);
    final text = AppLocalizations.of(context)!;
    final plan = selectedPlan;
    final owned = plan != null && isOwned(plan.id);
    final label = plan == null
        ? 'catalogSelect'
        : owned
        ? 'catalogOpen'
        : plan.price == 0
        ? 'catalogFree'
        : 'catalogCheckout';
    return Container(
      key: const ValueKey('catalog-action-bar'),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: p.background,
        border: Border(top: BorderSide(color: p.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (plan != null) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    plan.getName(context),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: p.ink,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    _price(context, plan),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: p.ink,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
          FilledButton(
            key: const ValueKey('catalog-proceed'),
            onPressed: plan == null || isNavigating ? null : onProceed,
            style: FilledButton.styleFrom(
              backgroundColor: p.button,
              foregroundColor: p.buttonInk,
              disabledBackgroundColor: p.border,
              disabledForegroundColor: p.secondary,
              minimumSize: const Size(double.infinity, 52),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    text.translate(isNavigating ? 'catalogOpening' : label),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (plan != null) ...[
                  const SizedBox(width: 12),
                  const Icon(Icons.arrow_forward, size: 22),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _price(BuildContext context, PaymentPlan plan) {
  final text = AppLocalizations.of(context)!;
  if (plan.price == 0) return text.translate('free');
  final locale = Localizations.localeOf(context).languageCode;
  final value = NumberFormat('#,##0.##', locale).format(plan.price);
  final currency = ['ر.س', 'SAR', 'ريال سعودي'].contains(plan.currency)
      ? text.translate('currency')
      : plan.currency;
  return '$value $currency';
}

// Keep the dashboard hue, lifting contrast only when the theme requires it.
Color _legible(Color color, Color surface, Color ink) {
  var result = Color.alphaBlend(color, surface);
  double contrast(Color a, Color b) {
    final x = a.computeLuminance();
    final y = b.computeLuminance();
    return ((x > y ? x : y) + .05) / ((x < y ? x : y) + .05);
  }

  for (var step = 0; step < 10 && contrast(result, surface) < 4.5; step++) {
    result = Color.lerp(result, ink, .18)!;
  }
  return result;
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.selected,
    required this.owned,
    required this.onTap,
  });
  final PaymentPlan plan;
  final bool selected;
  final bool owned;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = HomePalette.of(context);
    final text = AppLocalizations.of(context)!;
    final raw = plan.getPrimaryColor();
    final fill = Color.alphaBlend(
      raw.withValues(alpha: selected ? .09 : .025),
      p.panel,
    );
    final accent = _legible(raw, fill, p.ink);
    final secondary = _legible(plan.getSecondaryColor(), fill, p.ink);
    final name = plan.getName(context);
    final description = plan.getDescription(context).trim();
    final lower = (plan.name + plan.nameEn).toLowerCase();
    final icon = plan.price == 0
        ? Icons.assignment_outlined
        : lower.contains('gold') || lower.contains('ذهبي')
        ? Icons.auto_awesome_outlined
        : Icons.star_outline_rounded;
    final radius = BorderRadius.circular(8);
    return Semantics(
      key: ValueKey('catalog-plan-${plan.id}'),
      selected: selected,
      inMutuallyExclusiveGroup: true,
      button: true,
      child: Material(
        color: fill,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(
            color: selected
                ? accent
                : Color.alphaBlend(raw.withValues(alpha: .12), p.border),
            width: 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final compact =
                        constraints.maxWidth < 290 ||
                        MediaQuery.textScalerOf(context).scale(16) > 22;
                    final heading = Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Color.alphaBlend(
                              raw.withValues(alpha: .08),
                              fill,
                            ),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: secondary.withValues(alpha: .5),
                            ),
                          ),
                          child: Icon(icon, color: accent, size: 26),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            name,
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: p.ink,
                            ),
                          ),
                        ),
                      ],
                    );
                    final price = Text(
                      _price(context, plan),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: accent,
                      ),
                    );
                    final radio = Padding(
                      padding: const EdgeInsetsDirectional.only(start: 8),
                      child: Icon(
                        selected
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        color: selected ? accent : p.secondary,
                        size: 24,
                      ),
                    );
                    if (compact) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          heading,
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(child: price),
                              radio,
                            ],
                          ),
                        ],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(flex: 3, child: heading),
                        const SizedBox(width: 12),
                        Flexible(flex: 2, child: price),
                        radio,
                      ],
                    );
                  },
                ),
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.55,
                      color: p.secondary,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Divider(height: 1, color: p.border),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.quiz_outlined, color: p.secondary, size: 18),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            '${NumberFormat.decimalPattern(Localizations.localeOf(context).languageCode).format(plan.questionCount)} ${text.translate('question')}',
                            style: TextStyle(fontSize: 13, color: p.secondary),
                          ),
                        ),
                      ],
                    ),
                    if (owned)
                      Text(
                        text.translate('catalogOwned'),
                        style: TextStyle(
                          color: accent,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
