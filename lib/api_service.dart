// lib/api_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/base_url.dart';           // ✅ 절대 URL 빌더 사용
import 'models/post.dart';

// -------------------------------
// 공통 유틸
// -------------------------------
String _normalizeEmail(String email) => email.trim().toLowerCase();
Map<String, String> get _jsonHeaders => {'Content-Type': 'application/json'};

T? _get<T>(Object? obj, String key) {
  if (obj is Map) {
    final v = obj[key];
    return (v is T) ? v : null;
  }
  return null;
}

/// 서버 응답이 JSON이 아닐 경우 즉시 원인 노출
Map<String, dynamic> _parseJsonResponse(http.Response resp) {
  final ct = resp.headers['content-type'] ?? '';
  if (!ct.contains('application/json')) {
    final head = resp.body.length > 200 ? resp.body.substring(0, 200) : resp.body;
    throw FormatException('Non-JSON response (${resp.statusCode} $ct) :: $head');
  }
  final decoded = jsonDecode(resp.body);
  if (decoded is Map<String, dynamic>) return decoded;
  throw FormatException('JSON root is not an object');
}

// -------------------------------
// 🔑 로그인
// -------------------------------
Future<String?> login(String email, String password) async {
  final url = apiUrl('/auth/login');  // ✅ 절대 URL

  try {
    final resp = await http.post(
      url,
      headers: _jsonHeaders,
      body: jsonEncode({
        'email': _normalizeEmail(email),
        'password': password,
      }),
    );

    final body = _parseJsonResponse(resp);
    final data = _get<Map>(body, 'data') ?? body;

    if (resp.statusCode == 200) {
      final token =
          _get<String>(data, 'accessToken') ?? _get<String>(body, 'accessToken');
      if (token != null && token.isNotEmpty) return token;
      debugPrint('[API] 로그인 실패: accessToken 없음. resp=${resp.body}');
      return null;
    }

    final msg = _get<Map>(body, 'error')?['message'] ?? resp.body;
    debugPrint('[API] 로그인 실패 ${resp.statusCode}: $msg');
    return null;
  } catch (e, st) {
    debugPrint('[API] 로그인 예외: $e\n$st');
    return null;
  }
}

// -------------------------------
// 📝 회원가입
// -------------------------------
Future<String?> register(
  String email,
  String password,
  String name, {
  String? univToken,
}) async {
  final url = apiUrl('/auth/register');  // ✅

  try {
    final payload = <String, dynamic>{
      'email': _normalizeEmail(email),
      'password': password,
      'name': name.trim(),
      if (univToken != null && univToken.isNotEmpty) 'univToken': univToken,
    };

    final resp = await http.post(url, headers: _jsonHeaders, body: jsonEncode(payload));
    final body = _parseJsonResponse(resp);
    final data = _get<Map>(body, 'data') ?? body;

    if (resp.statusCode == 200 || resp.statusCode == 201) {
      final token =
          _get<String>(data, 'accessToken') ?? _get<String>(body, 'accessToken');
      if (token != null && token.isNotEmpty) return token;
      debugPrint('[API] 회원가입 응답에 accessToken 없음. resp=${resp.body}');
      return null;
    }

    final msg = _get<Map>(body, 'error')?['message'] ?? resp.body;
    debugPrint('[API] 회원가입 실패 ${resp.statusCode}: $msg');
    return null;
  } catch (e, st) {
    debugPrint('[API] 회원가입 예외: $e\n$st');
    return null;
  }
}

