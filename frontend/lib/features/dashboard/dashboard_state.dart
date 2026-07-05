import 'package:flutter/material.dart';
import 'package:tek_sensor_monitor/l10n/app_localizations.dart';

enum TimeRangePreset {
  minute(Duration(minutes: 1)),
  hour(Duration(hours: 1)),
  day(Duration(days: 1)),
  week(Duration(days: 7)),
  month(Duration(days: 30)),
  year(Duration(days: 365));

  const TimeRangePreset(this.duration);

  final Duration duration;
}

enum ChartScale {
  seconds('raw'),
  minutes('minute'),
  hours('hour'),
  days('hour'),
  weeks('day'),
  months('day'),
  years('day');

  const ChartScale(this.bucket);

  final String bucket;
}

/// Selected time window for chart queries (independent of Material [DateTimeRange]).
class TimeRange {
  const TimeRange({required this.start, required this.end});

  final DateTime start;
  final DateTime end;

  factory TimeRange.fromDateTimeRange(DateTimeRange range) {
    return TimeRange(start: range.start, end: range.end);
  }
}

/// Independent display settings for one dashboard chart panel.
class ChartPanelConfig {
  const ChartPanelConfig({
    required this.id,
    this.title = '',
    this.preset = TimeRangePreset.minute,
    this.customRange,
    this.isLive = true,
    this.liveSpan,
    this.scale = ChartScale.seconds,
    this.workshopIds = const {},
    this.siteIds = const {},
    this.allSensors = true,
    this.selectedSensorIds = const {},
  });

  final String id;
  final String title;
  final TimeRangePreset preset;
  final TimeRange? customRange;
  final bool isLive;
  final Duration? liveSpan;
  final ChartScale scale;
  final Set<int> workshopIds;
  final Set<int> siteIds;
  final bool allSensors;
  final Set<int> selectedSensorIds;

  String displayTitle(int index, AppLocalizations l10n) =>
      title.isNotEmpty ? title : l10n.defaultChartTitle(index + 1);

  ChartPanelConfig copyWith({
    String? title,
    TimeRangePreset? preset,
    TimeRange? customRange,
    bool clearCustomRange = false,
    bool? isLive,
    Duration? liveSpan,
    bool clearLiveSpan = false,
    ChartScale? scale,
    Set<int>? workshopIds,
    Set<int>? siteIds,
    bool? allSensors,
    Set<int>? selectedSensorIds,
  }) {
    return ChartPanelConfig(
      id: id,
      title: title ?? this.title,
      preset: preset ?? this.preset,
      customRange: clearCustomRange ? null : (customRange ?? this.customRange),
      isLive: isLive ?? this.isLive,
      liveSpan: clearLiveSpan ? null : (liveSpan ?? this.liveSpan),
      scale: scale ?? this.scale,
      workshopIds: workshopIds ?? this.workshopIds,
      siteIds: siteIds ?? this.siteIds,
      allSensors: allSensors ?? this.allSensors,
      selectedSensorIds: selectedSensorIds ?? this.selectedSensorIds,
    );
  }
}

extension ChartScaleCycle on ChartScale {
  ChartScale adjustByWheelDelta(double delta) {
    final values = ChartScale.values;
    final index = values.indexOf(this);
    if (index < 0) return this;
    final next = delta > 0 ? index + 1 : index - 1;
    if (next < 0 || next >= values.length) return this;
    return values[next];
  }
}
