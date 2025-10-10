// lib/api_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:kumeong_store/models/post.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http_parser/http_parser.dart'; // MediaType
import 'dart:html' as html; // Web localStorage

// 🔹 서버 주소
const String baseUrl = 'http://localhost:3000/api/v1';

String _normalizeEmail(String email) => email.trim().toLowerCase();

/// 🔑 회원가입 API (서버 경로 수정)
Future<String?> register(String email, String password, String name) async {
  // 🔹 서버에서 실제 회원가입 경로로 수정
  final url = Uri.parse('$baseUrl/auth/register'); // 기존 signup -> register
  try {
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(
        {'email': email.trim(), 'password': password, 'name': name.trim()},
      ),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final token = data['data']?['accessToken'] as String?;
      if (token != null) {
        if (kIsWeb) {
          html.window.localStorage['accessToken'] = token;
        } else {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('accessToken', token);
        }
        debugPrint('[API] 회원가입 성공, 토큰 저장 ✅');
      }
      return token;
    } else {
      debugPrint('[API] 회원가입 실패: ${response.statusCode} ${response.body}');
      return null;
    }
  } catch (e) {
    debugPrint('[API] 회원가입 예외: $e');
    return null;
  }
}

/// 🔹 로그인
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
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final token = data['data']?['accessToken'] as String?;
      if (token != null) {
        if (kIsWeb) {
          html.window.localStorage['accessToken'] = token;
        } else {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('accessToken', token);
        }
        debugPrint('[API] 로그인 성공, 토큰 저장 완료 ✅');
      }
      return token;
    }
    debugPrint('[API] 로그인 실패: ${response.statusCode} ${response.body}');
    return null;
  } catch (e) {
    debugPrint('[API] 로그인 예외: $e');
    return null;
  }
}

/// 🔹 상품 등록 (이미지 포함)
Future<Map<String, dynamic>?> createProductWithImages(
    Map<String, dynamic> productData,
    List<dynamic> images,
    String token) async {
  final uri = Uri.parse('$baseUrl/products');
  final request = http.MultipartRequest('POST', uri);
  request.headers['Authorization'] = 'Bearer $token';

  for (var img in images) {
    try {
      if (kIsWeb && img is XFile) {
        final bytes = await img.readAsBytes();
        request.files.add(
          http.MultipartFile.fromBytes(
            'images',
            bytes,
            filename: img.name,
            contentType: MediaType('image', _getImageSubtype(img.name)),
          ),
        );
      } else if (!kIsWeb && img is File) {
        final mimeType = _getImageSubtype(img.path);
        request.files.add(
          await http.MultipartFile.fromPath(
            'images',
            img.path,
            contentType: MediaType('image', mimeType),
          ),
        );
      }
    } catch (e) {
      debugPrint('[API] 이미지 처리 오류: $e');
    }
  }

  productData.forEach((k, v) {
    if (k != 'images' && v != null) {
      request.fields[k] = v.toString();
    }
  });

  try {
    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data['ok'] == true && data['data'] != null) {
        debugPrint('✅ [API] 상품 등록 성공: ${data['data']}');
        return data['data'] as Map<String, dynamic>;
      }
    }
    debugPrint('❌ [API] 상품 등록 실패: ${response.statusCode} ${response.body}');
    return null;
  } catch (e, st) {
    debugPrint('💥 [API] 상품 등록 예외: $e\n$st');
    return null;
  }
}

