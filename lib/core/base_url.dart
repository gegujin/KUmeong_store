// lib/core/base_url.dart
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;

/// ===============================
/// ORIGIN 결정 (환경변수 > 플랫폼별 자동)
/// ===============================
/// 빌드 시 --dart-define=API_ORIGIN=http://192.168.0.5:3000 로 덮어쓰기 가능.
const String _envOrigin =
    String.fromEnvironment('API_ORIGIN', defaultValue: '');

String _autoOrigin() {
  if (kIsWeb) {
    // 웹에선 현재 호스트를 따라가되, 백엔드 포트(3000)로 맞춘다.
    // 예: http://127.0.0.1:6529 → http://127.0.0.1:3000
    final base = Uri.base; // org-dartlang-app:/web_entrypoint.dart 일 수도 있음
    final scheme = (base.scheme == 'https' || base.scheme == 'http')
        ? base.scheme
        : 'http';
    final host = (base.host.isNotEmpty) ? base.host : 'localhost';
    return Uri(
      scheme: scheme,
      host: host,
      port: 3000,
    ).toString();
  }

  // dart:io 없이 플랫폼별 기본값
  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
      // Android emulator → 호스트는 10.0.2.2
      return 'http://10.0.2.2:3000';
    case TargetPlatform.iOS:
    case TargetPlatform.macOS:
    case TargetPlatform.windows:
    case TargetPlatform.linux:
      return 'http://127.0.0.1:3000';
    default:
      return 'http://127.0.0.1:3000';
  }
}

/// 최종 ORIGIN (환경변수 우선)
String apiOrigin() => _envOrigin.isNotEmpty ? _envOrigin : _autoOrigin();

/// ===============================
/// REST Base (/api/v1 고정)
/// ===============================
String restBase() => '${apiOrigin()}/api/v1';

/// 기존 코드 호환용 상수(런타임 계산값)
final String kApiOrigin = apiOrigin();
final String kApiBase = restBase();

/// 내부 경로 정규화: 선두 슬래시 보장
String _norm(String path) => path.startsWith('/') ? path : '/$path';

bool _isAbsoluteUrl(String s) =>
    s.startsWith('http://') || s.startsWith('https://');

Map<String, String> _stringifyQuery(Map<String, dynamic> raw) =>
    raw.map((k, v) => MapEntry(k, v?.toString() ?? ''));

/// ===============================
/// REST API URL 빌더 (호환용)
/// ===============================
/// 예) apiUrl('/auth/me') → http://<origin>/api/v1/auth/me
/// 예) apiUrl('http://.../api/v1/chat/friend-room', {'peerId': '...'})
///   → 절대 URL 유지 + 쿼리 병합
Uri apiUrl(String path, [Map<String, dynamic>? query]) {
  // 1) 절대 URL이면 그대로 사용(추가 쿼리 있으면 기존 쿼리와 병합)
  if (_isAbsoluteUrl(path)) {
    final baseUri = Uri.parse(path);
    if (query == null || query.isEmpty) return baseUri;

    final merged = {
      ...baseUri.queryParameters,
      ..._stringifyQuery(query),
    };
    return baseUri.replace(queryParameters: merged);
  }

  // 2) 상대 경로면 /api/v1 프리픽스 부착
  final uri = Uri.parse('${restBase()}${_norm(path)}');
  if (query == null || query.isEmpty) return uri;

  return uri.replace(queryParameters: _stringifyQuery(query));
}

/// ===============================
/// WebSocket URL
/// ===============================
/// 서버: WS_PATH=/ws/realtime
/// 프로젝트 컨벤션: ?room=<roomId>&me=<uuid>
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
