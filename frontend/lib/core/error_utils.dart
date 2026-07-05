import 'package:dio/dio.dart';
import 'package:tek_sensor_monitor/l10n/app_localizations.dart';

String friendlyApiError(Object error, AppLocalizations l10n) {
  if (error is DioException) {
    switch (error.type) {
      case DioExceptionType.connectionError:
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
        return l10n.errorNoConnection;
      case DioExceptionType.badResponse:
        final code = error.response?.statusCode;
        final detail = _extractDetail(error.response?.data);
        if (detail != null) {
          if (detail == 'Invalid login or password') {
            return l10n.errorInvalidCredentials;
          }
          if (detail == 'Wrong current password') {
            return l10n.errorWrongCurrentPassword;
          }
          return detail;
        }
        if (code == 401) return l10n.errorAuthRequired;
        if (code == 403) return l10n.errorForbidden;
        return l10n.errorServer(code ?? 0);
      default:
        return l10n.errorNetwork;
    }
  }
  return l10n.errorLoad;
}

String? _extractDetail(Object? data) {
  if (data is Map) {
    final detail = data['detail'];
    if (detail is String && detail.isNotEmpty) return detail;
    if (detail is List && detail.isNotEmpty) {
      final first = detail.first;
      if (first is Map && first['msg'] is String) {
        return first['msg'] as String;
      }
    }
  }
  return null;
}

bool isConnectionError(Object error) {
  if (error is! DioException) return false;
  return error.type == DioExceptionType.connectionError ||
      error.type == DioExceptionType.connectionTimeout ||
      error.type == DioExceptionType.receiveTimeout;
}
