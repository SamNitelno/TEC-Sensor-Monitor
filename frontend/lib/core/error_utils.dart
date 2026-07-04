import 'package:dio/dio.dart';

String friendlyApiError(Object error) {
  if (error is DioException) {
    switch (error.type) {
      case DioExceptionType.connectionError:
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Нет связи с сервером';
      case DioExceptionType.badResponse:
        final code = error.response?.statusCode;
        final detail = _extractDetail(error.response?.data);
        if (detail != null) return detail;
        if (code == 401) return 'Требуется вход';
        if (code == 403) return 'Недостаточно прав';
        return 'Ошибка сервера ($code)';
      default:
        return 'Ошибка сети';
    }
  }
  return 'Ошибка загрузки';
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
