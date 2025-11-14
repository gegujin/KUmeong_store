// lib/features/chat/chat_list_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:kumeong_store/core/router/route_names.dart' as R;
import 'package:kumeong_store/api_service.dart'; // fetchMyChatRooms, ChatRoomSummaryDto

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final df = DateFormat('HH:mm');

  List<ChatRoomSummaryDto> _items = [];
  bool _loading = true;
  String? _error;
  Timer? _poller;

  @override
  void initState() {
    super.initState();
    _load();
    // 10초 폴링(선택)
    _poller = Timer.periodic(const Duration(seconds: 10), (_) => _load(silent: true));
  }

  @override
  void dispose() {
    _poller?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final list = await fetchMyChatRooms(limit: 50);
      list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt)); // 최신순
      if (!mounted) return;
      setState(() {
        _items = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '채팅 목록을 불러오지 못했습니다: $e';
        _loading = false;
      });
    }
  }

  Future<void> _refresh() => _load();

  /// 🔹 partnerName이 비어있거나 '상대방'일 때를 위한 디스플레이용 이름
  String _displayName(ChatRoomSummaryDto chat) {
    final raw = (chat.partnerName ?? '').trim();
    if (raw.isNotEmpty && raw != '상대방') {
      return raw;
    }
    // TODO: 나중에 peerName / peerEmail 같은 필드 추가되면 여기서 사용
    return '상대방';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: _AppBarTitle(onRefresh: () => _load(silent: false)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Scaffold(
        appBar: _AppBarTitle(onRefresh: () => _load(silent: false)),
        body: Center(child: Text(_error!)),
      );
    }
    if (_items.isEmpty) {
      return Scaffold(
        appBar: _AppBarTitle(onRefresh: () => _load(silent: false)),
        body: const Center(child: Text('채팅방이 없습니다.')),
      );
    }

    return Scaffold(
      appBar: _AppBarTitle(onRefresh: () => _load(silent: false)),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: _items.length,
          separatorBuilder: (_, __) => const Divider(height: 1, thickness: 0.4),
          itemBuilder: (context, index) {
            final chat = _items[index];
            return ListTile(
              onTap: () async {
                await context.pushNamed(
                  R.RouteNames.chatRoomOverlay,
                  // 🔸 roomId로 사용하는 필드가 뭐가 맞는지 주의 (id vs roomId)
                  pathParameters: {'roomId': chat.id},
                  extra: {
                    'partnerName': _displayName(chat),
                    'isKuDelivery': false,
                    'securePaid': false,
                  },
                );
                if (!mounted) return;
                _load(silent: true); // 복귀 후 갱신(읽음/최근 메시지 반영)
              },
              leading: _Avatar(url: chat.avatarUrl),
              title: Text(
                _displayName(chat),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  chat.lastMessage.isEmpty ? '(메시지가 없습니다)' : chat.lastMessage,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    df.format(chat.updatedAt),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.grey),
                  ),
                  const SizedBox(height: 6),
                  if (chat.unreadCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      child: Text(
                        '${chat.unreadCount}',
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
      ),
    );
  }
}

class _AppBarTitle extends StatelessWidget implements PreferredSizeWidget {
  final VoidCallback onRefresh;
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
            onPressed: onRefresh,
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
