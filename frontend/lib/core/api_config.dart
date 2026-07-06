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

/// Maps host LAN IPs to [10.0.2.2] so the Android emulator reaches the dev machine.
String resolveApiBaseUrl(String configured) {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
    return configured;
  }
  final uri = Uri.parse(configured);
  if (isPrivateLanHost(uri.host)) {
    return uri.replace(host: '10.0.2.2').toString();
  }
  return configured;
}

String get defaultApiBaseUrl {
  final configured = apiBaseUrl != _defaultApiBaseUrl
      ? apiBaseUrl
      : (!kIsWeb && defaultTargetPlatform == TargetPlatform.android
          ? androidEmulatorApiBaseUrl
          : apiBaseUrl);
  return resolveApiBaseUrl(configured);
}

/// WebSocket URL derived from [defaultApiBaseUrl] (same host, ws/wss scheme).
String buildWebSocketUrl(String token) {
  final base = Uri.parse(defaultApiBaseUrl);
  final wsScheme = base.scheme == 'https' ? 'wss' : 'ws';
  return Uri(
    scheme: wsScheme,
    host: base.host,
    port: base.hasPort ? base.port : null,
    path: '/ws',
    queryParameters: {'token': token},
  ).toString();
}
