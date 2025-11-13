import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:kumeong_store/features/chat/data/chats_api.dart';

/// ✅ 채팅방에서 상대 이름 뽑아내기 헬퍼
///  - room['partnerName'] / friendName / sellerName / buyerName 등 우선 사용
///  - 아무것도 없으면 '상대방'
String _partnerNameFromRoom(Map<String, dynamic> room) {
  final candidates = [
    room['partnerName'],
    room['peerName'],
    room['friendName'],
    room['sellerName'],
    room['buyerName'],
    room['otherUserName'],
  ];

  for (final c in candidates) {
    if (c is String && c.trim().isNotEmpty) {
      return c.trim();
    }
  }

  return '상대방';
}

/// 내가 속한 채팅방 목록 (친구 + 거래방 모두)
final chatRoomsProvider = AsyncNotifierProvider<ChatRoomsNotifier, List<Map<String, dynamic>>>(
  ChatRoomsNotifier.new,
);

class ChatRoomsNotifier extends AsyncNotifier<List<Map<String, dynamic>>> {
  bool _loading = false;

  @override
  Future<List<Map<String, dynamic>>> build() async {
    return await refresh();
  }

  // 🔧 mine 제거, limit 기본값만 사용
  Future<List<Map<String, dynamic>>> refresh({int limit = 50}) async {
    if (_loading) return state.value ?? [];

    _loading = true;
    state = const AsyncLoading();

    try {
      // ✅ ChatsApi 쪽에서 mine=1 을 항상 붙이도록 했음
      final rooms = await chatsApi.fetchRooms(limit: limit);

      // ✅ room 마다 partnerName 필드 강제 세팅
      final list = rooms.whereType<Map<String, dynamic>>().map((room) {
        final name = _partnerNameFromRoom(room);
        return <String, dynamic>{
          ...room,
          'partnerName': name,
        };
      }).toList();

      state = AsyncData(list);
      return list;
    } catch (e, st) {
      debugPrint('[chatRoomsProvider] refresh 실패: $e');
      state = AsyncError(e, st);
      return [];
    } finally {
      _loading = false;
    }
  }

  /// 단일 방 upsert (소켓/실시간 업데이트 등에 사용)
  void upsertRoom(Map<String, dynamic> room) {
    final cur = state.value ?? const <Map<String, dynamic>>[];

    final id = (room['roomId'] ?? room['id'] ?? '').toString();
    if (id.isEmpty) return;

    // ✅ upsert 시에도 partnerName을 보정해서 저장
    final normalized = <String, dynamic>{
      ...room,
      'partnerName': _partnerNameFromRoom(room),
    };

    final next = [...cur];

    final idx = next.indexWhere((e) {
      final rid = (e['roomId'] ?? e['id'] ?? '').toString();
      return rid == id;
    });

    if (idx >= 0) {
      next[idx] = normalized;
    } else {
      // 새 방은 위로
      next.insert(0, normalized);
    }

    state = AsyncData(next);
  }

  /// 목록 전체 초기화 (로그아웃 등)
  void clear() {
    state = const AsyncData(<Map<String, dynamic>>[]);
  }
}
