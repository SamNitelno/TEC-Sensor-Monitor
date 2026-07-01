import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tek_sensor_monitor/features/auth/auth_providers.dart';
import 'package:tek_sensor_monitor/features/dashboard/dashboard_state.dart';
import 'package:tek_sensor_monitor/models/reading_point.dart';
import 'package:tek_sensor_monitor/models/sensor.dart';
import 'package:tek_sensor_monitor/models/site.dart';

final sensorsProvider = FutureProvider<List<Sensor>>((ref) async {
  final client = ref.watch(apiClientProvider);
  final siteId = ref.watch(siteFilterProvider);
  final workshopId = ref.watch(workshopFilterProvider);
  return client.fetchSensors(siteId: siteId, workshopId: workshopId);
});

final sitesProvider = FutureProvider<List<Site>>((ref) async {
  final client = ref.watch(apiClientProvider);
  return client.fetchSites();
});

final workshopsProvider = FutureProvider<List<Workshop>>((ref) async {
  final client = ref.watch(apiClientProvider);
  final siteId = ref.watch(siteFilterProvider);
  return client.fetchWorkshops(siteId: siteId);
});

final siteFilterProvider = StateProvider<int?>((ref) => null);
final workshopFilterProvider = StateProvider<int?>((ref) => null);

final selectedSensorIdsProvider = StateProvider<Set<int>>((ref) => {});

final timeRangePresetProvider =
    StateProvider<TimeRangePreset>((ref) => TimeRangePreset.hour);

final customTimeRangeProvider = StateProvider<TimeRange?>((ref) => null);

final chartScaleProvider = StateProvider<ChartScale>((ref) => ChartScale.seconds);

final timeRangeProvider = Provider<TimeRange>((ref) {
  final custom = ref.watch(customTimeRangeProvider);
  if (custom != null) {
    return custom;
  }
  final preset = ref.watch(timeRangePresetProvider);
  final now = DateTime.now();
  return TimeRange(
    start: now.subtract(preset.duration),
    end: now,
  );
});

final readingsProvider = FutureProvider.autoDispose<GroupedReadingsResponse>((ref) async {
  final client = ref.watch(apiClientProvider);
  final range = ref.watch(timeRangeProvider);
  final bucket = ref.watch(chartScaleProvider).bucket;
  final sensorIds = ref.watch(selectedSensorIdsProvider).toList();
  final siteId = ref.watch(siteFilterProvider);
  final workshopId = ref.watch(workshopFilterProvider);

  if (sensorIds.isEmpty && siteId == null && workshopId == null) {
    return const GroupedReadingsResponse(series: []);
  }

  return client.fetchGroupedReadings(
    from: range.start,
    to: range.end,
    bucket: bucket,
    sensorIds: sensorIds.isEmpty ? null : sensorIds,
    siteId: sensorIds.isEmpty ? siteId : null,
    workshopId: sensorIds.isEmpty ? workshopId : null,
  );
});
