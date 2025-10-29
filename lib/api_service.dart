// lib/api_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode, debugPrint;
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kumeong_store/utils/storage.dart'; // ✅ TokenStorage
import 'core/base_url.dart'; // ✅ apiUrl() 절대 URL 빌더
import 'models/post.dart';

const String baseUrl = 'http://localhost:3000/api/v1';

// 앱 어디서나 토큰을 공통 경로로 읽기 위한 헬퍼
Future<String?> getAccessToken() => TokenStorage.getToken();

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

Map<String, String> _authHeaders(String token, {bool json = false}) => {
      'Authorization': 'Bearer $token',
      if (json) 'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

// ---------------------------------------------------------
// 🔑 로그인 / 회원가입
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
// 🧾 상품 등록/수정 (Multipart)
// ---------------------------------------------------------
Future<Map<String, dynamic>?> createProductWithImages(
  Map<String, dynamic> productData,
  List<dynamic> images,
  String token,
) async {
  final uri = apiUrl('/products');
  final req = http.MultipartRequest('POST', uri);
  req.headers.addAll(_authHeaders(token));

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

  final title = productData['title']?.toString().trim();
  if (title != null && title.isNotEmpty) req.fields['title'] = title;

  final rawPrice =
      (productData['priceWon'] ?? productData['price'])?.toString();
  final priceNum = rawPrice == null
      ? 0
      : int.tryParse(rawPrice.replaceAll(RegExp(r'[, ]'), '')) ?? 0;
  req.fields['priceWon'] = priceNum.toString();

  final desc = productData['description']?.toString().trim();
  if (desc?.isNotEmpty == true) req.fields['description'] = desc!;
  final category = productData['category']?.toString().trim();
  if (category?.isNotEmpty == true) req.fields['category'] = category!;

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
    debugPrint('🧾 전송 필드(create): ${req.fields}');
    debugPrint('🖼 첨부 이미지 수: ${req.files.length}');
  }

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

Future<Map<String, dynamic>?> updateProductWithImages(
  String productId,
  Map<String, dynamic> productData,
  List<dynamic> images,
  String token,
) async {
  final uri = apiUrl('/products/$productId');
  final req = http.MultipartRequest('PATCH', uri);
  req.headers.addAll(_authHeaders(token));

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
// 📥 상품 리스트 조회
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
    final resp = await http.get(url, headers: _authHeaders(token));
    if (resp.statusCode != 200) {
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
        final retry = await http.get(retryUrl, headers: _authHeaders(token));
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
// 🏷️ 태그로 상품 리스트 조회
//  - fetchProductsByTagCards : 카드(Map) 포맷으로 반환 (toMapForHome 적용)
//  - fetchProductsByTag      : Product 객체 리스트로 반환
// ---------------------------------------------------------
Future<List<Map<String, dynamic>>> fetchProductsByTagCards({
  required String tag,
  int page = 1,
  int limit = 20,
  String? sortField, // 'createdAt' | 'price' | 'title'
  String? order, // 'ASC' | 'DESC'
}) async {
  final token = await _getToken();

  final params = <String, String>{
    'page': '$page',
    'limit': '$limit',
    'tag': tag, // 서버가 tags(복수)면 여기만 'tags'로 바꿔주면 됨
  };

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
    final headers = (token != null && token.isNotEmpty)
        ? _authHeaders(token)
        : {'Accept': 'application/json'};

    // 1차 호출
    http.Response resp = await http.get(url, headers: headers);

    // 정렬 파라미터 유효성 오류(400) 시 재시도 (정렬 제거)
    if (resp.statusCode != 200) {
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
        resp = await http.get(retryUrl, headers: headers);
      }
    }

    if (resp.statusCode != 200) {
      debugPrint('[API] 태그 상품 조회 실패: ${resp.statusCode} ${resp.body}');
      return const [];
    }

    final decoded = _parseJsonResponse(resp);
    final raw = decoded['data'];
    final items = _normalizeItems(raw);

    // Product -> 카드맵 포맷
    return items
        .whereType<Map<String, dynamic>>()
        .map((e) => Product.fromJson(e).toMapForHome())
        .toList();
  } catch (e, st) {
    debugPrint('[API] 태그 상품 조회 예외: $e\n$st');
    return const [];
  }
}

Future<List<Product>> fetchProductsByTag({
  required String tag,
  int page = 1,
  int limit = 20,
  String? sortField, // 'createdAt' | 'price' | 'title'
  String? order, // 'ASC' | 'DESC'
}) async {
  final token = await _getToken();
  final params = <String, String>{
    'page': '$page',
    'limit': '$limit',
    'tag': tag, // 서버가 tags(복수)면 여기만 'tags'로 바꿔
  };

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
    final headers = (token != null && token.isNotEmpty)
        ? _authHeaders(token)
        : {'Accept': 'application/json'};

    http.Response resp = await http.get(url, headers: headers);

    // 정렬 파라미터 오류 대응 재시도
    if (resp.statusCode != 200) {
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
        resp = await http.get(retryUrl, headers: headers);
      }
    }

    if (resp.statusCode != 200) {
      debugPrint('[API] 태그 상품(Product) 조회 실패: ${resp.statusCode} ${resp.body}');
      return const [];
    }

    final decoded = _parseJsonResponse(resp);
    final raw = decoded['data'];
    final items = _normalizeItems(raw);

    return items
        .whereType<Map<String, dynamic>>()
        .map((e) => Product.fromJson(e))
        .toList();
  } catch (e, st) {
    debugPrint('[API] 태그 상품(Product) 조회 예외: $e\n$st');
    return const [];
  }
}

