// lib/api_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode, debugPrint;
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
// import 'package:shared_preferences/shared_preferences.dart';
import 'package:kumeong_store/utils/storage.dart'; // ✅ TokenStorage 사용

import 'core/base_url.dart'; // ✅ 절대 URL 빌더
import 'models/post.dart';

// ---------------------------------------------------------
// 🧩 공통 유틸
// ---------------------------------------------------------
String _normalizeEmail(String email) => email.trim().toLowerCase();
Map<String, String> get _jsonHeaders => {'Content-Type': 'application/json'};

T? _get<T>(Object? obj, String key) {
  if (obj is Map) {
    final v = obj[key];
    return (v is T) ? v : null;
  }
  return null;
}

/// 서버 응답 JSON 검증
Map<String, dynamic> _parseJsonResponse(http.Response resp) {
  final ct = resp.headers['content-type'] ?? '';
  if (!ct.contains('application/json')) {
    final head =
        resp.body.length > 200 ? resp.body.substring(0, 200) : resp.body;
    throw FormatException(
        'Non-JSON response (${resp.statusCode} $ct) :: $head');
  }
  final decoded = jsonDecode(resp.body);
  if (decoded is Map<String, dynamic>) return decoded;
  throw FormatException('JSON root is not an object');
}

Future<String?> _getToken() => TokenStorage.getToken();

Map<String, String> _authHeaders(String token) => {
      'Authorization': 'Bearer $token',
    };

// ---------------------------------------------------------
// 🔑 로그인
// ---------------------------------------------------------
Future<String?> login(String email, String password) async {
  final url = apiUrl('/auth/login');
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
      final token = _get<String>(data, 'accessToken') ??
          _get<String>(body, 'accessToken');
      return token;
    }
    debugPrint('[API] 로그인 실패: ${resp.statusCode} ${resp.body}');
    return null;
  } catch (e, st) {
    debugPrint('[API] 로그인 예외: $e\n$st');
    return null;
  }
}

// ---------------------------------------------------------
// 📝 회원가입
// ---------------------------------------------------------
Future<String?> register(
  String email,
  String password,
  String name, {
  String? univToken,
}) async {
  final url = apiUrl('/auth/register');
  try {
    final payload = <String, dynamic>{
      'email': _normalizeEmail(email),
      'password': password,
      'name': name.trim(),
      if (univToken != null && univToken.isNotEmpty) 'univToken': univToken,
    };
    final resp =
        await http.post(url, headers: _jsonHeaders, body: jsonEncode(payload));
    final body = _parseJsonResponse(resp);
    final data = _get<Map>(body, 'data') ?? body;

    if (resp.statusCode == 200 || resp.statusCode == 201) {
      final token = _get<String>(data, 'accessToken') ??
          _get<String>(body, 'accessToken');
      return token;
    }
    debugPrint('[API] 회원가입 실패: ${resp.statusCode} ${resp.body}');
    return null;
  } catch (e, st) {
    debugPrint('[API] 회원가입 예외: $e\n$st');
    return null;
  }
}

