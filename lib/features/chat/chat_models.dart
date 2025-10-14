/// WebSocket 이벤트 종류를 정의하는 상수
class WsEventKind {
  static const chatMsg = 'chat.msg';
  static const chatRead = 'chat.read';
  static const friendReq = 'friend.req';
  static const friendAccept = 'friend.accept';
  static const friendReject = 'friend.reject';
}

/// WebSocket을 통해 전달되는 실시간 이벤트 데이터 모델
class ChatWsEvent {
  final int eventId; // realtimeEvents.id
  final String kind; // see WsEventKind
  final String? roomId;
  final String? userId;
  final String? refId;
  final Map<String, dynamic>? payload;

  ChatWsEvent({
    required this.eventId,
    required this.kind,
    this.roomId,
    this.userId,
    this.refId,
    this.payload,
  });

  factory ChatWsEvent.fromJson(Map<String, dynamic> j) => ChatWsEvent(
        eventId: (j['id'] as num).toInt(),
        kind: j['kind'] as String,
        roomId: j['roomId'] as String?,
        userId: j['userId'] as String?,
        refId: j['refId'] as String?,
        payload: j['payload'] as Map<String, dynamic>?,
      );
}

/// 서버의 도메인에서 정의하는 기본적인 채팅 메시지 모델
class ChatMessage {
  final String id;
  final String roomId;
  final String senderId;
  final String type; // 'TEXT' | 'FILE' | 'SYSTEM'
  final String? content;
  final String? fileUrl;
  final DateTime createdAt;
  final int? seq;

  ChatMessage({
    required this.id,
    required this.roomId,
    required this.senderId,
    required this.type,
    required this.createdAt,
    this.content,
    this.fileUrl,
    this.seq,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
        id: j['id'] as String,
        roomId: j['roomId'] as String,
        senderId: j['senderId'] as String,
        type: j['type'] as String,
        content: j['content'] as String?,
        fileUrl: j['fileUrl'] as String?,
        createdAt: DateTime.parse(j['createdAt'] as String),
        seq: (j['seq'] as num?)?.toInt(),
      );
}
