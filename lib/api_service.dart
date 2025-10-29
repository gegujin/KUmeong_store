// lib/api_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode, debugPrint;
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kumeong_store/utils/storage.dart';
import 'core/base_url.dart';
import 'models/post.dart';

const String baseUrl = 'http://localhost:3000/api/v1';

// -------------------- 공통 유틸 --------------------
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
Map<String, String> _authHeaders(String token) =>
    {'Authorization': 'Bearer $token'};

List _asList(dynamic v) => v is List ? v : const [];
List _pickFirstList(Map obj, List<String> keys) {
  for (final k in keys) {
    final v = obj[k];
    if (v is List) return v;
  }
  return const [];
}

// -------------------- 401 자동 복구 --------------------
Future<bool> _refreshAccessToken() async {
  try {
    final refresh = await TokenStorage.getRefresh();

    // 1) Authorization: Bearer <refresh>
    {
      final url = apiUrl('/auth/refresh');
      final h = <String, String>{..._jsonHeaders};
      if (refresh != null && refresh.isNotEmpty)
        h['Authorization'] = 'Bearer $refresh';
      final resp = await http.post(url, headers: h);
      if (resp.statusCode == 200) {
        final body = _parseJsonResponse(resp);
        final data = _get<Map>(body, 'data') ?? body;
        final access = _get<String>(data, 'accessToken') ??
            _get<String>(body, 'accessToken');
        final newRefresh = _get<String>(data, 'refreshToken') ??
            _get<String>(body, 'refreshToken');
        if (access != null && access.isNotEmpty) {
          await TokenStorage.setTokens(access, refreshToken: newRefresh);
          if (kDebugMode) debugPrint('[API] 🔄 refresh ok (Authorization)');
          return true;
        }
      }
    }

    // 2) x-refresh-token 헤더
    if (refresh != null && refresh.isNotEmpty) {
      final url = apiUrl('/auth/refresh');
      final h = <String, String>{..._jsonHeaders, 'x-refresh-token': refresh};
      final resp = await http.post(url, headers: h);
      if (resp.statusCode == 200) {
        final body = _parseJsonResponse(resp);
        final data = _get<Map>(body, 'data') ?? body;
        final access = _get<String>(data, 'accessToken') ??
            _get<String>(body, 'accessToken');
        final newRefresh = _get<String>(data, 'refreshToken') ??
            _get<String>(body, 'refreshToken');
        if (access != null && access.isNotEmpty) {
          await TokenStorage.setTokens(access, refreshToken: newRefresh);
          if (kDebugMode) debugPrint('[API] 🔄 refresh ok (x-refresh-token)');
          return true;
        }
      }
    }

    // 3) 쿠키 기반 최종 시도
    {
      final url = apiUrl('/auth/refresh');
      final resp = await http.post(url, headers: _jsonHeaders);
      if (resp.statusCode == 200) {
        final body = _parseJsonResponse(resp);
        final data = _get<Map>(body, 'data') ?? body;
        final access = _get<String>(data, 'accessToken') ??
            _get<String>(body, 'accessToken');
        final newRefresh = _get<String>(data, 'refreshToken') ??
            _get<String>(body, 'refreshToken');
        if (access != null && access.isNotEmpty) {
          await TokenStorage.setTokens(access, refreshToken: newRefresh);
          if (kDebugMode) debugPrint('[API] 🔄 refresh ok (cookie)');
          return true;
        }
      }
    }
  } catch (e, st) {
    debugPrint('[API] refresh exception: $e\n$st');
  }
  return false;
}

/// 인증 + 401 재시도 (JSON 전용)
Future<http.Response> _authed({
  required String method,
  required Uri url,
  Map<String, String>? headers,
  Object? body,
}) async {
  final token = await _getToken();
  final h = <String, String>{..._jsonHeaders, ...?headers};
  if (token != null && token.isNotEmpty) h.addAll(_authHeaders(token));

  Future<http.Response> _send(Map<String, String> hdrs) {
    switch (method) {
      case 'GET':
        return http.get(url, headers: hdrs);
      case 'POST':
        return http.post(url, headers: hdrs, body: body);
      case 'DELETE':
        return http.delete(url, headers: hdrs, body: body);
      case 'PATCH':
        return http.patch(url, headers: hdrs, body: body);
      default:
        throw UnsupportedError('Unsupported method: $method');
    }
  }

  var resp = await _send(h);
  if (resp.statusCode == 401) {
    final ok = await _refreshAccessToken();
    if (ok) {
      final t2 = await _getToken();
      final h2 = <String, String>{..._jsonHeaders, ...?headers};
      if (t2 != null && t2.isNotEmpty) h2.addAll(_authHeaders(t2));
      resp = await _send(h2);
    }
  }
  return resp;
}

// -------------------- 로그인/회원가입 --------------------
Future<String?> login(String email, String password) async {
  final url = apiUrl('/auth/login');
  try {
    final resp = await http.post(
      url,
      headers: _jsonHeaders,
      body: jsonEncode({'email': _normalizeEmail(email), 'password': password}),
    );
    final body = _parseJsonResponse(resp);
    final data = _get<Map>(body, 'data') ?? body;

    if (resp.statusCode == 200) {
      final access = _get<String>(data, 'accessToken') ??
          _get<String>(body, 'accessToken');
      final refresh = _get<String>(data, 'refreshToken') ??
          _get<String>(body, 'refreshToken');
      if (access != null && access.isNotEmpty) {
        await TokenStorage.setTokens(access, refreshToken: refresh);
      }
      return access;
    }
    debugPrint('[API] 로그인 실패: ${resp.statusCode} ${resp.body}');
    return null;
  } catch (e, st) {
    debugPrint('[API] 로그인 예외: $e\n$st');
    return null;
  }
}

