import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../theme/home_palette.dart';

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
    final colors = HomePalette.of(context);
    final text = AppLocalizations.of(context)!;
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 160);
    const destinations = [
      ('navHome', Icons.home_outlined, Icons.home_rounded),
      ('navExams', Icons.menu_book_outlined, Icons.menu_book_rounded),
      ('navResults', Icons.bar_chart_outlined, Icons.bar_chart_rounded),
      ('navAccount', Icons.person_outline, Icons.person_rounded),
    ];
    return DecoratedBox(
      key: const ValueKey('bottom-navigation-surface'),
      decoration: BoxDecoration(
        color: colors.background,
        border: Border(top: BorderSide(color: colors.border, width: .5)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 76,
          child: Row(
            children: [
              for (var index = 0; index < destinations.length; index++)
                Expanded(
                  child: Semantics(
                    selected: selectedIndex == index,
                    child: Tooltip(
                      message: text.translate(destinations[index].$1),
                      child: TextButton(
                        key: ValueKey('destination-$index'),
                        onPressed: () => onSelect(index),
                        style: TextButton.styleFrom(
                          foregroundColor: selectedIndex == index
                              ? colors.green
                              : colors.secondary,
                          minimumSize: const Size(48, 76),
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            AnimatedContainer(
                              key: ValueKey('destination-icon-$index'),
                              duration: duration,
                              width: 52,
                              height: 32,
                              decoration: BoxDecoration(
                                color: selectedIndex == index
                                    ? colors.greenSoft
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Icon(
                                selectedIndex == index
                                    ? destinations[index].$3
                                    : destinations[index].$2,
                                size: 25,
                              ),
                            ),
                            const SizedBox(height: 4),
                            SizedBox(
                              height: 22,
                              child: Align(
                                alignment: Alignment.center,
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    text.translate(destinations[index].$1),
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: selectedIndex == index
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      letterSpacing: 0,
                                    ),
                                  ),
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
        ),
      ),
    );
  }
}
