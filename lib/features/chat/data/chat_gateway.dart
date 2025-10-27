// lib/features/chat/data/chat_gateway.dart
import 'chat_models.dart';

abstract class ChatGateway {
  Future<List<ChatMessage>> history({
    required String roomId,
    required String afterSeq,
    int limit,
  });

  Future<ChatMessage> send({
    required String roomId,
    required String text,
  });

  Future<void> markRead({
    required String roomId,
    required String lastMessageId,
  });

  Stream<ChatMessage> onIncoming();

  void dispose();
}
