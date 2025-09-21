// import 'dart:convert';
// import 'package:flutter/foundation.dart' show kIsWeb;
// import 'package:http/http.dart' as http;

// String get _baseUrl {
//   if (kIsWeb) return 'http://localhost:3000/api/v1'; // Flutter Web용
//   return 'http://10.0.2.2:3000/api/v1'; // Android Emulator용
// }

// /// 로그인
// /// 성공 시 JWT access token 반환, 실패 시 null
// Future<String?> login(String email, String password) async {
//   final uri = Uri.parse('$_baseUrl/auth/login');

//   try {
//     final res = await http.post(
//       uri,
//       headers: {'Content-Type': 'application/json'},
//       body: jsonEncode({'email': email, 'password': password}),
//     );

//     if (res.statusCode == 200) {
//       final data = jsonDecode(res.body);
//       // API 구조에 맞춰 token 필드 확인
//       return data['accessToken'] ?? data['token'];
//     } else {
//       print('[API] 로그인 실패: ${res.statusCode} ${res.body}');
//       return null;
//     }
//   } catch (e) {
//     print('[API] 로그인 예외: $e');
//     return null;
//   }
// }
// lib/api_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

// ==============================
// ⚡ Flutter Web 로그인 POST 호출
// ==============================

/// 서버 기본 URL
/// Flutter Web에서 동작 시 localhost + NestJS 포트
const String baseUrl = 'http://localhost:3000/api/v1';

/// 로그인 함수
/// 성공 시 JWT 토큰 문자열 반환, 실패 시 null
Future<String?> login(String email, String password) async {
  final url = Uri.parse('$baseUrl/auth/login');

  try {
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'email': email,
        'password': password,
      }),
    );

    if (response.statusCode == 200) {
      // JSON 파싱 후 token 반환
      final data = jsonDecode(response.body);
      return data['accessToken'] ?? data['token']; // ✅ 두 케이스 모두 대응
    } else {
      // 실패 시 로그 출력
      print('[API] 로그인 실패 ${response.statusCode}: ${response.body}');
      return null;
    }
  } catch (e) {
    print('[API] 로그인 예외: $e');
    return null;
  }
}
