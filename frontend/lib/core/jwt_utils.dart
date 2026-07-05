import 'dart:convert';

/// Decode JWT exp claim without verification.
int? jwtExpUnix(String? token) {
  if (token == null || token.isEmpty) return null;
  final parts = token.split('.');
  if (parts.length < 2) return null;
  try {
    var payload = parts[1];
    final mod = payload.length % 4;
    if (mod > 0) payload += '=' * (4 - mod);
    final decoded = utf8.decode(base64Url.decode(payload));
    final map = jsonDecode(decoded) as Map<String, dynamic>;
    final exp = map['exp'];
    return exp is int ? exp : (exp as num?)?.toInt();
  } catch (_) {
    return null;
  }
}

bool isJwtExpired(String? token, {DateTime? now}) {
  final exp = jwtExpUnix(token);
  if (exp == null) return false;
  final nowSec = (now ?? DateTime.now()).millisecondsSinceEpoch ~/ 1000;
  return nowSec >= exp;
}
