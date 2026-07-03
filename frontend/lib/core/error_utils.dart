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
        if (code == 401) return 'Требуется вход';
        if (code == 403) return 'Недостаточно прав';
        return 'Ошибка сервера ($code)';
      default:
        return 'Ошибка сети';
    }
  }
  return 'Ошибка загрузки';
}

bool isConnectionError(Object error) {
  if (error is! DioException) return false;
  return error.type == DioExceptionType.connectionError ||
      error.type == DioExceptionType.connectionTimeout ||
      error.type == DioExceptionType.receiveTimeout;
}
