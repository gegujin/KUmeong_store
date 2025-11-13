import 'package:flutter/foundation.dart' show debugPrint;
import 'package:kumeong_store/core/network/http_client.dart'; // HttpX + ApiException

// ─────────────────────────────────────────────
// 0) 채팅 방 확보/조회 API
//   - 거래방 멱등 생성: POST /chat/rooms/ensure-trade
//   - 친구방 확보   : POST /chat/friend-room
//   - 방 목록 조회  : GET  /chat/rooms?mine=1&limit=50 ...
// ※ HttpX가 /api/v1을 자동 부착한다고 가정 → 여기서는 항상 "/chat/..." 사용
// ─────────────────────────────────────────────
class ChatsApi {
  const ChatsApi();

  /// 거래방 멱등 생성 (상품 상세 → 채팅하기에서 사용)
  ///
  /// POST /chat/rooms/ensure-trade
  /// body: { productId }
  /// res: { ok, roomId, data:{ id, ... } } 등
  Future<String> ensureTrade(String productId) async {
    final pid = productId.toString().trim();
    if (pid.isEmpty) {
      throw ApiException('productId가 비었습니다.');
    }

    // ✅ 서버가 product.sellerId로 판매자를 판단하므로 sellerId는 보내지 않음
    final dynamic res = await HttpX.postJson(
      '/chat/rooms/ensure-trade', // HttpX가 /api/v1 접두사 붙여줌
      {'productId': pid},
    );

    final rid = _pickRoomId(res);
    if (rid.isEmpty) {
      throw ApiException('roomId를 얻지 못했습니다', bodyPreview: '$res');
    }
    return rid;
  }

  /// 친구방 확보 (친구 상세 → 채팅하기)
  ///
  /// POST /chat/friend-room
  /// body: { peerUserId }
  /// (필요시 GET 폴백)
  Future<String> ensureFriendRoom(String peerUserId) async {
    final pid = peerUserId.trim();
    if (pid.isEmpty) {
      throw ApiException('peerUserId가 비었습니다.');
    }

    try {
      // ✅ 백엔드 스펙: peerUserId
      final dynamic res = await HttpX.postJson('/chat/friend-room', {'peerUserId': pid});
      final rid = _pickRoomId(res);
      if (rid.isEmpty) {
        throw ApiException('roomId 없음', bodyPreview: res.toString());
      }
      return rid;
    } catch (e) {
      // 필요 없으면 이 폴백은 삭제해도 됨
      debugPrint('[ChatsApi] POST /chat/friend-room 실패, GET 폴백: $e');
      final dynamic res = await HttpX.get(
        '/chat/friend-room',
        query: {'peerUserId': pid},
        noCache: true,
      );
      final rid = _pickRoomId(res);
      if (rid.isEmpty) {
        throw ApiException('roomId를 얻지 못했습니다', bodyPreview: res.toString());
      }
      return rid;
    }
  }

  /// 방 목록 조회
  ///
  /// GET /chat/rooms?mine=1&limit=50 ...
  ///
  /// - 응답이 List, { data: [...] }, { data: { items: [...] } } 인 경우 모두 처리
  /// - 최종 리턴 타입: List<dynamic>
  Future<List<dynamic>> fetchRooms({int limit = 50}) async {
    debugPrint('[ChatsApi] fetchRooms 호출, limit=$limit');

    final query = <String, dynamic>{
      'mine': '1', // ✅ 항상 mine=1
      'limit': '$limit', // 기본값 50
    };

    final dynamic res = await HttpX.get(
      '/chat/rooms',
      query: query,
      noCache: true,
    );

    List<dynamic> out = const <dynamic>[];

    if (res is List) {
      out = res;
    } else if (res is Map<String, dynamic>) {
      final data = res['data'];

      if (data is List) {
        out = data;
      } else if (data is Map && data['items'] is List) {
        out = data['items'] as List;
      }
    }

    return out;
  }

  Future<List<dynamic>> listRooms({int limit = 50}) async {
    return fetchRooms(limit: limit);
  }
}

// 공통 파서: {roomId} 또는 {data:{roomId}} 또는 {id}
String _pickRoomId(dynamic res) {
  String _asStr(dynamic v) => (v ?? '').toString().trim();

  if (res is String) {
    return res.isNotEmpty ? res : '';
  }

  if (res is Map) {
    // 최상위 우선
    for (final k in ['roomId', 'id']) {
      final v = _asStr(res[k]);
      if (v.isNotEmpty) return v;
    }

    // 래핑된 객체(data, result, room ...)
    for (final wrapper in ['data', 'result', 'room']) {
      final w = res[wrapper];
      if (w is Map) {
        for (final k in ['roomId', 'id']) {
          final v = _asStr(w[k]);
          if (v.isNotEmpty) return v;
        }
      }
    }
  }

  return '';
}

// 전역 인스턴스 (선택)
final chatsApi = const ChatsApi();

