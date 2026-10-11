import 'package:flutter/material.dart';
import '../constants/colors.dart';
import '../l10n/app_localizations.dart';
import '../models/payment_plan.dart';

class TestLibraryScreen extends StatelessWidget {
  const TestLibraryScreen({
    super.key,
    required this.subscriptions,
    required this.loading,
    required this.onStartTrial,
    required this.onOpenSubscription,
    required this.onBrowsePlans,
  });

  final List<Map<String, dynamic>> subscriptions;
  final bool loading;
  final VoidCallback onStartTrial;
  final ValueChanged<Map<String, dynamic>> onOpenSubscription;
  final VoidCallback onBrowsePlans;

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(text.translate('navExams')),
        automaticallyImplyLeading: false,
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            key: const ValueKey('library-trial'),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 6,
            ),
            leading: const Icon(
              Icons.assignment_outlined,
              color: AppColors.primary,
            ),
            title: Text(
              text.translate('homeTrialTitle'),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              text.translate('homeTrialCaption'),
              style: const TextStyle(fontSize: 13),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: onStartTrial,
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Text(
              text.translate('myActiveSubscriptions'),
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
          ),
          if (loading)
            Semantics(
              label: text.translate('examLibraryLoading'),
              child: const Center(child: CircularProgressIndicator()),
            )
          else if (subscriptions.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Text(
                text.translate('examLibraryEmpty'),
                style: theme.textTheme.bodyMedium,
              ),
            )
          else
            for (final subscription in subscriptions) ...[
              ListTile(
                key: ValueKey('library-plan-${subscription['planId']}'),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 6,
                ),
                leading: const Icon(Icons.menu_book_outlined),
                title: Text(
                  (subscription['planObject'] as PaymentPlan?)?.getName(
                        context,
                      ) ??
                      subscription['planName']?.toString() ??
                      '',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  '${subscription['questionCount'] ?? 0} ${text.translate('question')}',
                  style: const TextStyle(fontSize: 13),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => onOpenSubscription(subscription),
              ),
              const Divider(height: 1),
            ],
          const SizedBox(height: 24),
          OutlinedButton.icon(
            key: const ValueKey('library-browse-plans'),
            onPressed: onBrowsePlans,
            icon: const Icon(Icons.layers_outlined, size: 18),
            label: Text(text.translate('homeBrowsePlans')),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(48, 48),
              textStyle: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
