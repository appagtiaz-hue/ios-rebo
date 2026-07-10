import 'package:flutter/material.dart';
import '../services/theme_service.dart';
import '../constants/colors.dart';

class ThemeToggle extends StatelessWidget {
  const ThemeToggle({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: ThemeService.themeMode,
      builder: (context, value, _) {
        final mode = ThemeService.themeMode.value;
        return FloatingActionButton(
          onPressed: () {
            // Cycle through modes: system -> light -> dark -> system
            final next = mode == ThemeMode.system
                ? ThemeMode.light
                : mode == ThemeMode.light
                ? ThemeMode.dark
                : ThemeMode.system;
            ThemeService.setThemeMode(next);
          },
          backgroundColor: AppColors.primary,
          child: Icon(
            mode == ThemeMode.dark
                ? Icons.nights_stay
                : mode == ThemeMode.light
                ? Icons.wb_sunny
                : Icons.brightness_auto,
            color: AppColors.white,
          ),
        );
      },
    );
  }
}
