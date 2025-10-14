import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/base_url.dart';
import './chat_models.dart';

typedef Json = Map<String, dynamic>;

class ChatWsClient {
  ChatWsClient._(this._meUserId);

  static ChatWsClient? _instance;
  final String _meUserId;

  static ChatWsClient instance(String meUserId) {
    return _instance ??= ChatWsClient._(meUserId);
  }

  WebSocketChannel? _ch;
  Timer? _pingTimer;
  Timer? _reconnectTimer;
  bool _intentionalClose = false;

  final _eventCtrl = StreamController<ChatWsEvent>.broadcast();
  Stream<ChatWsEvent> get events => _eventCtrl.stream;

  // 룸별 필터 스트림
  Stream<ChatWsEvent> eventsForRoom(String roomId) =>
      events.where((e) => e.roomId == roomId);

  // 로컬에 마지막 본 realtimeEvents.id 저장 (증분 동기화)
  static const _kLastEventKeyPrefix = 'last_event_id_';
  Future<int> _loadLastEventId() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getInt('$_kLastEventKeyPrefix$_meUserId') ?? 0;
    }
  Future<void> _saveLastEventId(int id) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setInt('$_kLastEventKeyPrefix$_meUserId', id);
  }

  // ====== Public ======
  Future<void> connect() async {
    _intentionalClose = false;
    await _open();
  }

  Future<void> close() async {
    _intentionalClose = true;
    _pingTimer?.cancel();
    await _ch?.sink.close();
    _ch = null;
  }

  // ====== Internal ======
  Future<void> _open() async {
    try {
      final base = wsUrl(meUserId: _meUserId);
      final lastEventId = await _loadLastEventId();

      // 서버가 쿼리/초기 메시지로 lastEventId를 받도록(백엔드와 합의)
      final wsFinalUrl = '$base&since=$lastEventId';
      _ch = WebSocketChannel.connect(Uri.parse(wsFinalUrl));

      // 핑(하트비트)
      _pingTimer?.cancel();
      _pingTimer = Timer.periodic(const Duration(seconds: 25), (_) {
        _sendJson({'type': 'ping', 't': DateTime.now().toIso8601String()});
      });

      _ch!.stream.listen(
        (raw) {
          try {
            final obj = jsonDecode(raw as String) as Json;
            if (obj['type'] == 'pong') return;

            // 서버가 이벤트 프레이밍을 { id, kind, roomId, ... }로 보낸다고 가정
            final evt = ChatWsEvent.fromJson(obj);
            _eventCtrl.add(evt);

            _saveLastEventId(evt.eventId); // 증분 포인터 갱신
          } catch (_) {/* 안전무시 로그 생략 */}
        },
        onError: (e, st) => _scheduleReconnect(),
        onDone: () {
          if (!_intentionalClose) _scheduleReconnect();
        },
        cancelOnError: true,
      );
    } catch (e) {
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    _pingTimer?.cancel();
    if (_intentionalClose) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 3), () {
      _open();
    });
  }

  void _sendJson(Json j) {
    try {
      _ch?.sink.add(jsonEncode(j));
    } catch (_) {}
  }
}