Future<String?> register(String email, String password, String name,
    {String? univToken}) async {
  final url = apiUrl('/auth/register');
  try {
    final payload = {
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
      final access = _get<String>(data, 'accessToken') ??
          _get<String>(body, 'accessToken');
      final refresh = _get<String>(data, 'refreshToken') ??
          _get<String>(body, 'refreshToken');
      if (access != null && access.isNotEmpty) {
        await TokenStorage.setTokens(access, refreshToken: refresh);
      }
      return access;
    }
    debugPrint('[API] 회원가입 실패: ${resp.statusCode} ${resp.body}');
    return null;
  } catch (e, st) {
    debugPrint('[API] 회원가입 예외: $e\n$st');
    return null;
  }
}

// -------------------- 이미지 MIME --------------------
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

// -------------------- 상품 등록/수정 --------------------
Future<Map<String, dynamic>?> createProductWithImages(
    Map<String, dynamic> productData,
    List<dynamic> images,
    String token) async {
  final uri = apiUrl('/products');
  final req = http.MultipartRequest('POST', uri);
  req.headers['Authorization'] = 'Bearer $token';

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
  if (locationText != null && locationText.isNotEmpty)
    req.fields['locationText'] = locationText;

  final status = productData['status']?.toString().trim();
  if (status?.isNotEmpty == true) req.fields['status'] = status!;

  if (kDebugMode) {
    debugPrint('🧾 전송 필드(create): ${req.fields}');
    debugPrint('🖼 첨부 이미지 수: ${req.files.length}');
  }

  try {
    final streamed = await req.send();
    final resp = await http.Response.fromStream(streamed);
    if (resp.statusCode == 200 || resp.statusCode == 201) {
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
    String token) async {
  final uri = apiUrl('/products/$productId');
  final req = http.MultipartRequest('PATCH', uri);
  req.headers['Authorization'] = 'Bearer $token';

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
  if (locationText != null && locationText.isNotEmpty)
    req.fields['locationText'] = locationText;

  final status = productData['status']?.toString().trim();
  if (status?.isNotEmpty == true) req.fields['status'] = status!;

  if (kDebugMode) {
    debugPrint('🧾 전송 필드(update): ${req.fields}');
    debugPrint('🖼 첨부 이미지 수: ${req.files.length}');
  }

  try {
    final streamed = await req.send();
    final resp = await http.Response.fromStream(streamed);
    final body = _parseJsonResponse(resp);
    if (resp.statusCode == 200 || resp.statusCode == 201) {
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

// -------------------- 상품 리스트 --------------------
Future<List<Product>> fetchProducts(
  String token, {
  String? category,
  String? query,
  int page = 1,
  int limit = 20,
  String? sortField,
  String? order,
}) async {
  final params = <String, String>{'page': '$page', 'limit': '$limit'};
  if (category != null && category.isNotEmpty) params['category'] = category;
  if (query != null && query.isNotEmpty) params['query'] = query;

  const allowedSort = {'createdAt', 'price', 'title'};
  const allowedOrder = {'ASC', 'DESC'};
  if (sortField != null && allowedSort.contains(sortField))
    params['sort'] = sortField;
  if (order != null && allowedOrder.contains(order)) params['order'] = order;

  final base = apiUrl('/products');
  final url = base.replace(queryParameters: params);

  try {
    final resp =
        await http.get(url, headers: {'Authorization': 'Bearer $token'});
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

// -------------------- Favorites --------------------
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

Future<FavoriteToggleResult> toggleFavoriteDetailed(String productId) async {
  // 💡 토큰 선검사로 401 던지지 않음 — _authed()가 알아서 refresh 후 재시도
  Uri primary = apiUrl('/products/$productId/favorite');
  try {
    http.Response resp = await _authed(method: 'POST', url: primary);

    if (resp.statusCode == 404) {
      final legacy = apiUrl('/favorites/$productId/toggle');
      resp = await _authed(method: 'POST', url: legacy);
    }

    final ok = resp.statusCode >= 200 && resp.statusCode < 300;
    if (!ok) {
      throw Exception('favorite-toggle-failed:${resp.statusCode}:${resp.body}');
    }

    if ((resp.contentLength ?? 0) == 0 || resp.body.isEmpty) {
      return FavoriteToggleResult(true, null);
    }

    final body = _parseJsonResponse(resp);
    final parsed = _readFavoritePayload(body);
    final fav = parsed.isFavorited ?? true;
    return FavoriteToggleResult(fav, parsed.favoriteCount);
  } catch (e, st) {
    debugPrint('[API] 즐겨찾기 토글 예외: $e\n$st');
    rethrow;
  }
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

Future<Map<String, dynamic>?> fetchMyFavorites(
    {int page = 1, int limit = 50}) async {
  final url = apiUrl('/favorites')
      .replace(queryParameters: {'page': '$page', 'limit': '$limit'});
  try {
    final resp = await _authed(method: 'GET', url: url);
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

// -------------------- 단건 조회 --------------------
Future<Product?> fetchProductById(String productId, {String? token}) async {
  final t = token ?? await _getToken(); // 없어도 _authed()가 401→refresh 처리
  final url = apiUrl('/products/$productId');
  try {
    final resp = await _authed(method: 'GET', url: url);
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
