// lib/features/chat/open_friend_chat.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kumeong_store/features/friend/friend_chat_screen.dart';
import 'package:kumeong_store/features/chat/data/chats_api.dart';

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

/// 친구와 채팅 열기: 방 보장 후 **FriendChatPage** 로 이동
Future<void> openFriendChat({
  required BuildContext context,
  required String peerId,
  String? partnerName, // 앱바 타이틀에 표시
}) async {
  // 로딩 다이얼로그
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(child: CircularProgressIndicator()),
    useRootNavigator: true,
  );

  void _closeLoading() {
    final nav = Navigator.of(context, rootNavigator: true);
    if (nav.canPop()) nav.pop();
  }

  try {
    // 0) id 정규화
    final peer = _normalizeId(peerId);
    if (peer.isEmpty) {
      _closeLoading();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('상대 사용자 ID가 유효하지 않습니다.')),
        );
      }
      return;
    }

    // 1) 세션에서 meUserId 꺼내기
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
    meUserId ??= '';
    if (meUserId!.isEmpty) {
      _closeLoading();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('로그인 정보를 불러오지 못했습니다. 다시 로그인 해주세요.')),
        );
      }
      return;
    }

    // 2) 서버에서 친구방 확보
    final roomId = await chatsApi.ensureFriendRoom(peer);

    // 3) 로딩 닫고, 친구 채팅 화면으로 이동
    _closeLoading();
    if (!context.mounted) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FriendChatPage(
          friendName: partnerName ?? '친구',
          meUserId: meUserId!,
          roomId: roomId,
        ),
      ),
    );
  } catch (e) {
    _closeLoading();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('채팅방 열기 실패: $e')),
    );
  }
}
