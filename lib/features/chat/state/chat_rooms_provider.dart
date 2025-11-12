// lib/features/chat/state/chat_rooms_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:kumeong_store/features/chat/data/chats_api.dart';

/// 채팅방 목록 Provider
///
/// - `ref.watch(chatRoomsProvider)`로 구독하면 `AsyncValue<List<dynamic>>`를 받습니다.
/// - 목록 갱신: `ref.read(chatRoomsProvider.notifier).refresh();`
final chatRoomsProvider =
    StateNotifierProvider<ChatRoomsNotifier, AsyncValue<List<dynamic>>>(
  (ref) => ChatRoomsNotifier()..refresh(),
);

class ChatRoomsNotifier extends StateNotifier<AsyncValue<List<dynamic>>> {
  ChatRoomsNotifier() : super(const AsyncLoading());

  bool _loading = false;

  /// 서버에서 최신 목록 가져와서 상태 갱신
  Future<void> refresh({bool mine = true, int? limit}) async {
    if (_loading) return;
    _loading = true;

    // 데이터가 이미 있으면 로딩 스피너 대신 기존 값 유지 + 로딩 상태로 전환
    final prev = state;
    if (prev is AsyncData<List<dynamic>>) {
      state = AsyncValue.loading<List<dynamic>>().copyWithPrevious(prev);
    } else {
      state = const AsyncLoading();
    }

    try {
      final rooms = await chatsApi.fetchRooms(mine: mine, limit: limit ?? 50);
      state = AsyncData<List<dynamic>>(rooms);
    } catch (e, st) {
      debugPrint('[chatRoomsProvider] refresh 실패: $e');
      state = AsyncError<List<dynamic>>(e, st);
    } finally {
      _loading = false;
    }
  }

  /// 낙관적 갱신 도우미(선택): 외부에서 특정 방을 upsert할 때 사용 가능
  void upsertRoom(Map<String, dynamic> room) {
    final cur = state.value ?? const <dynamic>[];
    final id = (room['roomId'] ?? room['id'] ?? '').toString();
    if (id.isEmpty) return;

    final next = [...cur];
    final idx = next.indexWhere((e) {
      if (e is Map) {
        final rid = (e['roomId'] ?? e['id'] ?? '').toString();
        return rid == id;
      }
      return false;
    });

    if (idx >= 0) {
      next[idx] = room;
    } else {
      next.insert(0, room);
    }
    state = AsyncData<List<dynamic>>(next);
  }

  /// 목록을 비우고 싶을 때(로그아웃 등)
  void clear() {
    state = const AsyncData<List<dynamic>>(<dynamic>[]);
  }
}
