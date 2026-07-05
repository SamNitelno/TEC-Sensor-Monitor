import 'package:flutter/material.dart';
import 'package:tek_sensor_monitor/core/theme/app_theme.dart';

/// Rounded sort-field selector shared across list screens.
class TekSortDropdown<T> extends StatelessWidget {
  const TekSortDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    this.isExpanded = false,
  });

  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final bool isExpanded;

  static const _radius = 10.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tek = tekTheme(context);

    final dropdown = DropdownButton<T>(
      value: value,
      items: items,
      onChanged: onChanged,
      isExpanded: isExpanded,
      underline: const SizedBox.shrink(),
      borderRadius: BorderRadius.circular(_radius),
      dropdownColor: theme.colorScheme.surfaceContainerHighest,
      style: theme.textTheme.bodyMedium,
      icon: Icon(
        Icons.expand_more,
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: tek.elevated,
        borderRadius: BorderRadius.circular(_radius),
        border: Border.all(color: tek.border),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        child: dropdown,
      ),
    );
  }
}
