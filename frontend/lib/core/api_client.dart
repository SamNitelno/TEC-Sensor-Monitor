import 'package:dio/dio.dart';
import 'package:tek_sensor_monitor/core/api_config.dart';
import 'package:tek_sensor_monitor/models/auth_session.dart';
import 'package:tek_sensor_monitor/models/reading_point.dart';
import 'package:tek_sensor_monitor/models/sensor.dart';
import 'package:tek_sensor_monitor/models/site.dart';

typedef TokenGetter = String? Function();

class ApiClient {
  ApiClient({
    String? baseUrl,
    TokenGetter? getToken,
  })  : _getToken = getToken,
        _dio = Dio(
          BaseOptions(
            baseUrl: baseUrl ?? defaultApiBaseUrl,
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 30),
            headers: {'Content-Type': 'application/json'},
          ),
        ) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final token = _getToken?.call();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
      ),
    );
  }

  final Dio _dio;
  final TokenGetter? _getToken;

  Future<AuthSession> login(String login, String password) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/v1/auth/login',
      data: {'login': login, 'password': password},
    );
    final data = response.data ?? {};
    return AuthSession(
      token: data['access_token'] as String,
      role: data['role'] as String,
      login: login,
    );
  }

  Future<List<Sensor>> fetchSensors({
    int? siteId,
    int? workshopId,
  }) async {
    final response = await _dio.get<List<dynamic>>(
      '/api/v1/sensors',
      queryParameters: {
        if (siteId != null) 'site_id': siteId,
        if (workshopId != null) 'workshop_id': workshopId,
      },
    );
    return (response.data ?? [])
        .map((item) => Sensor.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<SensorCreateResult> createSensor({
    required String name,
    required String deviceId,
    int? workshopId,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/v1/sensors',
      data: {
        'name': name,
        'device_id': deviceId,
        if (workshopId != null) 'workshop_id': workshopId,
      },
    );
    return SensorCreateResult.fromJson(response.data ?? {});
  }

  Future<Sensor> updateSensor(
    int id, {
    String? name,
    int? workshopId,
    bool clearWorkshop = false,
  }) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      '/api/v1/sensors/$id',
      data: {
        if (name != null) 'name': name,
        if (clearWorkshop) 'workshop_id': null,
        if (!clearWorkshop && workshopId != null) 'workshop_id': workshopId,
      },
    );
    return Sensor.fromJson(response.data ?? {});
  }

  Future<void> deleteSensor(int id) async {
    await _dio.delete<void>('/api/v1/sensors/$id');
  }

  Future<Sensor> fetchSensor(int id) async {
    final response = await _dio.get<Map<String, dynamic>>('/api/v1/sensors/$id');
    return Sensor.fromJson(response.data ?? {});
  }

  Future<ProvisioningCredentials> fetchProvisioningToken(int sensorId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/v1/sensors/$sensorId/provisioning-token',
    );
    return ProvisioningCredentials.fromJson(response.data ?? {});
  }

  Future<List<Site>> fetchSites() async {
    final response = await _dio.get<List<dynamic>>('/api/v1/sites');
    return (response.data ?? [])
        .map((item) => Site.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<Site> createSite(String name) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/v1/sites',
      data: {'name': name},
    );
    return Site.fromJson(response.data ?? {});
  }

  Future<void> deleteSite(int id) async {
    await _dio.delete<void>('/api/v1/sites/$id');
  }

  Future<List<Workshop>> fetchWorkshops({int? siteId}) async {
    final response = await _dio.get<List<dynamic>>(
      '/api/v1/workshops',
      queryParameters: {if (siteId != null) 'site_id': siteId},
    );
    return (response.data ?? [])
        .map((item) => Workshop.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<Workshop> createWorkshop({
    required String name,
    required int siteId,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/v1/workshops',
      data: {'name': name, 'site_id': siteId},
    );
    return Workshop.fromJson(response.data ?? {});
  }

  Future<void> deleteWorkshop(int id) async {
    await _dio.delete<void>('/api/v1/workshops/$id');
  }

  Future<GroupedReadingsResponse> fetchGroupedReadings({
    required DateTime from,
    required DateTime to,
    List<int>? sensorIds,
    int? siteId,
    int? workshopId,
    String? bucket,
  }) async {
    final query = <String, dynamic>{
      'from': from.toUtc().toIso8601String(),
      'to': to.toUtc().toIso8601String(),
      if (bucket != null) 'bucket': bucket,
      if (siteId != null) 'site_id': siteId,
      if (workshopId != null) 'workshop_id': workshopId,
      if (sensorIds != null && sensorIds.isNotEmpty)
        'sensor_ids': sensorIds,
    };
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/v1/readings',
      queryParameters: query,
    );
    return GroupedReadingsResponse.fromJson(response.data ?? {});
  }
}
