// lib/api_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/base_url.dart';
import 'core/network/http_client.dart'; // ✅ HttpX 사용

// =======================================================
// 🔧 공통 유틸
// =======================================================
String _normalizeEmail(String email) => email.trim().toLowerCase();

T? _get<T>(Object? obj, String key) {
  if (obj is Map) {
    final v = obj[key];
    return (v is T) ? v : null;
  }
  return null;
}

Map<String, dynamic> _asMap(dynamic v) =>
    (v is Map<String, dynamic>) ? v : <String, dynamic>{};

List<Map<String, dynamic>> _asListOfMap(dynamic v) => (v is List)
    ? v.whereType<Map<String, dynamic>>().toList()
    : <Map<String, dynamic>>[];

/// 유연한 JSON 루트(data / user / rows / items ...) 추출
Map<String, dynamic> _extractDataMap(Map<String, dynamic> root) {
  // 1순위: data
  final data = _get<Map>(root, 'data');
  if (data is Map) return data.cast<String, dynamic>();

  // 대체 키들
  for (final k in ['user', 'payload', 'result']) {
    final v = _get<Map>(root, k);
    if (v is Map) return v.cast<String, dynamic>();
  }
  return root;
}

List<dynamic> _extractList(Map<String, dynamic> root) {
  final data = root['data'];
  if (data is List) return data;
  if (data is Map) {
    for (final k in ['rows', 'items', 'products', 'list']) {
      if (data[k] is List) return data[k] as List;
    }
    // data가 단일 객체면 리스트로 감싸서 반환
    return [data];
  }
  // 루트에서 바로 리스트 키가 있는 경우
  for (final k in ['rows', 'items', 'products', 'list']) {
    if (root[k] is List) return root[k] as List;
  }
  return const [];
}

// =======================================================
// 🧩 ApiService 싱글턴
// =======================================================
class ApiService {
  ApiService._();
  static final ApiService instance = ApiService._();

  // ── 인증 토큰 저장/로드 ─────────────────────────────────────────
  Future<void> _saveToken(String token) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString('session.v1', jsonEncode({'accessToken': token}));
  }

  // ── 즐겨찾기(찜) 목록 ─────────────────────────────────────────
  Future<List<dynamic>> fetchMyFavoriteItems(
      {int page = 1, int limit = 50}) async {
    final j =
        await HttpX.get('/favorites', query: {'page': page, 'limit': limit});
    return _extractList(j);
  }
}

// =======================================================
// 🔐 인증 관련
// =======================================================
Future<String?> login(String email, String password) async {
  try {
    final j = await HttpX.postJson(
      '/auth/login',
      {'email': _normalizeEmail(email), 'password': password},
      withAuth: false,
    );
    final data = _extractDataMap(j);
    final token = _get<String>(data, 'accessToken');
    debugPrint('[LOGIN] resp=${j.toString()}');

    if (token != null && token.isNotEmpty) {
      await ApiService.instance._saveToken(token);
      return token;
    }
    debugPrint('[API] 로그인 실패: accessToken 없음');
    return null;
  } catch (e, st) {
    debugPrint('[API] 로그인 예외: $e\n$st');
    return null;
  }
}

Future<String?> register(String email, String password, String name,
    {String? univToken}) async {
  try {
    final payload = {
      'email': _normalizeEmail(email),
      'password': password,
      'name': name.trim(),
      if (univToken != null && univToken.isNotEmpty) 'univToken': univToken,
    };
    final j = await HttpX.postJson('/auth/register', payload, withAuth: false);
    final data = _extractDataMap(j);
    final token = _get<String>(data, 'accessToken');

    debugPrint('[REGISTER] resp=${j.toString()}');

    if (token != null && token.isNotEmpty) {
      await ApiService.instance._saveToken(token);
      return token;
    }
    debugPrint('[API] 회원가입 실패: accessToken 없음');
    return null;
  } catch (e, st) {
    debugPrint('[API] 회원가입 예외: $e\n$st');
    return null;
  }
}

// =======================================================
// 💬 친구/채팅 유틸 (프런트에서 바로 사용 가능)
// =======================================================

