import 'dart:async';

import 'package:kumeong_store/features/chat/data/chats_api.dart' show ChatApi;
import 'chat_models.dart' as models;
import 'chat_gateway.dart';

class RestChatGateway implements ChatGateway {
  final ChatApi api;
  final String roomId;
  final Duration interval;

  final _controller = StreamController<models.ChatMessage>.broadcast();
  Timer? _timer;
  String _lastSeq = '0';
  bool _fetching = false;

  RestChatGateway({
    required this.api,
    required this.roomId,
    this.interval = const Duration(seconds: 2),
  }) {
    _timer = Timer.periodic(interval, (_) => _tick());
  }

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

  Future<void> _tick() async {
    if (_fetching) return;
    _fetching = true;
    try {
      final list = await api.fetchMessagesSinceSeq(
        roomId: roomId,
        sinceSeq: int.tryParse(_lastSeq) ?? 0,
        limit: 100,
      );
      if (list.isNotEmpty) {
        final mapped = list.map(_toModel).toList();
        for (final m in mapped) {
          _controller.add(m);
        }
        _lastSeq = mapped.last.seq;
      }
    } finally {
      _fetching = false;
    }
  }

  @override
  Future<List<models.ChatMessage>> history({
    required String roomId,
    required String afterSeq,
    int limit = 50,
  }) async {
    final list = await api.fetchMessagesSinceSeq(
      roomId: roomId,
      sinceSeq: int.tryParse(afterSeq) ?? 0,
      limit: limit,
    );
    final mapped = list.map(_toModel).toList();
    if (mapped.isNotEmpty) _lastSeq = mapped.last.seq;
    return mapped;
  }

  @override
  Future<models.ChatMessage> send({
    required String roomId,
    required String text,
  }) async {
    final sent = await api.sendMessage(roomId: roomId, text: text);
    return _toModel(sent);
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
    _timer?.cancel();
    _controller.close();
  }
}
