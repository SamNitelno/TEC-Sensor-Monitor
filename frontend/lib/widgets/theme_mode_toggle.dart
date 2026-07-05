import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tek_sensor_monitor/core/l10n/l10n_extensions.dart';
import 'package:tek_sensor_monitor/core/theme/app_theme.dart';

class ThemeModeToggleButton extends ConsumerWidget {
  const ThemeModeToggleButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preference = ref.watch(themePreferenceProvider);
    final l10n = context.l10n;
    return IconButton(
      tooltip: l10n.themeTooltip(preference.label(l10n)),
      onPressed: () => ref.read(themePreferenceProvider.notifier).cycle(),
      icon: Icon(
        preference.icon,
        key: ValueKey(preference),
      ),
    );
  }
}