/// 🔹 상품 수정
Future<Map<String, dynamic>?> updateProduct(
    String productId, Map<String, dynamic> productData, String token) async {
  final uri = Uri.parse('$baseUrl/products/$productId');
  final request = http.MultipartRequest('PUT', uri);
  request.headers['Authorization'] = 'Bearer $token';

  final images = productData['images'] as List<dynamic>?;
  if (images != null) {
    for (var img in images) {
      try {
        if (kIsWeb && img is XFile) {
          final bytes = await img.readAsBytes();
          request.files.add(
            http.MultipartFile.fromBytes(
              'images',
              bytes,
              filename: img.name,
              contentType: MediaType('image', _getImageSubtype(img.name)),
            ),
          );
        } else if (!kIsWeb && img is File) {
          final mimeType = _getImageSubtype(img.path);
          request.files.add(
            await http.MultipartFile.fromPath(
              'images',
              img.path,
              contentType: MediaType('image', mimeType),
            ),
          );
        }
      } catch (e) {
        debugPrint('[API] 이미지 처리 오류: $e');
      }
    }
  }

  productData.forEach((k, v) {
    if (k != 'images' && v != null) {
      request.fields[k] = v.toString();
    }
  });

  try {
    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data['ok'] == true && data['data'] != null) {
        debugPrint('✅ [API] 상품 수정 성공: ${data['data']}');
        return data['data'] as Map<String, dynamic>;
      }
    }
    debugPrint('❌ [API] 상품 수정 실패: ${response.statusCode} ${response.body}');
    return null;
  } catch (e, st) {
    debugPrint('💥 [API] 상품 수정 예외: $e\n$st');
    return null;
  }
}

/// 🔹 ProductEditScreen용
Future<Map<String, dynamic>?> updateProductApi(
    String productId, Map<String, dynamic> productData, String token) async {
  return updateProduct(productId, productData, token);
}

/// 🔹 이미지 타입 확인
String _getImageSubtype(String path) {
  final ext = path.split('.').last.toLowerCase();
  switch (ext) {
    case 'jpg':
    case 'jpeg':
      return 'jpeg';
    case 'png':
      return 'png';
    case 'gif':
      return 'gif';
    default:
      return 'jpeg';
  }
}

/// 🔹 상품 조회 (robust parsing)
Future<List<Product>> fetchProducts(String token) async {
  final url = Uri.parse('$baseUrl/products');
  try {
    final response = await http.get(
      url,
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode != 200) {
      debugPrint('[API] 상품 조회 실패: ${response.statusCode} ${response.body}');
      return [];
    }

    final decoded = jsonDecode(response.body);

    if (decoded == null) {
      debugPrint('[API] 상품 조회: 빈 응답');
      return [];
    }

    // 안전하게 Map으로 취급
    if (decoded is! Map<String, dynamic>) {
      debugPrint('[API] 상품 조회: 응답이 Map이 아님 -> $decoded');
      return [];
    }

    final Map<String, dynamic> dataMap = decoded as Map<String, dynamic>;
    final raw = dataMap['data'];

    List<dynamic> productsJson = [];

    if (raw == null) {
      // data가 비어있음
      productsJson = [];
    } else if (raw is List) {
      // 가장 간단한 케이스: data가 바로 리스트
      productsJson = raw;
    } else if (raw is Map<String, dynamic>) {
      // data가 Map인 경우: 여러 API 패턴 대응
      if (raw.containsKey('rows') && raw['rows'] is List) {
        productsJson = raw['rows'] as List<dynamic>;
      } else if (raw.containsKey('items') && raw['items'] is List) {
        productsJson = raw['items'] as List<dynamic>;
      } else if (raw.containsKey('products') && raw['products'] is List) {
        productsJson = raw['products'] as List<dynamic>;
      } else if (raw.containsKey('list') && raw['list'] is List) {
        productsJson = raw['list'] as List<dynamic>;
      } else {
        // data가 단일 객체(상품 하나)일 수 있으니 단일 요소 리스트로 감싸기
        productsJson = [raw];
      }
    } else {
      // 그 외 타입이면 빈 리스트로 처리
      productsJson = [];
    }

    // map -> Product (방어적으로 타입 검사)
    final List<Product> products = productsJson
        .where((e) => e is Map<String, dynamic>)
        .map((e) => Product.fromJson(e as Map<String, dynamic>))
        .toList();

    return products;
  } catch (e, st) {
    debugPrint('[API] 상품 조회 예외: $e\n$st');
    return [];
  }
}
