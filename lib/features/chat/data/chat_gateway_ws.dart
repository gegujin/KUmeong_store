import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'package:kumeong_store/features/chat/data/chats_api.dart'
    show ChatApi; // HTTP용
import 'chat_models.dart' as models; // 인터페이스 타입
import 'chat_gateway.dart';

class WsChatGateway implements ChatGateway {
  final Uri wsUri;
  final ChatApi api;

  final _controller = StreamController<models.ChatMessage>.broadcast();
  WebSocketChannel? _ch;
  StreamSubscription? _sub;

  WsChatGateway({
    required this.wsUri,
    required this.api,
  }) {
    _connect();
  }

  void _connect() {
    _ch = WebSocketChannel.connect(wsUri);
    _sub = _ch!.stream.listen(
      _onData,
      onDone: _reconnect,
      onError: (_) => _reconnect(),
    );
  }

  void _reconnect() {
    Future.delayed(const Duration(seconds: 2), _connect);
  }

  void _onData(dynamic raw) {
    try {
      final obj = jsonDecode(raw.toString());
      final kind = (obj['kind'] ?? obj['type'] ?? '').toString();

      Map<String, dynamic>? payload;
      if (kind == 'chat' || kind == 'chat.msg') {
        payload = (obj['data'] ?? obj['payload'] ?? obj['message'])
            as Map<String, dynamic>?;
      } else if (obj is Map<String, dynamic>) {
        if (obj.containsKey('id') && obj.containsKey('senderId')) {
          payload = obj;
        }
      }
      if (payload == null) return;

      // ✅ chat_models 스키마로 정규화
      final normalized = <String, dynamic>{
        'id': (payload['id'] ?? payload['messageId']).toString(),
        'seq': (payload['seq'] ?? '0').toString(),
        'roomId': (payload['roomId'] ?? payload['conversationId']).toString(),
        'senderId': (payload['senderId'] ?? payload['fromUserId']).toString(),
        'type': (payload['type'] ?? 'TEXT').toString(),
        'text':
            (payload['text'] ?? payload['content'] ?? payload['contentText'])
                ?.toString(),
        'createdAt': (payload['createdAt'] ??
                payload['timestamp'] ??
                DateTime.now().toIso8601String())
            .toString(),
      };

      final msg = models.ChatMessage.fromJson(normalized);
      _controller.add(msg);
    } catch (_) {
      // ignore parse errors
    }
  }

  // ChatApi(ChatMessage with int seq, DateTime timestamp) -> chat_models.ChatMessage
  models.ChatMessage _toModel(apiMsg) {
    return models.ChatMessage(
      id: apiMsg.id,
      seq: apiMsg.seq.toString(),
      roomId: apiMsg.roomId,
      senderId: apiMsg.senderId,
      type: 'TEXT',
      text: apiMsg.text,
      createdAt: apiMsg.timestamp,
    );
  }

  @override
  Future<List<models.ChatMessage>> history({
    required String roomId,
    required String afterSeq,
    int limit = 50,
  }) async {
    final since = int.tryParse(afterSeq) ?? 0;
    final list = await api.fetchMessagesSinceSeq(
      roomId: roomId,
      sinceSeq: since,
      limit: limit,
    );
    return list.map(_toModel).toList();
  }

  @override
  Future<models.ChatMessage> send({
    required String roomId,
    required String text,
  }) async {
    final sent = await api.sendMessage(roomId: roomId, text: text);
    final m = _toModel(sent);
    _controller.add(m); // UX용 로컬 push
    return m;
  }

  @override
  Future<void> markRead({
    required String roomId,
    required String lastMessageId,
  }) {
    return api.markRead(roomId: roomId, lastMessageId: lastMessageId);
  }

  @override
  Stream<models.ChatMessage> onIncoming() => _controller.stream;

  @override
  void dispose() {
    _sub?.cancel();
    _ch?.sink.close();
    _controller.close();
  }
}
