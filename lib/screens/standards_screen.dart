import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../models/professional_standard.dart';
import '../widgets/standards_overview.dart';

class StandardsScreen extends StatefulWidget {
  const StandardsScreen({super.key});

  @override
  State<StandardsScreen> createState() => _StandardsScreenState();
}

class _StandardsScreenState extends State<StandardsScreen> {
  String? _expandedId;
  final _rowKeys = {
    for (final standard in professionalStandards) standard.id: GlobalKey(),
  };

  void _toggleStandard(String id) {
    setState(() => _expandedId = _expandedId == id ? null : id);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _expandedId != id) return;
      final rowContext = _rowKeys[id]?.currentContext;
      if (rowContext != null) {
        Scrollable.ensureVisible(
          rowContext,
          alignment: 0.1,
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 180),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: Text(text.translate('standardsTitle')),
        titleTextStyle: theme.textTheme.titleMedium?.copyWith(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final domain in ProfessionalDomain.values) ...[
              Padding(
                padding: const EdgeInsets.only(top: 16, bottom: 6),
                child: ColoredBox(
                  color: standardDomainColor(domain).withValues(alpha: 0.08),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    child: Text(
                      text.translate(domain.titleKey),
                      style: TextStyle(
                        color: standardDomainColor(domain, dark: dark),
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                ),
              ),
              for (final standard in professionalStandards.where(
                (standard) => standard.domain == domain,
              ))
                _standardRow(context, standard),
            ],
          ],
        ),
      ),
    );
  }

  Widget _standardRow(BuildContext context, ProfessionalStandard standard) {
    final text = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final expanded = _expandedId == standard.id;
    final description = expanded
        ? Padding(
            key: ValueKey('description-${standard.id}'),
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
            child: Text(
              text.translate(standard.descriptionKey),
              style: TextStyle(
                fontSize: 13,
                height: 1.7,
                letterSpacing: 0,
                color: theme.textTheme.bodyMedium?.color,
              ),
            ),
          )
        : const SizedBox.shrink();
    return Column(
      key: _rowKeys[standard.id],
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          expanded: expanded,
          child: TextButton(
            key: ValueKey('standard-${standard.id}'),
            onPressed: () => _toggleStandard(standard.id),
            style: TextButton.styleFrom(
              foregroundColor: theme.colorScheme.onSurface,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              minimumSize: const Size(48, 48),
              alignment: AlignmentDirectional.centerStart,
              shape: const RoundedRectangleBorder(),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    text.translate(standard.titleKey),
                    style: const TextStyle(fontSize: 15, letterSpacing: 0),
                  ),
                ),
                const SizedBox(width: 12),
                Icon(
                  expanded ? Icons.expand_less : Icons.expand_more,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
        if (MediaQuery.disableAnimationsOf(context))
          description
        else
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            alignment: Alignment.topCenter,
            child: description,
          ),
        const Divider(height: 1),
      ],
    );
  }
}
