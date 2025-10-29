// lib/utils/storage.dart
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show debugPrint;

class TokenStorage {
  static const _key = 'accessToken';
  static const _legacyKeys = ['token', 'jwt', 'authToken'];
  static const _sessionKey = 'session.v1'; // JSON {"accessToken": "..."}

  static Future<void> setToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, token);
  }

  // 호환: 예전 이름
  static Future<void> saveToken(String token) => setToken(token);

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();

    // 1) 표준 위치
    final v = prefs.getString(_key);
    if (v != null && v.isNotEmpty) return v;

    // 2) 레거시 키들 (plain string)
    for (final k in _legacyKeys) {
      final legacy = prefs.getString(k);
      if (legacy != null && legacy.isNotEmpty) {
        debugPrint('[TokenStorage] migrate legacy "$k" → "$_key"');
        await prefs.setString(_key, legacy);
        for (final kk in _legacyKeys) {
          await prefs.remove(kk);
        }
        return legacy;
      }
    }

    // 3) session.v1(JSON) 마이그레이션
    final raw = prefs.getString(_sessionKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        // {"accessToken":"..."} 형태만 간단 추출
        final idx = raw.indexOf('"accessToken"');
        if (idx >= 0) {
          final after = raw.substring(idx);
          final sep = after.indexOf(':');
          if (sep > 0) {
            final part = after.substring(sep + 1);
            final q1 = part.indexOf('"');
            final q2 = part.indexOf('"', q1 + 1);
            if (q1 >= 0 && q2 > q1) {
              final token = part.substring(q1 + 1, q2);
              if (token.isNotEmpty) {
                debugPrint('[TokenStorage] migrate $_sessionKey → "$_key"');
                await prefs.setString(_key, token);
                await prefs.remove(_sessionKey);
                return token;
              }
            }
          }
        }
      } catch (_) {
        // 손상된 JSON이면 무시
      }
    }

    return null;
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  // 호환: 예전 이름
  static Future<void> clearToken() => clear();
}
