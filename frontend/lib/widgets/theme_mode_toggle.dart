import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tek_sensor_monitor/core/theme/app_theme.dart';

class ThemeModeToggleButton extends ConsumerWidget {
  const ThemeModeToggleButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preference = ref.watch(themePreferenceProvider);
    return IconButton(
      tooltip: 'Тема: ${preference.label}',
      onPressed: () => ref.read(themePreferenceProvider.notifier).cycle(),
      icon: AnimatedSwitcher(
        duration: tekAnimDuration(context, ref, const Duration(milliseconds: 200)),
        child: Icon(
          preference.icon,
          key: ValueKey(preference),
        ),
      ),
    );
  }
}
