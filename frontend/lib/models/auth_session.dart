class AuthSession {
  const AuthSession({
    required this.token,
    required this.role,
    required this.login,
  });

  final String token;
  final String role;
  final String login;

  bool get isAdmin => role == 'admin';
}
