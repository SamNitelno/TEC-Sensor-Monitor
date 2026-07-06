import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tek_sensor_monitor/core/error_utils.dart';
import 'package:tek_sensor_monitor/l10n/app_localizations_ru.dart';

void main() {
  test('404 maps to registration disabled message', () {
    final l10n = AppLocalizationsRu();
    final error = DioException(
      requestOptions: RequestOptions(path: '/api/v1/auth/register'),
      response: Response(
        requestOptions: RequestOptions(path: '/api/v1/auth/register'),
        statusCode: 404,
        data: {'detail': 'Not found'},
      ),
      type: DioExceptionType.badResponse,
    );
    expect(
      friendlyApiError(error, l10n),
      l10n.errorRegistrationDisabled,
    );
  });
}
