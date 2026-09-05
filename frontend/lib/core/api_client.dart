import 'package:dio/dio.dart';
import 'package:tek_sensor_monitor/core/api_config.dart';
import 'package:tek_sensor_monitor/core/dio_http_client.dart';
import 'package:tek_sensor_monitor/models/auth_capabilities.dart';
import 'package:tek_sensor_monitor/models/auth_session.dart';
import 'package:tek_sensor_monitor/models/notification.dart';
import 'package:tek_sensor_monitor/models/contact_verification.dart';
import 'package:tek_sensor_monitor/models/downtime.dart';
import 'package:tek_sensor_monitor/models/reading_point.dart';
import 'package:tek_sensor_monitor/models/sensor.dart';
import 'package:tek_sensor_monitor/models/site.dart';
import 'package:tek_sensor_monitor/models/password_reset.dart';
import 'package:tek_sensor_monitor/models/user.dart';

typedef TokenGetter = String? Function();
typedef UnauthorizedHandler = void Function();

class ApiClient {
  ApiClient({
    String? baseUrl,
    TokenGetter? getToken,
    UnauthorizedHandler? onUnauthorized,
  })  : _getToken = getToken,
        _onUnauthorized = onUnauthorized,
        _dio = Dio(
          BaseOptions(
            baseUrl: baseUrl ?? defaultApiBaseUrl,
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 30),
            headers: {'Content-Type': 'application/json'},
          ),
        ) {
    configureDioHttpClient(_dio);
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final token = _getToken?.call();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) {
          if (error.response?.statusCode == 401) {
            final path = error.requestOptions.path;
            final isAuthAttempt = path.contains('/auth/login') ||
                path.contains('/auth/register');
            final token = _getToken?.call();
            if (!isAuthAttempt && token != null && token.isNotEmpty) {
              _onUnauthorized?.call();
            }
          }
          handler.next(error);
        },
      ),
    );
  }

  final Dio _dio;
  final TokenGetter? _getToken;
  final UnauthorizedHandler? _onUnauthorized;

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

  Future<AuthSession> register(String login, String password) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/v1/auth/register',
      data: {'login': login, 'password': password},
    );
    final data = response.data ?? {};
    return AuthSession(
      token: data['access_token'] as String,
      role: data['role'] as String,
      login: login,
    );
  }

  Future<bool> checkLoginAvailable(String login) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/v1/auth/check-login',
      queryParameters: {'login': login},
    );
    return response.data?['available'] as bool? ?? false;
  }

  Future<AuthCapabilities> fetchAuthCapabilities() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/v1/auth/capabilities',
    );
    return AuthCapabilities.fromJson(response.data ?? {});
  }

  Future<UserProfile> fetchProfile() async {
    final response = await _dio.get<Map<String, dynamic>>('/api/v1/auth/me');
    return UserProfile.fromJson(response.data ?? {});
  }

  Future<ProfileUpdateResult> updateProfile({
    String? login,
    String? email,
    bool clearEmail = false,
    String? phone,
    bool clearPhone = false,
  }) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      '/api/v1/auth/me',
      data: {
        if (login != null) 'login': login,
        if (email != null) 'email': email,
        if (clearEmail) 'clear_email': true,
        if (phone != null) 'phone': phone,
        if (clearPhone) 'clear_phone': true,
      },
    );
    return ProfileUpdateResult.fromJson(response.data ?? {});
  }

  Future<ContactSendCodesResult> sendContactVerificationCodes({
    String? login,
    String? email,
    bool clearEmail = false,
    String? phone,
    bool clearPhone = false,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/v1/auth/me/contact/send-codes',
      data: {
        if (login != null) 'login': login,
        if (email != null) 'email': email,
        if (clearEmail) 'clear_email': true,
        if (phone != null) 'phone': phone,
        if (clearPhone) 'clear_phone': true,
      },
    );
    return ContactSendCodesResult.fromJson(response.data ?? {});
  }

  Future<ContactVerifyCodeResult> verifyContactEmail({
    required String batchId,
    required String code,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/v1/auth/me/contact/verify-email',
      data: {'batch_id': batchId, 'code': code},
    );
    return ContactVerifyCodeResult.fromJson(response.data ?? {});
  }

  Future<ContactVerifyCodeResult> verifyContactPhone({
    required String batchId,
    required String code,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/v1/auth/me/contact/verify-phone',
      data: {'batch_id': batchId, 'code': code},
    );
    return ContactVerifyCodeResult.fromJson(response.data ?? {});
  }

  Future<UserProfile> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/v1/auth/me/password',
      data: {
        'current_password': currentPassword,
        'new_password': newPassword,
      },
    );
    return UserProfile.fromJson(response.data ?? {});
  }

  Future<PasswordResetRequestResult> requestPasswordReset({
    String? email,
    String? phone,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/v1/auth/password-reset/request',
      data: {
        if (email != null && email.isNotEmpty) 'email': email,
        if (phone != null && phone.isNotEmpty) 'phone': phone,
      },
    );
    return PasswordResetRequestResult.fromJson(response.data ?? {});
  }

  Future<void> confirmPasswordReset({
    required String batchId,
    required String code,
    required String newPassword,
  }) async {
    await _dio.post<Map<String, dynamic>>(
      '/api/v1/auth/password-reset/confirm',
      data: {
        'batch_id': batchId,
        'code': code,
        'new_password': newPassword,
      },
    );
  }

  Future<void> adminResetUserPassword({
    required int userId,
    required String newPassword,
  }) async {
    await _dio.post<Map<String, dynamic>>(
      '/api/v1/users/$userId/reset-password',
      data: {'new_password': newPassword},
    );
  }

  Future<List<UserListItem>> fetchUsers() async {
    final response = await _dio.get<List<dynamic>>('/api/v1/users');
    return (response.data ?? [])
        .map((item) => UserListItem.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<UserListItem> promoteUser(int userId) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/v1/users/$userId/promote',
    );
    return UserListItem.fromJson(
      (response.data ?? {})['user'] as Map<String, dynamic>,
    );
  }

  Future<UserListItem> demoteUser(int userId) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/v1/users/$userId/demote',
    );
    return UserListItem.fromJson(
      (response.data ?? {})['user'] as Map<String, dynamic>,
    );
  }

  Future<SensorAuditInfo> fetchSensorAudit(int sensorId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/v1/sensors/$sensorId/audit',
    );
    return SensorAuditInfo.fromJson(response.data ?? {});
  }

  Future<List<AppNotification>> fetchNotifications() async {
    final response = await _dio.get<List<dynamic>>('/api/v1/notifications');
    return (response.data ?? [])
        .map((item) => AppNotification.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> acknowledgeNotification(int id) async {
    await _dio.post<void>('/api/v1/notifications/$id/ack');
  }

  Future<int> fetchUnreadNotificationCount() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/v1/notifications/unread-count',
    );
    return (response.data?['count'] as num?)?.toInt() ?? 0;
  }

  Future<int> acknowledgeAllNotifications() async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/v1/notifications/ack-all',
    );
    return (response.data?['acknowledged'] as num?)?.toInt() ?? 0;
  }

  Future<int> setAllSensorNotifications({required bool enabled}) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/v1/sensors/notifications/bulk',
      data: {'enabled': enabled},
    );
    return (response.data?['updated'] as num?)?.toInt() ?? 0;
  }

  Future<int> setAllWorkshopNotifications({required bool enabled}) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/v1/workshops/notifications/bulk',
      data: {'enabled': enabled},
    );
    return (response.data?['updated'] as num?)?.toInt() ?? 0;
  }

  Future<int> setAllSiteNotifications({required bool enabled}) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/v1/sites/notifications/bulk',
      data: {'enabled': enabled},
    );
    return (response.data?['updated'] as num?)?.toInt() ?? 0;
  }

  Future<Map<String, int>> seedDemoReadings() async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/v1/sensors/seed-demo-readings',
    );
    return (response.data ?? {}).map(
      (key, value) => MapEntry(key, (value as num).toInt()),
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
    int? siteId,
    String? color,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/v1/sensors',
      data: {
        'name': name,
        'device_id': deviceId,
        if (siteId != null) 'site_id': siteId,
        if (color != null) 'color': color,
      },
    );
    return SensorCreateResult.fromJson(response.data ?? {});
  }

  Future<Sensor> updateSensor(
    int id, {
    String? name,
    int? siteId,
    bool clearSite = false,
    String? color,
    bool clearColor = false,
    double? idlePowerThresholdW,
    bool clearIdlePowerThreshold = false,
    double? idleCurrentThresholdA,
    bool clearIdleCurrentThreshold = false,
    int? idleDurationSeconds,
    bool clearIdleDuration = false,
    bool? notificationsEnabled,
  }) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      '/api/v1/sensors/$id',
      data: {
        if (name != null) 'name': name,
        if (clearSite) 'site_id': null,
        if (!clearSite && siteId != null) 'site_id': siteId,
        if (color != null) 'color': color,
        if (clearColor) 'clear_color': true,
        if (idlePowerThresholdW != null)
          'idle_power_threshold_w': idlePowerThresholdW,
        if (clearIdlePowerThreshold) 'clear_idle_power_threshold': true,
        if (idleCurrentThresholdA != null)
          'idle_current_threshold_a': idleCurrentThresholdA,
        if (clearIdleCurrentThreshold) 'clear_idle_current_threshold': true,
        if (idleDurationSeconds != null)
          'idle_duration_seconds': idleDurationSeconds,
        if (clearIdleDuration) 'clear_idle_duration': true,
        if (notificationsEnabled != null)
          'notifications_enabled': notificationsEnabled,
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

  /// Issues a new device token. The old one stops working immediately.
  Future<ProvisioningCredentials> rotateSensorToken(int sensorId) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/v1/sensors/$sensorId/rotate-token',
    );
    return ProvisioningCredentials.fromJson(response.data ?? {});
  }

  Future<List<Site>> fetchSites({int? workshopId}) async {
    final response = await _dio.get<List<dynamic>>(
      '/api/v1/sites',
      queryParameters: {if (workshopId != null) 'workshop_id': workshopId},
    );
    return (response.data ?? [])
        .map((item) => Site.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<Site> createSite({
    required String name,
    required int workshopId,
    String? color,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/v1/sites',
      data: {
        'name': name,
        'workshop_id': workshopId,
        if (color != null) 'color': color,
      },
    );
    return Site.fromJson(response.data ?? {});
  }

  Future<Site> updateSite(
    int id, {
    String? name,
    int? workshopId,
    String? color,
    bool clearColor = false,
    bool? notificationsEnabled,
  }) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      '/api/v1/sites/$id',
      data: {
        if (name != null) 'name': name,
        if (workshopId != null) 'workshop_id': workshopId,
        if (color != null) 'color': color,
        if (clearColor) 'clear_color': true,
        if (notificationsEnabled != null)
          'notifications_enabled': notificationsEnabled,
      },
    );
    return Site.fromJson(response.data ?? {});
  }

  Future<void> deleteSite(int id) async {
    await _dio.delete<void>('/api/v1/sites/$id');
  }

  Future<List<Workshop>> fetchWorkshops() async {
    final response = await _dio.get<List<dynamic>>('/api/v1/workshops');
    return (response.data ?? [])
        .map((item) => Workshop.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<Workshop> createWorkshop({
    required String name,
    String? color,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/api/v1/workshops',
      data: {
        'name': name,
        if (color != null) 'color': color,
      },
    );
    return Workshop.fromJson(response.data ?? {});
  }

  Future<Workshop> updateWorkshop(
    int id, {
    String? name,
    String? color,
    bool clearColor = false,
    bool? notificationsEnabled,
  }) async {
    final response = await _dio.patch<Map<String, dynamic>>(
      '/api/v1/workshops/$id',
      data: {
        if (name != null) 'name': name,
        if (color != null) 'color': color,
        if (clearColor) 'clear_color': true,
        if (notificationsEnabled != null)
          'notifications_enabled': notificationsEnabled,
      },
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

  Future<List<DowntimeEvent>> fetchDowntimeEvents({
    required DateTime from,
    required DateTime to,
    int? sensorId,
    int? siteId,
    int? workshopId,
    String? type,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/v1/downtime/events',
      queryParameters: {
        'from': from.toUtc().toIso8601String(),
        'to': to.toUtc().toIso8601String(),
        if (sensorId != null) 'sensor_id': sensorId,
        if (siteId != null) 'site_id': siteId,
        if (workshopId != null) 'workshop_id': workshopId,
        if (type != null) 'type': type,
      },
    );
    final events = response.data?['events'] as List<dynamic>? ?? [];
    return events
        .map((e) => DowntimeEvent.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<DowntimeSummary> fetchDowntimeSummary({
    required DateTime from,
    required DateTime to,
    int? sensorId,
    int? siteId,
    int? workshopId,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/api/v1/downtime/summary',
      queryParameters: {
        'from': from.toUtc().toIso8601String(),
        'to': to.toUtc().toIso8601String(),
        if (sensorId != null) 'sensor_id': sensorId,
        if (siteId != null) 'site_id': siteId,
        if (workshopId != null) 'workshop_id': workshopId,
      },
    );
    return DowntimeSummary.fromJson(response.data ?? {});
  }
}
