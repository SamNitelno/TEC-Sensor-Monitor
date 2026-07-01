class ReadingPoint {
  const ReadingPoint({
    required this.time,
    required this.avg,
    required this.min,
    required this.max,
  });

  factory ReadingPoint.fromJson(Map<String, dynamic> json) {
    return ReadingPoint(
      time: DateTime.parse(json['time'] as String).toLocal(),
      avg: (json['avg'] as num).toDouble(),
      min: (json['min'] as num).toDouble(),
      max: (json['max'] as num).toDouble(),
    );
  }

  final DateTime time;
  final double avg;
  final double min;
  final double max;
}

class ReadingsResponse {
  const ReadingsResponse({
    required this.bucket,
    required this.points,
  });

  factory ReadingsResponse.fromJson(Map<String, dynamic> json) {
    final pointsJson = json['points'] as List<dynamic>? ?? [];
    return ReadingsResponse(
      bucket: json['bucket'] as String,
      points: pointsJson
          .map((item) => ReadingPoint.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }

  final String bucket;
  final List<ReadingPoint> points;
}

class SensorSeries {
  const SensorSeries({
    required this.sensorId,
    required this.sensorName,
    required this.bucket,
    required this.points,
  });

  factory SensorSeries.fromJson(Map<String, dynamic> json) {
    final pointsJson = json['points'] as List<dynamic>? ?? [];
    return SensorSeries(
      sensorId: json['sensor_id'] as int,
      sensorName: json['sensor_name'] as String,
      bucket: json['bucket'] as String,
      points: pointsJson
          .map((item) => ReadingPoint.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }

  final int sensorId;
  final String sensorName;
  final String bucket;
  final List<ReadingPoint> points;
}

class GroupedReadingsResponse {
  const GroupedReadingsResponse({required this.series});

  factory GroupedReadingsResponse.fromJson(Map<String, dynamic> json) {
    final seriesJson = json['series'] as List<dynamic>? ?? [];
    return GroupedReadingsResponse(
      series: seriesJson
          .map((item) => SensorSeries.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }

  final List<SensorSeries> series;
}
