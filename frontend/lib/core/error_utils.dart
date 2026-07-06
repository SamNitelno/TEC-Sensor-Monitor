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
          if (detail == 'Not found') {
            return l10n.errorRegistrationDisabled;
          }
          if (detail == 'Wrong current password') {
            return l10n.errorWrongCurrentPassword;
          }
          if (detail.contains('Функция в разработке') ||
              detail.contains('under development')) {
            return l10n.errorFeatureInDevelopment;
          }
          if (detail == 'Email already taken') {
            return l10n.errorEmailTaken;
          }
          if (detail == 'Phone already taken') {
            return l10n.errorPhoneTaken;
          }
          if (detail.contains('Too many') ||
              detail.contains('Слишком много')) {
            return l10n.errorRateLimited;
          }
          if (detail.contains('просроченный') ||
              detail.contains('Invalid verification') ||
              detail.contains('expired')) {
            return l10n.errorVerificationCodeInvalid;
          }
          if (detail.contains('Не удалось отправить') ||
              detail.contains('Could not send') ||
              detail.contains('не настроена')) {
            return l10n.errorDeliveryFailed;
          }
          return detail;
        }
        if (code == 401) return l10n.errorAuthRequired;
        if (code == 403) return l10n.errorForbidden;
        if (code == 404) return l10n.errorRegistrationDisabled;
        if (code == 429) return l10n.errorRateLimited;
        if (code == 503) return l10n.errorFeatureInDevelopment;
        if (code == 502) return l10n.errorDeliveryFailed;
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
