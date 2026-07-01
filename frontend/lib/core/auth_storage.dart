import 'package:shared_preferences/shared_preferences.dart';

class AuthStorage {
  AuthStorage(this._prefs);

  final SharedPreferences _prefs;

  static const _tokenKey = 'auth_token';
  static const _roleKey = 'auth_role';
  static const _loginKey = 'auth_login';

  String? get token => _prefs.getString(_tokenKey);
  String? get role => _prefs.getString(_roleKey);
  String? get login => _prefs.getString(_loginKey);

  bool get isAuthenticated => token != null && token!.isNotEmpty;
  bool get isAdmin => role == 'admin';

  Future<void> saveSession({
    required String token,
    required String role,
    required String login,
  }) async {
    await _prefs.setString(_tokenKey, token);
    await _prefs.setString(_roleKey, role);
    await _prefs.setString(_loginKey, login);
  }

  Future<void> clear() async {
    await _prefs.remove(_tokenKey);
    await _prefs.remove(_roleKey);
    await _prefs.remove(_loginKey);
  }

  static Future<AuthStorage> create() async {
    final prefs = await SharedPreferences.getInstance();
    return AuthStorage(prefs);
  }
}
