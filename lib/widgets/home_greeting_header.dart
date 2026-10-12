import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../theme/home_palette.dart';

class HomeGreetingHeader extends StatelessWidget {
  const HomeGreetingHeader({
    super.key,
    this.name,
    this.avatar,
    this.completedTests,
  });
  final String? name;
  final ImageProvider? avatar;
  final int? completedTests;

  @override
  Widget build(BuildContext context) {
    final palette = HomePalette.of(context);
    final text = AppLocalizations.of(context)!;
    final displayName = name?.trim() ?? '';
    final greeting = displayName.isEmpty
        ? text.translate('homeGreetingFallback')
        : text.translate('homeGreeting').replaceAll('{name}', displayName);
    final subtitle = completedTests == null
        ? 'homeGreetingNeutral'
        : completedTests! > 0
        ? 'homeGreetingReturning'
        : 'homeGreetingNew';
    final fallback = Center(
      child: displayName.isEmpty
          ? Icon(Icons.person_outline, color: palette.green, size: 27)
          : Text(
              displayName.characters.first,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: palette.green,
                letterSpacing: 0,
              ),
            ),
    );
    return Row(
      key: const ValueKey('home-greeting'),
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                greeting,
                style: TextStyle(
                  fontSize: 26,
                  height: 1.35,
                  fontWeight: FontWeight.w700,
                  color: palette.ink,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                text.translate(subtitle),
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: palette.secondary,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 14),
        ExcludeSemantics(
          child: Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: palette.greenSoft,
              shape: BoxShape.circle,
              border: Border.all(color: palette.border, width: 2),
            ),
            child: ClipOval(
              child: avatar == null
                  ? fallback
                  : Image(
                      image: avatar!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => fallback,
                    ),
            ),
          ),
        ),
      ],
    );
  }
}
