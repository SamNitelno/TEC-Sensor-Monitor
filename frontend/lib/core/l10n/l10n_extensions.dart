import 'package:flutter/widgets.dart';
import 'package:tek_sensor_monitor/core/theme/app_theme.dart';
import 'package:tek_sensor_monitor/features/dashboard/dashboard_state.dart';
import 'package:tek_sensor_monitor/l10n/app_localizations.dart';

extension L10nContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

extension TimeRangePresetL10n on TimeRangePreset {
  String label(AppLocalizations l10n) => switch (this) {
        TimeRangePreset.minute => l10n.timePresetMinute,
        TimeRangePreset.hour => l10n.timePresetHour,
        TimeRangePreset.day => l10n.timePresetDay,
        TimeRangePreset.week => l10n.timePresetWeek,
        TimeRangePreset.month => l10n.timePresetMonth,
        TimeRangePreset.year => l10n.timePresetYear,
      };
}

extension ChartScaleL10n on ChartScale {
  String label(AppLocalizations l10n) => switch (this) {
        ChartScale.seconds => l10n.chartScaleSeconds,
        ChartScale.minutes => l10n.chartScaleMinutes,
        ChartScale.hours => l10n.chartScaleHours,
        ChartScale.days => l10n.chartScaleDays,
        ChartScale.weeks => l10n.chartScaleWeeks,
        ChartScale.months => l10n.chartScaleMonths,
        ChartScale.years => l10n.chartScaleYears,
      };
}

extension AppThemePreferenceL10n on AppThemePreference {
  String label(AppLocalizations l10n) => switch (this) {
        AppThemePreference.system => l10n.themeSystem,
        AppThemePreference.light => l10n.themeLight,
        AppThemePreference.dark => l10n.themeDark,
      };
}
