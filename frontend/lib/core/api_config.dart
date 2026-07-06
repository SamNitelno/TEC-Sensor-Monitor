import 'package:flutter/foundation.dart';

/// API base URL. Override at build/run time:
/// `flutter run --dart-define=API_BASE_URL=https://192.168.0.181`
const String _defaultApiBaseUrl = 'http://localhost:8000';

const String apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: _defaultApiBaseUrl,
);

/// Android emulator alias for host machine localhost (dev docker on :8000).
const String androidEmulatorApiBaseUrl = 'http://10.0.2.2:8000';

/// Placeholder shown in server URL input fields.
const String apiBaseUrlPlaceholder = 'https://192.168.0.181';

bool isPrivateLanHost(String host) {
  if (host == 'localhost' || host == '10.0.2.2' || host == '127.0.0.1') {
    return false;
  }
  final parts = host.split('.');
  if (parts.length != 4) return false;
  final octets = <int>[];
  for (final part in parts) {
    final value = int.tryParse(part);
    if (value == null || value < 0 || value > 255) return false;
    octets.add(value);
  }
  final a = octets[0];
  final b = octets[1];
  if (a == 10) return true;
  if (a == 172 && b >= 16 && b <= 31) return true;
  if (a == 192 && b == 168) return true;
  return false;
}

/// On Android emulator only: map host localhost to [10.0.2.2].
/// Real LAN IPs and hostnames are passed through for physical devices.
String resolveApiBaseUrl(String configured) {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
    return configured;
  }
  final uri = Uri.parse(configured);
  if (uri.host == 'localhost' || uri.host == '127.0.0.1') {
    return uri.replace(host: '10.0.2.2').toString();
  }
  return configured;
}

String platformDefaultApiBaseUrl() {
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    return androidEmulatorApiBaseUrl;
  }
  return _defaultApiBaseUrl;
}

/// Priority: [savedUrl] → dart-define → platform default.
String computeApiBaseUrl({String? savedUrl}) {
  final String configured;
  if (savedUrl != null && savedUrl.isNotEmpty) {
    configured = savedUrl;
  } else if (apiBaseUrl != _defaultApiBaseUrl) {
    configured = apiBaseUrl;
  } else {
    configured = platformDefaultApiBaseUrl();
  }
  return resolveApiBaseUrl(configured);
}

/// Sync fallback before preferences load (no saved URL).
String get defaultApiBaseUrl => computeApiBaseUrl();

/// Returns null when valid; otherwise a validation error key (`empty` / `invalid`).
String? validateApiBaseUrlInput(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return 'empty';
  final Uri uri;
  try {
    uri = Uri.parse(trimmed);
  } catch (_) {
    return 'invalid';
  }
  if (uri.scheme != 'http' && uri.scheme != 'https') return 'invalid';
  if (uri.host.isEmpty) return 'invalid';
  if (uri.userInfo.isNotEmpty) return 'invalid';
  return null;
}

String normalizeApiBaseUrl(String raw) {
  var value = raw.trim();
  while (value.endsWith('/')) {
    value = value.substring(0, value.length - 1);
  }
  return value;
}

/// WebSocket URL derived from [baseUrl] (same host, ws/wss scheme).
String buildWebSocketUrl(String token, String baseUrl) {
  final base = Uri.parse(baseUrl);
  final wsScheme = base.scheme == 'https' ? 'wss' : 'ws';
  return Uri(
    scheme: wsScheme,
    host: base.host,
    port: base.hasPort ? base.port : null,
    path: '/ws',
    queryParameters: {'token': token},
  ).toString();
}
