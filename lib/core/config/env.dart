// lib/core/config/env.dart
//
// Flutter Web에서 env.js 를 우선 읽고,
// 없다면 --dart-define 값 사용,
// 마지막으로 localhost fallback.
//
// env.js 내용 예시:
// window.kumeongEnv = {
//   API_ORIGIN: "http://k3s-nlb-xxxxx.elb.ap-northeast-1.amazonaws.com"
// };

import 'dart:js' as js;

/// 외부 env.js 에서 API_ORIGIN을 가져옴
String _getJsApiOrigin() {
  try {
    final jsEnv = js.context['kumeongEnv'];
    if (jsEnv != null) {
      final origin = jsEnv['API_ORIGIN'] as String?;
      if (origin != null && origin.isNotEmpty) {
        return origin;
      }
    }
  } catch (_) {
    // ignore: web/js errors 안 나게
  }
  return '';
}

/// flutter --dart-define=API_BASE_URL 으로 전달된 값
const _dartDefineBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: '',
);

/// 📌 최종적으로 사용될 API Base URL
/// 우선순위:
/// 1) env.js의 API_ORIGIN
/// 2) --dart-define=API_BASE_URL
/// 3) fallback: http://localhost:3000
String get kBaseUrl {
  final jsOrigin = _getJsApiOrigin();
  if (jsOrigin.isNotEmpty) return jsOrigin;

  if (_dartDefineBaseUrl.isNotEmpty) return _dartDefineBaseUrl;

  return 'http://localhost:3000';
}

/// API 경로 헬퍼
Uri apiUrl(String path) {
  final base = kBaseUrl.endsWith('/')
      ? kBaseUrl.substring(0, kBaseUrl.length - 1)
      : kBaseUrl;

  final normalized = path.startsWith('/') ? path : '/$path';
  return Uri.parse('$base/api/v1$normalized');
}
