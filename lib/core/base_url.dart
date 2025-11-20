// lib/core/base_url.dart
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/foundation.dart' show debugPrint;

/// ===============================
/// 1) 빌드 환경 ENV
/// ===============================
/// flutter build web --dart-define=API_ORIGIN=https://xxxx.com
const String _envOrigin =
    String.fromEnvironment('API_ORIGIN', defaultValue: '');

/// ===============================
/// 2) 플랫폼 자동 ORIGIN 결정 (웹 제외)
/// ===============================
/// 웹에서는 자동 감지 금지 → 반드시 ENV 사용.
/// 모바일/데스크탑에서는 기존 값 유지.
String _autoOrigin() {
  if (kIsWeb) {
    // Web 빌드에서 빈 문자열("")을 반환하면 Uri.parse("")가 발생하여 Flutter가 크래시함.
    // 따라서 ENV가 비어 있으면 fallback 고정 값을 반환한다.
    if (_envOrigin.isEmpty) {
      debugPrint(
        '[ERROR] API_ORIGIN is empty. Set via --dart-define=API_ORIGIN=<your-api-url>',
      );
      return 'http://invalid-origin'; // 절대 "" 반환 금지!!!
    }
    return _envOrigin.trim();
  }

  // 모바일/데스크탑 자동 설정
  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
      return 'http://10.0.2.2:3000'; // Android emulator
    case TargetPlatform.iOS:
    case TargetPlatform.macOS:
    case TargetPlatform.windows:
    case TargetPlatform.linux:
      return 'http://127.0.0.1:3000';
    default:
      return 'http://127.0.0.1:3000';
  }
}

/// ===============================
/// 3) API Origin (ENV > 자동)
/// ===============================
/// Web → 무조건 _autoOrigin() (ENV or fallback)
/// Mobile/PC → ENV 있으면 ENV, 아니면 자동값
String apiOrigin() {
  if (kIsWeb) return _autoOrigin();

  // 모바일/데스크탑
  return _envOrigin.isNotEmpty ? _envOrigin.trim() : _autoOrigin();
}

/// ===============================
/// 4) REST Base (/api/v1)
/// ===============================
String restBase() => '${apiOrigin()}/api/v1';

/// 기존 코드 호환용 상수(런타임 계산값)
final String kApiOrigin = apiOrigin();
final String kApiBase = restBase();

/// ===============================
/// 내부 util
/// ===============================
String _norm(String path) => path.startsWith('/') ? path : '/$path';

bool _isAbsoluteUrl(String s) =>
    s.startsWith('http://') || s.startsWith('https://');

Map<String, String> _stringifyQuery(Map<String, dynamic> raw) =>
    raw.map((k, v) => MapEntry(k, v?.toString() ?? ''));

/// ===============================
/// 5) REST API URL 빌더
/// ===============================
Uri apiUrl(String path, [Map<String, dynamic>? query]) {
  // 1) 절대 URL이면 그대로
  if (_isAbsoluteUrl(path)) {
    final baseUri = Uri.parse(path);
    if (query == null || query.isEmpty) return baseUri;

    final merged = {
      ...baseUri.queryParameters,
      ..._stringifyQuery(query),
    };
    return baseUri.replace(queryParameters: merged);
  }

  // 2) 상대 경로 → 반드시 valid origin 기반
  final uri = Uri.parse('${restBase()}${_norm(path)}');
  if (query == null || query.isEmpty) return uri;

  return uri.replace(queryParameters: _stringifyQuery(query));
}

/// ===============================
/// 6) WebSocket URL 빌더
/// ===============================
String wsUrl({required String meUserId, String? roomId}) {
  final httpOrigin = apiOrigin();

  final wsScheme = httpOrigin.startsWith('https') ? 'wss' : 'ws';
  final wsOrigin = httpOrigin.replaceFirst(RegExp(r'^https?'), wsScheme);

  final params = <String, String>{'me': meUserId};
  if (roomId != null && roomId.isNotEmpty) params['room'] = roomId;

  final uri =
      Uri.parse('$wsOrigin/ws/realtime').replace(queryParameters: params);
  return uri.toString();
}
