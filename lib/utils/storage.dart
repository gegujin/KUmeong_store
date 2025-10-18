// lib/utils/storage.dart
// Web과 Mobile을 직접 분기 없이 구현한 간단한 버전
// -> dart:html은 웹에서만 동작하므로 import는 파일 최상단에서 조건부로 쓰지 않음.
//    여기서는 dart:html을 직접 사용하되, 모바일에서는 사용되지 않도록 kIsWeb으로 보호합니다.

import 'dart:html' as html; // 웹 전용 API (kIsWeb로 보호)
import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:shared_preferences/shared_preferences.dart';

class TokenStorage {
  static Future<void> saveToken(String token) async {
    if (kIsWeb) {
      html.window.localStorage['token'] = token;
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', token);
  }

  static Future<String?> getToken() async {
    if (kIsWeb) {
      return html.window.localStorage['token'];
    }
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  static Future<void> clearToken() async {
    if (kIsWeb) {
      html.window.localStorage.remove('token');
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
  }
}
