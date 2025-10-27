// lib/core/config/env.dart
//
// 환경별 API 기본 URL 설정 파일.
// 실행 시 flutter run --dart-define=API_BASE_URL=<주소> 로 변경 가능.
//
// 예시:
//   flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000
//   flutter build apk --dart-define=API_BASE_URL=https://api.kumarket.kr

/// API 서버 기본 주소
/// - 개발(default): http://localhost:3000
/// - 에뮬레이터: http://10.0.2.2:3000
/// - 실서버: https://api.kumarket.kr (예시)
const kBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://localhost:3000',
);

/// API 경로 헬퍼
/// 사용 예시:
/// ```dart
/// final uri = apiUrl('/friends');
/// // => http://localhost:3000/api/v1/friends
/// ```
Uri apiUrl(String path) {
  final base = kBaseUrl.endsWith('/') ? kBaseUrl.substring(0, kBaseUrl.length - 1) : kBaseUrl;
  final normalized = path.startsWith('/') ? path : '/$path';
  return Uri.parse('$base/api/v1$normalized');
}
