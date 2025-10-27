// lib/features/auth/login_service.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/network/http_client.dart'; // HttpX static 메서드 사용
import 'package:kumeong_store/core/utils/email.dart';

class LoginService {
  /// 로그인 성공 시 true 반환
  static Future<bool> login(String email, String password) async {
    try {
      final res = await HttpX.postJson('/auth/login', {
        'email': email.trim().toLowerCase(),
        'email': normalizeEmail(email),
        'password': password,
      });

      // 다양한 응답 포맷 대응: {accessToken} 또는 { ok, data: { accessToken } }
      String? token;
      if (res['accessToken'] is String) {
        token = res['accessToken'] as String;
      } else if (res['data'] is Map && (res['data'] as Map)['accessToken'] is String) {
        token = (res['data'] as Map)['accessToken'] as String;
      }

      if (token == null || token.isEmpty) return false;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('session.v1', jsonEncode({'accessToken': token}));
      return true;
    } catch (e) {
      // 네트워크/서버 오류
      // debugPrint로 바꿔도 됨
      print('❌ LoginService.login error: $e');
      return false;
    }
  }

  /// 내 정보 확인 (토큰 자동 주입 확인용)
  static Future<Map<String, dynamic>?> me() async {
    try {
      final res = await HttpX.get('/auth/me');
      // 서버가 { ok, data: {...} } 또는 비래핑 {...} 로 줄 수 있음
      if (res['data'] is Map) {
        return Map<String, dynamic>.from(res['data'] as Map);
      }
      return Map<String, dynamic>.from(res);
    } catch (e) {
      print('❌ LoginService.me error: $e');
      return null;
    }
  }

  /// 로그아웃 (로컬 세션 삭제)
  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('session.v1');
  }
}
