// lib/features/chat/data/chat_models.dart

class ChatMessage {
  final String id;
  final String seq; // BIGINT → 문자열로 받기
  final String roomId;
  final String senderId;
  final String type; // 'TEXT' | 'FILE' | 'SYSTEM'
  final String? text;
  final DateTime createdAt;

  // ✅ 옛 코드(m.content) 호환용 getter
  String? get content => text;

  ChatMessage({
    required this.id,
    required this.seq,
    required this.roomId,
    required this.senderId,
    required this.type,
    required this.text,
    required this.createdAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
        id: j['id'] as String,
        seq: (j['seq']).toString(),
        roomId: j['roomId'] as String,
        senderId: j['senderId'] as String,
        type: (j['type'] ?? 'TEXT').toString(),
        // ✅ 다양한 필드명 대응 (text, content, contentText 등)
        text: j['text']?.toString() ??
            j['content']?.toString() ??
            j['contentText']?.toString(),
        createdAt: DateTime.parse(j['createdAt'].toString()),
      );
}

class ChatRoomSummary {
  final String id;
  final String peerName;
  final String? lastSnippet;
  final int unreadCount;
  final DateTime? lastMessageAt;

  ChatRoomSummary({
    required this.id,
    required this.peerName,
    required this.lastSnippet,
    required this.unreadCount,
    required this.lastMessageAt,
  });

  factory ChatRoomSummary.fromJson(Map<String, dynamic> j) => ChatRoomSummary(
        id: j['id'] as String,
        peerName: (j['peer']?['displayName'] ?? j['peerName'] ?? '친구').toString(),
        lastSnippet: j['lastSnippet']?.toString(),
        unreadCount: (j['unreadCount'] ?? 0) as int,
        lastMessageAt: j['lastMessageAt'] != null
            ? DateTime.tryParse(j['lastMessageAt'].toString())
            : null,
      );
}
