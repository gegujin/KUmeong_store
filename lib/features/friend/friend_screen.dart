// C:\Users\82105\KU-meong Store\lib\features\friend\friend_screen.dart
import 'package:go_router/go_router.dart';
import 'package:kumeong_store/core/router/route_names.dart' as R;
import 'package:flutter/material.dart';

import 'package:kumeong_store/features/chat/data/chats_api.dart';
import 'package:kumeong_store/core/session/session_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kumeong_store/features/friend/data/friends_api.dart';

// ✅ roomId 서버 획득 & 예외 타입
import 'package:kumeong_store/core/network/http_client.dart';
import 'friend_detail_screen.dart';
import 'friend_plus_screen.dart';

class FriendScreen extends ConsumerStatefulWidget {
  const FriendScreen({super.key});

  @override
  ConsumerState<FriendScreen> createState() => FriendScreenState();
}

class FriendScreenState extends ConsumerState<FriendScreen> {
  // ---------- UUID 정규화 ----------
  static final RegExp _uuidRe = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
    caseSensitive: false,
  );

  void refreshUnreadAll() {
    _refreshUnreadAll();
  }

  String _normalizeId(Object? raw, {String? label}) {
    final s = (raw ?? '').toString().trim();
    if (s.isEmpty) return '';
    if (_uuidRe.hasMatch(s)) return s.toLowerCase();
    debugPrint('[FriendScreen] WARN: $label is not UUID(36): "$s"');
    return '';
  }

  // ✅ 폴백용 roomId 조합기 (정렬 후 '_' 결합, 클라-서버 동일 규칙이어야 함)
  String _composeRoomId(String me, String peer) {
    final ids = [me, peer]..sort();
    return ids.join('_');
  }

  // ---------- 상태 ----------
  final Map<String, int> _unread = {}; // peerUuid -> count
  final Map<String, String> _roomIdByPeer = {}; // peerUuid -> roomId cache

  Future<String> _getRoomIdByPeer(String peerUuid) async {
    if (_roomIdByPeer.containsKey(peerUuid)) return _roomIdByPeer[peerUuid]!;
    // ✅ 서버에서 방 보장 후 roomId 획득
    final roomId = await chatsApi.ensureFriendRoom(peerUuid);
    _roomIdByPeer[peerUuid] = roomId;
    return roomId;
  }

  String? _meUuid;
  ChatApi? _chatApi;
  late final FriendsApi _friendsApi;

  List<_FriendRow> _friends = [];
  bool _loading = true;
  String? _error;
  String _searchQuery = "";

  ProviderSubscription<SessionState>? _sessionSub;
  bool _didFirstLoad = false;

  @override
  void initState() {
    super.initState();

    _friendsApi = friendsApi;

    _sessionSub = ref.listenManual<SessionState>(sessionProvider, (prev, next) {
      final rawId =
          next.me?['userId'] ?? next.me?['id'] ?? next.me?['uuid'] ?? '';
      final me = _normalizeId(rawId, label: 'session.me.userId');

      if (next.isAuthed && me.isNotEmpty) {
        final firstSet = _meUuid == null;
        _meUuid = me;
        _chatApi ??= ChatApi(meUserId: me);
        debugPrint('[FriendScreen] session ready, me=$_meUuid');

        if (firstSet && !_didFirstLoad) {
          _didFirstLoad = true;
          _reload();
        }
      }
    });
  }

  @override
  void dispose() {
    _sessionSub?.close();
    super.dispose();
  }

  Future<void> _reload() async {
    if ((_meUuid ?? '').isEmpty) {
      setState(() {
        _loading = true;
        _error = null;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _fetchFriendsFromServer();
      await _refreshUnreadAll();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _fetchFriendsFromServer() async {
    try {
      final list = await _friendsApi.listFriends();
      final parsed = list
          .map<_FriendRow>((s) => _FriendRow(
                userId: s.userId,
                displayName: s.displayName,
                trustScore: s.trustScore.toDouble(),
                tradeCount: s.tradeCount,
              ))
          .toList();

      if (mounted) setState(() => _friends = parsed);
    } catch (e) {
      throw Exception('친구 목록을 불러오지 못했습니다: $e');
    }
  }

  bool _refreshing = false;

  Future<void> _refreshUnreadAll() async {
    if (_refreshing) return;
    _refreshing = true;
    try {
      // ✅ 읽음 커서 반영 대기
      await Future.delayed(const Duration(milliseconds: 500));

      final me = _meUuid;
      final chat = _chatApi;
      if (me == null || me.isEmpty || chat == null) return;

      for (final f in _friends) {
        final peerUuid = _normalizeId(f.userId, label: 'peerUserId');
        if (peerUuid.isEmpty) continue;

        try {
          final roomId = await _getRoomIdByPeer(peerUuid);
          final msgs = await chat.fetchMessagesSinceSeq(
              roomId: roomId, sinceSeq: 0, limit: 50);

          int count = 0;
          for (final m in msgs) {
            final fromPeer = _normalizeId(m.senderId) == peerUuid;
            final read = m.readByMe == true;
            if (fromPeer && !read) count++;
          }
          if (mounted) setState(() => _unread[peerUuid] = count);
        } catch (_) {
          if (mounted) {
            _unread[peerUuid] = _unread[peerUuid] ?? 0;
            setState(() {});
          }
        }
      }
    } finally {
      _refreshing = false;
    }
  }

  Widget _unreadBadge(int n) {
    if (n <= 0) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFE64A19),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        n > 99 ? '99+' : '$n',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mainColor = Theme.of(context).colorScheme.primary;

    // ✅ 검색: 대소문자 무시
    final q = _searchQuery.trim().toLowerCase();
    final filtered = _friends
        .where((f) => q.isEmpty || f.displayName.toLowerCase().contains(q))
        .toList(growable: false);

    final sessionReady = (_meUuid ?? '').isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('친구'),
        backgroundColor: mainColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: '요청함',
            icon: const Icon(Icons.inbox_outlined),
            onPressed: () {
              final s = ref.read(sessionProvider);
              final rawId =
                  s.me?['userId'] ?? s.me?['id'] ?? s.me?['uuid'] ?? '';
              final meUuid = _normalizeId(rawId, label: 'session.me.userId');
              context.pushNamed(
                R.RouteNames.friendRequests,
                extra: {'meUserId': meUuid},
              );
            },
          ),
          IconButton(
            tooltip: '새로고침',
            icon: const Icon(Icons.refresh),
            onPressed: _reload,
          ),
        ],
      ),
      body: !sessionReady
          ? const Center(child: CircularProgressIndicator())
          : _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(child: Text('불러오기에 실패했어요.\n$_error'))
                  : Column(
                      children: [
                        // 검색 + 친구 추가
                        Container(
                          padding: const EdgeInsets.all(12),
                          color: mainColor,
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  onChanged: (v) =>
                                      setState(() => _searchQuery = v),
                                  style: const TextStyle(color: Colors.white),
                                  decoration: InputDecoration(
                                    hintText: "친구 검색",
                                    hintStyle:
                                        const TextStyle(color: Colors.white70),
                                    prefixIcon: const Icon(Icons.search,
                                        color: Colors.white),
                                    filled: true,
                                    fillColor: Colors.black26,
                                    contentPadding: const EdgeInsets.symmetric(
                                      vertical: 0,
                                      horizontal: 10,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(25),
                                      borderSide: BorderSide.none,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              // IconButton(
                              //   icon: const Icon(Icons.person_add, color: Colors.white),
                              //   onPressed: () async {
                              //     final addedName = await Navigator.push<String?>(
                              //       context,
                              //       MaterialPageRoute(
                              //         builder: (_) => FriendPlusPage(
                              //           currentFriends: _friends.map((e) => e.displayName).toList(),
                              //         ),
                              //       ),
                              //     );
                              //
                              //     if (addedName == null || addedName.isEmpty) return;
                              //
                              //     if (mounted) {
                              //       ScaffoldMessenger.of(context).showSnackBar(
                              //         SnackBar(content: Text('친구 요청 전송: $addedName')),
                              //       );
                              //     }
                              //
                              //     await _reload();
                              //   },
                              // ),
                            ],
                          ),
                        ),

                        // 친구 수
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              "친구 ${filtered.length}명",
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),

                        // 친구 목록
                        Expanded(
                          child: RefreshIndicator(
                            onRefresh: _reload,
                            child: ListView.separated(
                              itemCount: filtered.length,
                              separatorBuilder: (_, __) =>
                                  const Divider(height: 24),
                              itemBuilder: (_, index) {
                                final f = filtered[index];
                                final peerUuid = _normalizeId(f.userId);
                                final unread = _unread[peerUuid] ?? 0;

                                final trust =
                                    f.trustScore.isNaN ? 0 : f.trustScore;
                                final trades = f.tradeCount;

                                // ✅ 공통: 두 핸들러(onTap, onLongPress)에서 모두 쓰도록 여기서 계산
                                final partnerName =
                                    f.displayName.trim().isNotEmpty
                                        ? f.displayName.trim()
                                        : '친구';

                                return ListTile(
                                  leading: const CircleAvatar(
                                      radius: 25, child: Icon(Icons.person)),
                                  title: Text(f.displayName.isEmpty
                                      ? '(이름 없음)'
                                      : f.displayName),
                                  subtitle: Text(
                                      '신뢰도 ${trust.toStringAsFixed(1)} · 거래 $trades건'),
                                  trailing: _unreadBadge(unread),

                                  // 탭: 친구 상세 → 채팅 → 복귀
                                  onTap: () async {
                                    try {
                                      final me = _meUuid?.trim() ?? '';
                                      if (me.isEmpty) {
                                        if (!mounted) return;
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                              content: Text(
                                                  '로그인 정보가 없습니다. 다시 시도해주세요.')),
                                        );
                                        return;
                                      }

                                      final peerUuidNorm = _normalizeId(
                                              f.userId,
                                              label: 'peerUserId')
                                          .trim();
                                      if (peerUuidNorm.isEmpty) {
                                        if (!mounted) return;
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                              content: Text(
                                                  '상대 사용자 ID가 유효하지 않습니다.')),
                                        );
                                        return;
                                      }

                                      final partnerName =
                                          f.displayName.trim().isNotEmpty
                                              ? f.displayName.trim()
                                              : '친구';

                                      // ✅ 채팅방 roomId 확보(없으면 서버에서 생성)
                                      final roomId =
                                          await _getRoomIdByPeer(peerUuidNorm);

                                      // ✅ 채팅 화면으로 이동 (GoRouter 사용)
                                      final result = await context.pushNamed(
                                        R.RouteNames.friendChat,
                                        extra: {
                                          'friendName': partnerName,
                                          'meUserId': me,
                                          'roomId': roomId,
                                        },
                                      );

                                      if (!mounted) return;

                                      // ✅ 1) 낙관적 업데이트: 복귀 즉시 해당 친구 배지 0으로 선반영
                                      final poppedWithRoomOk = (result is Map &&
                                              result['roomId'] == roomId) ||
                                          (result == true);
                                      if (poppedWithRoomOk) {
                                        _unread[peerUuidNorm] = 0;
                                        setState(() {}); // 즉시 반영
                                      }

                                      // ✅ 2) 백엔드 재조회로 최종 동기화
                                      await _refreshUnreadAll();
                                      setState(() {}); // 최종 반영
                                    } catch (e) {
                                      if (!mounted) return;
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                            content:
                                                Text('채팅 화면으로 이동 중 오류: $e')),
                                      );
                                    }
                                  },

                                  // 롱탭: 친구 상세로 이동(동일 로직 적용)
                                  onLongPress: () async {
                                    try {
                                      final me = _meUuid?.trim() ?? '';
                                      final peerUuidNorm = _normalizeId(
                                              f.userId,
                                              label: 'peerUserId')
                                          .trim();
                                      if (me.isEmpty || peerUuidNorm.isEmpty)
                                        return;

                                      final partnerName =
                                          f.displayName.trim().isNotEmpty
                                              ? f.displayName.trim()
                                              : '친구';
                                      final roomId =
                                          await _getRoomIdByPeer(peerUuidNorm);

                                      final result = await context.pushNamed(
                                        R.RouteNames.friendChat,
                                        extra: {
                                          'friendName': partnerName,
                                          'meUserId': me,
                                          'roomId': roomId,
                                        },
                                      );

                                      if (!mounted) return;

                                      final poppedWithRoomOk = (result is Map &&
                                              result['roomId'] == roomId) ||
                                          (result == true);
                                      if (poppedWithRoomOk) {
                                        _unread[peerUuidNorm] = 0; // 낙관적 0
                                        setState(() {});
                                      }

                                      await _refreshUnreadAll();
                                      setState(() {});
                                    } catch (_) {}
                                  },
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
    );
  }
}

class _FriendRow {
  final String userId;
  final String displayName;
  final double trustScore;
  final int tradeCount;

  _FriendRow({
    required this.userId,
    required this.displayName,
    required this.trustScore,
    required this.tradeCount,
  });
}