// ─────────────────────────────────────────────
// 1) 모델
// ─────────────────────────────────────────────
class ChatMessage {
  final String id;
  final String roomId;
  final String senderId;
  final String text;
  final DateTime timestamp;
  final int seq;
  final bool? readByMe;

  ChatMessage({
    required this.id,
    required this.roomId,
    required this.senderId,
    required this.text,
    required this.timestamp,
    required this.seq,
    this.readByMe,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    // seq 안전 변환
    final rawSeq = json['seq'];
    final int safeSeq =
        rawSeq is num ? rawSeq.toInt() : (rawSeq is String ? int.tryParse(rawSeq) ?? 0 : 0);

    // 타임스탬프 안전 파싱(서버가 timestamp 또는 createdAt 제공)
    DateTime safeTime;
    final tsStr =
        (json['timestamp'] ?? json['createdAt'] ?? DateTime.now().toIso8601String()).toString();
    try {
      safeTime = DateTime.parse(tsStr);
    } catch (_) {
      safeTime = DateTime.now();
    }

    // 본문 필드 다양성(content 옛 스키마 대비)
    final text = (json['text'] ?? json['content'] ?? '').toString();

    // readByMe 안전 파싱
    bool? safeReadByMe;
    final rb = json['readByMe'];
    if (rb is bool) {
      safeReadByMe = rb;
    } else if (rb is String) {
      final lower = rb.toLowerCase();
      if (lower == 'true') safeReadByMe = true;
      if (lower == 'false') safeReadByMe = false;
    }

    return ChatMessage(
      id: (json['id'] ?? json['messageId']).toString(),
      roomId: (json['roomId'] ?? json['conversationId']).toString(),
      senderId: (json['senderId'] ?? json['fromUserId']).toString(),
      text: text,
      timestamp: safeTime,
      seq: safeSeq,
      readByMe: safeReadByMe,
    );
  }
}

// ─────────────────────────────────────────────
// 2) Chat API (메시지 목록/전송/읽음 커서)
// ※ HttpX가 /api/v1 자동 부착 → 여기서는 항상 "/chat/..." 사용
// ─────────────────────────────────────────────
class ChatApi {
  final String meUserId;
  ChatApi({required this.meUserId});

  String _normalizeRoomId(String roomId) {
    final s = roomId.trim();
    return s.startsWith('_') ? s.substring(1) : s;
  }

  /// 메시지 목록
  ///
  /// GET /chat/rooms/:rid/messages?sinceSeq=&limit=
  Future<List<ChatMessage>> fetchMessagesSinceSeq({
    required String roomId,
    required int sinceSeq,
    int limit = 50,
  }) async {
    final rid = _normalizeRoomId(roomId);

    final dynamic j = await HttpX.get(
      '/chat/rooms/$rid/messages',
      query: {'sinceSeq': '$sinceSeq', 'limit': '$limit'},
      noCache: true,
    );

    List<dynamic> arr = const <dynamic>[];

    // 1) 응답이 바로 배열인 경우
    if (j is List) {
      arr = j;
    }
    // 2) 응답이 Map 구조인 경우
    else if (j is Map) {
      // { data: [...] }
      if (j['data'] is List) {
        arr = j['data'] as List;
      }
      // { data: { items: [...] } }
      else if (j['data'] is Map && (j['data']['items'] is List)) {
        arr = j['data']['items'] as List;
      }
    }

    // 각 원소를 Map으로 보장 후 모델 변환
    return arr.whereType<Map<String, dynamic>>().map(ChatMessage.fromJson).toList();
  }

  /// 메시지 전송 (서버 요구: { type, text, clientMessageId? })
  ///
  /// POST /chat/rooms/:rid/messages
  Future<ChatMessage> sendMessage({
    required String roomId,
    required String text,
    String? clientMessageId,
  }) async {
    final rid = _normalizeRoomId(roomId);

    final body = <String, dynamic>{
      'type': 'TEXT', // ✅ 기본 TEXT 타입
      'text': text,
    };
    if (clientMessageId != null && clientMessageId.isNotEmpty) {
      body['clientMessageId'] = clientMessageId;
    }

    final dynamic j = await HttpX.postJson(
      '/chat/rooms/$rid/messages',
      body,
    );

    // 응답이 { ok, data: {...} } 또는 {...} 모두 대응
    Map<String, dynamic> data;
    if (j is Map && j['data'] is Map) {
      data = j['data'] as Map<String, dynamic>;
    } else {
      data = j as Map<String, dynamic>;
    }
    return ChatMessage.fromJson(data);
  }

  /// 읽음 커서 갱신
  ///
  /// PUT /chat/rooms/:rid/read
  /// - lastMessageId 없으면 {}
  /// - 있으면 { lastMessageId }
  Future<void> markRead({
    required String roomId,
    String? lastMessageId,
  }) async {
    final rid = _normalizeRoomId(roomId);
    final body = (lastMessageId == null || lastMessageId.isEmpty)
        ? const {}
        : {'lastMessageId': lastMessageId};

    await HttpX.putJson('/chat/rooms/$rid/read', body);
  }
}
