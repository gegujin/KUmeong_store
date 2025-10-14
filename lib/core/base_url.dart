// lib/core/base_url.dart
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

/// ===============================
/// ORIGIN 결정 (환경변수 > 플랫폼별 기본)
/// ===============================
/// 빌드 시 --dart-define=API_ORIGIN=http://192.168.0.5:3000 식으로 덮어쓰기 가능.
const String _envOrigin =
    String.fromEnvironment('API_ORIGIN', defaultValue: '');

String _autoOrigin() {
  if (kIsWeb) return 'http://localhost:3000';
  if (Platform.isAndroid) return 'http://10.0.2.2:3000'; // Android emulator
  return 'http://127.0.0.1:3000'; // iOS Simulator / desktop
}

String apiOrigin() => _envOrigin.isNotEmpty ? _envOrigin : _autoOrigin();

/// ===============================
/// REST API URL 빌더
/// ===============================
/// 서버가 /api + (v1 버전 경로)를 사용하므로, 클라이언트는 /api/v1로 고정 호출.
Uri apiUrl(String path, [Map<String, dynamic>? query]) {
  final base = '${apiOrigin()}/api/v1';
  final uri = Uri.parse('$base$path');
  if (query == null || query.isEmpty) return uri;
  return uri.replace(
    queryParameters: query.map((k, v) => MapEntry(k, '$v')),
  );
}

/// ===============================
/// WebSocket URL
/// ===============================
String wsUrl({required String meUserId}) {
  final wsOrigin = apiOrigin().replaceFirst(RegExp('^http'), 'ws');
  return '$wsOrigin/ws/realtime?me=$meUserId';
}
