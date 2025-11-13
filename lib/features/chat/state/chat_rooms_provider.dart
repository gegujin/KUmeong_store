import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:kumeong_store/features/chat/data/chats_api.dart';

final chatRoomsProvider = AsyncNotifierProvider<ChatRoomsNotifier, List<Map<String, dynamic>>>(
  ChatRoomsNotifier.new,
);

class ChatRoomsNotifier extends AsyncNotifier<List<Map<String, dynamic>>> {
  bool _loading = false;

  @override
  Future<List<Map<String, dynamic>>> build() async {
    return await refresh();
  }

  Future<List<Map<String, dynamic>>> refresh({bool mine = true, int? limit}) async {
    if (_loading) return state.value ?? [];

    _loading = true;
    state = const AsyncLoading();

    try {
      final rooms = await chatsApi.fetchRooms(mine: mine, limit: limit ?? 50);

      final list = rooms.whereType<Map<String, dynamic>>().toList();
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

  void upsertRoom(Map<String, dynamic> room) {
    final cur = state.value ?? [];
    final id = (room['roomId'] ?? room['id'] ?? '').toString();
    if (id.isEmpty) return;

    final next = [...cur];
    final idx = next.indexWhere((e) {
      final rid = (e['roomId'] ?? e['id'] ?? '').toString();
      return rid == id;
    });

    if (idx >= 0) {
      next[idx] = room;
    } else {
      next.insert(0, room);
    }

    state = AsyncData(next);
  }

  void clear() {
    state = const AsyncData([]);
  }
}
