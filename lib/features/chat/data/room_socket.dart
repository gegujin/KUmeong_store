// lib/features/chat/data/room_socket.dart
import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

/// 매우 단순한 WebSocket 래퍼:
/// - connect(): 연결 및 수신 리스너 등록
/// - onEvent(Map) 콜백으로 JSON 이벤트 전달
/// - 20초마다 ping 전송
/// - 에러/종료 시 2초 후 자동 재연결
class RoomSocket {
  final Uri uri;
  final void Function(Map<String, dynamic> event) onEvent;

  WebSocketChannel? _ch;
  Timer? _ping;

  RoomSocket({required this.uri, required this.onEvent});

  void connect() {
    _ch = WebSocketChannel.connect(uri);

    _ch!.stream.listen((raw) {
      try {
        final obj = jsonDecode(raw.toString());
        if (obj is Map) {
          onEvent(obj.cast<String, dynamic>());
        }
      } catch (_) {
        // JSON 아님 → 무시
      }
    }, onDone: _reconnect, onError: (_) => _reconnect());

    // 20초마다 ping
    _ping?.cancel();
    _ping = Timer.periodic(const Duration(seconds: 20), (_) {
      try {
        _ch?.sink.add(jsonEncode({'type': 'ping'}));
      } catch (_) {/* no-op */}
    });
  }

  void _reconnect() {
    // 간단 재연결(고정 2초)
    Future.delayed(const Duration(seconds: 2), connect);
  }

  void dispose() {
    _ping?.cancel();
    _ping = null;
    try {
      _ch?.sink.close();
    } catch (_) {/* no-op */}
    _ch = null;
  }
}
