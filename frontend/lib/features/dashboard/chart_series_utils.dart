import 'package:tek_sensor_monitor/features/dashboard/dashboard_state.dart';
import 'package:tek_sensor_monitor/models/reading_point.dart';

/// Max gap between consecutive points before the line is broken (ESP off / no data).
Duration gapThresholdForScale(ChartScale scale) {
  return switch (scale) {
    ChartScale.seconds => const Duration(seconds: 15),
    ChartScale.minutes => const Duration(minutes: 2),
    ChartScale.hours => const Duration(hours: 2),
    ChartScale.days => const Duration(days: 2),
    ChartScale.weeks => const Duration(days: 8),
    ChartScale.months => const Duration(days: 45),
    ChartScale.years => const Duration(days: 400),
  };
}

List<List<ReadingPoint>> splitPointsAtGaps(
  List<ReadingPoint> points,
  Duration maxGap,
) {
  if (points.isEmpty) return const [];
  if (points.length == 1) return [points];

  final sorted = [...points]..sort((a, b) => a.time.compareTo(b.time));
  final segments = <List<ReadingPoint>>[];
  var current = <ReadingPoint>[sorted.first];

  for (var i = 1; i < sorted.length; i++) {
    final gap = sorted[i].time.difference(sorted[i - 1].time);
    if (gap > maxGap) {
      segments.add(current);
      current = [];
    }
    current.add(sorted[i]);
  }
  segments.add(current);
  return segments;
}
