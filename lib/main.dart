// lib/main.dart
import 'dart:io' show Platform; // 모바일 플랫폼 체크용(웹에서 자동 tree-shake)
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:timeago/timeago.dart' as timeago;

import 'core/theme.dart';
import 'core/router/app_router.dart'; // appRouter (GoRouter)
import 'core/router/route_names.dart' as R; // 라우트 네임 상수(있다면)
import 'core/network/http_client.dart'; // ✅ HttpX 사용

// flutter run --dart-define=NAVER_MAP_CLIENT_ID=YOUR_ID
const _naverClientId = String.fromEnvironment('NAVER_MAP_CLIENT_ID');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ 전역 401(Unauthorized) 핸들러: 토큰 만료/부재 시 공통 처리
  HttpX.setOnUnauthorized(() {
    debugPrint('[HTTP] 401 detected -> navigate to login');

    // 로그인 화면으로 이동 (GoRouter 전역 인스턴스 사용)
    try {
      // appRouter.goNamed(R.RouteNames.login); // 네임드 라우트가 있다면
      appRouter.go('/login'); // 경로가 확정이면
    } catch (e) {
      debugPrint('[HTTP] 401 redirect failed: $e');
    }
  });

  // 전역 에러 로깅(선택)
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    // TODO: Sentry/Crashlytics 연동 가능
  };

  // timeago 한국어 등록
  timeago.setLocaleMessages('ko', timeago.KoMessages());

  // ✅ 네이버 지도 SDK 초기화 (모바일에서만)
  if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
    // 빌드타임 환경변수 미설정 시 개발 중 알림
    assert(
      _naverClientId.isNotEmpty,
      'NAVER_MAP_CLIENT_ID 가 --dart-define 으로 전달되지 않았습니다.',
    );

    await NaverMapSdk.instance.initialize(
      clientId: _naverClientId,
      onAuthFailed: (e) => debugPrint('NaverMap auth failed: $e'),
    );
  }

  runApp(const ProviderScope(child: MyApp())); // ✅ Riverpod 루트
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // 전역 탭 시 키보드 닫기(UX)
    return GestureDetector(
      onTap: () {
        final f = FocusManager.instance.primaryFocus;
        if (f != null && !f.hasPrimaryFocus) f.unfocus();
      },
      child: MaterialApp.router(
        title: 'KU멍가게',
        debugShowCheckedModeBanner: false,
        theme: appTheme,
        routerConfig: appRouter,

        // ↓ Flutter SDK 낮아서 routerConfig 미지원이면 아래 3줄 사용
        // routeInformationProvider: appRouter.routeInformationProvider,
        // routeInformationParser: appRouter.routeInformationParser,
        // routerDelegate: appRouter.routerDelegate,
      ),
    );
  }
}
