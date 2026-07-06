import 'package:shared_preferences/shared_preferences.dart';

class ApiUrlStorage {
  ApiUrlStorage(this._prefs);

  final SharedPreferences _prefs;

  static const _key = 'api_base_url';

  String? get savedUrl {
    final value = _prefs.getString(_key);
    if (value == null || value.trim().isEmpty) return null;
    return value;
  }

  Future<void> saveUrl(String url) async {
    await _prefs.setString(_key, url);
  }

  static Future<ApiUrlStorage> create() async {
    final prefs = await SharedPreferences.getInstance();
    return ApiUrlStorage(prefs);
  }
}
