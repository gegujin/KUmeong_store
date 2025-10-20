// lib/api_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode, debugPrint;
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kumeong_store/utils/storage.dart'; // ✅ TokenStorage 사용

import 'core/base_url.dart'; // ✅ 절대 URL 빌더
import 'models/post.dart';

const String baseUrl = 'http://localhost:3000/api/v1';

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
    if (resp.statusCode == 401) {
      // 화면에서 로그인 유도 가능하도록 구분
      throw Exception('401');
    }
    if (resp.statusCode != 200) {
      debugPrint('[API] 즐겨찾기 목록 실패: ${resp.statusCode} ${resp.body}');
      return null;
    }
    final body = _parseJsonResponse(resp);
    final data = _get<Map>(body, 'data') ??
        body; // { ok:true, data:{...} } or { items:... }
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

/// 내부 유틸: 서버 응답에서 isFavorited / favoriteCount 안전 추출
({bool? isFavorited, int? favoriteCount}) _readFavoritePayload(
    Map<String, dynamic> root) {
  final data = _get<Map>(root, 'data') ?? root;
  bool? fav = _get<bool>(data, 'isFavorited');
  int? cnt;
  final rawCnt = data['favoriteCount'];
  if (rawCnt is num) cnt = rawCnt.toInt();
  if (rawCnt is String && rawCnt.isNotEmpty) {
    cnt = int.tryParse(rawCnt.replaceAll(RegExp(r'[, ]'), ''));
  }
  return (isFavorited: fav, favoriteCount: cnt);
}

/// 토글 결과를 (상태, 카운트)로 리턴하는 타입
class FavoriteToggleResult {
  final bool isFavorited;
  final int? favoriteCount;
  FavoriteToggleResult(this.isFavorited, this.favoriteCount);
}

/// 특정 상품 하트 토글(상세). 성공 시 (isFavorited, favoriteCount) 반환.
/// 실패 시:
///  - 401 → Exception('401') throw (화면에서 로그인 유도)
///  - 그 외 → Exception('favorite-toggle-failed:...') throw
Future<FavoriteToggleResult> toggleFavoriteDetailed(String productId) async {
  final token = await _getToken();
  if (token == null || token.isEmpty) {
    throw Exception('401');
  }
  final url = apiUrl('/favorites/$productId/toggle');

  try {
    http.Response resp = await http.post(url, headers: _authHeaders(token));

    if (resp.statusCode == 401) {
      throw Exception('401');
    }

    // ✅ 404면 서버가 /favorites/:id/toggle를 지원하지 않을 수 있으니 폴백 시도
    if (resp.statusCode == 404) {
      final alt = apiUrl('/products/$productId/favorite');
      // 우선 POST 시도 (토글 의미의 엔드포인트일 수 있음)
      final altResp = await http.post(alt, headers: _authHeaders(token));
      if (altResp.statusCode == 401) throw Exception('401');
      if (altResp.statusCode >= 200 && altResp.statusCode < 300) {
        if ((altResp.contentLength ?? 0) == 0 || altResp.body.isEmpty) {
          // 바디가 없으면 상태/카운트는 알 수 없으므로 호출부의 낙관값 유지
          return FavoriteToggleResult(true, null);
        }
        final altBody = _parseJsonResponse(altResp);
        final parsed = _readFavoritePayload(altBody);
        final fav = parsed.isFavorited ?? true;
        return FavoriteToggleResult(fav, parsed.favoriteCount);
      }
      // POST가 405 등으로 막히면 DELETE도 시도 가능(선택)
      if (altResp.statusCode == 405) {
        final delResp = await http.delete(alt, headers: _authHeaders(token));
        if (delResp.statusCode == 401) throw Exception('401');
        if (delResp.statusCode >= 200 && delResp.statusCode < 300) {
          if ((delResp.contentLength ?? 0) == 0 || delResp.body.isEmpty) {
            return FavoriteToggleResult(false, null);
          }
          final delBody = _parseJsonResponse(delResp);
          final parsed = _readFavoritePayload(delBody);
          final fav = parsed.isFavorited ?? false;
          return FavoriteToggleResult(fav, parsed.favoriteCount);
        }
      }
      // 폴백도 실패 → 원래 에러로 보고
      throw Exception('favorite-toggle-failed:${resp.statusCode}:${resp.body}');
    }

    // ✅ 2xx 전체를 성공으로 처리 (200, 201, 204 등)
    final ok = resp.statusCode >= 200 && resp.statusCode < 300;
    if (!ok) {
      throw Exception('favorite-toggle-failed:${resp.statusCode}:${resp.body}');
    }

    // ✅ 204 No Content 같은 경우 바디가 없을 수 있음
    if ((resp.contentLength ?? 0) == 0 || resp.body.isEmpty) {
      // 상태/카운트는 알 수 없으므로 호출부의 낙관값을 유지하도록 null 카운트만 반환
      return FavoriteToggleResult(true, null);
    }

    // ✅ JSON 파싱 (서버가 { ok, isFavorited } 또는 { ok, data:{ isFavorited } } 둘 다 지원)
    final body = _parseJsonResponse(resp);
    final parsed = _readFavoritePayload(body);
    final fav = parsed.isFavorited ?? true; // 정보 없으면 보수적으로 true 가정
    return FavoriteToggleResult(fav, parsed.favoriteCount);
  } catch (e, st) {
    debugPrint('[API] 즐겨찾기 토글 예외: $e\n$st');
    rethrow;
  }
}

/// ✅ 호환용: 기존 시그니처를 유지하고 싶은 화면들을 위해 bool? 반환 버전
///  - 성공: true/false
///  - 401 또는 실패: null
Future<bool?> toggleFavoriteById(String productId) async {
  try {
    final res = await toggleFavoriteDetailed(productId);
    return res.isFavorited;
  } catch (e) {
    if ('$e' == 'Exception: 401') return null;
    return null;
  }
}

/// ✅ 필요 시: 관심목록을 바로 Product 리스트로 받고 싶을 때
Future<List<Product>> fetchMyFavoriteItems(
    {int page = 1, int limit = 50}) async {
  final m = await fetchMyFavorites(page: page, limit: limit);
  if (m == null) return const [];
  final items = (m['items'] as List?) ?? const [];
  return items
      .whereType<Map<String, dynamic>>()
      .map((e) => Product.fromJson(e))
      .toList();
}

// ---------------------------------------------------------
// 🔎 단건 상품 조회 (관심목록 즉시 반영용)
// ---------------------------------------------------------
Future<Product?> fetchProductById(String productId, {String? token}) async {
  final t = token ?? await _getToken();
  if (t == null || t.isEmpty) return null;
  final url = apiUrl('/products/$productId');
  try {
    final resp = await http.get(url, headers: _authHeaders(t));
    if (resp.statusCode != 200) {
      debugPrint('[API] 상품 단건 조회 실패: ${resp.statusCode} ${resp.body}');
      return null;
    }
    final body = _parseJsonResponse(resp);
    final data = _get<Map>(body, 'data') ?? body;
    return Product.fromJson(data.cast<String, dynamic>());
  } catch (e, st) {
    debugPrint('[API] 상품 단건 조회 예외: $e\n$st');
    return null;
  }
}
