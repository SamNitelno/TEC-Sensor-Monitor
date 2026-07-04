import 'package:tek_sensor_monitor/models/user.dart';

class ContactSendCodesResult {
  const ContactSendCodesResult({
    required this.batchId,
    required this.step,
    this.destinationMasked,
    this.message,
    this.profile,
    this.accessToken,
  });

  factory ContactSendCodesResult.fromJson(Map<String, dynamic> json) {
    return ContactSendCodesResult(
      batchId: json['batch_id'] as String? ?? '',
      step: json['step'] as String? ?? 'complete',
      destinationMasked: json['destination_masked'] as String?,
      message: json['message'] as String?,
      profile: json['profile'] != null
          ? UserProfile.fromJson(json['profile'] as Map<String, dynamic>)
          : null,
      accessToken: json['access_token'] as String?,
    );
  }

  final String batchId;
  final String step;
  final String? destinationMasked;
  final String? message;
  final UserProfile? profile;
  final String? accessToken;
}

class ContactVerifyCodeResult {
  const ContactVerifyCodeResult({
    required this.step,
    this.destinationMasked,
    this.message,
    this.profile,
    this.accessToken,
  });

  factory ContactVerifyCodeResult.fromJson(Map<String, dynamic> json) {
    return ContactVerifyCodeResult(
      step: json['step'] as String? ?? 'complete',
      destinationMasked: json['destination_masked'] as String?,
      message: json['message'] as String?,
      profile: json['profile'] != null
          ? UserProfile.fromJson(json['profile'] as Map<String, dynamic>)
          : null,
      accessToken: json['access_token'] as String?,
    );
  }

  final String step;
  final String? destinationMasked;
  final String? message;
  final UserProfile? profile;
  final String? accessToken;
}
