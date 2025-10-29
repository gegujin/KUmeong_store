// lib/features/chat/data/chats_api.dart
import 'package:kumeong_store/core/network/http_client.dart';

// ─────────────────────────────────────────────
// 전역 Friends 전용 API (친구방 보장)
// ─────────────────────────────────────────────
class ChatsApi {
  const ChatsApi();

  /// 친구 DM 방 멱등 보장
  /// GET /api/v1/chat/friend-room?peerId=<UUID>
  Future<String> ensureFriendRoom(String peerId) async {
    final res = await HttpX.get(
      '/chat/friend-room',
      query: {'peerId': peerId}, // ← 백엔드 컨트롤러 규격에 맞춤
      noCache: true,
    );

    // { ok:true, roomId, data:{ id, roomId } } 모두 허용
    if (res['data'] is Map<String, dynamic>) {
      final data = res['data'] as Map<String, dynamic>;
      final rid = (data['roomId'] as String?) ?? (data['id'] as String?) ?? '';
      if (rid.isNotEmpty) return rid.toLowerCase();
    }
    final rid = (res['roomId'] as String?) ?? '';
    if (rid.isNotEmpty) return rid.toLowerCase();

    throw ApiException('roomId를 얻지 못했습니다', bodyPreview: res.toString());
  }
}

// 전역 인스턴스
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
  // 클라이언트에서 붙여 보낸 중복방지용 UUID (서버가 지원할 때 매칭에 사용)
  final String? clientMessageId;

  ChatMessage({
    required this.id,
    required this.roomId,
    required this.senderId,
    required this.text,
    required this.timestamp,
    required this.seq,
    this.readByMe,
    this.clientMessageId,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final rawSeq = json['seq'];
    final int safeSeq =
        rawSeq is num ? rawSeq.toInt() : (rawSeq is String ? int.tryParse(rawSeq) ?? 0 : 0);

    final tsStr =
        (json['timestamp'] ?? json['createdAt'] ?? DateTime.now().toIso8601String()).toString();

    final text = (json['text'] ?? json['content'] ?? '').toString();

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
      timestamp: DateTime.parse(tsStr),
      seq: safeSeq,
      readByMe: safeReadByMe,
      clientMessageId:
          (json['clientMessageId'] ?? json['client_id'] ?? json['clientMsgId'])?.toString(),
    );
  }
}

// ─────────────────────────────────────────────
// 2) Chat API (메시지/읽음/거래방)
// ─────────────────────────────────────────────
class ChatApi {
  final String meUserId;

  ChatApi({required this.meUserId});

  String _normalizeRoomId(String roomId) {
    final s = roomId.trim();
    final core = s.startsWith('_') ? s.substring(1) : s;
    return core.toLowerCase(); // 서버 normalizeId와 일치
  }

  /// 메시지 목록
  /// GET /api/v1/chat/rooms/:roomId/messages?sinceSeq&limit
  Future<List<ChatMessage>> fetchMessagesSinceSeq({
    required String roomId,
    required int sinceSeq,
    int limit = 50,
  }) async {
    if (limit > 200) limit = 200;
    final rid = _normalizeRoomId(roomId);
    final j = await HttpX.get(
      '/chat/rooms/$rid/messages',
      query: {'sinceSeq': sinceSeq, 'limit': limit},
      noCache: true,
    );

    final data = (j['data'] is List) ? j['data'] as List : const [];
    return data.whereType<Map<String, dynamic>>().map(ChatMessage.fromJson).toList();
  }

  /// 거래 채팅방 멱등 보장
  /// POST /api/v1/chat/rooms/trade/ensure  body: { productId }
  Future<String> ensureTradeRoom(String productId) async {
    final res = await HttpX.postJson(
      '/chat/rooms/trade/ensure',
      {'productId': productId},
    );
    if (res['ok'] != true || res['data'] == null) {
      throw ApiException('ensureTradeRoom 실패', bodyPreview: 'productId=$productId; res=$res');
    }
    final data = res['data'] as Map<String, dynamic>;
    final id = (data['id'] ?? data['roomId'])?.toString();
    if (id == null || id.isEmpty) {
      throw ApiException('ensureTradeRoom: room id 없음', bodyPreview: res.toString());
    }
    return id.toLowerCase();
  }

  /// 메시지 전송
  /// POST /api/v1/chat/rooms/:roomId/messages  body: { text }
  Future<ChatMessage> sendMessage({
    required String roomId,
    required String text,
    String? clientMessageId, // ← 선택: 있으면 중복방지용으로 서버에 전달
  }) async {
    final rid = _normalizeRoomId(roomId);
    final body = <String, dynamic>{'text': text};
    if (clientMessageId != null && clientMessageId.isNotEmpty) {
      body['clientMessageId'] = clientMessageId;
    }
    final j = await HttpX.postJson('/chat/rooms/$rid/messages', body);

    final data = (j['data'] is Map) ? j['data'] as Map : j as Map;
    return ChatMessage.fromJson(Map<String, dynamic>.from(data));
  }

  /// 읽음 커서 갱신
  /// PUT /api/v1/chat/rooms/:roomId/read  body: { lastMessageId? }
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
