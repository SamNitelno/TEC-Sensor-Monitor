import 'package:tek_sensor_monitor/models/user.dart';

class AppNotification {
  const AppNotification({
    required this.id,
    required this.message,
    required this.kind,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as int,
      message: json['message'] as String,
      kind: json['kind'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  final int id;
  final String message;
  final String kind;
  final DateTime createdAt;

  bool get isRoleChange => kind == 'role_promoted' || kind == 'role_demoted';

  bool get isDowntime => kind == 'sensor_offline' || kind == 'sensor_idle';
}

class ProfileUpdateResult {
  const ProfileUpdateResult({
    required this.profile,
    this.accessToken,
  });

  factory ProfileUpdateResult.fromJson(Map<String, dynamic> json) {
    return ProfileUpdateResult(
      profile: UserProfile.fromJson(json['profile'] as Map<String, dynamic>),
      accessToken: json['access_token'] as String?,
    );
  }

  final UserProfile profile;
  final String? accessToken;
}
