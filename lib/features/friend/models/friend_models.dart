// lib/features/friend/models/friend_models.dart
typedef UUID = String;

enum FriendRequestBox { incoming, outgoing }

class FriendRequestRow {
  final UUID id;
  final UUID fromUserId;
  final UUID toUserId;
  final String status; // 'pending'
  final DateTime createdAt;
  final DateTime? decidedAt;
  final String? fromEmail;
  final String? toEmail;

  FriendRequestRow({
    required this.id,
    required this.fromUserId,
    required this.toUserId,
    required this.status,
    required this.createdAt,
    this.decidedAt,
    this.fromEmail,
    this.toEmail,
  });

  factory FriendRequestRow.fromJson(Map<String, dynamic> j) => FriendRequestRow(
        id: j['id'],
        fromUserId: j['fromUserId'],
        toUserId: j['toUserId'],
        status: j['status'],
        createdAt: DateTime.parse(j['createdAt']),
        decidedAt: j['decidedAt'] != null ? DateTime.parse(j['decidedAt']) : null,
        fromEmail: j['fromEmail'],
        toEmail: j['toEmail'],
      );
}

class FriendSummary {
  final UUID userId;
  final String displayName;
  final int trustScore;
  final int tradeCount;
  final List<String> topItems;
  final DateTime? lastActiveAt;

  FriendSummary({
    required this.userId,
    required this.displayName,
    required this.trustScore,
    required this.tradeCount,
    required this.topItems,
    this.lastActiveAt,
  });

  factory FriendSummary.fromJson(Map<String, dynamic> j) => FriendSummary(
        userId: j['userId'],
        displayName: j['displayName'] ?? '',
        trustScore: j['trustScore'] ?? 0,
        tradeCount: j['tradeCount'] ?? 0,
        topItems: (j['topItems'] as List?)?.cast<String>() ?? const [],
        lastActiveAt: j['lastActiveAt'] != null ? DateTime.parse(j['lastActiveAt']) : null,
      );
}
