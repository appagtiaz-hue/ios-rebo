import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../models/payment_plan.dart';
import '../theme/home_palette.dart';

class SubscribedPlansScreen extends StatelessWidget {
  const SubscribedPlansScreen({super.key, required this.subscriptions});
  final List<Map<String, dynamic>> subscriptions;

  @override
  Widget build(BuildContext context) {
    final p = HomePalette.of(context);
    final text = AppLocalizations.of(context)!;
    return Scaffold(
      key: const ValueKey('subscribed-plans-screen'),
      backgroundColor: p.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(8, 12, 20, 12),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: MaterialLocalizations.of(
                          context,
                        ).backButtonTooltip,
                        color: p.ink,
                        icon: const BackButtonIcon(),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          text.translate('homeChooseTrainingPlan'),
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: p.ink,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    itemCount: subscriptions.isEmpty ? 1 : subscriptions.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      if (subscriptions.isEmpty) {
                        return Text(
                          text.translate('examLibraryEmpty'),
                          style: TextStyle(color: p.secondary),
                        );
                      }
                      final sub = subscriptions[index];
                      final plan = sub['planObject'];
                      final name = plan is PaymentPlan
                          ? plan.getName(context)
                          : sub['planName']?.toString() ?? '';
                      return Material(
                        color: p.panel,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(color: p.border),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          key: ValueKey('subscribed-plan-$index'),
                          onTap: () =>
                              Navigator.pop<Map<String, dynamic>>(context, sub),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minHeight: 80),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.menu_book_outlined,
                                    size: 26,
                                    color: p.gold,
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          name,
                                          style: TextStyle(
                                            fontSize: 17,
                                            fontWeight: FontWeight.w700,
                                            color: p.ink,
                                            height: 1.5,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          '${sub['questionCount'] ?? 0} ${text.translate('question')}',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: p.secondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Icon(
                                    Directionality.of(context) ==
                                            TextDirection.rtl
                                        ? Icons.chevron_left_rounded
                                        : Icons.chevron_right_rounded,
                                    color: p.green,
                                    size: 24,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
