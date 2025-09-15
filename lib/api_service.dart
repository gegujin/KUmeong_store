// lib/api_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

/// ==========================
/// 1️⃣ API Base URL 자동 설정
String get apiBaseUrl {
  if (kIsWeb) {
    return "http://localhost:3000/api/v1"; // 맞음
  } else if (Platform.isAndroid) {
    return "http://10.0.2.2:3000/api/v1";
  } else if (Platform.isIOS) {
    return "http://localhost:3000/api/v1";
  } else {
    return "http://localhost:3000/api/v1"; // PC
  }
}

/// ==========================
/// 2️⃣ JWT 토큰 관리
/// ==========================
String? jwtToken;

Future<void> saveToken(String token) async {
  jwtToken = token;
  // 필요하면 SharedPreferences 등에 저장 가능
}

/// ==========================
/// 3️⃣ 회원가입
/// ==========================
Future<bool> register(String email, String password, String name) async {
  final uri = Uri.parse('$apiBaseUrl/auth/register');
  final response = await http.post(
    uri,
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({'email': email, 'password': password, 'name': name}),
  );

  print('[API] POST $uri -> ${response.statusCode} ${response.body}');
  return response.statusCode == 200 || response.statusCode == 201;
}

/// ==========================
/// 4️⃣ 로그인
/// ==========================
Future<String?> login(String email, String password) async {
  final uri = Uri.parse('$apiBaseUrl/auth/login');
  try {
    print('[API] POST $uri body: ${{"email": email, "password": "******"}}');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );

    print('[API] Response ${response.statusCode} -> ${response.body}');

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);

      // 안전하게 accessToken 추출
      String? token;
      if (decoded is Map<String, dynamic>) {
        if (decoded['accessToken'] != null) {
          token = decoded['accessToken'] as String;
        } else if (decoded['data'] is Map &&
            decoded['data']['accessToken'] != null) {
          token = decoded['data']['accessToken'] as String;
        }
      }

      if (token != null) {
        await saveToken(token);
        return token;
      } else {
        print('[API] 로그인 성공 응답이지만 accessToken을 찾지 못함');
        return null;
      }
    } else {
      print('[API] 로그인 실패: ${response.statusCode} ${response.body}');
      return null;
    }
  } catch (e) {
    print('[API] 로그인 예외: $e');
    return null;
  }
}

/// ==========================
/// 5️⃣ 상품 목록 조회 (JWT 불필요)
/// ==========================
Future<List<dynamic>> fetchProducts() async {
  final response = await http.get(Uri.parse('$apiBaseUrl/products'));
  if (response.statusCode == 200) {
    return jsonDecode(response.body);
  } else {
    throw Exception('Failed to load products: ${response.body}');
  }
}

/// ==========================
/// 6️⃣ 상품 등록 (JWT 필요)
/// ==========================
Future<bool> createProduct(Map<String, dynamic> productData) async {
  final response = await http.post(
    Uri.parse('$apiBaseUrl/products'),
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $jwtToken',
    },
    body: jsonEncode(productData),
  );
  print(
      '[API] POST $apiBaseUrl/products -> ${response.statusCode} ${response.body}');
  return response.statusCode == 201;
}

/// ==========================
/// 7️⃣ 상품 수정 (JWT 필요)
/// ==========================
Future<bool> updateProduct(int id, Map<String, dynamic> data) async {
  final response = await http.patch(
    Uri.parse('$apiBaseUrl/products/$id'),
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $jwtToken',
    },
    body: jsonEncode(data),
  );
  return response.statusCode == 200;
}

/// ==========================
/// 8️⃣ 상품 삭제 (JWT 필요)
/// ==========================
Future<bool> deleteProduct(int id) async {
  final response = await http.delete(
    Uri.parse('$apiBaseUrl/products/$id'),
    headers: {'Authorization': 'Bearer $jwtToken'},
  );
  return response.statusCode == 200;
}
