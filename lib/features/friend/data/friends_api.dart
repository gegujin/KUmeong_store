// lib/features/friend/data/friends_api.dart
import 'dart:async'; // TimeoutException
import 'dart:convert'; // jsonDecode

import 'package:kumeong_store/core/network/http_client.dart'; // HttpX, ApiException, apiUrl
import 'package:kumeong_store/features/friend/dto.dart'; // FriendVm, FriendSummaryDto 등

typedef UUID = String;

enum FriendRequestBox { incoming, outgoing }

class FriendRequestRow {
  final UUID id, fromUserId, toUserId;
  final String status;
  final DateTime createdAt;
  final DateTime? decidedAt;
  final String? fromEmail, toEmail;
  final FriendRequestBox? box;

  FriendRequestRow({
    required this.id,
    required this.fromUserId,
    required this.toUserId,
    required this.status,
    required this.createdAt,
    this.decidedAt,
    this.fromEmail,
    this.toEmail,
    this.box,
  });

  factory FriendRequestRow.fromJson(Map<String, dynamic> j) {
    final idStr = (j['id'] ?? j['requestId'])?.toString() ?? '';
    final fromId = (j['fromUserId'] ?? j['otherUserId'])?.toString() ?? '';
    final toId = j['toUserId']?.toString() ?? '';
    final status = (j['status'] ?? 'PENDING').toString();

    final createdRaw = (j['createdAt'] ?? j['requestedAt'])?.toString();
    final createdAt =
        createdRaw != null ? DateTime.parse(createdRaw) : DateTime.fromMillisecondsSinceEpoch(0);

    final decidedRaw = j['decidedAt']?.toString();
    final fromEmail = (j['fromEmail'] ?? j['otherEmail'])?.toString();
    final toEmail = j['toEmail']?.toString();

    final boxStr = j['box']?.toString();
    final box = switch (boxStr) {
      'incoming' => FriendRequestBox.incoming,
      'outgoing' => FriendRequestBox.outgoing,
      _ => null,
    };

    return FriendRequestRow(
      id: idStr,
      fromUserId: fromId,
      toUserId: toId,
      status: status,
      createdAt: createdAt,
      decidedAt: decidedRaw != null ? DateTime.parse(decidedRaw) : null,
      fromEmail: fromEmail,
      toEmail: toEmail,
      box: box,
    );
  }
}

class FriendsApi {
  const FriendsApi();

  // ─────────────────────────────────────────────────────────
  // ✅ ID 기반 상태 변경(권장)
  // ─────────────────────────────────────────────────────────

  /// 친구요청 수락. 성공 시 roomId 반환.
  Future<String> acceptById(String requestId) async {
    final j = await HttpX.postJson('/friends/requests/$requestId/accept', const {});
    if (j is Map) {
      final data = (j['data'] is Map) ? j['data'] as Map : j;
      final rid = (data['roomId'] ?? data['id'] ?? '').toString();
      if (rid.isNotEmpty) return rid;
    }
    throw StateError('수락 응답에 roomId가 없습니다.');
  }

  Future<void> rejectById(String requestId) async {
    await HttpX.postJson('/friends/requests/$requestId/reject', const {});
  }

  Future<void> cancelById(String requestId) async {
    await HttpX.postJson('/friends/requests/$requestId/cancel', const {});
  }

  // ─────────────────────────────────────────────────────────
  // (보조) 이메일 기반 — 레거시/임시 호환용
  // ─────────────────────────────────────────────────────────

  @deprecated
  Future<void> request(String toUserId) async {
    throw UnimplementedError('id 기반 API는 폐기되었습니다. requestByEmail을 사용하세요.');
  }

  Future<void> requestByEmail(String email) async {
    if (email.isEmpty) throw Exception('email을 입력하세요.');
    await HttpX.postJson('/friends/requests/by-email', {'email': email});
  }

  /// 받은/보낸 요청 목록
  Future<List<FriendRequestRow>> listRequests(FriendRequestBox box) async {
    final j = await HttpX.get('/friends/requests', query: {'box': box.name});
    final raw = (j is Map) ? j['data'] : null;
    final data = (raw is List) ? raw : const [];
    final all = data.whereType<Map<String, dynamic>>().map(FriendRequestRow.fromJson).toList();
    return all.where((r) => r.box == null || r.box == box).toList();
  }

  Future<void> acceptByEmail(String fromEmail) async {
    await HttpX.postJson('/friends/requests/by-email/accept', {'email': fromEmail});
  }

  Future<void> rejectByEmail(String fromEmail) async {
    await HttpX.postJson('/friends/requests/by-email/reject', {'email': fromEmail});
  }

  Future<void> cancelByEmail(String toEmail) async {
    await HttpX.postJson('/friends/requests/by-email/cancel', {'email': toEmail});
  }

  // ─────────────────────────────────────────────────────────
  // 친구 목록 / 프로필
  // ─────────────────────────────────────────────────────────

  /// 친구 목록(간단 뷰모델) — FriendSummaryDto 사용
  Future<List<FriendSummaryDto>> listFriends() async {
    final j = await HttpX.get('/friends');
    final raw = (j is Map) ? j['data'] : null;
    final data = (raw is List) ? raw : const [];
    return data.whereType<Map<String, dynamic>>().map(FriendSummaryDto.fromJson).toList();
  }

  /// (옵션) FriendVm를 반환하는 목록 — 필요 시 사용
  Future<List<FriendSummaryDto>> list() async {
    try {
      final j = await HttpX.get('/friends').timeout(const Duration(seconds: 10));
      final data = (j is Map && j['data'] is List) ? j['data'] as List : const [];
      return data.whereType<Map<String, dynamic>>().map(FriendSummaryDto.fromJson).toList();
    } on TimeoutException {
      throw ApiException('요청이 지연되었습니다. 네트워크 상태를 확인해주세요.');
    }
  }

  Future<void> unfriend(String peerId) async {
    await HttpX.delete('/friends/$peerId');
  }

  Future<void> blockFriend(String peerId) async {
    final j = await HttpX.postJson('/friends/blocks/$peerId', const {});
    if (j is Map && j['ok'] != true) {
      throw StateError(j['message']?.toString() ?? '차단 실패');
    }
  }

  Future<void> unblock(String peerId) async {
    final j = await HttpX.delete('/friends/blocks/$peerId');
    if (j is Map && j['ok'] != true) {
      throw StateError(j['message']?.toString() ?? '차단 해제 실패');
    }
  }

  Future<FriendProfile> getFriendProfile(String peerId) async {
    final j = await HttpX.get('/friends/$peerId/profile');
    final data = (j is Map && j['data'] is Map)
        ? (j['data'] as Map).cast<String, dynamic>()
        : <String, dynamic>{};
    return FriendProfile.fromJson(data);
  }
}

final friendsApi = FriendsApi();

class FriendProfile {
  final String userId;
  final String email;
  final double trustScore;
  final int tradeCount;

  FriendProfile({
    required this.userId,
    required this.email,
    required this.trustScore,
    required this.tradeCount,
  });

  factory FriendProfile.fromJson(Map<String, dynamic> j) => FriendProfile(
        userId: (j['userId'] ?? j['id'] ?? '').toString(),
        email: (j['email'] ?? '').toString(),
        trustScore: (j['trustScore'] is num)
            ? (j['trustScore'] as num).toDouble()
            : double.tryParse('${j['trustScore']}') ?? 0.0,
        tradeCount: (j['tradeCount'] is num)
            ? (j['tradeCount'] as num).toInt()
            : int.tryParse('${j['tradeCount']}') ?? 0,
      );
}
