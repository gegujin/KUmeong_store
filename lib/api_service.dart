// lib/api_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

const String baseUrl = 'http://localhost:3000/api/v1';
// ※ Android 에뮬레이터라면 10.0.2.2 사용 권장: http://10.0.2.2:3000/api/v1

/// 이메일 정규화: 공백 제거 + 소문자 변환
String _normalizeEmail(String email) => email.trim().toLowerCase();

Map<String, String> get _jsonHeaders => {'Content-Type': 'application/json'};

T? _get<T>(Map obj, String key) {
  final v = obj[key];
  return (v is T) ? v : null;
}

/// 로그인
/// - 성공 시 accessToken(String) 반환, 실패 시 null
Future<String?> login(String email, String password) async {
  final url = Uri.parse('$baseUrl/auth/login');
  final normalizedEmail = _normalizeEmail(email);

  try {
    final response = await http.post(
      url,
      headers: _jsonHeaders,
      body: jsonEncode({'email': normalizedEmail, 'password': password}),
    );

    final body = jsonDecode(response.body);
    final data = _get<Map>(body, 'data') ?? body;

    if (response.statusCode == 200) {
      final token = _get<String>(data, 'accessToken') ?? _get<String>(body, 'accessToken');
      if (token != null && token.isNotEmpty) return token;
      print('[API] 로그인 실패: accessToken 없음. resp=${response.body}');
      return null;
    } else {
      final msg = _get<Map>(body, 'error')?['message'] ?? response.body;
      print('[API] 로그인 실패 ${response.statusCode}: $msg');
      return null;
    }
  } catch (e) {
    print('[API] 로그인 예외: $e');
    return null;
  }
}

/// 회원가입
/// - 학교인증 강제(REQUIRE_UNIV_VERIFY=true)일 경우, univToken 필수
/// - 성공 시 accessToken(String) 반환, 실패 시 null
Future<String?> register(
  String email,
  String password,
  String name, {
  String? univToken, // ✅ 학교인증 토큰 전달
}) async {
  final url = Uri.parse('$baseUrl/auth/register');
  final normalizedEmail = _normalizeEmail(email);

  try {
    final payload = <String, dynamic>{
      'email': normalizedEmail,
      'password': password,
      'name': name.trim(),
      if (univToken != null && univToken.isNotEmpty) 'univToken': univToken,
    };

    final response = await http.post(
      url,
      headers: _jsonHeaders,
      body: jsonEncode(payload),
    );

    final body = jsonDecode(response.body);
    final data = _get<Map>(body, 'data') ?? body;

    // 백엔드가 200 또는 201을 반환할 수 있으므로 둘 다 성공 처리
    if (response.statusCode == 200 || response.statusCode == 201) {
      final token = _get<String>(data, 'accessToken') ?? _get<String>(body, 'accessToken');
      if (token != null && token.isNotEmpty) return token;

      // 혹시 래핑 구조에서 ok=true지만 토큰을 다른 키로 내려줄 수도 있으니 로그만 남김
      print('[API] 회원가입 응답에서 accessToken 없음. resp=${response.body}');
      return null;
    } else {
      final msg = _get<Map>(body, 'error')?['message'] ?? response.body;
      print('[API] 회원가입 실패 ${response.statusCode}: $msg');
      return null;
    }
  } catch (e) {
    print('[API] 회원가입 예외: $e');
    return null;
  }
}
