import 'dart:async';

import 'package:dio/dio.dart';

/// Session-scoped debug logging for agent investigations.
void agentDebugLog({
  required String location,
  required String message,
  required Map<String, dynamic> data,
  required String hypothesisId,
  String runId = 'pre-fix',
}) {
  final payload = {
    'sessionId': '8746e9',
    'timestamp': DateTime.now().millisecondsSinceEpoch,
    'location': location,
    'message': message,
    'data': data,
    'hypothesisId': hypothesisId,
    'runId': runId,
  };
  // #region agent log
  // Fire-and-forget; ignore ingest failures during local debug.
  unawaited(
    Dio()
        .post<void>(
          'http://127.0.0.1:7937/ingest/b28ec7a2-6b52-40c6-a193-e77f762c2310',
          data: payload,
          options: Options(
            headers: {'X-Debug-Session-Id': '8746e9'},
            sendTimeout: const Duration(milliseconds: 500),
            receiveTimeout: const Duration(milliseconds: 500),
          ),
        )
        .then((_) {}, onError: (_, __) {}),
  );
  // #endregion
}
