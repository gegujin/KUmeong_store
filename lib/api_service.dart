// lib/api_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

const String baseUrl = 'http://localhost:3000/api/v1';

/// 이메일 정규화: 공백 제거 + 소문자 변환
String _normalizeEmail(String email) => email.trim().toLowerCase();

/// 로그인
Future<String?> login(String email, String password) async {
  final url = Uri.parse('$baseUrl/auth/login');
  final normalizedEmail = _normalizeEmail(email);

  try {
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': normalizedEmail, 'password': password}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['ok'] == true) {
        return data['data']['accessToken']; // 서버 응답에 맞춰 조정
      } else {
        print('[API] 로그인 실패: ${data['error']['message']}');
        return null;
      }
    } else {
      print('[API] 로그인 실패 ${response.statusCode}: ${response.body}');
      return null;
    }
  } catch (e) {
    print('[API] 로그인 예외: $e');
    return null;
  }
}

/// 회원가입
Future<Map<String, dynamic>?> register(
    String email, String password, String name) async {
  final url = Uri.parse('$baseUrl/auth/register');
  final normalizedEmail = _normalizeEmail(email);

  try {
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': normalizedEmail,
        'password': password,
        'name': name.trim(),
      }),
    );

    if (response.statusCode == 201 || response.statusCode == 200) {
      final data = jsonDecode(response.body);

      if (data['ok'] == true) {
        // 가입한 유저 정보 반환
        return data['data'];
      } else {
        print('[API] 회원가입 실패: ${data['error']['message']}');
        return null;
      }
    } else {
      print('[API] 회원가입 실패 ${response.statusCode}: ${response.body}');
      return null;
    }
  } catch (e) {
    print('[API] 회원가입 예외: $e');
    return null;
  }
}
