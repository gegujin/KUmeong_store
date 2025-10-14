// C:\Users\82105\KU-meong Store\lib\features\chat\chat_facade.dart
import 'dart:async';
import '../../core/chat_api.dart';
import 'chat_ws_client.dart';

/// ✅ WS 이벤트 kind 상수 (서버와 합의한 문자열)
class WsEventKind {
  static const String chatMsg = 'chat.msg';
  // 필요 시, 'chat.read', 'friend.req' 등 추가
}

class RoomStreamState {
  final List<ChatMessage> messages;
  final int? maxSeq; // 현재까지 받은 최대 seq
  RoomStreamState({required this.messages, required this.maxSeq});

  RoomStreamState copyWith({
    List<ChatMessage>? messages,
    int? maxSeq,
  }) =>
      RoomStreamState(
        messages: messages ?? this.messages,
        maxSeq: maxSeq ?? this.maxSeq,
      );
}

class ChatRoomFacade {
  ChatRoomFacade({
    required this.meUserId,
    required this.roomId,
  }) : api = ChatApi(meUserId) {
    ws = ChatWsClient.instance(meUserId);
  }

  final String meUserId;
  final String roomId;
  final ChatApi api;
  late final ChatWsClient ws;

  final _stateCtrl = StreamController<RoomStreamState>.broadcast();
  RoomStreamState _state = RoomStreamState(messages: const [], maxSeq: null);
  Stream<RoomStreamState> get state => _stateCtrl.stream;

  StreamSubscription? _wsSub;
  bool _opened = false;

  Future<void> open() async {
    if (_opened) return;
    _opened = true;
    await ws.connect(); // idempotent

    // ▶ 초기 백필(최근 50)
    final init = await api.fetchMessagesSinceSeq(
      roomId: roomId,
      sinceSeq: 0,
      limit: 50,
    );

    // ✅ int? 연산/비교 제거: reduce로 최대값 추출
    int? newMax;
    if (init.isNotEmpty) {
      newMax = init
          .map((m) => m.seq) // int
          .reduce((a, b) => a > b ? a : b); // int
    }

    _state = RoomStreamState(messages: init, maxSeq: newMax);
    _stateCtrl.add(_state);

    // ▶ WS 구독
    _wsSub = ws.eventsForRoom(roomId).listen((evt) async {
      if (evt.kind == WsEventKind.chatMsg) {
        final p = evt.payload ?? {};

        // ✅ seq를 항상 int로 확정 (nullable/문자열 방지)
        int ensuredSeq() {
          final raw = p['seq'];
          if (raw is num) return raw.toInt();
          if (raw is String) {
            final n = int.tryParse(raw);
            if (n != null) return n;
          }
          return (_state.maxSeq ?? 0) + 1; // fallback: 증가
        }

        final ensuredText =
            (p['text'] ?? p['content'] ?? '').toString();
        final ensuredTs = (p['timestamp'] ??
                p['createdAt'] ??
                DateTime.now().toIso8601String())
            .toString();

        // ChatMessage 스키마로 매핑 (seq는 int 확정)
        final msg = ChatMessage.fromJson({
          'id': evt.refId ?? p['id'],
          'roomId': roomId,
          'senderId': p['senderId'] ?? evt.userId,
          'text': ensuredText,
          'timestamp': ensuredTs,
          'seq': ensuredSeq(),
          'readByMe': p['readByMe'],
        });

        // 누락 보정: seq 점프 시 REST 백필
        final lastSeq = _state.maxSeq ?? 0; // int
        final newSeq = msg.seq; // int
        if (newSeq > lastSeq + 1) {
          final missing = await api.fetchMessagesSinceSeq(
            roomId: roomId,
            sinceSeq: lastSeq,
            limit: 100,
          );
          // ✅ fold 제네릭 명시 + int만 다룸
          final mergedMax = missing.fold<int>(
            lastSeq,
            (mx, m) => m.seq > mx ? m.seq : mx,
          );
          _state = _state.copyWith(
            messages: _merge(_state.messages, missing),
            maxSeq: mergedMax,
          );
        }

        // 상태 갱신 (maxSeq는 int? 이지만 newSeq는 int라 안전)
        final updatedMax = (_state.maxSeq == null || newSeq > _state.maxSeq!)
            ? newSeq
            : _state.maxSeq;

        _state = _state.copyWith(
          messages: _append(_state.messages, msg),
          maxSeq: updatedMax,
        );
        _stateCtrl.add(_state);
      }
    });
  }

  Future<void> dispose() async {
    await _wsSub?.cancel();
    await _stateCtrl.close();
  }

  // ▶ 전송은 REST → 서버가 WS 브로드캐스트
  Future<void> sendText(String text) async {
    final sent = await api.sendMessage(roomId: roomId, text: text);
    final nextMax =
        (sent.seq > (_state.maxSeq ?? 0)) ? sent.seq : _state.maxSeq;
    _state = _state.copyWith(
      messages: _append(_state.messages, sent),
      maxSeq: nextMax,
    );
    _stateCtrl.add(_state);
  }

  Future<void> markReadIfAny() async {
    if (_state.messages.isEmpty) return;
    final lastId = _state.messages.last.id;
    await api.markRead(roomId: roomId, lastMessageId: lastId);
  }

  // ===== Helpers =====
  List<ChatMessage> _append(List<ChatMessage> cur, ChatMessage m) {
    if (cur.isNotEmpty && cur.last.id == m.id) return cur; // 중복 방지
    final list = [...cur, m]
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return list;
  }

  List<ChatMessage> _merge(List<ChatMessage> cur, List<ChatMessage> inc) {
    final map = {for (final m in cur) m.id: m};
    for (final m in inc) {
      map[m.id] = m;
    }
    final list = map.values.toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return list;
  }
}
