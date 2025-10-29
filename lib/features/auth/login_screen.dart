// C:\Users\82105\KU-meong Store\lib\features\auth\login_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kumeong_store/core/router/route_names.dart' as R;
import 'package:kumeong_store/features/auth/login_service.dart'; // ✅ LoginService 사용
import 'package:kumeong_store/core/utils/email.dart';
import 'package:flutter/services.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool isLoading = false;

  Future<void> _signIn() async {
    final email = normalizeEmail(emailController.text);
    final password = passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이메일과 비밀번호를 모두 입력하세요.')),
      );
      return;
    }

    setState(() => isLoading = true);
    try {
      debugPrint('[LOGIN] 시도: $email'); // 항상 소문자/트림된 값으로 로그

      // ✅ 서버 응답의 최상위 accessToken을 session.v1에 저장
      final ok = await LoginService.login(email, password);

      if (!ok) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('로그인 실패: 계정 정보를 확인하세요.')),
        );
        return;
      }

      // (선택) 토큰 주입 확인용 호출
      // final me = await LoginService.me();
      // debugPrint('[LOGIN] /auth/me = $me');

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인 성공!')),
      );
      context.goNamed(R.RouteNames.home); // ✅ 홈 이동
    } catch (e, st) {
      debugPrint('[LOGIN] 예외: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('로그인 중 오류가 발생했습니다: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
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
                decoration: const InputDecoration(labelText: '아이디(이메일)'),
                style: const TextStyle(fontSize: 16),
                keyboardType: TextInputType.emailAddress,
                inputFormatters: [_LowercaseFormatter()], // (선택) 입력 즉시 소문자화
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
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(color: Colors.white),
                      )
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

/// (선택) 입력 즉시 소문자 변환 포매터
class _LowercaseFormatter extends TextInputFormatter {
  const _LowercaseFormatter(); // (선택) 원하면 const 생성자 추가 가능
  @override
  TextEditingValue formatEditUpdate(TextEditingValue a, TextEditingValue b) =>
      b.copyWith(text: b.text.toLowerCase());
}
