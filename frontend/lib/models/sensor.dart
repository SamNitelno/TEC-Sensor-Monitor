class Sensor {
  const Sensor({
    required this.id,
    required this.name,
    required this.deviceId,
    required this.workshopId,
    required this.status,
    required this.lastSeen,
  });

  factory Sensor.fromJson(Map<String, dynamic> json) {
    final lastSeenRaw = json['last_seen'];
    return Sensor(
      id: json['id'] as int,
      name: json['name'] as String,
      deviceId: json['device_id'] as String,
      workshopId: json['workshop_id'] as int?,
      status: json['status'] as String,
      lastSeen: lastSeenRaw == null ? null : DateTime.parse(lastSeenRaw as String),
    );
  }

  final int id;
  final String name;
  final String deviceId;
  final int? workshopId;
  final String status;
  final DateTime? lastSeen;

  bool get isOnline => status == 'online';
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