// ---------------------------------------------------------
// 🧾 상품 등록 (Web/Mobile 완전 검증 통과 버전)
// ---------------------------------------------------------
Future<Map<String, dynamic>?> createProductWithImages(
  Map<String, dynamic> productData,
  List<dynamic> images,
  String token,
) async {
  final uri = apiUrl('/products');
  final req = http.MultipartRequest('POST', uri);
  req.headers['Authorization'] = 'Bearer $token';

  // ---------------------------------
  // 🖼 이미지 첨부
  // ---------------------------------
  for (final img in images) {
    try {
      if (img is XFile) {
        if (kIsWeb) {
          final bytes = await img.readAsBytes();
          req.files.add(http.MultipartFile.fromBytes(
            'images',
            bytes,
            filename: img.name,
            contentType: MediaType('image', _imgSubtype(img.name)),
          ));
        } else {
          req.files.add(await http.MultipartFile.fromPath(
            'images',
            img.path,
            contentType: MediaType('image', _imgSubtype(img.path)),
          ));
        }
      } else if (img is String) {
        req.files.add(await http.MultipartFile.fromPath(
          'images',
          img,
          contentType: MediaType('image', _imgSubtype(img)),
        ));
      }
    } catch (e) {
      debugPrint('[API] 💥 이미지 처리 오류: $e');
    }
  }

  // ---------------------------------
  // 📦 필드 매핑 (서버가 받는 키로 정규화)
  // ---------------------------------
  // title
  final title = productData['title']?.toString().trim();
  if (title != null && title.isNotEmpty) req.fields['title'] = title;

  // priceWon (문자/쉼표 허용)
  final rawPrice =
      (productData['priceWon'] ?? productData['price'])?.toString();
  final priceNum = rawPrice == null
      ? 0
      : int.tryParse(rawPrice.replaceAll(RegExp(r'[, ]'), '')) ?? 0;
  req.fields['priceWon'] = priceNum.toString();

  // description / category
  final desc = productData['description']?.toString().trim();
  if (desc?.isNotEmpty == true) req.fields['description'] = desc!;
  final category = productData['category']?.toString().trim();
  if (category?.isNotEmpty == true) req.fields['category'] = category!;

  // ✅ locationText (location으로 들어오면 자동 매핑)
  final locationText = (productData['locationText'] ??
          (productData['location'] is String ? productData['location'] : null))
      ?.toString()
      .trim();
  if (locationText != null && locationText.isNotEmpty) {
    req.fields['locationText'] = locationText;
  }

  // status (LISTED/RESERVED/SOLD 등)
  final status = productData['status']?.toString().trim();
  if (status?.isNotEmpty == true) req.fields['status'] = status!;

  if (kDebugMode) {
    debugPrint('🧾 전송 필드(create): ${req.fields}');
    debugPrint('🖼 첨부 이미지 수: ${req.files.length}');
  }

  // ---------------------------------
  // 🚀 요청 전송
  // ---------------------------------
  try {
    final streamed = await req.send();
    final resp = await http.Response.fromStream(streamed);

    final ok = resp.statusCode == 200 || resp.statusCode == 201;
    if (ok) {
      final body = _parseJsonResponse(resp);
      final data = _get<Map>(body, 'data');
      if (kDebugMode) debugPrint('✅ 상품 등록 성공: ${data?['id'] ?? '-'}');
      return data?.cast<String, dynamic>();
    }

    debugPrint('❌ [API] 상품 등록 실패 ${resp.statusCode}: ${resp.body}');
    return null;
  } catch (e, st) {
    debugPrint('💥 [API] 상품 등록 예외: $e\n$st');
    return null;
  }
}

