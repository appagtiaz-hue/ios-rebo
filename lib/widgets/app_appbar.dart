import 'package:flutter/material.dart';
import '../widgets/app_logo.dart';
import '../services/theme_service.dart';
import '../theme/app_colors.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

// Simple unified AppBar that includes logo, title and a theme toggle.

class AppAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  const AppAppBar({this.title = '', this.actions, super.key});

  @override
  Widget build(BuildContext context) {
    final mergedActions = <Widget>[];
    if (actions != null) mergedActions.addAll(actions!);

    // Theme toggle button
    mergedActions.add(
      ValueListenableBuilder(
        valueListenable: ThemeService.themeMode,
        builder: (context, value, _) {
          final mode = ThemeService.themeMode.value;
          return IconButton(
            tooltip: 'تبديل الثيم',
            icon: Icon(
              mode == ThemeMode.dark
                  ? Icons.nights_stay
                  : mode == ThemeMode.light
                  ? Icons.wb_sunny
                  : Icons.brightness_auto,
              size: 20,
            ),
            onPressed: () {
              final next = mode == ThemeMode.system
                  ? ThemeMode.light
                  : mode == ThemeMode.light
                  ? ThemeMode.dark
                  : ThemeMode.system;
              ThemeService.setThemeMode(next);
            },
          );
        },
      ),
    );

    return AppBar(
      titleSpacing: 0,
      centerTitle: false,
      backgroundColor: AppColors.primary,
      title: Row(
        children: [
          const SizedBox(width: 8),
          SizedBox(width: 36, height: 36, child: const AppLogo(size: 36)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: AppColors.white,
                fontSize: 20.sp,
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      actions: mergedActions,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
