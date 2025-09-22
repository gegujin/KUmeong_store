import 'dart:convert';
import 'package:http/http.dart' as http;

const String baseUrl = 'http://localhost:3000/api/v1';

/// 로그인 함수
Future<String?> login(String email, String password) async {
  final url = Uri.parse('$baseUrl/auth/login');

  try {
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['data']['accessToken']; // AuthService 반환 구조에 맞춤
    } else {
      print('[API] 로그인 실패 ${response.statusCode}: ${response.body}');
      return null;
    }
  } catch (e) {
    print('[API] 로그인 예외: $e');
    return null;
  }
}