// ---------------------------------------------------------
// ✏️ 상품 수정 (이미지 포함)
// ---------------------------------------------------------
Future<Map<String, dynamic>?> updateProductWithImages(
  String productId,
  Map<String, dynamic> productData,
  List<dynamic> images,
  String token,
) async {
  final uri = apiUrl('/products/$productId');
  final req = http.MultipartRequest('PATCH', uri); // ✅ PATCH로 변경
  req.headers['Authorization'] = 'Bearer $token';

  // 🖼 이미지 첨부
  for (final img in images) {
    try {
      if (img is XFile) {
        if (kIsWeb) {
          final bytes = await img.readAsBytes();
          req.files.add(http.MultipartFile.fromBytes(
            'images',
            bytes,
            filename: img.name,
            contentType: MediaType('image', _imgSubtype(img.name)),
          ));
        } else {
          req.files.add(await http.MultipartFile.fromPath(
            'images',
            img.path,
            contentType: MediaType('image', _imgSubtype(img.path)),
          ));
        }
      } else if (img is String) {
        req.files.add(await http.MultipartFile.fromPath(
          'images',
          img,
          contentType: MediaType('image', _imgSubtype(img)),
        ));
      }
    } catch (e) {
      debugPrint('[API] 이미지 첨부 오류: $e');
    }
  }

  // 📦 필드 매핑
  final title = productData['title']?.toString().trim();
  if (title?.isNotEmpty == true) req.fields['title'] = title!;

  final rawPrice =
      (productData['priceWon'] ?? productData['price'])?.toString();
  if (rawPrice != null) {
    final priceNum =
        int.tryParse(rawPrice.replaceAll(RegExp(r'[, ]'), '')) ?? 0;
    req.fields['priceWon'] = priceNum.toString();
  }

  final desc = productData['description']?.toString().trim();
  if (desc?.isNotEmpty == true) req.fields['description'] = desc!;
  final category = productData['category']?.toString().trim();
  if (category?.isNotEmpty == true) req.fields['category'] = category!;

  // ✅ locationText 매핑
  final locationText = (productData['locationText'] ??
          (productData['location'] is String ? productData['location'] : null))
      ?.toString()
      .trim();
  if (locationText != null && locationText.isNotEmpty) {
    req.fields['locationText'] = locationText;
  }

  final status = productData['status']?.toString().trim();
  if (status?.isNotEmpty == true) req.fields['status'] = status!;

  if (kDebugMode) {
    debugPrint('🧾 전송 필드(update): ${req.fields}');
    debugPrint('🖼 첨부 이미지 수: ${req.files.length}');
  }

  try {
    final streamed = await req.send();
    final resp = await http.Response.fromStream(streamed);

    final ok = resp.statusCode == 200 || resp.statusCode == 201;
    final body = _parseJsonResponse(resp);

    if (ok) {
      final data = _get<Map>(body, 'data');
      debugPrint('✅ 상품 수정 성공');
      return data?.cast<String, dynamic>();
    } else {
      debugPrint('❌ 상품 수정 실패: ${resp.statusCode} ${resp.body}');
    }
  } catch (e, st) {
    debugPrint('💥 상품 수정 예외: $e\n$st');
  }

  return null;
}

// ---------------------------------------------------------
// 🧭 이미지 MIME 추론
// ---------------------------------------------------------
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

// ---------------------------------------------------------
// 📥 상품 리스트 조회 (카테고리/검색/페이지 지원)
// ---------------------------------------------------------
Future<List<Product>> fetchProducts(
  String token, {
  String? category,
  String? query,
  int page = 1,
  int limit = 20,
  String? sortField, // 'createdAt' | 'price' | 'title'
  String? order, // 'ASC' | 'DESC'
}) async {
  final params = <String, String>{
    'page': '$page',
    'limit': '$limit',
  };
  if (category != null && category.isNotEmpty) params['category'] = category;
  if (query != null && query.isNotEmpty) params['query'] = query;
  // ✅ 서버 검증을 통과하는 값만 전송
  const allowedSort = {'createdAt', 'price', 'title'};
  const allowedOrder = {'ASC', 'DESC'};
  if (sortField != null && allowedSort.contains(sortField)) {
    params['sort'] = sortField;
  }
  if (order != null && allowedOrder.contains(order)) {
    params['order'] = order;
  }

  final base = apiUrl('/products');
  final url = base.replace(queryParameters: params);

  try {
    final resp =
        await http.get(url, headers: {'Authorization': 'Bearer $token'});
    if (resp.statusCode != 200) {
      // 🔁 방어적 재시도: sort/order로 400나면 정렬 제거 후 한 번 더
      final body = resp.body;
      final isSortError = resp.statusCode == 400 &&
          body.contains('"sort"') &&
          body.contains('must be one of');
      if (isSortError &&
          (params.containsKey('sort') || params.containsKey('order'))) {
        final retryParams = Map<String, String>.from(params)
          ..remove('sort')
          ..remove('order');
        final retryUrl = base.replace(queryParameters: retryParams);
        final retry = await http
            .get(retryUrl, headers: {'Authorization': 'Bearer $token'});
        if (retry.statusCode == 200) {
          final decoded = _parseJsonResponse(retry);
          final raw = decoded['data'];
          final items = _normalizeItems(raw);
          return items.map((e) => Product.fromJson(e)).toList();
        }
      }
      debugPrint('[API] 상품 조회 실패: ${resp.statusCode} ${resp.body}');
      return [];
    }

    final decoded = _parseJsonResponse(resp);
    final raw = decoded['data'];
    final items = _normalizeItems(raw);

    return items
        .whereType<Map<String, dynamic>>()
        .map((e) => Product.fromJson(e))
        .toList();
  } catch (e, st) {
    debugPrint('[API] 상품 조회 예외: $e\n$st');
    return [];
  }
}