// ---------------------------------------------------------
// 📦 상품 등록 (이미지 포함)
// ---------------------------------------------------------
Future<Map<String, dynamic>?> createProductWithImages(
  Map<String, dynamic> productData,
  List<dynamic> images,
  String token,
) async {
  final uri = apiUrl('/products');     // ✅
  final req = http.MultipartRequest('POST', uri);
  req.headers['Authorization'] = 'Bearer $token';

  for (final img in images) {
    try {
      if (img is XFile) {
        if (kIsWeb) {
          final bytes = await img.readAsBytes();
          req.files.add(http.MultipartFile.fromBytes(
            'images', bytes,
            filename: img.name,
            contentType: MediaType('image', _imgSubtype(img.name)),
          ));
        } else {
          req.files.add(await http.MultipartFile.fromPath(
            'images', img.path,
            contentType: MediaType('image', _imgSubtype(img.path)),
          ));
        }
      } else if (img is String) {
        req.files.add(await http.MultipartFile.fromPath(
          'images', img,
          contentType: MediaType('image', _imgSubtype(img)),
        ));
      } else {
        debugPrint('[API] 알 수 없는 이미지 타입: $img');
      }
    } catch (e) {
      debugPrint('[API] 이미지 처리 오류: $e');
    }
  }

  productData.forEach((k, v) {
    if (k != 'images' && v != null) req.fields[k] = v.toString();
  });

  try {
    final streamed = await req.send();
    final resp = await http.Response.fromStream(streamed);
    final ok = resp.statusCode == 200 || resp.statusCode == 201;
    if (ok) {
      final body = _parseJsonResponse(resp);
      final data = _get<Map>(body, 'data');
      if (data != null) return data.cast<String, dynamic>();
    }
    debugPrint('❌ [API] 상품 등록 실패: ${resp.statusCode} ${resp.body}');
    return null;
  } catch (e, st) {
    debugPrint('💥 [API] 상품 등록 예외: $e\n$st');
    return null;
  }
}

// ---------------------------------------------------------
// 🛠️ 상품 수정
// ---------------------------------------------------------
Future<Map<String, dynamic>?> updateProduct(
  String productId,
  Map<String, dynamic> productData,
  String token,
) async {
  final uri = apiUrl('/products/$productId'); // ✅
  final req = http.MultipartRequest('PUT', uri);
  req.headers['Authorization'] = 'Bearer $token';

  final images = productData['images'] as List<dynamic>?;
  if (images != null) {
    for (final img in images) {
      try {
        if (img is XFile) {
          if (kIsWeb) {
            final bytes = await img.readAsBytes();
            req.files.add(http.MultipartFile.fromBytes(
              'images', bytes,
              filename: img.name,
              contentType: MediaType('image', _imgSubtype(img.name)),
            ));
          } else {
            req.files.add(await http.MultipartFile.fromPath(
              'images', img.path,
              contentType: MediaType('image', _imgSubtype(img.path)),
            ));
          }
        } else if (img is String) {
          req.files.add(await http.MultipartFile.fromPath(
            'images', img,
            contentType: MediaType('image', _imgSubtype(img)),
          ));
        }
      } catch (e) {
        debugPrint('[API] 이미지 처리 오류: $e');
      }
    }
  }

  productData.forEach((k, v) {
    if (k != 'images' && v != null) req.fields[k] = v.toString();
  });

  try {
    final streamed = await req.send();
    final resp = await http.Response.fromStream(streamed);
    if (resp.statusCode == 200) {
      final body = _parseJsonResponse(resp);
      final data = _get<Map>(body, 'data');
      if (data != null) return data.cast<String, dynamic>();
    }
    debugPrint('❌ [API] 상품 수정 실패: ${resp.statusCode} ${resp.body}');
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
) async =>
    updateProduct(productId, productData, token);

// 이미지 MIME subtype 추론
String _imgSubtype(String pathOrName) {
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
// 📥 상품 리스트 조회
// -------------------------------------------
Future<List<Product>> fetchProducts(String token) async {
  final url = apiUrl('/products');    // ✅
  try {
    final resp = await http.get(url, headers: {'Authorization': 'Bearer $token'});
    if (resp.statusCode != 200) {
      debugPrint('[API] 상품 조회 실패: ${resp.statusCode} ${resp.body}');
      return [];
    }

    final decoded = _parseJsonResponse(resp);
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
