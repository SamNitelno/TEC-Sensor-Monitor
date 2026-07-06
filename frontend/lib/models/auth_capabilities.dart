class AuthCapabilities {
  const AuthCapabilities({
    required this.publicRegistration,
    required this.passwordReset,
  });

  final bool publicRegistration;
  final bool passwordReset;

  factory AuthCapabilities.fromJson(Map<String, dynamic> json) {
    return AuthCapabilities(
      publicRegistration: json['public_registration'] as bool? ?? false,
      passwordReset: json['password_reset'] as bool? ?? false,
    );
  }
}
