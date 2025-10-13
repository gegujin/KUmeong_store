// C:\Users\82105\KU-meong Store\lib\core\chat_api.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

class ChatMessageDto {
  final String id;          // UUID(8-4-4-4-12; 서버에서 생성)
  final String senderId;    // UUID
  final String content;
  final DateTime createdAt;
  final bool? readByPeer;
  final bool? readByMe;

  ChatMessageDto({
    required this.id,
    required this.senderId,
    required this.content,
    required this.createdAt,
    this.readByPeer,
    this.readByMe,
  });

  factory ChatMessageDto.fromJson(Map<String, dynamic> j) {
    return ChatMessageDto(
      id: (j['id'] ?? '').toString(),
      senderId: (j['senderId'] ?? '').toString(),
      content: (j['text'] ?? j['content'] ?? '') as String,
      createdAt: DateTime.parse(j['createdAt'] as String),
      readByPeer: j['readByPeer'] as bool?,
      readByMe: j['readByMe'] as bool?,
    );
  }
}

class ChatApi {
  final String baseUrl;   // e.g. http://localhost:3000/api/v1
  final http.Client _client;

  // 정규화된 "내 ID"(항상 UUID 8-4-4-4-12로 통일)
  final String _meUuid;

  ChatApi({
    required this.baseUrl,
    required String meUserId, // 숫자/UUID 모두 허용
    http.Client? client,
  })  : _client = client ?? http.Client(),
        _meUuid = _normalizeId(meUserId);

  // ───────────────── 내부 유틸 (서버 규칙과 동일) ─────────────────

  static bool _ok(int s) => s >= 200 && s < 300;

  // UUID 패턴 (버전 고정 아님)
  static final RegExp _uuidRe = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
    caseSensitive: false,
  );

  static bool _isUuid(String? v) => v != null && _uuidRe.hasMatch(v);

  // replace 없이 숫자만 추출
  static String _digitsOnly(String s) {
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      final c = s.codeUnitAt(i);
      if (c >= 48 && c <= 57) b.writeCharCode(c); // '0'..'9'
    }
    return b.toString();
  }

  // 왼쪽 0 패딩 (padStart 미사용)
  static String _leftPadZeros(String s, int total) {
    final need = total - s.length;
    if (need <= 0) return s;
    final b = StringBuffer();
    for (var i = 0; i < need; i++) b.writeCharCode(48);
    b.write(s);
    return b.toString();
  }

  /// 숫자/UUID를 표준 UUID(8-4-4-4-12)로 정규화.
  /// - "1" -> "00000000-0000-0000-0000-000000000001"
  /// - "123456789012345" -> "...-234567890123" (오른쪽 12자리)
  /// - 이미 UUID면 그대로 소문자화
  /// - 그 외는 빈 문자열 반환
  static String _normalizeId(String? raw) {
    final s = (raw ?? '').trim();
    if (s.isEmpty) return '';
    if (_isUuid(s)) return s.toLowerCase();

    final digits = _digitsOnly(s);
    if (digits.isEmpty) return '';

    final start = digits.length > 12 ? digits.length - 12 : 0;
    final last12 = digits.substring(start);
    final padded = _leftPadZeros(last12, 12);
    return '00000000-0000-0000-0000-$padded';
  }

  Map<String, String> _headers() => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'X-User-Id': _meUuid, // ✅ 항상 정규화된 "내 ID"
      };

  Uri _build(String path, [Map<String, String>? qp]) {
    final base = Uri.parse(baseUrl);
    return base.replace(
      path: '${base.path}$path',
      queryParameters: qp,
    );
  }

  // 서버 응답을 안전하게 파싱 ({ok:true, data:...} 또는 바로 data 둘 다 수용)
  T _parseData<T>(http.Response res, T Function(Object? json) mapper) {
    final raw = utf8.decode(res.bodyBytes);
    final decoded = raw.isEmpty ? null : jsonDecode(raw);

    Object? payload;
    if (decoded is Map && decoded.containsKey('data')) {
      payload = decoded['data'];
    } else {
      // 리스트/오브젝트를 바로 내려주는 경우도 허용
      payload = decoded;
    }
    return mapper(payload);
  }

  // ───────────────── API ─────────────────

  /// peerId/afterId도 숫자/UUID 모두 허용 → 내부에서 정규화
  Future<List<ChatMessageDto>> fetchMessagesWithPeer(
    String peerId, {
    String? afterId,
    int limit = 50,
  }) async {
    final peer = _normalizeId(peerId);
    if (peer.isEmpty) {
      throw ArgumentError('peerId must be numeric or UUID-like. got: $peerId');
    }
    // ✅ 자기 자신 대화 가드
    if (peer == _meUuid) {
      throw ArgumentError('me and peer cannot be the same.');
    }

    final qp = <String, String>{};
    final normalizedAfter = (afterId != null) ? _normalizeId(afterId) : '';
    if (normalizedAfter.isNotEmpty) qp['afterId'] = normalizedAfter;
    if (limit > 0) qp['limit'] = '$limit';

    final uri = _build('/chats/$peer/messages', qp);
    final res = await _client
        .get(uri, headers: _headers())
        .timeout(const Duration(seconds: 10));

    if (!_ok(res.statusCode)) {
      throw Exception('GET messages failed: ${res.statusCode} ${res.body}');
    }

    return _parseData<List<ChatMessageDto>>(res, (json) {
      final list = (json as List?)?.cast<Map<String, dynamic>>() ?? const [];
      return list.map(ChatMessageDto.fromJson).toList();
    });
  }

  Future<ChatMessageDto> sendToPeer(String peerId, String text) async {
    final peer = _normalizeId(peerId);
    if (peer.isEmpty) {
      throw ArgumentError('peerId must be numeric or UUID-like. got: $peerId');
    }
    // ✅ 자기 자신 대화 가드
    if (peer == _meUuid) {
      throw ArgumentError('me and peer cannot be the same.');
    }

    final uri = _build('/chats/$peer/messages');
    final res = await _client
        .post(uri, headers: _headers(), body: jsonEncode({'text': text}))
        .timeout(const Duration(seconds: 10));

    // ✅ 2xx 전부 성공으로 간주 (201 포함)
    if (!_ok(res.statusCode)) {
      throw Exception('POST send failed: ${res.statusCode} ${res.body}');
    }

    return _parseData<ChatMessageDto>(res, (json) {
      return ChatMessageDto.fromJson((json as Map).cast<String, dynamic>());
    });
  }

  Future<void> markReadUpTo(String peerId, String lastMessageId) async {
    final peer = _normalizeId(peerId);
    final last = _normalizeId(lastMessageId);
    if (peer.isEmpty) {
      throw ArgumentError('peerId must be numeric or UUID-like. got: $peerId');
    }
    if (last.isEmpty) {
      throw ArgumentError('lastMessageId must be numeric or UUID-like. got: $lastMessageId');
    }
    // ✅ 자기 자신 대화 가드
    if (peer == _meUuid) {
      throw ArgumentError('me and peer cannot be the same.');
    }

    final uri = _build('/chats/$peer/read');
    final res = await _client
        .post(uri, headers: _headers(), body: jsonEncode({'lastMessageId': last}))
        .timeout(const Duration(seconds: 8));

    // ✅ 2xx 전부 성공으로 간주 (혹시 204 등도 허용)
    if (!_ok(res.statusCode)) {
      throw Exception('POST read failed: ${res.statusCode} ${res.body}');
    }
  }
}
