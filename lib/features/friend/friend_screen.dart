import 'package:go_router/go_router.dart';
import 'package:kumeong_store/core/router/route_names.dart' as R;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../core/base_url.dart';
import '../../core/chat_api.dart'; // ChatApi 임포트

import 'friend_chat_screen.dart';
import 'friend_detail_screen.dart';
import 'friend_plus_screen.dart';
import 'friend_requests_screen.dart';

class FriendScreen extends StatefulWidget {
  /// 로그인한 내 사용자 ID(숫자/UUID 모두 가능)
  final String meUserId;

  const FriendScreen({super.key, required this.meUserId});

  @override
  State<FriendScreen> createState() => _FriendScreenState();
}

class _FriendScreenState extends State<FriendScreen> {
  // ---------- UUID 정규화 ----------
  static final RegExp _uuidRe = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
    caseSensitive: false,
  );

  String _leftPadZeros(String s, int total) {
    final need = total - s.length;
    if (need <= 0) return s;
    final b = StringBuffer();
    for (var i = 0; i < need; i++) {
      b.writeCharCode(48);
    }
    b.write(s);
    return b.toString();
  }

  /// 숫자 문자열도 UUID로 승격: 끝 12자리 + 0패딩 → 00000000-0000-0000-0000-XXXXXXXXXXXX
  String _normalizeId(Object? raw, {String? label}) {
    final s = (raw ?? '').toString().trim();
    if (s.isEmpty) return '';
    if (_uuidRe.hasMatch(s)) return s.toLowerCase();

    // 숫자만 추출
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      final c = s.codeUnitAt(i);
      if (c >= 48 && c <= 57) buf.writeCharCode(c);
    }
    final digits = buf.toString();
    if (digits.isEmpty) {
      debugPrint('[FriendScreen] WARN: $label has no digits/uuid, got="$s"');
      return '';
    }
    final start = digits.length > 12 ? digits.length - 12 : 0;
    final last12 = digits.substring(start);
    final padded = _leftPadZeros(last12, 12);
    return '00000000-0000-0000-0000-$padded';
  }
  
  // ───────────────── Room ID 생성 유틸리티 추가 ─────────────────
  // FriendChatPage에서 사용하는 것과 동일하게 roomId를 생성합니다.
  String _generateRoomId(String id1, String id2) {
    final ids = [id1, id2]..sort();
    return ids.join('_'); 
  }
  // ──────────────────────────────────────────────────────────

  // ---------- 상태 ----------
  final Map<String, int> _unread = {}; // key = peerUserId(UUID), value = count
  late final String _meUuid;
  late final ChatApi _chatApi;

  List<_FriendRow> _friends = [];
  bool _loading = true;
  String? _error;
  String _searchQuery = "";

  @override
  void initState() {
    super.initState();
    _meUuid = _normalizeId(widget.meUserId, label: 'meUserId');
    
    // ❌ (오류 수정): baseUrl, meUserId 인수를 제거하고, userId만 위치 인수로 전달
    _chatApi = ChatApi(_meUuid); 

    // 디버그 로그
    debugPrint('[FriendScreen] meUserId(raw)=${widget.meUserId}, normalized=$_meUuid');

    _reload(); // 최초 로딩
  }

  Future<Map<String, String>> _authHeaders() async {
    final token = ''; // TODO: 실제 토큰
    return {
      'Content-Type': 'application/json',
      if (token.isNotEmpty) 'Authorization': 'Bearer $token',
      'X-User-Id': _meUuid, // 비어있지 않게 이미 정규화됨
    };
  }

  Future<void> _reload() async {
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

  /// 서버에서 친구 목록 가져오기: GET /v1/friends
  Future<void> _fetchFriendsFromServer() async {
    // ✅ 새 구조: apiUrl('/friends')는 /api/v1/friends로 자동 완성됨
    final apiUri = apiUrl('/friends');
    debugPrint('[FriendScreen] GET $apiUri');

    try {
      // 요청
      final res = await http
          .get(apiUri, headers: await _authHeaders())
          .timeout(const Duration(seconds: 15));

      debugPrint('[FriendScreen] <- ${res.statusCode} ${res.body}');

      if (res.statusCode != 200) {
        String msg = '친구 목록을 불러오지 못했습니다. (${res.statusCode})';
        try {
          final j = jsonDecode(res.body);
          if (j is Map) {
            if (j['message'] != null) {
              msg = j['message'].toString();
            } else if (j['error'] != null) {
              msg = j['error'].toString();
            }
          }
        } catch (_) {}
        throw Exception(msg);
      }

      final j = jsonDecode(res.body);
      final list = (j is Map) ? (j['data'] as List? ?? []) : (j as List? ?? []);

      String _str(dynamic v) => v?.toString() ?? '';
      double _toDouble(dynamic v) =>
          (v is num) ? v.toDouble() : double.tryParse(_str(v)) ?? 0.0;
      int _toInt(dynamic v) =>
          (v is num) ? v.toInt() : int.tryParse(_str(v)) ?? 0;

      // ✅ 응답 필드 유연 파싱: friendId|userId|id, friendName|displayName|name
      final parsed = list.map<_FriendRow>((e) {
        final m = e as Map<String, dynamic>;
        final userId = _str(
              m['friendId'] ??
                  m['userId'] ??
                  m['id'] ??
                  m['peerId'],
            )
            .trim();

        final displayName = _str(
              m['friendName'] ??
                  m['displayName'] ??
                  m['name'] ??
                  m['nickname'],
            )
            .trim();

        final trustScore = _toDouble(m['trustScore'] ?? m['trust']);
        final tradeCount = _toInt(m['tradeCount'] ?? m['trades'] ?? m['trade_cnt']);

        return _FriendRow(
          userId: userId,
          displayName: displayName,
          trustScore: trustScore,
          tradeCount: tradeCount,
        );
      }).toList();

      if (mounted) setState(() => _friends = parsed);
    } catch (e) {
      // 여기서 던지면 상위 _reload()가 _error에 표시함
      throw Exception(e.toString());
    }
  }

  /// 각 친구별 안읽은 카운트 계산
  Future<void> _refreshUnreadAll() async {
    for (final f in _friends) {
      final peerUuid = _normalizeId(f.userId, label: 'peerUserId');
      final roomId = _generateRoomId(_meUuid, peerUuid); // 💡 roomId 생성
      
      try {
        // ❌ (오류 수정): fetchMessagesWithPeer 대신 fetchMessagesSinceSeq 사용
        final msgs = await _chatApi.fetchMessagesSinceSeq(roomId: roomId, sinceSeq: 0, limit: 50); 
        
        int count = 0;
        for (final m in msgs) {
          final sender = _normalizeId(m.senderId);
          final isFromPeer = sender == peerUuid;
          // ChatMessage에는 readByMe 필드가 없지만, 메시지를 불러왔다면 서버에서 최신 상태를
          // 반영하므로, 여기서는 임시로 readByMe 속성을 사용하지 않거나,
          // ChatMessage 모델에 해당 속성이 있다고 가정하고 `m.readByMe ?? false`로 처리해야 합니다.
          // 현재는 ChatMessage 모델 정의가 없으므로, 이전 로직을 유지하면서 API만 변경합니다.
          final readByMe = m.readByMe ?? false; 
          
          if (isFromPeer && !readByMe) count++;
        }
        if (mounted) setState(() => _unread[peerUuid] = count);
      } catch (e) {
        // 실패해도 UI는 진행
        if (mounted) setState(() => _unread[peerUuid] = _unread[peerUuid] ?? 0);
        debugPrint(
            '[FriendScreen] unread fetch failed for ${f.displayName}($peerUuid): $e');
      }
    }
  }

  Future<void> _openChat({required _FriendRow friend}) async {
    final peer = _normalizeId(friend.userId, label: 'peerUserId');

    if (_meUuid.isEmpty || peer.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('유효하지 않은 사용자 ID입니다.')),
      );
      return;
    }
    if (_meUuid == peer) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('자기 자신과는 대화를 시작할 수 없어요.')),
      );
      return;
    }

    // ✅ roomId 생성(정렬 후 결합 방식 예시)
    final roomId = _generateRoomId(_meUuid, peer);

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FriendChatPage(
          friendName: friend.displayName.isEmpty ? '(이름 없음)' : friend.displayName,
          meUserId: _meUuid,
          roomId: roomId,
        ),
      ),
    );

    // 돌아오면 읽음 상태 갱신
    await _refreshUnreadAll();
    if (mounted) setState(() {});
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

    final filtered = _friends
        .where((f) => f.displayName.contains(_searchQuery))
        .toList(growable: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text('친구'),
        backgroundColor: mainColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: '요청함',
            icon: const Icon(Icons.inbox_outlined),
            onPressed: () => context.pushNamed(
              R.RouteNames.friendRequests,
              extra: {'meUserId': widget.meUserId}, // 👈 내 UUID 전달
            ),
          ),
          IconButton(
            tooltip: '새로고침',
            icon: const Icon(Icons.refresh),
            onPressed: _reload,
          ),
        ],
      ),
      body: _loading
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
                              onChanged: (v) => setState(() => _searchQuery = v),
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                hintText: "친구 검색",
                                hintStyle: const TextStyle(color: Colors.white70),
                                prefixIcon:
                                    const Icon(Icons.search, color: Colors.white),
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
                          IconButton(
                            icon:
                                const Icon(Icons.person_add, color: Colors.white),
                            onPressed: () async {
                              // FriendPlusPage는 “이름 하나(String)”를 반환
                              final addedName = await Navigator.push<String?>(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => FriendPlusPage(
                                    currentFriends: _friends
                                        .map((e) => e.displayName)
                                        .toList(),
                                  ),
                                ),
                              );

                              if (addedName == null || addedName.isEmpty) return;

                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: Text('친구 요청 전송: $addedName')),
                                );
                              }

                              // 실제 친구 목록은 수락 후에만 /v1/friends에 나타남 → 동기화
                              await _reload();
                            },
                          ),
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

                            return ListTile(
                              leading: const CircleAvatar(
                                radius: 25,
                                child: Icon(Icons.person),
                              ),
                              title: Text(
                                f.displayName.isEmpty
                                    ? '(이름 없음)'
                                    : f.displayName,
                              ),
                              subtitle: Text(
                                  '신뢰도 ${trust.toStringAsFixed(1)} · 거래 ${trades}건'),
                              trailing: _unreadBadge(unread),
                              onTap: () {
                                final peerUuid = _normalizeId(f.userId);
                                final roomId = _generateRoomId(_meUuid, peerUuid);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => FriendChatPage(
                                      friendName: f.displayName.isEmpty ? '(이름 없음)' : f.displayName,
                                      meUserId: _meUuid,
                                      roomId: roomId,
                                    ),
                                  ),
                                ).then((_) => _refreshUnreadAll());
                              },
                              onLongPress: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => FriendDetailPage(
                                      friendName: f.displayName.isEmpty
                                          ? '(이름 없음)'
                                          : f.displayName,
                                      meUserId: _meUuid,
                                      peerUserId: peerUuid,
                                    ),
                                  ),
                                ).then((_) => _refreshUnreadAll());
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
