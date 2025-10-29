// lib/features/auth/login_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/network/http_client.dart'; // HttpX
import 'package:kumeong_store/core/utils/email.dart';
import 'package:kumeong_store/utils/storage.dart'; // ✅ TokenStorage

class LoginService {
  /// 내부: 다양한 응답 포맷에서 accessToken 추출
  static String? _extractAccessToken(Map<String, dynamic> res) {
    // 1) 최상위
    if (res['accessToken'] is String) return res['accessToken'] as String;

    // 2) data 래핑
    final data =
        (res['data'] is Map) ? Map<String, dynamic>.from(res['data']) : null;
    if (data != null) {
      if (data['accessToken'] is String) return data['accessToken'] as String;
      if (data['token'] is String) return data['token'] as String;
      if (data['jwt'] is String) return data['jwt'] as String;

      // 3) 흔한 nested 형식: { data: { tokens: { access: { token: '...' } } } }
      final tokens = (data['tokens'] is Map)
          ? Map<String, dynamic>.from(data['tokens'])
          : null;
      final access = (tokens?['access'] is Map)
          ? Map<String, dynamic>.from(tokens!['access'])
          : null;
      if (access != null && access['token'] is String)
        return access['token'] as String;
    }

    // 4) 다른 변형들
    if (res['token'] is String) return res['token'] as String;
    if (res['jwt'] is String) return res['jwt'] as String;

    return null;
  }

  /// 내부: session.v1 → TokenStorage로 1회 마이그레이션
  static Future<void> _migrateSessionV1IfNeeded() async {
    final prefs = await SharedPreferences.getInstance();

    // 이미 표준 위치(accessToken)에 있으면 패스
    final std = await TokenStorage.getToken();
    if (std != null && std.isNotEmpty) return;

    final raw = prefs.getString('session.v1');
    if (raw == null || raw.isEmpty) return;

    try {
      final m = jsonDecode(raw);
      if (m is Map && m['accessToken'] is String) {
        final legacy = m['accessToken'] as String;
        if (legacy.isNotEmpty) {
          await TokenStorage.setToken(legacy);
          debugPrint(
              '[LoginService] migrated session.v1 → TokenStorage(accessToken)');
        }
      }
    } catch (_) {
      // 무시 (손상된 JSON 등)
    }
  }

  /// 로그인 성공 시 true 반환
  static Future<bool> login(String email, String password) async {
    try {
      final res = await HttpX.postJson('/auth/login', {
        // ❗중복 키 제거 + 정규화
        'email': normalizeEmail(email),
        'password': password,
      });

      final token = _extractAccessToken(Map<String, dynamic>.from(res));
      if (token == null || token.isEmpty) return false;

      // ✅ 표준 저장소에 저장
      await TokenStorage.setToken(token);

      // (선택) 과거 호환: session.v1도 유지하면 기존 로직이 있어도 안전
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('session.v1', jsonEncode({'accessToken': token}));

      return true;
    } catch (e) {
      debugPrint('❌ LoginService.login error: $e');
      return false;
    }
  }

  /// 내 정보 확인 (토큰 자동 주입 확인용)
  static Future<Map<String, dynamic>?> me() async {
    try {
      // ✅ 먼저 레거시 세션을 표준 위치로 보정
      await _migrateSessionV1IfNeeded();

      final res = await HttpX.get('/auth/me');
      if (res is Map && res['data'] is Map) {
        return Map<String, dynamic>.from(res['data'] as Map);
      }
      return Map<String, dynamic>.from(res as Map);
    } catch (e) {
      debugPrint('❌ LoginService.me error: $e');
      return null;
    }
  }

  /// 로그아웃 (로컬 세션 삭제)
  static Future<void> logout() async {
    // ✅ 표준 저장 삭제
    await TokenStorage.clear();

    // ✅ 레거시 세션 삭제
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('session.v1');
  }
}
