import 'package:flutter/material.dart';
import 'package:tek_sensor_monitor/core/l10n/l10n_extensions.dart';
import 'package:tek_sensor_monitor/features/dashboard/dashboard_state.dart';

class ChartTimeControlBar extends StatelessWidget {
  const ChartTimeControlBar({
    super.key,
    required this.preset,
    required this.presetSelected,
    required this.hasCustom,
    required this.onPreset,
    required this.onCustom,
  });

  final TimeRangePreset preset;
  final bool presetSelected;
  final bool hasCustom;
  final ValueChanged<TimeRangePreset> onPreset;
  final VoidCallback onCustom;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(l10n.periodLabel, style: theme.textTheme.labelSmall),
        for (final p in TimeRangePreset.values)
          ChoiceChip(
            label: Text(p.label(l10n), style: theme.textTheme.labelSmall),
            labelPadding: const EdgeInsets.symmetric(horizontal: 4),
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            selected: presetSelected && preset == p,
            selectedColor: theme.colorScheme.secondaryContainer,
            labelStyle: (presetSelected && preset == p)
                ? theme.chipTheme.secondaryLabelStyle
                : theme.chipTheme.labelStyle,
            onSelected: (_) => onPreset(p),
          ),
        ActionChip(
          label: Text(l10n.customPeriod, style: theme.textTheme.labelSmall),
          avatar: const Icon(Icons.date_range, size: 14),
          visualDensity: VisualDensity.compact,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          onPressed: onCustom,
        ),
      ],
    );
  }
}
