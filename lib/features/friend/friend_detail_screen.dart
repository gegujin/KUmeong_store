// C:\Users\82105\KU-meong Store\lib\features\friend\friend_detail_screen.dart
import 'package:flutter/material.dart';
import '../friend/friend_chat_screen.dart';

class FriendDetailPage extends StatelessWidget {
  final String friendName;
  final String meUserId;    // 로그인 사용자 문자열 ID (개발가드 X-User-Id)
  final String peerUserId;  // 친구 ID (숫자 문자열이어야 함: "42" 등)
  final String? avatarUrl;

  const FriendDetailPage({
    super.key,
    required this.friendName,
    required this.meUserId,
    required this.peerUserId,
    this.avatarUrl,
  });

  @override
  Widget build(BuildContext context) {
    final mainColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: mainColor,
        title: Text(friendName, style: const TextStyle(color: Colors.white)),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // 프로필 이미지
            CircleAvatar(
              radius: 50,
              backgroundColor: Colors.grey[300],
              backgroundImage: (avatarUrl != null && avatarUrl!.isNotEmpty)
                  ? NetworkImage(avatarUrl!)
                  : null,
              child: (avatarUrl == null || avatarUrl!.isEmpty)
                  ? Text(
                      friendName.isNotEmpty ? friendName[0] : '?',
                      style: const TextStyle(fontSize: 40, color: Colors.black),
                    )
                  : null,
            ),
            const SizedBox(height: 15),

            // 이름
            Text(
              friendName,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),

            // 별점 (임시 더미)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                5,
                (index) => const Icon(Icons.star, color: Colors.amber, size: 28),
              ),
            ),
            const SizedBox(height: 20),

            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "판매내역",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 10),

            Expanded(
              child: ListView(
                children: const [
                  ListTile(
                    leading: Icon(Icons.shopping_bag),
                    title: Text("노트북 판매"),
                    subtitle: Text("2025-08-01"),
                  ),
                  ListTile(
                    leading: Icon(Icons.shopping_bag),
                    title: Text("책 판매"),
                    subtitle: Text("2025-07-25"),
                  ),
                ],
              ),
            ),

            // 채팅하기 버튼
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: mainColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => FriendChatPage(
                        friendName: friendName,
                        meUserId: meUserId,      // ✅ 문자열 UUID
                        peerUserId: peerUserId,  // ✅ 그대로 문자열 전달
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.chat, color: Colors.white),
                label: const Text(
                  "채팅하기",
                  style: TextStyle(color: Colors.white, fontSize: 18),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
