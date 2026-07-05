import 'package:tek_sensor_monitor/l10n/app_localizations.dart';

class DowntimeEvent {
  const DowntimeEvent({
    required this.id,
    required this.sensorId,
    required this.sensorName,
    required this.type,
    required this.startedAt,
    this.endedAt,
    this.durationSeconds,
    this.siteId,
    this.siteName,
    this.workshopId,
    this.workshopName,
  });

  factory DowntimeEvent.fromJson(Map<String, dynamic> json) {
    return DowntimeEvent(
      id: json['id'] as int,
      sensorId: json['sensor_id'] as int,
      sensorName: json['sensor_name'] as String,
      type: json['type'] as String,
      startedAt: DateTime.parse(json['started_at'] as String),
      endedAt: json['ended_at'] == null
          ? null
          : DateTime.parse(json['ended_at'] as String),
      durationSeconds: (json['duration_seconds'] as num?)?.toDouble(),
      siteId: json['site_id'] as int?,
      siteName: json['site_name'] as String?,
      workshopId: json['workshop_id'] as int?,
      workshopName: json['workshop_name'] as String?,
    );
  }

  final int id;
  final int sensorId;
  final String sensorName;
  final String type;
  final DateTime startedAt;
  final DateTime? endedAt;
  final double? durationSeconds;
  final int? siteId;
  final String? siteName;
  final int? workshopId;
  final String? workshopName;

  bool get isOffline => type == 'offline';
  bool get isIdle => type == 'idle';
  bool get isOpen => endedAt == null;
}

class DowntimeSummaryRow {
  const DowntimeSummaryRow({
    required this.sensorId,
    required this.sensorName,
    required this.offlineSeconds,
    required this.idleSeconds,
    required this.totalSeconds,
    this.siteName,
    this.workshopName,
  });

  factory DowntimeSummaryRow.fromJson(Map<String, dynamic> json) {
    return DowntimeSummaryRow(
      sensorId: json['sensor_id'] as int,
      sensorName: json['sensor_name'] as String,
      offlineSeconds: (json['offline_seconds'] as num).toDouble(),
      idleSeconds: (json['idle_seconds'] as num).toDouble(),
      totalSeconds: (json['total_seconds'] as num).toDouble(),
      siteName: json['site_name'] as String?,
      workshopName: json['workshop_name'] as String?,
    );
  }

  final int sensorId;
  final String sensorName;
  final double offlineSeconds;
  final double idleSeconds;
  final double totalSeconds;
  final String? siteName;
  final String? workshopName;
}

class WorkshopDowntimeSummary {
  const WorkshopDowntimeSummary({
    required this.workshopId,
    required this.workshopName,
    required this.offlineSeconds,
    required this.idleSeconds,
    required this.totalSeconds,
  });

  factory WorkshopDowntimeSummary.fromJson(Map<String, dynamic> json) {
    return WorkshopDowntimeSummary(
      workshopId: json['workshop_id'] as int,
      workshopName: json['workshop_name'] as String,
      offlineSeconds: (json['offline_seconds'] as num).toDouble(),
      idleSeconds: (json['idle_seconds'] as num).toDouble(),
      totalSeconds: (json['total_seconds'] as num).toDouble(),
    );
  }

  final int workshopId;
  final String workshopName;
  final double offlineSeconds;
  final double idleSeconds;
  final double totalSeconds;
}

class DowntimeSummary {
  const DowntimeSummary({
    required this.sensors,
    required this.workshops,
  });

  factory DowntimeSummary.fromJson(Map<String, dynamic> json) {
    return DowntimeSummary(
      sensors: (json['sensors'] as List<dynamic>? ?? [])
          .map((e) => DowntimeSummaryRow.fromJson(e as Map<String, dynamic>))
          .toList(),
      workshops: (json['workshops'] as List<dynamic>? ?? [])
          .map(
            (e) => WorkshopDowntimeSummary.fromJson(e as Map<String, dynamic>),
          )
          .toList(),
    );
  }

  final List<DowntimeSummaryRow> sensors;
  final List<WorkshopDowntimeSummary> workshops;
}

String formatDowntimeDuration(double seconds, AppLocalizations l10n) {
  if (seconds < 60) return l10n.durationSeconds(seconds.round());
  if (seconds < 3600) return l10n.durationMinutes((seconds / 60).round());
  final hours = seconds / 3600;
  if (hours < 24) return l10n.durationHours(hours.round());
  return l10n.durationDays((hours / 24).round());
}
