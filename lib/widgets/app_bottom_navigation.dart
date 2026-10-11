import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';

class AppBottomNavigation extends StatelessWidget {
  const AppBottomNavigation({
    super.key,
    required this.selectedIndex,
    required this.onSelect,
  });
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labels = AppLocalizations.of(context)!;
    final dark = theme.brightness == Brightness.dark;
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 200);
    const destinations = [
      ('navHome', Icons.home_outlined, Icons.home_rounded, Color(0xFF148452)),
      (
        'navExams',
        Icons.menu_book_outlined,
        Icons.menu_book_rounded,
        Color(0xFF986919),
      ),
      (
        'navResults',
        Icons.bar_chart_outlined,
        Icons.bar_chart_rounded,
        Color(0xFF3174BA),
      ),
      (
        'navAccount',
        Icons.person_outline,
        Icons.person_rounded,
        Color(0xFF637083),
      ),
    ];
    final surface = dark ? const Color(0xFF242927) : Colors.white;
    return SafeArea(
      top: false,
      child: SizedBox(
        height: 82,
        child: Stack(
          children: [
            Positioned.fill(
              top: 12,
              child: DecoratedBox(
                key: const ValueKey('bottom-navigation-surface'),
                decoration: BoxDecoration(
                  color: surface,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: dark ? .18 : .07),
                      blurRadius: 18,
                      offset: const Offset(0, -3),
                    ),
                  ],
                ),
              ),
            ),
            Row(
              children: [
                for (final index in const [1, 0, 2, 3])
                  Expanded(
                    child: Semantics(
                      selected: selectedIndex == index,
                      child: Tooltip(
                        message: labels.translate(destinations[index].$1),
                        child: TextButton(
                          key: ValueKey('destination-$index'),
                          onPressed: () => onSelect(index),
                          style: TextButton.styleFrom(
                            foregroundColor: dark
                                ? Color.lerp(
                                    destinations[index].$4,
                                    Colors.white,
                                    .4,
                                  )
                                : destinations[index].$4,
                            fixedSize: const Size.fromHeight(82),
                            minimumSize: const Size(48, 82),
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                height: 52,
                                child: Align(
                                  alignment: index == 0
                                      ? Alignment.topCenter
                                      : Alignment.bottomCenter,
                                  child: AnimatedContainer(
                                    key: ValueKey('destination-icon-$index'),
                                    duration: duration,
                                    width: index == 0 ? 50 : 38,
                                    height: index == 0 ? 50 : 34,
                                    padding: index == 0
                                        ? const EdgeInsets.all(4)
                                        : EdgeInsets.zero,
                                    decoration: BoxDecoration(
                                      color: index == 0
                                          ? destinations[index].$4.withValues(
                                              alpha: dark ? .3 : .12,
                                            )
                                          : destinations[index].$4.withValues(
                                              alpha: selectedIndex == index
                                                  ? .2
                                                  : dark
                                                  ? .16
                                                  : .09,
                                            ),
                                      borderRadius: BorderRadius.circular(
                                        index == 0 ? 25 : 12,
                                      ),
                                    ),
                                    child: Container(
                                      decoration: index == 0
                                          ? BoxDecoration(
                                              color: destinations[index].$4,
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: surface,
                                                width: 3,
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: destinations[index].$4
                                                      .withValues(alpha: .2),
                                                  blurRadius: 5,
                                                ),
                                              ],
                                            )
                                          : null,
                                      child: Icon(
                                        selectedIndex == index
                                            ? destinations[index].$3
                                            : destinations[index].$2,
                                        color: index == 0 ? Colors.white : null,
                                        size: index == 0 ? 23 : 22,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  labels.translate(destinations[index].$1),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: selectedIndex == index
                                        ? FontWeight.w700
                                        : FontWeight.w600,
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
              ],
            ),
          ],
        ),
      ),
    );
  }
}
