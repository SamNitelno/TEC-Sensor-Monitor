class Sensor {
  const Sensor({
    required this.id,
    required this.name,
    required this.deviceId,
    required this.siteId,
    required this.status,
    required this.lastSeen,
    this.color,
    this.idlePowerThresholdW,
    this.idleCurrentThresholdA,
    this.idleDurationSeconds,
    this.notificationsEnabled = true,
    this.createdAt,
  });

  factory Sensor.fromJson(Map<String, dynamic> json) {
    final lastSeenRaw = json['last_seen'];
    final createdAtRaw = json['created_at'];
    return Sensor(
      id: json['id'] as int,
      name: json['name'] as String,
      deviceId: json['device_id'] as String,
      siteId: json['site_id'] as int?,
      status: json['status'] as String,
      lastSeen: lastSeenRaw == null ? null : DateTime.parse(lastSeenRaw as String),
      color: json['color'] as String?,
      idlePowerThresholdW: (json['idle_power_threshold_w'] as num?)?.toDouble(),
      idleCurrentThresholdA:
          (json['idle_current_threshold_a'] as num?)?.toDouble(),
      idleDurationSeconds: json['idle_duration_seconds'] as int?,
      notificationsEnabled: json['notifications_enabled'] as bool? ?? true,
      createdAt: createdAtRaw == null
          ? null
          : DateTime.parse(createdAtRaw as String),
    );
  }

  final int id;
  final String name;
  final String deviceId;
  final int? siteId;
  final String status;
  final DateTime? lastSeen;
  final String? color;
  final double? idlePowerThresholdW;
  final double? idleCurrentThresholdA;
  final int? idleDurationSeconds;
  final bool notificationsEnabled;
  final DateTime? createdAt;

  bool get isOnline => status == 'online';
}

class SensorPlacementRecord {
  const SensorPlacementRecord({
    this.siteId,
    this.siteName,
    this.workshopId,
    this.workshopName,
    required this.assignedAt,
    this.assignedByLogin,
  });

  factory SensorPlacementRecord.fromJson(Map<String, dynamic> json) {
    return SensorPlacementRecord(
      siteId: json['site_id'] as int?,
      siteName: json['site_name'] as String?,
      workshopId: json['workshop_id'] as int?,
      workshopName: json['workshop_name'] as String?,
      assignedAt: DateTime.parse(json['assigned_at'] as String),
      assignedByLogin: json['assigned_by_login'] as String?,
    );
  }

  final int? siteId;
  final String? siteName;
  final int? workshopId;
  final String? workshopName;
  final DateTime assignedAt;
  final String? assignedByLogin;
}

class SensorAuditInfo {
  const SensorAuditInfo({
    required this.id,
    required this.name,
    required this.deviceId,
    required this.createdAt,
    this.createdByLogin,
    this.currentSiteId,
    this.currentSiteName,
    this.currentWorkshopId,
    this.currentWorkshopName,
    this.color,
    required this.placementHistory,
  });

  factory SensorAuditInfo.fromJson(Map<String, dynamic> json) {
    return SensorAuditInfo(
      id: json['id'] as int,
      name: json['name'] as String,
      deviceId: json['device_id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      createdByLogin: json['created_by_login'] as String?,
      currentSiteId: json['current_site_id'] as int?,
      currentSiteName: json['current_site_name'] as String?,
      currentWorkshopId: json['current_workshop_id'] as int?,
      currentWorkshopName: json['current_workshop_name'] as String?,
      color: json['color'] as String?,
      placementHistory: (json['placement_history'] as List<dynamic>? ?? [])
          .map((e) => SensorPlacementRecord.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  final int id;
  final String name;
  final String deviceId;
  final DateTime createdAt;
  final String? createdByLogin;
  final int? currentSiteId;
  final String? currentSiteName;
  final int? currentWorkshopId;
  final String? currentWorkshopName;
  final String? color;
  final List<SensorPlacementRecord> placementHistory;
}

class ProvisioningCredentials {
  const ProvisioningCredentials({
    required this.apiToken,
    required this.ingestUrl,
  });

  factory ProvisioningCredentials.fromJson(Map<String, dynamic> json) {
    return ProvisioningCredentials(
      apiToken: json['api_token'] as String,
      ingestUrl: json['ingest_url'] as String,
    );
  }

  final String apiToken;
  final String ingestUrl;
}

class SensorCreateResult {
  const SensorCreateResult({
    required this.sensor,
    required this.apiToken,
    required this.warning,
    required this.integration,
  });

  factory SensorCreateResult.fromJson(Map<String, dynamic> json) {
    return SensorCreateResult(
      sensor: Sensor.fromJson(json['sensor'] as Map<String, dynamic>),
      apiToken: json['api_token'] as String,
      warning: json['warning'] as String,
      integration: IntegrationSnippet.fromJson(
        json['integration'] as Map<String, dynamic>,
      ),
    );
  }

  final Sensor sensor;
  final String apiToken;
  final String warning;
  final IntegrationSnippet integration;
}

class IntegrationSnippet {
  const IntegrationSnippet({
    required this.method,
    required this.url,
    required this.headers,
    required this.bodySchema,
    required this.bodyExample,
    required this.curl,
  });

  factory IntegrationSnippet.fromJson(Map<String, dynamic> json) {
    return IntegrationSnippet(
      method: json['method'] as String,
      url: json['url'] as String,
      headers: Map<String, String>.from(json['headers'] as Map),
      bodySchema: Map<String, String>.from(
        (json['body_schema'] as Map).map(
          (key, value) => MapEntry(key.toString(), value.toString()),
        ),
      ),
      bodyExample: Map<String, dynamic>.from(json['body_example'] as Map),
      curl: json['curl'] as String,
    );
  }

  final String method;
  final String url;
  final Map<String, String> headers;
  final Map<String, String> bodySchema;
  final Map<String, dynamic> bodyExample;
  final String curl;

  String get copyText => [
        'URL: $method $url',
        'Headers:',
        ...headers.entries.map((e) => '  ${e.key}: ${e.value}'),
        'Body: ${bodyExample.toString()}',
        '',
        curl,
      ].join('\n');
}
