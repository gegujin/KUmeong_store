import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:kumeong_store/js_interop.dart';
import 'dart:html' as html;

// ===============================================
// 1) 빌드 ENV (모바일/데스크탑 only)
// ===============================================
const String _envOrigin =
    String.fromEnvironment('API_ORIGIN', defaultValue: '');

// ===============================================
// 2) 모바일/데스크탑 기본값 (웹 제외)
// ===============================================
String _autoOrigin() {
  if (kIsWeb) return ''; // ← 웹에서는 절대 fallback 사용 금지

  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
      return 'http://10.0.2.2:3000';
    default:
      return 'http://127.0.0.1:3000';
  }
}

// ===============================================
// 3) Web 런타임 Origin (env.js)
// ===============================================
String _loadWebOrigin() {
  if (!kIsWeb) return '';

  try {
    final env = kumeongEnv;
    if (env != null &&
        env is dynamic &&
        env.API_ORIGIN is String &&
        (env.API_ORIGIN as String).trim().isNotEmpty) {
      return (env.API_ORIGIN as String).trim();
    }
  } catch (e) {
    debugPrint('[WEB] env.js 읽기 오류: $e');
  }

  // ❌ fallback 제거 — 웹에서는 빈 문자열만 허용
  return '';
}

// ===============================================
// 4) 최종 ORIGIN
// ===============================================
String apiOrigin() {
  if (kIsWeb) {
    final o = _loadWebOrigin();
    return o; // ← 비어 있으면 main.dart.js가 API 호출을 못함 → 문제 즉시 발견 가능
  }

  // 모바일/데스크탑
  if (_envOrigin.isNotEmpty) return _envOrigin.trim();
  return _autoOrigin();
}

// ===============================================
String restBase() => '${apiOrigin()}/api/v1';

final String kApiOrigin = apiOrigin();
final String kApiBase = restBase();

// ===============================================
// 6) REST API URL
// ===============================================
Uri apiUrl(String path, [Map<String, dynamic>? query]) {
  final normalized = path.startsWith('/') ? path : '/$path';
  final base = restBase();

  final uri = Uri.parse('$base$normalized');

  if (query == null || query.isEmpty) return uri;
  final q = query.map((k, v) => MapEntry(k, v.toString()));

  return uri.replace(queryParameters: q);
}

// ===============================================
// 7) WebSocket
// ===============================================
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
