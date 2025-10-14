// C:\Users\82105\KU-meong Store\lib\core\chat_api.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'base_url.dart'; // ✅ apiUrl() 사용

/// 1) 모델
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
    final int safeSeq = rawSeq is num
        ? rawSeq.toInt()
        : (rawSeq is String ? int.tryParse(rawSeq) ?? 0 : 0);

    final String tsStr = (json['timestamp'] ??
            json['createdAt'] ??
            DateTime.now().toIso8601String())
        .toString();

    final String safeText = (json['text'] ?? json['content'] ?? '').toString();

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
      id: json['id'] as String,
      roomId: json['roomId'] as String,
      senderId: json['senderId'] as String,
      text: safeText,
      timestamp: DateTime.parse(tsStr),
      seq: safeSeq,
      readByMe: safeReadByMe,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'roomId': roomId,
        'senderId': senderId,
        'text': text,
        'timestamp': timestamp.toIso8601String(),
        'seq': seq,
        'readByMe': readByMe,
      };
}

/// 2) Chat API
class ChatApi {
  final String _userId;

  /// X-User-Id만 필요 (토큰은 필요 시 추가)
  ChatApi(this._userId);

  Future<Map<String, String>> _getAuthHeaders() async {
    final token = ''; // TODO: 실제 토큰 연결 시 사용
    return {
      'Content-Type': 'application/json',
      if (token.isNotEmpty) 'Authorization': 'Bearer $token',
      'X-User-Id': _userId,
    };
  }

  /// 메시지 목록 (sinceSeq 기준)
  Future<List<ChatMessage>> fetchMessagesSinceSeq({
    required String roomId,
    required int sinceSeq,
    int limit = 50,
  }) async {
    final uri = apiUrl(
      '/chat/rooms/$roomId/messages',
      {'sinceSeq': sinceSeq, 'limit': limit},
    );

    debugPrint('[ChatApi] GET $uri');

    final res = await http
        .get(uri, headers: await _getAuthHeaders())
        .timeout(const Duration(seconds: 15));

    if (res.statusCode != 200) {
      throw Exception('메시지 불러오기 실패: ${res.statusCode} ${res.body}');
    }

    try {
      final decoded = jsonDecode(res.body);
      final List<dynamic> list = (decoded is Map)
          ? (decoded['data'] as List? ?? [])
          : (decoded as List? ?? []);
      return list
          .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[ChatApi] JSON 파싱 오류: $e');
      throw Exception('메시지 데이터 파싱 실패');
    }
  }

  /// 메시지 전송
  Future<ChatMessage> sendMessage({
    required String roomId,
    required String text,
  }) async {
    final uri = apiUrl('/chat/rooms/$roomId/messages');

    final body = jsonEncode({
      'text': text,
      'senderId': _userId,
      'roomId': roomId,
    });

    debugPrint('[ChatApi] POST $uri (Text: "$text")');

    final res = await http
        .post(uri, headers: await _getAuthHeaders(), body: body)
        .timeout(const Duration(seconds: 15));

    if (res.statusCode != 201) {
      throw Exception('메시지 전송 실패: ${res.statusCode} ${res.body}');
    }

    try {
      final decoded = jsonDecode(res.body);
      final Map<String, dynamic> data = (decoded is Map)
          ? (decoded['data'] as Map<String, dynamic>? ?? {})
          : (decoded as Map<String, dynamic>? ?? {});
      return ChatMessage.fromJson(data);
    } catch (e) {
      debugPrint('[ChatApi] 전송 응답 파싱 오류: $e');
      throw Exception('메시지 전송 후 응답 데이터 파싱 실패');
    }
  }

  /// 읽음 커서 갱신
  Future<void> markRead({
    required String roomId,
    required String lastMessageId,
  }) async {
    final uri = apiUrl('/chat/rooms/$roomId/read_cursor');

    final body = jsonEncode({
      'lastMessageId': lastMessageId,
      'userId': _userId,
    });

    debugPrint('[ChatApi] PUT $uri (Msg ID: $lastMessageId)');

    final res = await http
        .put(uri, headers: await _getAuthHeaders(), body: body)
        .timeout(const Duration(seconds: 15));

    if (res.statusCode != 200) {
      throw Exception('읽음 처리 실패: ${res.statusCode} ${res.body}');
    }
  }
}
