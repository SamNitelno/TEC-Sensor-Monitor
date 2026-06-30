import 'package:dio/dio.dart';
import 'package:tek_sensor_monitor/models/reading_point.dart';
import 'package:tek_sensor_monitor/models/sensor.dart';

class ApiClient {
  ApiClient({String baseUrl = 'http://localhost:8000'})
      : _dio = Dio(
          BaseOptions(
            baseUrl: baseUrl,
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 30),
            headers: {'Content-Type': 'application/json'},
          ),
        );

  final Dio _dio;

  Future<Map<String, dynamic>> health() async {
    final response = await _dio.get<Map<String, dynamic>>('/health');
    return response.data ?? {};
  }

  Future<List<Sensor>> fetchSensors() async {
    final response = await _dio.get<List<dynamic>>('/api/v1/sensors');
    final data = response.data ?? [];
    return data
        .map((item) => Sensor.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<ReadingsResponse> fetchReadings({
    required int sensorId,
    required DateTime from,
    required DateTime to,
    String? bucket,
  }) async {
    final query = <String, dynamic>{
      'from': from.toUtc().toIso8601String(),
      'to': to.toUtc().toIso8601String(),
      if (bucket != null) 'bucket': bucket,
    };
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/v1/sensors/$sensorId/readings',
      queryParameters: query,
    );
    return ReadingsResponse.fromJson(response.data ?? {});
  }
}