/// 1) 친구 DM 방 보장 후 roomId(UUID) 반환
Future<String> resolveFriendRoomId(String peerId) async {
  final j = await HttpX.get('/chat/friend-room', query: {'peerId': peerId});
  // 응답 형태 지원: { ok:true, roomId:'...' } 또는 { data:{roomId:'...'} }
  final roomId =
      _get<String>(j, 'roomId') ?? _get<String>(_extractDataMap(j), 'roomId');
  if (roomId == null || roomId.isEmpty) {
    throw StateError('FRIEND_ROOM_RESOLVE_FAILED');
  }
  return roomId;
}

/// 2) 메시지 조회 (sinceSeq<=0 이면 최신 limit개)
Future<List<Map<String, dynamic>>> fetchFriendMessages(
  String roomId, {
  int sinceSeq = 0,
  int limit = 50,
}) async {
  final j = await HttpX.get(
    '/chat/rooms/$roomId/messages',
    query: {'sinceSeq': sinceSeq, 'limit': limit},
  );
  final list = _extractList(j);
  return list.whereType<Map<String, dynamic>>().toList();
}

/// 3) 친구요청(by email)  ✅ 서버가 기대하는 키는 email
Future<void> sendFriendRequestByEmail(String email) async {
  final body = {'email': _normalizeEmail(email)}; // ✅ key 변경
  await HttpX.postJson('/friends/requests/by-email', body);
}

/// 4) 친구요청(by userId)  ⛔️ 더 이상 사용 안 함 (서버 라우트 제거)
@deprecated
Future<void> sendFriendRequestById(String toUserId) async {
  throw UnimplementedError('id 기반 요청은 폐기되었습니다. requestByEmail을 사용하세요.');
}

// =======================================================
// 📦 상품 등록 / 수정 (멀티파트)
// =======================================================
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

Future<Map<String, dynamic>?> createProductWithImages(
  Map<String, dynamic> productData,
  List<dynamic> images,
  String token, // 남겨두지만 HttpX가 토큰을 자동 주입
) async {
  try {
    // 파일들 준비
    final files = <http.MultipartFile>[];
    for (final img in images) {
      try {
        if (img is XFile) {
          if (kIsWeb) {
            final bytes = await img.readAsBytes();
            files.add(http.MultipartFile.fromBytes(
              'images',
              bytes,
              filename: img.name,
              contentType: MediaType('image', _imgSubtype(img.name)),
            ));
          } else {
            files.add(await http.MultipartFile.fromPath(
              'images',
              img.path,
              contentType: MediaType('image', _imgSubtype(img.path)),
            ));
          }
        } else if (img is String) {
          files.add(await http.MultipartFile.fromPath(
            'images',
            img,
            contentType: MediaType('image', _imgSubtype(img)),
          ));
        }
      } catch (e) {
        debugPrint('[API] 이미지 처리 오류: $e');
      }
    }

    // 필드(이미지 제외)
    final fields = <String, String>{};
    productData.forEach((k, v) {
      if (k != 'images' && v != null) fields[k] = v.toString();
    });

    final j = await HttpX.multipart(
      '/products',
      fields: fields,
      files: files,
      method: 'POST',
    );

    final data = _extractDataMap(j);
    return _asMap(data);
  } catch (e, st) {
    debugPrint('[API] 상품 등록 예외: $e\n$st');
    return null;
  }
}

Future<Map<String, dynamic>?> updateProduct(
  String productId,
  Map<String, dynamic> productData,
  String token, // 남겨두지만 HttpX가 토큰을 자동 주입
) async {
  try {
    final files = <http.MultipartFile>[];
    final images = productData['images'] as List<dynamic>?;

    if (images != null) {
      for (final img in images) {
        try {
          if (img is XFile) {
            if (kIsWeb) {
              final bytes = await img.readAsBytes();
              files.add(http.MultipartFile.fromBytes(
                'images',
                bytes,
                filename: img.name,
                contentType: MediaType('image', _imgSubtype(img.name)),
              ));
            } else {
              files.add(await http.MultipartFile.fromPath(
                'images',
                img.path,
                contentType: MediaType('image', _imgSubtype(img.path)),
              ));
            }
          } else if (img is String) {
            files.add(await http.MultipartFile.fromPath(
              'images',
              img,
              contentType: MediaType('image', _imgSubtype(img)),
            ));
          }
        } catch (e) {
          debugPrint('[API] 이미지 처리 오류: $e');
        }
      }
    }

    final fields = <String, String>{};
    productData.forEach((k, v) {
      if (k != 'images' && v != null) fields[k] = v.toString();
    });

    final j = await HttpX.multipart(
      '/products/$productId',
      fields: fields,
      files: files,
      method: 'PUT',
    );

    final data = _extractDataMap(j);
    return _asMap(data);
  } catch (e, st) {
    debugPrint('[API] 상품 수정 예외: $e\n$st');
    return null;
  }
}

