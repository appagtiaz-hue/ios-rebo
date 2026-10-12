import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../models/payment_plan.dart';
import '../theme/home_palette.dart';

class ProfileContent extends StatelessWidget {
  const ProfileContent({
    super.key,
    required this.name,
    required this.email,
    required this.subscriptions,
    required this.loadingSubscriptions,
    required this.themeMode,
    required this.language,
    required this.onBack,
    required this.onEditName,
    required this.onEditPhoto,
    required this.onStatistics,
    required this.onBrowsePlans,
    required this.onOpenSubscription,
    required this.onTheme,
    required this.onLanguage,
    required this.onSupport,
    required this.onLogout,
    this.photo,
  });
  final String name, email, language;
  final ImageProvider? photo;
  final List<Map<String, dynamic>> subscriptions;
  final bool loadingSubscriptions;
  final ThemeMode themeMode;
  final VoidCallback onBack,
      onEditName,
      onEditPhoto,
      onStatistics,
      onBrowsePlans,
      onTheme,
      onLanguage,
      onSupport,
      onLogout;
  final ValueChanged<Map<String, dynamic>> onOpenSubscription;

  @override
  Widget build(BuildContext context) {
    final p = HomePalette.of(context);
    final strings =
        AppLocalizations.of(context) ?? AppLocalizations(const Locale('ar'));
    String t(String key) => strings.translate(key);
    final displayName = name.trim().isEmpty ? t('userDefault') : name.trim();
    final themeKey = switch (themeMode) {
      ThemeMode.system => 'systemTheme',
      ThemeMode.light => 'lightTheme',
      ThemeMode.dark => 'darkTheme',
    };
    Widget heading(String title) => Padding(
      padding: const EdgeInsets.only(top: 28, bottom: 12),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: p.secondary,
        ),
      ),
    );
    return ColoredBox(
      color: p.background,
      child: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          key: const PageStorageKey('profile-scroll'),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      IconButton(
                        key: const ValueKey('profile-back'),
                        tooltip: MaterialLocalizations.of(
                          context,
                        ).backButtonTooltip,
                        onPressed: onBack,
                        color: p.ink,
                        icon: const BackButtonIcon(),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          t('navAccount'),
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: p.ink,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 80,
                        height: 80,
                        child: IconButton(
                          key: const ValueKey('profile-edit-photo'),
                          tooltip: t('profileEditPhoto'),
                          padding: EdgeInsets.zero,
                          onPressed: onEditPhoto,
                          icon: Stack(
                            children: [
                              ClipOval(
                                child: SizedBox(
                                  width: 80,
                                  height: 80,
                                  child: photo != null
                                      ? Image(
                                          image: photo!,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) =>
                                              _initial(displayName, p),
                                        )
                                      : _initial(displayName, p),
                                ),
                              ),
                              PositionedDirectional(
                                bottom: 0,
                                end: 0,
                                child: Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: p.goldSoft,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: p.background,
                                      width: 2,
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.camera_alt_outlined,
                                    size: 16,
                                    color: p.gold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              displayName,
                              key: const ValueKey('profile-name'),
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: p.ink,
                                height: 1.4,
                              ),
                            ),
                            if (email.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                email,
                                key: const ValueKey('profile-email'),
                                textDirection: TextDirection.ltr,
                                textAlign:
                                    Directionality.of(context) ==
                                        TextDirection.rtl
                                    ? TextAlign.right
                                    : TextAlign.left,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: p.secondary,
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      IconButton(
                        key: const ValueKey('profile-edit-name'),
                        tooltip: t('editNameTitle'),
                        onPressed: onEditName,
                        color: p.green,
                        icon: const Icon(Icons.edit_outlined, size: 21),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  ProfileActionRow(
                    key: const ValueKey('profile-statistics'),
                    icon: Icons.bar_chart_rounded,
                    title: t('statistics'),
                    subtitle: t('homeResultsDescription'),
                    onTap: onStatistics,
                  ),
                  heading(t('profilePlans')),
                  if (loadingSubscriptions)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        t('homePlansLoading'),
                        style: TextStyle(color: p.secondary, fontSize: 15),
                      ),
                    )
                  else if (subscriptions.isEmpty)
                    ProfileActionRow(
                      key: const ValueKey('profile-browse-plans'),
                      icon: Icons.workspace_premium_outlined,
                      title: t('noActivePlan'),
                      subtitle: t('homePremiumDescription'),
                      color: p.gold,
                      onTap: onBrowsePlans,
                    )
                  else ...[
                    for (var index = 0; index < subscriptions.length; index++)
                      _subscription(context, subscriptions[index], index),
                    TextButton(
                      key: const ValueKey('profile-browse-plans'),
                      onPressed: onBrowsePlans,
                      style: TextButton.styleFrom(
                        foregroundColor: p.green,
                        minimumSize: const Size(48, 48),
                        alignment: AlignmentDirectional.centerStart,
                      ),
                      child: Text(
                        t('homeBrowsePlans'),
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                  heading(t('settings')),
                  ProfileActionRow(
                    key: const ValueKey('profile-theme'),
                    icon: Icons.palette_outlined,
                    title: t('appearance'),
                    subtitle: t(themeKey),
                    color: p.gold,
                    onTap: onTheme,
                  ),
                  Divider(height: 1, color: p.border),
                  ProfileActionRow(
                    key: const ValueKey('profile-language'),
                    icon: Icons.language_rounded,
                    title: t('language'),
                    subtitle: language == 'ar' ? t('arabic') : t('english'),
                    onTap: onLanguage,
                  ),
                  Column(
                    key: const ValueKey('profile-support-section'),
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      heading(t('supportSection')),
                      ProfileActionRow(
                        key: const ValueKey('profile-contact-support'),
                        icon: Icons.support_agent_rounded,
                        title: t('contactUs'),
                        subtitle: t('contactUsChannels'),
                        onTap: onSupport,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Divider(height: 1, color: p.border),
                  ProfileActionRow(
                    key: const ValueKey('profile-logout'),
                    icon: Icons.logout_rounded,
                    title: t('logout'),
                    color: p.dark
                        ? const Color(0xFFF0ADA5)
                        : const Color(0xFF9E342A),
                    onTap: onLogout,
                    showArrow: false,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _initial(String name, HomePalette p) => ColoredBox(
    color: p.greenSoft,
    child: Center(
      child: Text(
        name.characters.first.toUpperCase(),
        style: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: p.green,
        ),
      ),
    ),
  );

  Widget _subscription(
    BuildContext context,
    Map<String, dynamic> sub,
    int index,
  ) {
    final p = HomePalette.of(context);
    final strings =
        AppLocalizations.of(context) ?? AppLocalizations(const Locale('ar'));
    final raw = sub['planObject'];
    final name = raw is Map<String, dynamic>
        ? PaymentPlan.fromJson(raw).getName(context)
        : sub['planName']?.toString() ?? '';
    final count = sub['questionCount'] ?? 0;
    return Container(
      key: ValueKey('profile-plan-$index'),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: p.panel,
        border: Border.all(color: p.goldBorder),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.workspace_premium_outlined, color: p.gold, size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  name,
                  style: TextStyle(
                    color: p.ink,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                strings.translate('active'),
                style: TextStyle(fontSize: 12, color: p.green),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '$count ${strings.translate('question')}',
            style: TextStyle(color: p.secondary, fontSize: 13),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            key: ValueKey('profile-enter-plan-$index'),
            onPressed: () => onOpenSubscription(sub),
            icon: const Icon(Icons.play_arrow_rounded, size: 20),
            label: Text(
              strings.translate('homeContinueTraining'),
              textAlign: TextAlign.center,
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: p.green,
              side: BorderSide(color: p.border),
              minimumSize: const Size(48, 48),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ProfileActionRow extends StatelessWidget {
  const ProfileActionRow({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.color,
    this.showArrow = true,
    this.subtitleDirection,
  });
  final IconData icon;
  final String title;
  final String? subtitle;
  final Color? color;
  final bool showArrow;
  final TextDirection? subtitleDirection;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = HomePalette.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 72),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
            child: Row(
              children: [
                SizedBox(
                  width: 40,
                  height: 40,
                  child: Icon(icon, size: 25, color: color ?? p.green),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 15,
                          color: color ?? p.ink,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle!,
                          textDirection: subtitleDirection,
                          style: TextStyle(
                            fontSize: 13,
                            color: p.secondary,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (showArrow) ...[
                  const SizedBox(width: 12),
                  Icon(
                    Directionality.of(context) == TextDirection.rtl
                        ? Icons.chevron_left_rounded
                        : Icons.chevron_right_rounded,
                    color: p.secondary,
                    size: 21,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
