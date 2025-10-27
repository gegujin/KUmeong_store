import 'package:flutter/foundation.dart' show debugPrint;
import 'package:kumeong_store/core/network/http_client.dart'; // HttpX (토큰, 캐시방지, 에러 처리)

// ─────────────────────────────────────────────
// 0) 친구방 확보 API (없으면 생성, 있으면 반환)
// ─────────────────────────────────────────────
class ChatsApi {
  const ChatsApi();

  Future<String> ensureFriendRoom(String peerId) async {
    // ✅ 반드시 path+query 형태로 HttpX.get 사용 (풀 URL 넣지 않기)
    final res = await HttpX.get(
      '/chat/friend-room',
      query: {'peerId': peerId},
      noCache: true,
    );

    if (res['data'] is Map<String, dynamic>) {
      final data = res['data'] as Map<String, dynamic>;
      final rid = (data['roomId'] as String?) ?? (data['id'] as String?) ?? '';
      if (rid.isNotEmpty) return rid;
    }
    final rid = (res['roomId'] as String?) ?? '';
    if (rid.isNotEmpty) return rid;

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
    );
  }
}

// ─────────────────────────────────────────────
// 2) Chat API (X-User-Id + noCache)
// ─────────────────────────────────────────────
class ChatApi {
  final String meUserId;
  ChatApi({required this.meUserId});

  String _normalizeRoomId(String roomId) {
    final s = roomId.trim();
    return s.startsWith('_') ? s.substring(1) : s;
  }

  /// 메시지 목록
  Future<List<ChatMessage>> fetchMessagesSinceSeq({
    required String roomId,
    required int sinceSeq,
    int limit = 50,
  }) async {
    final rid = _normalizeRoomId(roomId);
    final j = await HttpX.get(
      '/chat/rooms/$rid/messages',
      query: {'sinceSeq': sinceSeq, 'limit': limit},
      // headers: {'X-User-Id': meUserId}, // ❌ JWT 주입이면 생략
      noCache: true,
    );

    final data = (j['data'] is List) ? j['data'] as List : const [];
    return data.whereType<Map<String, dynamic>>().map(ChatMessage.fromJson).toList();
  }

  /// 메시지 전송
  Future<ChatMessage> sendMessage({
    required String roomId,
    required String text,
  }) async {
    final rid = _normalizeRoomId(roomId);
    final j = await HttpX.postJson(
      '/chat/rooms/$rid/messages',
      {
        'text': text, // ✅ 서버가 senderId/roomId를 JWT/파라미터로 판단
      },
      // headers: {'X-User-Id': meUserId}, // ❌ 불필요하면 제거
    );

    final data = (j['data'] is Map) ? j['data'] as Map : j as Map;
    return ChatMessage.fromJson(Map<String, dynamic>.from(data));
  }

  /// 읽음 커서 갱신
  Future<void> markRead({
    required String roomId,
    String? lastMessageId, // 옵션
  }) async {
    final rid = _normalizeRoomId(roomId);

    if (lastMessageId == null || lastMessageId.isEmpty) {
      // 구버전 호환: 바디 없이 → putJson에 빈 맵 전달
      await HttpX.putJson('/chat/rooms/$rid/read', const {});
      return;
    }

    // 신버전: /read_cursor
    await HttpX.putJson(
      '/chat/rooms/$rid/read_cursor',
      {
        'lastMessageId': lastMessageId,
        // 'userId': meUserId, // 서버가 JWT로 식별하면 불필요
      },
      // headers: {'X-User-Id': meUserId}, // 필요 없으면 제거
    );
  }
}
