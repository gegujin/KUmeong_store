// lib/core/base_url.dart
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

/// 백엔드에서 main.ts에 `app.setGlobalPrefix('api')`
/// 와 `app.enableVersioning({ type: URI, defaultVersion: '1' })`
/// 두 가지가 있으므로, 실제 엔드포인트는 "/api/v1" 입니다.
/// 따라서 baseUrl은 "/api"까지만 반환해야 함.
String apiBaseUrl() {
  const port = 3000;
  const prefix = '/api'; // ✅ 여기까지만 (v1은 각 API 내부에서 붙임)
  if (kIsWeb) {
    return 'http://localhost:$port$prefix';
  }
  if (Platform.isAndroid) {
    // Android 에뮬레이터 → 호스트 PC 접근
    return 'http://10.0.2.2:$port$prefix';
  }
  // iOS 시뮬레이터/데스크톱
  return 'http://127.0.0.1:$port$prefix';
}
