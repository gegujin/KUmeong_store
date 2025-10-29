import 'dart:convert';
import 'package:http/http.dart' as http;

class UserMini {
  final String id;
  final String name;
  final String email;
  UserMini({required this.id, required this.name, required this.email});
}

class FriendSummary {
  final String userId;
  final String displayName;
  final int tradeCount;
  final double trustScore;
  final DateTime? lastActiveAt;
  final bool pendingLocal;
  FriendSummary({
    required this.userId,
    required this.displayName,
    required this.tradeCount,
    required this.trustScore,
    this.lastActiveAt,
    this.pendingLocal = false,
  });

  factory FriendSummary.fromJson(Map<String, dynamic> j) {
    String _s(k) => (j[k] ?? '').toString();
    num _n(k) => (j[k] is num) ? j[k] as num : num.tryParse(_s(k)) ?? 0;
    return FriendSummary(
      userId: _s('userId').isNotEmpty
          ? _s('userId')
          : (_s('friendId').isNotEmpty ? _s('friendId') : _s('id')),
      displayName: _s('displayName').isNotEmpty
          ? _s('displayName')
          : (_s('friendName').isNotEmpty ? _s('friendName') : _s('name')),
      tradeCount: _n('tradeCount').toInt(),
      trustScore: _n('trustScore').toDouble(),
      lastActiveAt: j['lastActiveAt'] != null
          ? DateTime.tryParse(_s('lastActiveAt'))
          : null,
    );
  }
}

class FriendApi {
  final String baseUrl;
  final Future<String?> Function() tokenProvider;
  FriendApi({required this.baseUrl, required this.tokenProvider});

  Future<Map<String, String>> _authHeaders() async {
    final t = await tokenProvider();
    return {
      'Content-Type': 'application/json',
      if (t != null && t.isNotEmpty) 'Authorization': 'Bearer $t',
    };
  }

  /// (선택) 이메일→사용자 조회가 필요할 때만 사용.
  /// GET /v1/users/lookup?email=...
  Future<UserMini> lookupUserByEmail(String email) async {
    final uri = Uri.parse('$baseUrl/v1/users/lookup?email=$email');
    final res = await http.get(uri, headers: await _authHeaders());
    if (res.statusCode != 200) throw Exception('사용자를 찾을 수 없습니다.');
    final j = jsonDecode(res.body);
    final d = (j is Map && j['data'] != null) ? j['data'] : j;
    return UserMini(
      id: d['id'] as String,
      name: (d['name'] ?? '') as String,
      email: (d['email'] ?? email) as String,
    );
  }

  /// POST /v1/friends/requests  { toUserId? , targetEmail? }
  Future<void> sendFriendRequest(
      {String? toUserId, String? targetEmail}) async {
    final uri = Uri.parse('$baseUrl/v1/friends/requests');
    final payload = <String, dynamic>{
      if (toUserId != null && toUserId.isNotEmpty) 'toUserId': toUserId,
      if (targetEmail != null && targetEmail.isNotEmpty)
        'targetEmail': targetEmail,
    };
    final res = await http.post(uri,
        headers: await _authHeaders(), body: jsonEncode(payload));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(res.body.isNotEmpty ? res.body : '친구 요청 전송 실패');
    }
  }

  /// GET /v1/friends
  Future<List<FriendSummary>> fetchFriends() async {
    final uri = Uri.parse('$baseUrl/v1/friends');
    final res = await http.get(uri, headers: await _authHeaders());
    if (res.statusCode != 200) throw Exception('친구 목록을 불러오지 못했습니다.');
    final j = jsonDecode(res.body);
    final data = (j is Map) ? (j['data'] as List? ?? []) : (j as List? ?? []);
    return data
        .map((e) => FriendSummary.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
