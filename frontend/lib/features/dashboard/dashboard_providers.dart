import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tek_sensor_monitor/features/auth/auth_providers.dart';
import 'package:tek_sensor_monitor/features/dashboard/dashboard_state.dart';
import 'package:tek_sensor_monitor/models/reading_point.dart';
import 'package:tek_sensor_monitor/models/sensor.dart';
import 'package:tek_sensor_monitor/models/site.dart';

/// Bumped every 5 s on the dashboard to slide live time windows forward.
final dashboardPollTickProvider = StateProvider<int>((ref) => 0);

/// When true, the chart window keeps its width but anchors the end to [DateTime.now].
final chartLiveWindowProvider = StateProvider<bool>((ref) => true);

/// Width of a user-zoomed live window (ignored when [chartLiveWindowProvider] is false).
final chartWindowSpanProvider = StateProvider<Duration?>((ref) => null);

final workshopsProvider = FutureProvider<List<Workshop>>((ref) async {
  final client = ref.watch(apiClientProvider);
  final workshops = await client.fetchWorkshops();
  ref.read(workshopsCacheProvider.notifier).state = workshops;
  return workshops;
});

final sitesProvider = FutureProvider<List<Site>>((ref) async {
  final client = ref.watch(apiClientProvider);
  final workshopId = ref.watch(workshopFilterProvider);
  final sites = await client.fetchSites(workshopId: workshopId);
  ref.read(sitesCacheProvider.notifier).state = sites;
  return sites;
});

final sensorsProvider = FutureProvider<List<Sensor>>((ref) async {
  final client = ref.watch(apiClientProvider);
  final siteId = ref.watch(siteFilterProvider);
  final workshopId = ref.watch(workshopFilterProvider);
  final sensors = await client.fetchSensors(siteId: siteId, workshopId: workshopId);
  ref.read(sensorsCacheProvider.notifier).state = sensors;
  return sensors;
});

final workshopsCacheProvider = StateProvider<List<Workshop>?>((ref) => null);
final sitesCacheProvider = StateProvider<List<Site>?>((ref) => null);
final sensorsCacheProvider = StateProvider<List<Sensor>?>((ref) => null);
final readingsCacheProvider = StateProvider<GroupedReadingsResponse?>((ref) => null);

final workshopFilterProvider = StateProvider<int?>((ref) => null);
final siteFilterProvider = StateProvider<int?>((ref) => null);

final selectedSensorIdsProvider = StateProvider<Set<int>>((ref) => {});

final timeRangePresetProvider =
    StateProvider<TimeRangePreset>((ref) => TimeRangePreset.minute);

final customTimeRangeProvider = StateProvider<TimeRange?>((ref) => null);

final chartScaleProvider = StateProvider<ChartScale>((ref) => ChartScale.seconds);

final timeRangeProvider = Provider<TimeRange>((ref) {
  ref.watch(dashboardPollTickProvider);
  final now = DateTime.now();
  final isLive = ref.watch(chartLiveWindowProvider);
  final liveSpan = ref.watch(chartWindowSpanProvider);
  final custom = ref.watch(customTimeRangeProvider);

  if (isLive) {
    final span = liveSpan ?? ref.watch(timeRangePresetProvider).duration;
    return TimeRange(start: now.subtract(span), end: now);
  }
  if (custom != null) {
    return custom;
  }
  final preset = ref.watch(timeRangePresetProvider);
  return TimeRange(
    start: now.subtract(preset.duration),
    end: now,
  );
});

final readingsProvider = FutureProvider<GroupedReadingsResponse>((ref) async {
  ref.watch(dashboardPollTickProvider);
  final client = ref.watch(apiClientProvider);
  final range = ref.watch(timeRangeProvider);
  final bucket = ref.watch(chartScaleProvider).bucket;
  final sensorIds = ref.watch(selectedSensorIdsProvider).toList();
  final siteId = ref.watch(siteFilterProvider);
  final workshopId = ref.watch(workshopFilterProvider);

  if (sensorIds.isEmpty && siteId == null && workshopId == null) {
    return const GroupedReadingsResponse(series: []);
  }

  try {
    final response = await client.fetchGroupedReadings(
      from: range.start,
      to: range.end,
      bucket: bucket,
      sensorIds: sensorIds.isEmpty ? null : sensorIds,
      siteId: sensorIds.isEmpty ? siteId : null,
      workshopId: sensorIds.isEmpty ? workshopId : null,
    );
    ref.read(readingsCacheProvider.notifier).state = response;
    return response;
  } catch (error) {
    final cached = ref.read(readingsCacheProvider);
    if (cached != null) {
      return cached;
    }
    rethrow;
  }
});

ChartScale chartScaleForVisibleSpan(Duration span) {
  if (span <= const Duration(minutes: 5)) return ChartScale.seconds;
  if (span <= const Duration(hours: 2)) return ChartScale.minutes;
  if (span <= const Duration(days: 2)) return ChartScale.hours;
  if (span <= const Duration(days: 14)) return ChartScale.days;
  if (span <= const Duration(days: 90)) return ChartScale.weeks;
  if (span <= const Duration(days: 400)) return ChartScale.months;
  return ChartScale.years;
}

ChartScale defaultChartScaleForPreset(TimeRangePreset preset) {
  return switch (preset) {
    TimeRangePreset.minute => ChartScale.seconds,
    TimeRangePreset.hour => ChartScale.seconds,
    TimeRangePreset.day => ChartScale.minutes,
    TimeRangePreset.week => ChartScale.hours,
    TimeRangePreset.month => ChartScale.days,
    TimeRangePreset.year => ChartScale.months,
  };
}

void setLiveChartWindow(WidgetRef ref, {Duration? span}) {
  ref.read(chartLiveWindowProvider.notifier).state = true;
  ref.read(chartWindowSpanProvider.notifier).state = span;
  ref.read(customTimeRangeProvider.notifier).state = null;
}

void setHistoricalChartWindow(WidgetRef ref, TimeRange range) {
  ref.read(chartLiveWindowProvider.notifier).state = false;
  ref.read(chartWindowSpanProvider.notifier).state = null;
  ref.read(customTimeRangeProvider.notifier).state = range;
}
