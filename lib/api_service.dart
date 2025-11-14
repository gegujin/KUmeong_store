// lib/api_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode, debugPrint;
import 'package:http/http.dart' as http; // MultipartFile 용
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';

import 'models/post.dart';
import 'core/network/http_client.dart'; // ✅ HttpX + ApiException
import 'package:kumeong_store/utils/storage.dart'; // TokenStorage (로그인/회원가입 저장용)

// ----------------------------------------------------
// 공통 유틸
// ----------------------------------------------------
String _normalizeEmail(String email) => email.trim().toLowerCase();

T? _get<T>(Object? obj, String key) {
  if (obj is Map) {
    final v = obj[key];
    return (v is T) ? v : null;
  }
  return null;
}

Map<String, dynamic> _flatten(Object? raw) {
  var cur = raw;
  // { ok?, data: {...} } 혹은 { success, data: {...} } 구조를 끝까지 벗김
  while (cur is Map && cur['data'] != null) {
    cur = cur['data'];
  }
  if (cur is Map<String, dynamic>) return cur;
  if (cur is List) return {'items': cur};
  return <String, dynamic>{};
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

// ----------------------------------------------------
// ▶ 로그인 / 회원가입  (HttpX.withAuth=false)
// ----------------------------------------------------
Future<String?> login(String email, String password) async {
  try {
    final res = await HttpX.postJson(
      '/auth/login',
      {'email': _normalizeEmail(email), 'password': password},
      withAuth: false, // ✅ 비인증 호출
    );

    final flat = _flatten(res);
    final access = _get<String>(flat, 'accessToken') ?? _get<String>(res, 'accessToken');
    final refresh = _get<String>(flat, 'refreshToken') ?? _get<String>(res, 'refreshToken');

    if (access != null && access.isNotEmpty) {
      // ✅ HttpX는 session.v1 을 읽지만, 저장은 기존 TokenStorage 사용 유지
      await TokenStorage.setTokens(access, refreshToken: refresh);
      return access;
    }
    debugPrint('[API] 로그인 실패(토큰 없음): $res');
    return null;
  } catch (e, st) {
    debugPrint('[API] 로그인 예외: $e\n$st');
    return null;
  }
}

Future<String?> register(String email, String password, String name, {String? univToken}) async {
  try {
    final payload = {
      'email': _normalizeEmail(email),
      'password': password,
      'name': name.trim(),
      if (univToken != null && univToken.isNotEmpty) 'univToken': univToken,
    };
    final res = await HttpX.postJson('/auth/register', payload, withAuth: false);

    final flat = _flatten(res);
    final access = _get<String>(flat, 'accessToken') ?? _get<String>(res, 'accessToken');
    final refresh = _get<String>(flat, 'refreshToken') ?? _get<String>(res, 'refreshToken');

    if (access != null && access.isNotEmpty) {
      await TokenStorage.setTokens(access, refreshToken: refresh);
      return access;
    }
    debugPrint('[API] 회원가입 실패(토큰 없음): $res');
    return null;
  } catch (e, st) {
    debugPrint('[API] 회원가입 예외: $e\n$st');
    return null;
  }
}

// ----------------------------------------------------
// ▶ 상품 등록/수정 (멀티파트: HttpX.multipart 사용)
// ----------------------------------------------------
Future<List<http.MultipartFile>> _buildImageFiles(List<dynamic> images) async {
  final files = <http.MultipartFile>[];
  for (final img in images) {
    try {
      if (img is XFile) {
        if (kIsWeb) {
          final bytes = await img.readAsBytes();
          final safeName = (img.name.trim().isNotEmpty) ? img.name : 'image.jpg';
          files.add(http.MultipartFile.fromBytes(
            'images',
            bytes,
            filename: safeName,
            contentType: MediaType('image', _imgSubtype(safeName)),
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
      debugPrint('[API] 💥 이미지 처리 오류: $e');
    }
  }
  return files;
}

Future<Map<String, dynamic>?> createProductWithImages(
  Map<String, dynamic> productData,
  List<dynamic> images,
  String _ignoredToken, // ✅ 호출부 호환을 위해 남기되, 더 이상 사용하지 않음
) async {
  try {
    final title = productData['title']?.toString().trim();
    final rawPrice = (productData['priceWon'] ?? productData['price'])?.toString();
    final priceNum =
        rawPrice == null ? 0 : int.tryParse(rawPrice.replaceAll(RegExp(r'[, ]'), '')) ?? 0;
    final desc = productData['description']?.toString().trim();
    final categoryPath =
        (productData['categoryPath'] ?? productData['category'])?.toString().trim();
    final locationText = (productData['locationText'] ??
            (productData['location'] is String ? productData['location'] : null))
        ?.toString()
        .trim();
    final status = productData['status']?.toString().trim();

    final fields = <String, String>{
      if (title != null && title.isNotEmpty) 'title': title,
      'priceWon': priceNum.toString(),
      if (desc?.isNotEmpty == true) 'description': desc!,
      if (categoryPath?.isNotEmpty == true) 'categoryPath': categoryPath!,
      if (locationText != null && locationText.isNotEmpty) 'locationText': locationText,
      if (status?.isNotEmpty == true) 'status': status!,
    };

    final files = await _buildImageFiles(images);

    if (kDebugMode) {
      debugPrint('🧾 전송 필드(create): $fields');
      debugPrint('🖼 첨부 이미지 수: ${files.length}');
    }

    final res = await HttpX.multipart(
      '/products',
      fields: fields,
      files: files,
      method: 'POST',
      withAuth: true,
    );

    final flat = _flatten(res);
    if (kDebugMode) debugPrint('✅ 상품 등록 성공: ${flat['id'] ?? '-'}');
    return Map<String, dynamic>.from(flat);
  } catch (e, st) {
    debugPrint('💥 [API] 상품 등록 예외: $e\n$st');
    return null;
  }
}

Future<Map<String, dynamic>?> updateProductWithImages(
  String productId,
  Map<String, dynamic> productData,
  List<dynamic> images,
  String _ignoredToken, // ✅ 더 이상 사용하지 않음
) async {
  try {
    final title = productData['title']?.toString().trim();
    final rawPrice = (productData['priceWon'] ?? productData['price'])?.toString();
    final desc = productData['description']?.toString().trim();
    final categoryPath =
        (productData['categoryPath'] ?? productData['category'])?.toString().trim();
    final category = productData['category']?.toString().trim();
    final locationText = (productData['locationText'] ??
            (productData['location'] is String ? productData['location'] : null))
        ?.toString()
        .trim();
    final status = productData['status']?.toString().trim();

    final fields = <String, String>{
      if (title?.isNotEmpty == true) 'title': title!,
      if (rawPrice != null)
        'priceWon': (int.tryParse(rawPrice.replaceAll(RegExp(r'[, ]'), '')) ?? 0).toString(),
      if (desc?.isNotEmpty == true) 'description': desc!,
      if (categoryPath?.isNotEmpty == true) 'categoryPath': categoryPath!,
      if (category?.isNotEmpty == true) 'category': category!,
      if (locationText != null && locationText.isNotEmpty) 'locationText': locationText,
      if (status?.isNotEmpty == true) 'status': status!,
    };

    final files = await _buildImageFiles(images);

    if (kDebugMode) {
      debugPrint('🧾 전송 필드(update): $fields');
      debugPrint('🖼 첨부 이미지 수: ${files.length}');
    }

    final res = await HttpX.multipart(
      '/products/$productId',
      fields: fields,
      files: files,
      method: 'PATCH',
      withAuth: true,
    );

    final flat = _flatten(res);
    debugPrint('✅ 상품 수정 성공');
    return Map<String, dynamic>.from(flat);
  } catch (e, st) {
    debugPrint('💥 상품 수정 예외: $e\n$st');
    return null;
  }
}

// ----------------------------------------------------
// ▶ 상품 리스트 / 단건
//   - token 파라미터는 호환용이며 무시됨
// ----------------------------------------------------
Future<List<Product>> fetchProducts(
  String _ignoredToken, {
  String? category,
  String? query,
  int page = 1,
  int limit = 100,
  String? sortField,
  String? order,
}) async {
  final params = <String, dynamic>{'page': '$page', 'limit': '$limit'};
  if (category != null && category.isNotEmpty) params['category'] = category;
  if (query != null && query.isNotEmpty) params['query'] = query;

  const allowedSort = {'createdAt', 'price', 'title'};
  const allowedOrder = {'ASC', 'DESC'};
  if (sortField != null && allowedSort.contains(sortField)) params['sort'] = sortField;
  if (order != null && allowedOrder.contains(order)) params['order'] = order;

  try {
    // 1차 호출
    Map<String, dynamic> j = await HttpX.get('/products', query: params);

    // 서버가 잘못된 sort/order로 400을 줄 경우(레거시 호환) 한 번 폴백 시도
    if ((j['status'] == 400 || j['code'] == 400) &&
        (params.containsKey('sort') || params.containsKey('order'))) {
      final retryParams = Map<String, dynamic>.from(params)
        ..remove('sort')
        ..remove('order');
      j = await HttpX.get('/products', query: retryParams);
    }

    final flat = _flatten(j);
    final items = _normalizeItems(flat);
    return items.whereType<Map<String, dynamic>>().map((e) => Product.fromJson(e)).toList();
  } catch (e, st) {
    debugPrint('[API] 상품 조회 예외: $e\n$st');
    return [];
  }
}

Future<Product?> fetchProductById(String productId, {String? token}) async {
  try {
    final j = await HttpX.get('/products/$productId');
    final flat = _flatten(j);
    return Product.fromJson(Map<String, dynamic>.from(flat));
  } catch (e, st) {
    debugPrint('[API] 상품 단건 조회 예외: $e\n$st');
    return null;
  }
}

// ----------------------------------------------------
// ▶ Favorites
//   - 기본 경로: POST /products/:id/favorite
//   - 레거시 폴백: /favorites/:id/toggle (404시에만)
// ----------------------------------------------------
({bool? isFavorited, int? favoriteCount}) _readFavoritePayload(Map<String, dynamic> root) {
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

class ChatRoomSummaryDto {
  final String id;
  final String roomId;
  final String partnerName; // 상대방 표시 이름(없으면 roomId 일부로 대체 가능)
  final String lastMessage;
  final int unreadCount;
  final DateTime updatedAt;

  /// 🔹 프로필 이미지 URL (지금은 서버에서 안 보내서 대부분 빈 문자열)
  final String avatarUrl;

  ChatRoomSummaryDto({
    required this.id,
    required this.roomId,
    required this.partnerName,
    required this.lastMessage,
    required this.unreadCount,
    required this.updatedAt,
    this.avatarUrl = '',
  });

  factory ChatRoomSummaryDto.fromJson(Map<String, dynamic> json) {
    // id / roomId
    final id = (json['id'] ?? json['roomId'] ?? '').toString();
    final roomId = (json['roomId'] ?? id).toString();

    // 안 읽은 개수
    final unreadRaw = json['unreadCount'];
    final unread = unreadRaw is num ? unreadRaw.toInt() : 0;

    // 마지막 메시지(스니펫)
    final snippet = (json['lastSnippet'] ?? '').toString();

    // 마지막 메시지 시간
    final lastAtStr = json['lastMessageAt']?.toString();
    DateTime lastAt;
    if (lastAtStr == null || lastAtStr.isEmpty) {
      // null이면 아주 옛날 시점으로 넣어서 정렬 시 뒤로 가도록
      lastAt = DateTime.fromMillisecondsSinceEpoch(0);
    } else {
      lastAt = DateTime.parse(lastAtStr).toLocal();
    }

    // 🔹 상대방 이름: partnerName > peerName > peerEmail > fallback
    String partnerName = '';
    final rawPartner =
        (json['partnerName'] ?? json['peerName'] ?? json['peerEmail'] ?? '').toString().trim();

    if (rawPartner.isNotEmpty) {
      partnerName = rawPartner;
    } else {
      // 서버가 아직 이름을 안 줄 때는 roomId 앞부분으로 임시 표시
      partnerName = '거래 채팅 (${roomId.substring(0, 6)})';
    }

    // 🔹 아바타 URL: 나중에 서버가 뭘 줄지 대비해서 후보 키 여러 개 체크
    final avatar = (json['avatarUrl'] ??
            json['peerAvatar'] ??
            json['peerProfileImage'] ??
            json['peerProfileImageUrl'] ??
            '')
        .toString();

    return ChatRoomSummaryDto(
      id: id,
      roomId: roomId,
      partnerName: partnerName,
      lastMessage: snippet,
      unreadCount: unread,
      updatedAt: lastAt,
      avatarUrl: avatar,
    );
  }
}

/// 서버에서 내 채팅방 목록(친구+거래)을 가져온다.
/// 백엔드 구현에 따라 우선 순서:
/// 1) /chat/rooms (권장)
/// 2) 없으면 friends 목록을 요약으로 변환(친구채팅 커버)
/// 서버에서 내 채팅방 목록(친구+거래)을 가져온다.
/// 백엔드 구현에 따라 우선 순서:
/// 1) /chat/rooms (권장)
/// 2) 없으면 friends 목록을 요약으로 변환(친구채팅 커버)
Future<List<ChatRoomSummaryDto>> fetchMyChatRooms({int limit = 50}) async {
  // 1) 표준: /chat/rooms?mine=1&limit=...
  try {
    final res = await HttpX.get(
      '/chat/rooms',
      query: {
        'mine': '1',
        'limit': '$limit',
      },
      noCache: true,
    );

    dynamic data = res;
    if (data is Map<String, dynamic>) {
      data = data['data'] ?? data['items'] ?? data;
    }

    List<dynamic> list;
    if (data is List) {
      list = data;
    } else if (data is Map && data['items'] is List) {
      list = data['items'] as List;
    } else {
      list = const [];
    }

    return list
        .whereType<Map<String, dynamic>>()
        .map((e) => ChatRoomSummaryDto.fromJson(e))
        .toList();
  } catch (_) {
    // fall through to friends
  }

  // 2) /friends 폴백
  final r2 = await HttpX.get('/friends');
  final arr = (r2['data'] ?? r2['items'] ?? r2);
  final list = arr is List ? arr : const [];

  return list.whereType<Map<String, dynamic>>().map((e) => ChatRoomSummaryDto.fromJson(e)).toList();
}

class FavoriteToggleResult {
  final bool isFavorited;
  final int? favoriteCount;
  FavoriteToggleResult(this.isFavorited, this.favoriteCount);
}

Future<FavoriteToggleResult> toggleFavoriteDetailed(
  String productId, {
  required bool currentlyFavorited,
}) async {
  try {
    Map<String, dynamic> res;

    if (currentlyFavorited) {
      // 이미 찜 → "언찜" 수행 (레거시 토글 사용)
      // 백엔드가 DELETE를 요구하더라도 HttpX에 delete 헬퍼가 없어
      // 안전하게 동작하는 토글 엔드포인트로 언찜을 처리.
      res = await HttpX.postJson('/favorites/$productId/toggle', {});
    } else {
      // 아직 안 찜 → "찜 추가"
      try {
        res = await HttpX.postJson('/products/$productId/favorite', {});
      } on ApiException catch (e) {
        // 어떤 서버에선 products 경로가 없고 favorites 토글만 있는 경우가 있어서 폴백
        if (e.status == 404) {
          res = await HttpX.postJson('/favorites/$productId/toggle', {});
        } else {
          rethrow;
        }
      }
    }

    final parsed = _readFavoritePayload(res); // 내부에서 _flatten 적용됨
    final fav = parsed.isFavorited ?? true;
    return FavoriteToggleResult(fav, parsed.favoriteCount);
  } catch (e, st) {
    debugPrint('[API] 즐겨찾기 토글 예외: $e\n$st');
    rethrow;
  }
}

Future<bool?> toggleFavoriteById(String productId) async {
  try {
    // 호환용: 상태를 모르면 안전하게 토글 엔드포인트로만 처리 (필요시 HeartPage에서 직접 호출 권장)
    final r = await toggleFavoriteDetailed(productId, currentlyFavorited: false);
    return r.isFavorited;
  } catch (_) {
    return null;
  }
}

Future<Map<String, dynamic>?> fetchMyFavorites({int page = 1, int limit = 50}) async {
  try {
    final j = await HttpX.get('/favorites/me', query: {'page': '$page', 'limit': '$limit'});
    if ((j['ok'] is bool && j['ok'] == false) || (j['status'] is int && j['status'] != 200)) {
      debugPrint('[API] 즐겨찾기 목록 실패: $j');
      return null;
    }
    final flat = _flatten(j);
    final items = _get<List>(flat, 'items') ?? const [];
    final total = _get<num>(flat, 'total') ?? 0;
    final pg = _get<num>(flat, 'page') ?? page;
    final lm = _get<num>(flat, 'limit') ?? limit;

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

Future<List<Product>> fetchMyFavoriteItems({int page = 1, int limit = 50}) async {
  final m = await fetchMyFavorites(page: page, limit: limit);
  if (m == null) return const [];
  final items = (m['items'] as List?) ?? const [];
  return items.whereType<Map<String, dynamic>>().map((e) => Product.fromJson(e)).toList();
}

// ───────────────────────────────────────────────────────────
// ▶ 조회수 적립 (상세 진입 시 1회 호출)
//    - 서버가 최신 조회수를 돌려주면 그 값을 반환
//    - 엔드포인트가 다르면 try-catch 폴백 분기만 바꿔주면 됨
// ───────────────────────────────────────────────────────────
class ViewIncrementResult {
  final String productId;
  final int views;
  const ViewIncrementResult(this.productId, this.views);
}

Future<ViewIncrementResult?> incrementProductView(String productId) async {
  if (productId.isEmpty || productId.startsWith('demo-')) return null;

  // JSON 숫자/문자 어떤 형식이 와도 int로 안전 파싱
  int _asInt(Object? v) {
    if (v is num) return v.toInt();
    if (v is String && v.isNotEmpty) {
      return int.tryParse(v.replaceAll(RegExp(r'[, ]'), '')) ?? 0;
    }
    return 0;
  }

  Map<String, dynamic> _asMap(Object? v) => (v is Map<String, dynamic>) ? v : <String, dynamic>{};

  try {
    // 1차 시도: POST /products/:id/views
    Map<String, dynamic> r = await HttpX.postJson('/products/$productId/views', {});

    // 응답은 { ok?, data: { id, views } } 혹은 평평한 { id, views } 등 다양할 수 있음
    final flat = _flatten(r);
    final id = (flat['id'] ?? productId).toString();
    final views = _asInt(flat['views'] ?? _asMap(r)['views']);
    if (views > 0) return ViewIncrementResult(id, views);

    // 혹시 data 깊이에 들어있다면 거기서도 시도
    final dat = _asMap(r['data']);
    final v2 = _asInt(dat['views']);
    if (v2 > 0) return ViewIncrementResult(id, v2);

    // 서버가 2xx지만 views를 안 보내는 경우도 있어 null 반환(홈에서는 낙관값 유지 가능)
    return null;
  } on ApiException catch (e) {
    // 404라면 서버 엔드포인트가 다른 경우일 수 있으니 폴백 경로 한 번 더 시도
    if (e.status == 404) {
      try {
        // 2차 폴백 예: POST /products/:id/view  (서버에 맞춰 교체)
        final r = await HttpX.postJson('/products/$productId/view', {});
        final flat = _flatten(r);
        final id = (flat['id'] ?? productId).toString();
        final views = _asInt(flat['views']);
        if (views > 0) return ViewIncrementResult(id, views);
        return null;
      } catch (_) {
        return null;
      }
    }
    // 그 외 에러는 무시(상세 화면은 계속 진행)
    if (kDebugMode) debugPrint('[API] incrementProductView error: $e');
    return null;
  } catch (e, st) {
    if (kDebugMode) debugPrint('[API] incrementProductView ex: $e\n$st');
    return null;
  }
}