List<dynamic> _normalizeItems(dynamic raw) {
  if (raw == null) return const [];
  if (raw is List) return raw;
  if (raw is Map<String, dynamic>) {
    if (raw['items'] is List) return raw['items'] as List;
    if (raw['rows'] is List) return raw['rows'] as List;
    return [raw];
  }
  return const [];
}

// ---------------------------------------------------------
// ❤️ Favorites (관심목록)
// ---------------------------------------------------------

/// 내 관심상품 목록 가져오기
/// 반환: { items: [...], total, page, limit } 또는 null(실패/비로그인)
Future<Map<String, dynamic>?> fetchMyFavorites({
  int page = 1,
  int limit = 50,
}) async {
  final token = await _getToken();
  if (token == null || token.isEmpty) return null;

  final url = apiUrl('/favorites').replace(queryParameters: {
    'page': '$page',
    'limit': '$limit',
  });

  try {
    final resp = await http.get(url, headers: _authHeaders(token));
    if (resp.statusCode != 200) {
      debugPrint('[API] 즐겨찾기 목록 실패: ${resp.statusCode} ${resp.body}');
      return null;
    }
    final body = _parseJsonResponse(resp);
    final data = _get<Map>(body, 'data') ??
        body; // { ok:true, data:{...} } 또는 { items:... }
    final items = _get<List>(data, 'items') ?? const [];
    final total = _get<num>(data, 'total') ?? 0;
    final pg = _get<num>(data, 'page') ?? page;
    final lm = _get<num>(data, 'limit') ?? limit;

    return {
      'items': items,
      'total': total is num ? total.toInt() : 0,
      'page': pg is num ? pg.toInt() : page,
      'limit': lm is num ? lm.toInt() : limit,
    };
  } catch (e, st) {
    debugPrint('[API] 즐겨찾기 목록 예외: $e\n$st');
    return null;
  }
}

/// 특정 상품 하트 토글. 성공 시 서버의 “다음 상태”(true=하트됨) 반환, 실패/비로그인 시 null.
Future<bool?> toggleFavoriteById(String productId) async {
  final token = await _getToken();
  if (token == null || token.isEmpty) return null;

  final url = apiUrl('/favorites/$productId/toggle');

  try {
    final resp = await http.post(url, headers: _authHeaders(token));

    // ✅ 2xx 전체를 성공으로 처리 (200, 201, 204 등)
    final ok = resp.statusCode >= 200 && resp.statusCode < 300;
    if (!ok) {
      debugPrint('[API] 즐겨찾기 토글 실패: ${resp.statusCode} ${resp.body}');
      return null;
    }

    // ✅ 204 No Content 같은 경우 바디가 없으므로 바로 처리
    if ((resp.contentLength ?? 0) == 0 || resp.body.isEmpty) {
      // 서버가 토글 후 바디를 안 주는 설계라면, 프런트에서 상태를 직접 반전시키도록
      // 호출부에서 이전 상태를 알고 있을 때만 유용하므로 여기서는 null 반환
      // (필요하면 true/false로 낙관적 처리 가능)
      return null;
    }

    // ✅ JSON 파싱 (서버가 { ok, isFavorited } 또는 { ok, data:{ isFavorited } } 둘 다 지원)
    final body = _parseJsonResponse(resp);
    final isFav = _get<bool>(body, 'isFavorited') ??
        _get<bool>(_get<Map>(body, 'data') ?? const {}, 'isFavorited');

    if (isFav == null) {
      // 형식이 다를 때 디버깅에 도움
      debugPrint('[API] 즐겨찾기 토글 응답에 isFavorited 없음: ${resp.body}');
    }

    return isFav;
  } catch (e, st) {
    debugPrint('[API] 즐겨찾기 토글 예외: $e\n$st');
    return null;
  }
}
