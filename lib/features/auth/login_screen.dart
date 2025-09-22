// lib/features/auth/login_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kumeong_store/core/router/route_names.dart' as R;
import 'package:kumeong_store/api_service.dart'; // login 함수 정의

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
    final email = emailController.text.trim();
    final password = passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이메일과 비밀번호를 모두 입력하세요.')),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      debugPrint('[DEBUG] 로그인 시도: $email');

      // api_service.dart에 정의된 login 함수 호출
      final token = await login(email, password);

      if (!mounted) return;

      if (token != null) {
        debugPrint('[DEBUG] 로그인 성공, 토큰 길이: ${token.length}');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('로그인 성공!')),
        );
        context.goNamed(R.RouteNames.home); // 홈 화면 이동
      } else {
        debugPrint('[DEBUG] 로그인 실패: 서버가 null을 반환');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('로그인 실패: 이메일 또는 비밀번호를 확인하세요.')),
        );
      }
    } catch (e, st) {
      debugPrint('[DEBUG] 로그인 예외 발생: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('로그인 중 오류가 발생했습니다: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
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
                decoration: const InputDecoration(labelText: '아이디(이메일)'),
                style: const TextStyle(fontSize: 16),
                keyboardType: TextInputType.emailAddress,
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

// // lib/features/auth/login_screen.dart

// // 임시 코드
// import 'package:flutter/material.dart';
// import 'package:go_router/go_router.dart';
// import 'package:kumeong_store/core/router/route_names.dart' as R;

// class LoginPage extends StatefulWidget {
//   const LoginPage({super.key});

//   @override
//   State<LoginPage> createState() => _LoginPageState();
// }

// class _LoginPageState extends State<LoginPage> {
//   final TextEditingController emailController = TextEditingController();
//   final TextEditingController passwordController = TextEditingController();
//   bool isLoading = false;

//   Future<void> _signIn() async {
//     final email = emailController.text.trim();
//     final password = passwordController.text;

//     if (email.isEmpty || password.isEmpty) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('이메일과 비밀번호를 모두 입력하세요.')),
//       );
//       return;
//     }

//     setState(() => isLoading = true);

//     print('[DEBUG] 로그인 시도: $email');

//     // 🔹 서버 호출 없이 가짜 로딩 & 결과 처리
//     await Future.delayed(const Duration(seconds: 1));

//     if (!mounted) return;

//     // 예시: 이메일이 "test@test.com", 비밀번호가 "1234"면 성공 처리
//     if (email == "test@kku.ac.kr" && password == "1234") {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('로그인 성공!')),
//       );
//       context.goNamed(R.RouteNames.home);
//     } else {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('로그인 실패: 이메일 또는 비밀번호 확인')),
//       );
//     }

//     setState(() => isLoading = false);
//   }

//   @override
//   Widget build(BuildContext context) {
//     final mainColor = Theme.of(context).colorScheme.primary;

//     return Scaffold(
//       body: SingleChildScrollView(
//         child: Padding(
//           padding: const EdgeInsets.all(20),
//           child: Column(
//             mainAxisAlignment: MainAxisAlignment.start,
//             children: [
//               const SizedBox(height: 60),
//               Text(
//                 'KU멍가게',
//                 style: TextStyle(
//                   color: mainColor,
//                   fontSize: 40,
//                   fontWeight: FontWeight.bold,
//                 ),
//               ),
//               const SizedBox(height: 40),
//               TextField(
//                 controller: emailController,
//                 decoration: const InputDecoration(labelText: '아이디'),
//                 style: const TextStyle(fontSize: 16),
//               ),
//               const SizedBox(height: 10),
//               TextField(
//                 controller: passwordController,
//                 decoration: const InputDecoration(labelText: '비밀번호'),
//                 obscureText: true,
//                 style: const TextStyle(fontSize: 16),
//               ),
//               const SizedBox(height: 10),
//               Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                 children: [
//                   TextButton(
//                     onPressed: () => context.pushNamed(R.RouteNames.idFind),
//                     child: const Text('아이디 찾기'),
//                   ),
//                   TextButton(
//                     onPressed: () =>
//                         context.pushNamed(R.RouteNames.passwordFind),
//                     child: const Text('비밀번호 찾기'),
//                   ),
//                 ],
//               ),
//               const SizedBox(height: 20),
//               ElevatedButton(
//                 style: ElevatedButton.styleFrom(
//                   backgroundColor: mainColor,
//                   minimumSize: const Size(double.infinity, 55),
//                 ),
//                 onPressed: isLoading ? null : _signIn,
//                 child: isLoading
//                     ? const SizedBox(
//                         width: 24,
//                         height: 24,
//                         child: CircularProgressIndicator(color: Colors.white),
//                       )
//                     : const Text('로그인', style: TextStyle(color: Colors.white)),
//               ),
//               const SizedBox(height: 10),
//               OutlinedButton(
//                 style: OutlinedButton.styleFrom(
//                   minimumSize: const Size(double.infinity, 55),
//                   side: BorderSide(color: mainColor),
//                 ),
//                 onPressed: () => context.pushNamed(R.RouteNames.schoolSignUp),
//                 child: Text('회원가입', style: TextStyle(color: mainColor)),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }
