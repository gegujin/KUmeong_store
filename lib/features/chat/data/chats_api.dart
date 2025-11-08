import 'package:flutter/foundation.dart' show debugPrint;
import 'package:kumeong_store/core/network/http_client.dart'; // HttpX + ApiException

// ─────────────────────────────────────────────
// 0) 채팅 방 확보 API
//   - 거래방 멱등 생성: POST /api/v1/chat/rooms/ensure-trade
//   - 친구방 확보   : POST /api/v1/chat/friend-room (실패시 GET 폴백)
// ※ HttpX가 /api/v1을 자동 부착한다고 가정 → 여기서는 항상 "/chat/..." 사용
// ─────────────────────────────────────────────
class ChatsApi {
  const ChatsApi();

  /// 거래방 멱등 생성 (상품 상세 → 채팅하기에서 사용)
  Future<String> ensureTrade(String productId) async {
    final res = await HttpX.postJson(
      '/chat/rooms/ensure-trade', // ✅ HttpX가 /api/v1 붙여줌
      {'productId': productId},
    );

    // 응답 { roomId } 또는 { data:{ roomId } } 또는 { id } 모두 대응
    final rid = _pickRoomId(res);
    if (rid.isEmpty) {
      throw ApiException('roomId를 얻지 못했습니다', bodyPreview: res.toString());
    }
    return rid;
  }

  /// 친구방 확보 (친구 상세 → 채팅하기)
  /// 서버가 POST면 POST 우선, 실패 시 GET 폴백
  Future<String> ensureFriendRoom(String peerId) async {
    try {
      final res = await HttpX.postJson('/chat/friend-room', {'peerId': peerId});
      final rid = _pickRoomId(res);
      if (rid.isEmpty) {
        throw ApiException('roomId 없음', bodyPreview: res.toString());
      }
      return rid;
    } catch (e) {
      debugPrint('[ChatsApi] POST /chat/friend-room 실패, GET 폴백: $e');
      final res = await HttpX.get('/chat/friend-room', query: {'peerId': peerId}, noCache: true);
      final rid = _pickRoomId(res);
      if (rid.isEmpty) {
        throw ApiException('roomId를 얻지 못했습니다', bodyPreview: res.toString());
      }
      return rid;
    }
  }

  // 공통 파서: {roomId} 또는 {data:{roomId}} 또는 {id}
  String _pickRoomId(dynamic res) {
    if (res is Map) {
      final data = res['data'];
      if (data is Map) {
        final rid = (data['roomId'] as String?) ?? (data['id'] as String?) ?? '';
        if (rid.isNotEmpty) return rid;
      }
      final rid = (res['roomId'] as String?) ?? (res['id'] as String?) ?? '';
      if (rid.isNotEmpty) return rid;
    }
    return '';
  }
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
  /// GET /api/v1/chat/rooms/:rid/messages?sinceSeq=&limit=
  Future<List<ChatMessage>> fetchMessagesSinceSeq({
    required String roomId,
    required int sinceSeq,
    int limit = 50,
  }) async {
    final rid = _normalizeRoomId(roomId);

    final j = await HttpX.get(
      '/chat/rooms/$rid/messages', // ✅ 슬래시/경로 정확
      query: {'sinceSeq': '$sinceSeq', 'limit': '$limit'},
      noCache: true,
    );

    // j['data']가 List인지 안전 확인
    final List<dynamic> arr =
        (j is Map && j['data'] is List) ? j['data'] as List<dynamic> : const <dynamic>[];

    // 각 원소를 Map으로 보장 후 모델 변환
    return arr.whereType<Map<String, dynamic>>().map(ChatMessage.fromJson).toList();
  }

  /// 메시지 전송 (서버 요구: { text })
  /// POST /api/v1/chat/rooms/:rid/messages
  Future<ChatMessage> sendMessage({
    required String roomId,
    required String text,
  }) async {
    final rid = _normalizeRoomId(roomId);
    final j = await HttpX.postJson(
      '/chat/rooms/$rid/messages',
      {
        'text': text, // ✅ content → text (서버 스키마)
      },
    );

    // 응답이 { ok, data: {...} } 또는 {...} 모두 대응
    final data = (j is Map && j['data'] is Map) ? j['data'] as Map : (j as Map);
    return ChatMessage.fromJson(Map<String, dynamic>.from(data));
  }

  /// 읽음 커서 갱신
  /// PUT /api/v1/chat/rooms/:rid/read
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
