// test_login.dart
import 'dart:async';
import 'package:kumeong_store/api_service.dart';

Future<void> main() async {
  print('--- LOGIN TEST START ---');

  // 🔧 테스트용 이메일 / 비밀번호 입력
  const email = '11@kku.ac.kr';
  const password = '1111'; // 실제 DB 비밀번호로 교체해

  try {
    final token = await login(email, password);
    if (token == null) {
      print('❌ 로그인 실패 (null 반환)');
    } else {
      print('✅ 로그인 성공!');
      print('Access Token: $token');
    }
  } catch (e, st) {
    print('🚨 로그인 중 오류 발생: $e');
    print(st);
  }

  print('--- LOGIN TEST END ---');
}
