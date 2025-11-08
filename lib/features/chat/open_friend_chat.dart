// lib/features/chat/open_friend_chat.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../friend/friend_chat_screen.dart';
import 'data/chats_api.dart';

// 숫자/UUID 모두 -> UUID로 정규화
final RegExp _uuidRe = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
  caseSensitive: false,
);

String _leftPadZeros(String s, int total) {
  final need = total - s.length;
  if (need <= 0) return s;
  final b = StringBuffer();
  for (var i = 0; i < need; i++) {
    b.writeCharCode(48); // '0'
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

/// 친구 채팅방으로 이동 (상품 채팅 X)
/// - peerId: 상대 유저 id(숫자/UUID 허용)
/// - partnerName: 앱바에 표시할 상대 이름
Future<void> openFriendChat({
  required BuildContext context,
  required String peerId,
  required String partnerName,
}) async {
  final peer = _normalizeId(peerId);
  if (peer.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('상대 사용자 ID가 유효하지 않습니다.')),
    );
    return;
  }

  // meUserId는 저장된 세션에서 추출
  String? meUserId;
  try {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString('session.v1');
    if (raw != null && raw.isNotEmpty) {
      final j = jsonDecode(raw);
      if (j is Map && j['user'] is Map) {
        meUserId = _normalizeId((j['user'] as Map)['id']);
      }
    }
  } catch (_) {}
  meUserId ??= ''; // null 방지
  if (meUserId!.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('로그인 정보를 불러오지 못했습니다. 다시 로그인 해주세요.')),
    );
    return;
  }

  try {
    // 1) 서버에서 친구방 확보
    final roomId = await chatsApi.ensureTrade(peer);

    // 2) 친구 채팅 화면으로 이동 (✅ FriendChatPage)
    if (context.mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => FriendChatPage(
            friendName: partnerName,
            meUserId: meUserId!,
            roomId: roomId,
          ),
        ),
      );
    }
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('채팅방 진입 실패: $e')),
    );
  }
}
