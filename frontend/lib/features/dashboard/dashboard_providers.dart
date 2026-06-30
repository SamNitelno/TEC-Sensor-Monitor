import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tek_sensor_monitor/core/api_client.dart';
import 'package:tek_sensor_monitor/features/dashboard/dashboard_state.dart';
import 'package:tek_sensor_monitor/models/reading_point.dart';
import 'package:tek_sensor_monitor/models/sensor.dart';

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());

final sensorsProvider = FutureProvider<List<Sensor>>((ref) async {
  final client = ref.watch(apiClientProvider);
  return client.fetchSensors();
});

final selectedSensorIdProvider = StateProvider<int?>((ref) => null);

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

typedef ReadingsQuery = ({int sensorId, TimeRange range, String bucket});

final readingsQueryProvider = Provider<ReadingsQuery?>((ref) {
  final sensorId = ref.watch(selectedSensorIdProvider);
  if (sensorId == null) {
    return null;
  }
  final range = ref.watch(timeRangeProvider);
  final bucket = ref.watch(chartScaleProvider).bucket;
  return (sensorId: sensorId, range: range, bucket: bucket);
});

final readingsProvider = FutureProvider.autoDispose<ReadingsResponse>((ref) async {
  final query = ref.watch(readingsQueryProvider);
  if (query == null) {
    return const ReadingsResponse(bucket: 'raw', points: []);
  }

  final client = ref.watch(apiClientProvider);
  return client.fetchReadings(
    sensorId: query.sensorId,
    from: query.range.start,
    to: query.range.end,
    bucket: query.bucket,
  );
});
