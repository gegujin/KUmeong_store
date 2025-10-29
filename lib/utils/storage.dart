// lib/utils/storage.dart
import 'package:shared_preferences/shared_preferences.dart';

class TokenStorage {
  static const _kAccess = 'accessToken';
  static const _kRefresh = 'refreshToken';

  /// 액세스/리프레시 동시 저장 (refreshToken은 null 가능)
  static Future<void> setTokens(String accessToken,
      {String? refreshToken}) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kAccess, accessToken);
    if (refreshToken != null && refreshToken.isNotEmpty) {
      await sp.setString(_kRefresh, refreshToken);
    }
  }

  /// 기존 호환: 액세스만 저장
  static Future<void> setToken(String token) => setTokens(token);

  static Future<String?> getToken() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getString(_kAccess);
  }

  static Future<String?> getRefresh() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getString(_kRefresh);
  }

  static Future<void> removeToken() async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_kAccess);
  }

  static Future<void> clearAll() async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_kAccess);
    await sp.remove(_kRefresh);
  }

  // ===== 호환용 별칭 (기존 코드 유지용)
  static Future<void> saveToken(String token) => setTokens(token);
  static Future<void> clearToken() => clearAll();
}
