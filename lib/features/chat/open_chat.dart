// lib/features/chat/open_chat.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kumeong_store/features/friend/friend_chat_screen.dart';
import 'package:kumeong_store/features/chat/chat_room_screen.dart';
import 'package:kumeong_store/features/chat/data/chats_api.dart';

/// ─────────────────────────────────────────────
/// 공통: ID 정규화(숫자/UUID → UUID) & 친구 룸ID 규칙
/// ─────────────────────────────────────────────

final RegExp _uuidRe = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
  caseSensitive: false,
);

bool _isUuid(String s) => _uuidRe.hasMatch(s);

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

/// me/peer UUID를 소문자 정규화 → 사전순 정렬 → 'a_b'로 결합
String _calcFriendRoomId(String me, String peer) {
  final a = _normalizeId(me);
  final b = _normalizeId(peer);
  if (a.isEmpty || b.isEmpty) return '';
  return (a.compareTo(b) <= 0) ? '${a}_${b}' : '${b}_${a}';
}

/// 세션에서 me.id 혹은 user.id를 안전히 읽어오기
Future<String> _readMeUserId() async {
  try {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString('session.v1');
    if (raw == null || raw.isEmpty) return '';
    final j = jsonDecode(raw);
    if (j is Map) {
      if (j['me'] is Map && (j['me'] as Map)['id'] != null) {
        return _normalizeId((j['me'] as Map)['id']);
      }
      if (j['user'] is Map && (j['user'] as Map)['id'] != null) {
        return _normalizeId((j['user'] as Map)['id']);
      }
    }
    return '';
  } catch (_) {
    return '';
  }
}

void _showLoading(BuildContext context) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(child: CircularProgressIndicator()),
    useRootNavigator: true,
  );
}

void _closeLoading(BuildContext context) {
  final nav = Navigator.of(context, rootNavigator: true);
  if (nav.canPop()) nav.pop();
}

void _toast(BuildContext context, String msg) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
}

/// ─────────────────────────────────────────────
/// 친구와 채팅 열기 (서버 호출 없음)
///   - me/peer로 roomId 계산 → FriendChatPage로 이동
/// ─────────────────────────────────────────────
Future<void> openFriendChat({
  required BuildContext context,
  required String peerId,
  String? partnerName, // 앱바 타이틀
}) async {
  _showLoading(context);

  try {
    // 0) peer 정규화
    final peer = _normalizeId(peerId);
    if (peer.isEmpty) {
      _closeLoading(context);
      _toast(context, '상대 사용자 ID가 유효하지 않습니다.');
      return;
    }

    // 1) 세션에서 meUserId
    final meUserId = await _readMeUserId();
    if (meUserId.isEmpty) {
      _closeLoading(context);
      _toast(context, '로그인 정보를 불러오지 못했습니다. 다시 로그인 해주세요.');
      return;
    }

    // 2) 친구 룸ID 로컬 계산 (서버 호출 불필요)
    final String roomId = _calcFriendRoomId(meUserId, peer);
    if (roomId.isEmpty) {
      _closeLoading(context);
      _toast(context, '채팅방 ID 계산에 실패했습니다.');
      return;
    }

    // 3) 이동
    _closeLoading(context);
    if (!context.mounted) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FriendChatPage(
          friendName: partnerName ?? '친구',
          meUserId: meUserId,
          roomId: roomId,
        ),
      ),
    );
  } catch (e) {
    _closeLoading(context);
    if (!context.mounted) return;
    _toast(context, '채팅방 열기 실패: $e');
  }
}

/// ─────────────────────────────────────────────
/// 상품 채팅 열기 (서버 멱등생성 필요)
///   - productId(UUID)로 ensureTrade 호출 → ChatScreen으로 이동
/// ─────────────────────────────────────────────
Future<void> openProductChat({
  required BuildContext context,
  required String productId, // 반드시 UUID
  String? sellerId,
  String? sellerName,
  bool isKuDelivery = false,
  bool securePaid = false,
}) async {
  _showLoading(context);

  try {
    final pid = productId.trim();
    if (!_isUuid(pid)) {
      _closeLoading(context);
      _toast(context, '상품 ID가 유효한 UUID가 아닙니다.');
      return;
    }

    // (선택) meUserId 필요 시 읽기
    final meUserId = await _readMeUserId();
    if (meUserId.isEmpty) {
      _closeLoading(context);
      _toast(context, '로그인 정보를 불러오지 못했습니다. 다시 로그인 해주세요.');
      return;
    }

    // 1) 서버에서 거래방 멱등 생성
    final api = const ChatsApi();
    final String roomId = await api.ensureTrade(pid);

    // 2) 이동
    _closeLoading(context);
    if (!context.mounted) return;

    // ChatScreen으로 진입 (파트너명/배달옵션 전달)
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          partnerName: sellerName ?? '판매자',
          roomId: roomId,
          isKuDelivery: isKuDelivery,
          securePaid: securePaid,
        ),
      ),
    );
  } catch (e) {
    _closeLoading(context);
    if (!context.mounted) return;
    _toast(context, '상품 채팅 열기 실패: $e');
  }
}
