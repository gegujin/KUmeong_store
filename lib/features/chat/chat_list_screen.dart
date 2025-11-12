// lib/features/chat/chat_list_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';

import 'package:kumeong_store/core/router/route_names.dart' as R;
import 'package:kumeong_store/features/chat/state/chat_rooms_provider.dart'; // ✅ Riverpod provider

class ChatListScreen extends ConsumerStatefulWidget {
  const ChatListScreen({super.key});

  @override
  ConsumerState<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends ConsumerState<ChatListScreen> {
  final df = DateFormat('HH:mm');
  Timer? _poller;

  @override
  void initState() {
    super.initState();
    // 최초 로드
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(chatRoomsProvider.notifier).refresh();
    });
    // 10초 폴링(선택)
    _poller = Timer.periodic(const Duration(seconds: 10), (_) {
      ref.read(chatRoomsProvider.notifier).refresh();
    });
  }

  @override
  void dispose() {
    _poller?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    await ref.read(chatRoomsProvider.notifier).refresh();
  }

  @override
  Widget build(BuildContext context) {
    final roomsAsync = ref.watch(chatRoomsProvider);

    return Scaffold(
      appBar: _AppBarTitle(onRefresh: _refresh),
      body: roomsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('채팅 목록을 불러오지 못했습니다: $e')),
        data: (rooms) {
          if (rooms.isEmpty) {
            return const Center(child: Text('채팅방이 없습니다.'));
          }

          // 안전 정렬: updatedAt/lastMessageAt 중 있는 값 기준 최신순
          final sorted = [...rooms];
          int _cmp(dynamic a, dynamic b) {
            DateTime parseTime(dynamic v) {
              final s = (v ?? '').toString();
              try {
                return DateTime.parse(s);
              } catch (_) {
                return DateTime.fromMillisecondsSinceEpoch(0);
              }
            }

            DateTime t(dynamic r) {
              if (r is Map) {
                final m = r;
                final t1 = parseTime(m['updatedAt']);
                final t2 = parseTime(m['lastMessageAt']);
                final t3 = parseTime(m['createdAt']);
                return [t1, t2, t3].reduce((x, y) => x.isAfter(y) ? x : y);
              }
              return DateTime.fromMillisecondsSinceEpoch(0);
            }

            return t(b).compareTo(t(a));
          }

          sorted.sort(_cmp);

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: sorted.length,
              separatorBuilder: (_, __) => const Divider(height: 1, thickness: 0.4),
              itemBuilder: (context, index) {
                final r = (sorted[index] as Map);

                final roomId = (r['roomId'] ?? r['id'] ?? '').toString();
                final peer = (r['peer'] is Map) ? (r['peer'] as Map) : const {};
                final partnerName = (peer['name'] ?? r['partnerName'] ?? '상대방').toString();
                final avatarUrl = (peer['avatarUrl'] ?? r['avatarUrl'])?.toString();

                final lastMsg = (r['lastSnippet'] ?? r['lastMessage'] ?? '').toString();

                DateTime updated;
                final updatedStr = (r['updatedAt'] ?? r['lastMessageAt'] ?? r['createdAt'] ?? '').toString();
                try {
                  updated = DateTime.parse(updatedStr);
                } catch (_) {
                  updated = DateTime.fromMillisecondsSinceEpoch(0);
                }

                final unreadCount = () {
                  final u = r['unreadCount'];
                  if (u is num) return u.toInt();
                  if (u is String) return int.tryParse(u) ?? 0;
                  return 0;
                }();

                return ListTile(
                  onTap: () async {
                    await context.pushNamed(
                      R.RouteNames.chatRoomOverlay,
                      pathParameters: {'roomId': roomId},
                      extra: {
                        'partnerName': partnerName,
                        'isKuDelivery': false,
                        'securePaid': false,
                      },
                    );
                    if (!mounted) return;
                    // 복귀 후 갱신(읽음/최근 메시지 반영)
                    ref.read(chatRoomsProvider.notifier).refresh();
                  },
                  leading: _Avatar(url: avatarUrl),
                  title: Text(
                    partnerName,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      lastMsg.isEmpty ? '(메시지가 없습니다)' : lastMsg,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        updated.millisecondsSinceEpoch == 0 ? '' : df.format(updated.toLocal()),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.grey),
                      ),
                      const SizedBox(height: 6),
                      if (unreadCount > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          child: Text(
                            '$unreadCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _AppBarTitle extends StatelessWidget implements PreferredSizeWidget {
  final Future<void> Function() onRefresh;
  const _AppBarTitle({required this.onRefresh, super.key});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) => AppBar(
        centerTitle: true,
        title: const Text('채팅'),
        actions: [
          IconButton(
            tooltip: '새로고침',
            onPressed: () => onRefresh(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      );
}

class _Avatar extends StatelessWidget {
  const _Avatar({this.url});
  final String? url;

  @override
  Widget build(BuildContext context) {
    const radius = 26.0;
    if (url == null || url!.isEmpty) {
      return const CircleAvatar(radius: radius, child: Icon(Icons.person));
    }
    return CircleAvatar(
      radius: radius,
      backgroundImage: NetworkImage(url!),
      backgroundColor: Colors.transparent,
    );
  }
}
