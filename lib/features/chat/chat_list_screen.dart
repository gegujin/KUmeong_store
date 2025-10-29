// lib/features/chat/chat_list_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:kumeong_store/core/widgets/app_bottom_nav.dart'; // 하단바
import '../../core/theme.dart';
import 'package:kumeong_store/core/router/route_names.dart' as R;

class ChatSummary {
  final String id; // 채팅방 ID
  final String partnerName; // 거래자 이름
  final String lastMessage; // 마지막 메시지
  final DateTime updatedAt; // 마지막 갱신 시간
  final int unreadCount; // 안읽은 개수
  final String? avatarUrl; // 프로필 이미지(옵션)

  const ChatSummary({
    required this.id,
    required this.partnerName,
    required this.lastMessage,
    required this.updatedAt,
    this.unreadCount = 0,
    this.avatarUrl,
  });
}

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  // TODO: 이후 Firebase/서버 연동으로 교체
  List<ChatSummary> _items = [
    ChatSummary(
      id: 'room-1',
      partnerName: '거래자',
      lastMessage: '1:1 채팅 내용 ( 채팅 거래, 가격 협의 )',
      updatedAt: DateTime.now(),
    ),
  ];

  @override
  void initState() {
    super.initState();
    // 데모 데이터 조금 늘리기 (시간/읽지않음 수 랜덤)
    final now = DateTime.now();
    _items = List.generate(4, (i) {
      return ChatSummary(
        id: 'room-${i + 1}',
        partnerName: '거래자${i == 0 ? '' : i + 0}', // 첫 줄만 '거래자'
        lastMessage: i == 0
            ? '1:1 채팅 내용 ( 채팅 거래, 가격 협의 )'
            : '최근 메시지 미리보기입니다. 길면 … 으로 잘려요.',
        updatedAt: now.subtract(Duration(minutes: (i + 1) * 7)),
        unreadCount: i == 0 ? 0 : (i % 3 == 0 ? 2 : (i % 2)),
        avatarUrl: null,
      );
    });
  }

  Future<void> _refresh() async {
    // TODO: 실제 데이터 새로고침으로 교체
    await Future.delayed(const Duration(milliseconds: 600));
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('HH:mm'); // 하단 시간 표기
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('채팅'),
        actions: [
          IconButton(
            tooltip: '알림',
            onPressed: () {
              // TODO: 알림 화면 라우팅
            },
            icon: const Icon(Icons.notifications_none_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: _items.length,
          separatorBuilder: (_, __) => const Divider(height: 1, thickness: 0.4),
          itemBuilder: (context, index) {
            final chat = _items[index];
            return ListTile(
              onTap: () {
                context.pushNamed(
                  R.RouteNames.chatRoomOverlay, // ✅ 루트 레벨 오버레이
                  pathParameters: {'roomId': chat.id},
                  extra: {
                    'partnerName': chat.partnerName,
                    'isKuDelivery': false,
                    'securePaid': false
                  },
                );
              },
              leading: _Avatar(url: chat.avatarUrl),
              title: Text(
                chat.partnerName,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  chat.lastMessage,
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
                    style: Theme.of(context)
                        .textTheme
                        .labelSmall
                        ?.copyWith(color: Colors.grey),
                  ),
                  const SizedBox(height: 6),
                  if (chat.unreadCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        // 테마 색으로 바꾸고 싶으면 Theme.of(context).colorScheme.primary 사용
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
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            );
          },
        ),
      ),
      // bottomNavigationBar: const AppBottomNav(currentIndex: 1),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({this.url});
  final String? url;

  @override
  Widget build(BuildContext context) {
    final radius = 26.0;
    if (url == null || url!.isEmpty) {
      return CircleAvatar(
        radius: radius,
        child: const Icon(Icons.person),
      );
    }
    return CircleAvatar(
      radius: radius,
      backgroundImage: NetworkImage(url!),
      backgroundColor: Colors.transparent,
    );
  }
}