// ---------------------------------------------------------
// ❤️ Favorites (관심목록)
// ---------------------------------------------------------
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
      throw Exception('401');
    }
    // ✅ 서버에 아직 /favorites 목록 엔드포인트가 없을 때(404) → 빈 목록 처리
    if (resp.statusCode == 404) {
      debugPrint('[API] /favorites 목록 미구현(404) → 빈 목록으로 처리');
      return {'items': <dynamic>[], 'total': 0, 'page': page, 'limit': limit};
    }
    if (resp.statusCode != 200) {
      debugPrint('[API] 즐겨찾기 목록 실패: ${resp.statusCode} ${resp.body}');
      return null;
    }
    final body = _parseJsonResponse(resp);
    final data = _get<Map>(body, 'data') ?? body;
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

class FavoriteToggleResult {
  final bool isFavorited;
  final int? favoriteCount;
  FavoriteToggleResult(this.isFavorited, this.favoriteCount);
}

/// ✅ 우선 /products/:id/favorite → 실패 시 /favorites/:id/toggle
Future<FavoriteToggleResult> toggleFavoriteDetailed(String productId) async {
  final token = await _getToken();
  if (token == null || token.isEmpty) {
    throw Exception('401');
  }

  // 1) 제품 경로 먼저 시도
  final prodFav = apiUrl('/products/$productId/favorite');

  // 1-a) POST 토글 시도
  http.Response resp = await http.post(prodFav, headers: _authHeaders(token));
  if (resp.statusCode == 401 || resp.statusCode == 403) {
    throw Exception('401');
  }
  if (resp.statusCode >= 200 && resp.statusCode < 300) {
    if ((resp.contentLength ?? 0) == 0 || resp.body.isEmpty) {
      return FavoriteToggleResult(true, null); // 본문 없으면 낙관값 유지
    }
    final body = _parseJsonResponse(resp);
    final parsed = _readFavoritePayload(body);
    return FavoriteToggleResult(
        parsed.isFavorited ?? true, parsed.favoriteCount);
  }
  // 1-b) POST가 405면 DELETE로 언토글 시도(설계가 add/remove 분리인 경우)
  if (resp.statusCode == 405) {
    final del = await http.delete(prodFav, headers: _authHeaders(token));
    if (del.statusCode == 401 || del.statusCode == 403) throw Exception('401');
    if (del.statusCode >= 200 && del.statusCode < 300) {
      if ((del.contentLength ?? 0) == 0 || del.body.isEmpty) {
        return FavoriteToggleResult(false, null);
      }
      final body = _parseJsonResponse(del);
      final parsed = _readFavoritePayload(body);
      return FavoriteToggleResult(
          parsed.isFavorited ?? false, parsed.favoriteCount);
    }
  }

  // 2) 대체 경로: /favorites/:id/toggle
  final favToggle = apiUrl('/favorites/$productId/toggle');
  final alt = await http.post(favToggle, headers: _authHeaders(token));
  if (alt.statusCode == 401 || alt.statusCode == 403) throw Exception('401');
  if (alt.statusCode == 404) {
    throw Exception('favorite-toggle-failed:404');
  }
  if (alt.statusCode < 200 || alt.statusCode >= 300) {
    throw Exception('favorite-toggle-failed:${alt.statusCode}:${alt.body}');
  }
  if ((alt.contentLength ?? 0) == 0 || alt.body.isEmpty) {
    return FavoriteToggleResult(true, null);
  }
  final body = _parseJsonResponse(alt);
  final parsed = _readFavoritePayload(body);
  return FavoriteToggleResult(parsed.isFavorited ?? true, parsed.favoriteCount);
}

Future<bool?> toggleFavoriteById(String productId) async {
  try {
    final res = await toggleFavoriteDetailed(productId);
    return res.isFavorited;
  } catch (e) {
    if ('$e' == 'Exception: 401') return null;
    return null;
  }
}

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
// 🔎 단건 상품 조회
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
