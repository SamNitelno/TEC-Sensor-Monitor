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
