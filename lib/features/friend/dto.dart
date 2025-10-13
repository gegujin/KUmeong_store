// C:\Users\82105\KU-meong Store\lib\features\friend\dto.dart

/// 친구 요약 DTO
class FriendSummaryDto {
  final String userId;
  final String displayName;
  final double trustScore;
  final int tradeCount;
  final DateTime? friendedAt;

  FriendSummaryDto({
    required this.userId,
    required this.displayName,
    required this.trustScore,
    required this.tradeCount,
    this.friendedAt,
  });

  factory FriendSummaryDto.fromJson(Map<String, dynamic> j) => FriendSummaryDto(
        userId: (j['userId'] ?? j['friendId'] ?? j['id']).toString(),
        displayName:
            (j['displayName'] ?? j['friendName'] ?? j['name'] ?? '').toString(),
        trustScore: ((j['trustScore'] ?? 0) as num).toDouble(),
        tradeCount: (j['tradeCount'] ?? 0) as int,
        friendedAt:
            j['friendedAt'] != null ? DateTime.parse(j['friendedAt']) : null,
      );
}

/// 친구 요청 DTO
class FriendRequestItem {
  final String id;
  final String fromUserId;
  final String toUserId;

  /// 상태: 'pending' | 'accepted' | 'rejected' | 'canceled'
  final String status;

  final DateTime createdAt;
  final DateTime? decidedAt;

  // ===== 표시용(옵션) =====
  final String? fromEmail;
  final String? toEmail;
  final String? fromLoginId;
  final String? toLoginId;

  FriendRequestItem({
    required this.id,
    required this.fromUserId,
    required this.toUserId,
    required this.status,
    required this.createdAt,
    this.decidedAt,
    this.fromEmail,
    this.toEmail,
    this.fromLoginId,
    this.toLoginId,
  });

  factory FriendRequestItem.fromJson(Map<String, dynamic> j) {
    // status 정규화 (null-safe)
    final rawStatus = (j['status'] ?? 'pending').toString();
    final normalizedStatus = rawStatus.toLowerCase();

    return FriendRequestItem(
      id: j['id'].toString(),
      fromUserId: j['fromUserId'].toString(),
      toUserId: j['toUserId'].toString(),
      status: normalizedStatus,
      createdAt: DateTime.parse(j['createdAt'].toString()),
      decidedAt: j['decidedAt'] != null
          ? DateTime.parse(j['decidedAt'].toString())
          : null,
      fromEmail: j['fromEmail'] as String?,
      toEmail: j['toEmail'] as String?,
      fromLoginId: j['fromLoginId'] as String?,
      toLoginId: j['toLoginId'] as String?,
    );
  }

  /// 보낸 사람을 표시할 때 우선순위: email > loginId > UUID
  String get displaySender =>
      fromEmail ?? fromLoginId ?? fromUserId;

  /// 받는 사람을 표시할 때 우선순위: email > loginId > UUID
  String get displayReceiver =>
      toEmail ?? toLoginId ?? toUserId;
}
