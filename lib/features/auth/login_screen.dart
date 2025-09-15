// lib/features/auth/login_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kumeong_store/core/router/route_names.dart' as R;
import 'package:kumeong_store/api_service.dart'; // API 서비스 임포트
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool isLoading = false;

  // 🔹 플랫폼별 API URL 자동 감지
  String get currentApiUrl {
    if (kIsWeb) return "http://localhost:3000/api/v1";
    if (Platform.isAndroid) return "http://10.0.2.2:3000/api/v1";
    if (Platform.isIOS) return "http://localhost:3000/api/v1";
    return "http://localhost:3000/api/v1";
  }

  Future<void> _signIn() async {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이메일과 비밀번호를 모두 입력하세요')),
      );
      return;
    }

    setState(() => isLoading = true);

    print('[DEBUG] 로그인 시도: $email');
    print('[DEBUG] 사용 중 API URL: $currentApiUrl/auth/login');

    try {
      final token = await login(email, password);

      print('[DEBUG] 로그인 완료, 토큰: $token');

      if (!context.mounted) return;

      if (token != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('로그인 성공')),
        );
        context.goNamed(R.RouteNames.home);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('로그인 실패: 이메일 또는 비밀번호 확인 또는 네트워크 오류')),
        );
      }
    } catch (e) {
      print('[DEBUG] 로그인 예외 발생: $e');

      // 네트워크 오류인지 확인
      if (e.toString().contains('Failed host lookup') ||
          e.toString().contains('ClientException')) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('네트워크 오류: 서버에 연결할 수 없습니다. API URL 확인 필요')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('로그인 중 오류가 발생했습니다.')),
        );
      }
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mainColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              const SizedBox(height: 60),
              Text(
                'KU멍가게',
                style: TextStyle(
                  color: mainColor,
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 40),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(labelText: '아이디'),
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: passwordController,
                decoration: const InputDecoration(labelText: '비밀번호'),
                obscureText: true,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => context.pushNamed(R.RouteNames.idFind),
                    child: const Text('아이디 찾기'),
                  ),
                  TextButton(
                    onPressed: () =>
                        context.pushNamed(R.RouteNames.passwordFind),
                    child: const Text('비밀번호 찾기'),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: mainColor,
                  minimumSize: const Size(double.infinity, 55),
                ),
                onPressed: isLoading ? null : _signIn,
                child: isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('로그인', style: TextStyle(color: Colors.white)),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 55),
                  side: BorderSide(color: mainColor),
                ),
                onPressed: () => context.pushNamed(R.RouteNames.schoolSignUp),
                child: Text('회원가입', style: TextStyle(color: mainColor)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
