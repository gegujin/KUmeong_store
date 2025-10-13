// lib/api_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart'; // MediaType
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kumeong_store/models/post.dart';

// 🔹 서버 주소
// - 기본은 localhost:3000
// - 안드로이드 에뮬레이터는 10.0.2.2 사용 권장 (필요 시 baseUrl만 바꾸면 됨)
const String baseUrl = 'http://localhost:3000/api/v1';
// const String baseUrl = 'http://10.0.2.2:3000/api/v1'; // ← 에뮬레이터일 때 사용

String _normalizeEmail(String email) => email.trim().toLowerCase();

Map<String, String> get _jsonHeaders => {'Content-Type': 'application/json'};

T? _get<T>(Object? obj, String key) {
  if (obj is Map) {
    final v = obj[key];
    return (v is T) ? v : null;
  }
  return null;
}

// -------------------------------
// 🔑 로그인: 성공 시 accessToken 반환
// -------------------------------
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
      final token =
          _get<String>(data, 'accessToken') ?? _get<String>(body, 'accessToken');
      if (token != null && token.isNotEmpty) {
        // 저장은 호출부(LoginPage)에서 하도록 유지 (원한다면 여기서 저장해도 됨)
        return token;
      }
      debugPrint('[API] 로그인 실패: accessToken 없음. resp=${response.body}');
      return null;
    }

    final msg = _get<Map>(body, 'error')?['message'] ?? response.body;
    debugPrint('[API] 로그인 실패 ${response.statusCode}: $msg');
    return null;
  } catch (e, st) {
    debugPrint('[API] 로그인 예외: $e\n$st');
    return null;
  }
}

// -------------------------------------------
// 📝 회원가입: (옵션) univToken 포함 가능
// 성공 시 accessToken 반환
// -------------------------------------------
Future<String?> register(
  String email,
  String password,
  String name, {
  String? univToken,
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

    if (response.statusCode == 200 || response.statusCode == 201) {
      final token =
          _get<String>(data, 'accessToken') ?? _get<String>(body, 'accessToken');
      if (token != null && token.isNotEmpty) {
        return token;
      }
      debugPrint('[API] 회원가입 응답에 accessToken 없음. resp=${response.body}');
      return null;
    }

    final msg = _get<Map>(body, 'error')?['message'] ?? response.body;
    debugPrint('[API] 회원가입 실패 ${response.statusCode}: $msg');
    return null;
  } catch (e, st) {
    debugPrint('[API] 회원가입 예외: $e\n$st');
    return null;
  }
}

// ---------------------------------------------------------
// 📦 상품 등록 (이미지 포함)
// - images: List<dynamic> (XFile 또는 경로(String)) 지원
// - 웹: XFile.readAsBytes → fromBytes
// - 그 외: fromPath(img.path 또는 경로 문자열)
// ---------------------------------------------------------
Future<Map<String, dynamic>?> createProductWithImages(
  Map<String, dynamic> productData,
  List<dynamic> images,
  String token,
) async {
  final uri = Uri.parse('$baseUrl/products');
  final request = http.MultipartRequest('POST', uri);
  request.headers['Authorization'] = 'Bearer $token';

  for (final img in images) {
    try {
      if (img is XFile) {
        if (kIsWeb) {
          final bytes = await img.readAsBytes();
          request.files.add(
            http.MultipartFile.fromBytes(
              'images',
              bytes,
              filename: img.name,
              contentType: MediaType('image', _getImageSubtype(img.name)),
            ),
          );
        } else {
          request.files.add(
            await http.MultipartFile.fromPath(
              'images',
              img.path,
              contentType: MediaType('image', _getImageSubtype(img.path)),
            ),
          );
        }
      } else if (img is String) {
        request.files.add(
          await http.MultipartFile.fromPath(
            'images',
            img,
            contentType: MediaType('image', _getImageSubtype(img)),
          ),
        );
      } else {
        debugPrint('[API] 알 수 없는 이미지 타입: $img');
      }
    } catch (e) {
      debugPrint('[API] 이미지 처리 오류: $e');
    }
  }

  // 나머지 필드 세팅
  productData.forEach((k, v) {
    if (k != 'images' && v != null) {
      request.fields[k] = v.toString();
    }
  });

  try {
    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body);
      if (data is Map && data['ok'] == true && data['data'] != null) {
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

// ---------------------------------------------------------
// 🛠️ 상품 수정 (이미지 포함 로직 동일)
// ---------------------------------------------------------
Future<Map<String, dynamic>?> updateProduct(
  String productId,
  Map<String, dynamic> productData,
  String token,
) async {
  final uri = Uri.parse('$baseUrl/products/$productId');
  final request = http.MultipartRequest('PUT', uri);
  request.headers['Authorization'] = 'Bearer $token';

  final images = productData['images'] as List<dynamic>?;
  if (images != null) {
    for (final img in images) {
      try {
        if (img is XFile) {
          if (kIsWeb) {
            final bytes = await img.readAsBytes();
            request.files.add(
              http.MultipartFile.fromBytes(
                'images',
                bytes,
                filename: img.name,
                contentType: MediaType('image', _getImageSubtype(img.name)),
              ),
            );
          } else {
            request.files.add(
              await http.MultipartFile.fromPath(
                'images',
                img.path,
                contentType: MediaType('image', _getImageSubtype(img.path)),
              ),
            );
          }
        } else if (img is String) {
          request.files.add(
            await http.MultipartFile.fromPath(
              'images',
              img,
              contentType: MediaType('image', _getImageSubtype(img)),
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
    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data is Map && data['ok'] == true && data['data'] != null) {
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

// ProductEditScreen alias
Future<Map<String, dynamic>?> updateProductApi(
  String productId,
  Map<String, dynamic> productData,
  String token,
) async {
  return updateProduct(productId, productData, token);
}

// 이미지 MIME subtype 추론
String _getImageSubtype(String pathOrName) {
  final ext = pathOrName.split('.').last.toLowerCase();
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

// -------------------------------------------
// 📥 상품 리스트 조회 (견고한 파싱)
// -------------------------------------------
Future<List<Product>> fetchProducts(String token) async {
  final url = Uri.parse('$baseUrl/products');
  try {
    final response = await http.get(url, headers: {'Authorization': 'Bearer $token'});

    if (response.statusCode != 200) {
      debugPrint('[API] 상품 조회 실패: ${response.statusCode} ${response.body}');
      return [];
    }

    final decoded = jsonDecode(response.body);
    if (decoded == null || decoded is! Map<String, dynamic>) {
      debugPrint('[API] 상품 조회: 응답 형식이 Map이 아님 -> $decoded');
      return [];
    }

    final raw = decoded['data'];
    List<dynamic> items;

    if (raw == null) {
      items = [];
    } else if (raw is List) {
      items = raw;
    } else if (raw is Map<String, dynamic>) {
      if (raw['rows'] is List) {
        items = raw['rows'] as List<dynamic>;
      } else if (raw['items'] is List) {
        items = raw['items'] as List<dynamic>;
      } else if (raw['products'] is List) {
        items = raw['products'] as List<dynamic>;
      } else if (raw['list'] is List) {
        items = raw['list'] as List<dynamic>;
      } else {
        items = [raw];
      }
    } else {
      items = [];
    }

    return items
        .whereType<Map<String, dynamic>>()
        .map((e) => Product.fromJson(e))
        .toList();
  } catch (e, st) {
    debugPrint('[API] 상품 조회 예외: $e\n$st');
    return [];
  }
}
