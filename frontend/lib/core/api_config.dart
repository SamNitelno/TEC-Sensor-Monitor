import 'package:flutter/foundation.dart';

/// API base URL. Override at build/run time:
/// `flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000`
const String apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://localhost:8000',
);

/// Android emulator alias for host machine localhost.
const String androidEmulatorApiBaseUrl = 'http://10.0.2.2:8000';

String get defaultApiBaseUrl {
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    return androidEmulatorApiBaseUrl;
  }
  return apiBaseUrl;
}
