// C:\Users\82105\KU-meong Store\lib\features\friend\friend_detail_screen.dart
import 'package:flutter/material.dart';
import '../friend/friend_chat_screen.dart';
import '../chat/data/chats_api.dart';

class FriendDetailPage extends StatelessWidget {
  final String friendName;
  final String meUserId; // 로그인 사용자 ID
  final String peerUserId; // 친구 ID (숫자/UUID 허용)
  final String? avatarUrl;

  const FriendDetailPage({
    super.key,
    required this.friendName,
    required this.meUserId,
    required this.peerUserId,
    this.avatarUrl,
  });

  // ───────── UUID/숫자 정규화 ─────────
  // static final RegExp _uuidRe = RegExp(
  //   r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
  //   caseSensitive: false,
  // );

  static final RegExp _uuidRe = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
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

  String _normalizeId(Object? raw) {
    final s = (raw ?? '').toString().trim();
    if (s.isEmpty) return '';
    if (_uuidRe.hasMatch(s)) return s.toLowerCase();

    // 숫자만 추출 → 마지막 12자리 → 00000000-0000-0000-0000-XXXXXXXXXXXX
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      final c = s.codeUnitAt(i);
      if (c >= 48 && c <= 57) buf.writeCharCode(c);
    }
    final digits = buf.toString();
    if (digits.isEmpty) return '';
    final start = digits.length > 12 ? digits.length - 12 : 0;
    final last12 = digits.substring(start);
    final padded = _leftPadZeros(last12, 12);
    return '00000000-0000-0000-0000-$padded';
  }
  // ───────────────────────────────────

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
              backgroundImage:
                  (avatarUrl != null && avatarUrl!.isNotEmpty) ? NetworkImage(avatarUrl!) : null,
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
                onPressed: () async {
                  final peer = _normalizeId(peerUserId);
                  if (peer.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('상대 사용자 ID가 유효하지 않습니다.')),
                    );
                    return;
                  }

                  try {
                    // ✅ ChatApi 로컬 생성 (HttpX는 static 메서드이므로 주입 불필요)
                    final api = ChatApi(meUserId: meUserId);

                    // ✅ 친구방 확보 (백엔드: GET /chat/friend-room)
                    final roomId = await chatsApi.ensureFriendRoom(peerUserId);

                    // ✅ 채팅 화면으로 이동
                    final chatClosed = await Navigator.of(context).push<bool>(
                      MaterialPageRoute(
                        builder: (_) => FriendChatPage(
                          friendName: friendName,
                          meUserId: meUserId,
                          roomId: roomId, // 이미 소문자 정규화됨
                        ),
                      ),
                    );

                    if (chatClosed == true && context.mounted) {
                      Navigator.of(context).pop(true);
                    }
                  } catch (e) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('채팅방 진입 실패: $e')),
                    );
                  }
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
