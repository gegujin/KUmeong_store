// lib/common/friend_error.dart
import 'dart:convert';

String mapFriendError(String body) {
  try {
    final j = jsonDecode(body);
    final code = j['code'] as String?;
    final msg  = j['message']?.toString();
    switch (code) {
      case 'SELF_NOT_ALLOWED': return '자기 자신에게는 요청할 수 없어요.';
      case 'BLOCKED': return '차단된 사용자입니다.';
      case 'ALREADY_FRIEND': return '이미 친구예요.';
      case 'ALREADY_REQUESTED': return '이미 대기 중인 요청이 있어요.';
      case 'NOT_PENDING': return '대기 중인 요청이 아닙니다.';
      case 'NOT_TARGET': return '이 요청의 대상이 아니에요.';
      case 'NOT_OWNER': return '내가 보낸 요청만 취소할 수 있어요.';
      // DB 트리거 기본 메시지 매핑(방어)
      case 'MYSQL_DUP_PENDING': return '이미 대기 중인 요청이 있어요.';
    }
    if (msg != null && msg.isNotEmpty) return msg;
  } catch (_) {}
  return '요청을 처리할 수 없습니다. 잠시 후 다시 시도해주세요.';
}
