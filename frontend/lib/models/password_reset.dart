class PasswordResetRequestResult {
  const PasswordResetRequestResult({
    required this.batchId,
    required this.destinationMasked,
    required this.message,
  });

  factory PasswordResetRequestResult.fromJson(Map<String, dynamic> json) {
    return PasswordResetRequestResult(
      batchId: json['batch_id'] as String? ?? '',
      destinationMasked: json['destination_masked'] as String? ?? '',
      message: json['message'] as String? ?? '',
    );
  }

  final String batchId;
  final String destinationMasked;
  final String message;
}