// =======================================================
// 🧾 상품 목록
// =======================================================
Future<List<Map<String, dynamic>>> fetchProducts(String token) async {
  try {
    final j = await HttpX.get('/products');
    final list = _extractList(j);
    return list.whereType<Map<String, dynamic>>().toList();
  } catch (e, st) {
    debugPrint('[API] 상품 조회 예외: $e\n$st');
    return [];
  }
}

// =======================================================
// ❤️ 즐겨찾기(찜) 토글
//  - 우선 A) /products/{id}/favorite 시도
//  - 404/경로없음이면 B) /favorites/toggle 로 폴백
//  - 성공 시 true/false, 401(비로그인)이나 판별불가면 null
// =======================================================
Future<bool?> toggleFavoriteById(String productId) async {
  if (productId.isEmpty) {
    throw ArgumentError('productId is empty');
  }

  Future<bool?> _parseBool(dynamic j) async {
    final data = (j is Map)
        ? _extractDataMap(j.cast<String, dynamic>())
        : <String, dynamic>{};
    if (data['isFavorited'] is bool) return data['isFavorited'] as bool;
    if (data['favorited'] is bool) return data['favorited'] as bool;
    if (data['favorite'] is bool) return data['favorite'] as bool;

    if (data['ok'] == true) {
      final inner = _get<Map>(data, 'data');
      if (inner != null) {
        final b =
            inner['isFavorited'] ?? inner['favorited'] ?? inner['favorite'];
        if (b is bool) return b as bool;
      }
    }
    return null;
  }

  bool _is401(dynamic j) {
    try {
      if (j is Map && (j['status'] == 401 || j['statusCode'] == 401))
        return true;
    } catch (_) {}
    return false;
  }

  bool _isNotFoundOrRouteMissing(dynamic j) {
    try {
      if (j is Map) {
        final sc = j['status'] ?? j['statusCode'];
        if (sc == 404) return true;
        final msg = (j['message'] ?? '').toString();
        if (msg.contains('Cannot POST') || msg.contains('Not Found'))
          return true;
      }
    } catch (_) {}
    return false;
  }

  try {
    // A) REST 스타일: /products/{id}/favorite
    final j = await HttpX.postJson('/products/$productId/favorite', {});
    if (_is401(j)) return null; // 비로그인 → 호출부에서 안내
    final parsed = await _parseBool(j);
    if (parsed != null) return parsed;

    // 파싱 실패했지만 404/경로 문제면 B로 폴백
    if (_isNotFoundOrRouteMissing(j)) {
      // fall through to B
    } else {
      // 다른 원인(200이어도 포맷 불명확) → null로 반환
      return null;
    }
  } catch (e) {
    // 네트워크/서버 예외 시 B 경로로 폴백
    debugPrint('[API] favorite(A) 예외: $e → B 경로 시도');
  }

  try {
    // B) 토글 API: /favorites/toggle  (body로 productId 전달)
    final j2 =
        await HttpX.postJson('/favorites/toggle', {'productId': productId});
    if (_is401(j2)) return null;
    final parsed2 = await _parseBool(j2);
    return parsed2; // 여전히 null이면 호출부에서 "로그인 필요/실패" 처리
  } catch (e, st) {
    debugPrint('[API] favorite(B) 예외: $e\n$st');
    // 호출부에서 롤백/스낵바 처리하므로 여기선 예외 던지지 않고 null
    return null;
  }
}

// =======================================================
// ⭐ 외부 호출용 래퍼
// =======================================================
Future<List<dynamic>> fetchMyFavoriteItems({int page = 1, int limit = 50}) {
  return ApiService.instance.fetchMyFavoriteItems(page: page, limit: limit);
}
