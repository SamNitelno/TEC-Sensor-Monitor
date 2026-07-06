import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tek_sensor_monitor/core/api_config.dart';
import 'package:tek_sensor_monitor/core/api_url_storage.dart';

final apiUrlStorageProvider = FutureProvider<ApiUrlStorage>((ref) async {
  return ApiUrlStorage.create();
});

class ApiBaseUrlNotifier extends AsyncNotifier<String> {
  @override
  Future<String> build() async {
    final storage = await ref.watch(apiUrlStorageProvider.future);
    return computeApiBaseUrl(savedUrl: storage.savedUrl);
  }

  Future<void> setUrl(String rawUrl) async {
    final normalized = normalizeApiBaseUrl(rawUrl);
    final storage = await ref.read(apiUrlStorageProvider.future);
    await storage.saveUrl(normalized);
    state = AsyncData(normalized);
  }
}

/// Resolved API base URL: saved preference → dart-define → platform default.
final apiBaseUrlProvider =
    AsyncNotifierProvider<ApiBaseUrlNotifier, String>(ApiBaseUrlNotifier.new);
