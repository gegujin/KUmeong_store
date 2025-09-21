// API 있는 버전
// // lib/features/auth/signup_screen.dart
// import 'package:flutter/material.dart';
// // 🔹 API 서비스 import
// import 'package:kumeong_store/api_service.dart';
// import 'login_screen.dart';

// class SignUpPage extends StatefulWidget {
//   const SignUpPage({super.key});

//   @override
//   State<SignUpPage> createState() => _SignUpPageState();
// }

// class _SignUpPageState extends State<SignUpPage> {
//   final TextEditingController emailController = TextEditingController();
//   final TextEditingController nameController = TextEditingController();
//   final TextEditingController passwordController = TextEditingController();
//   final TextEditingController passwordConfirmController =
//       TextEditingController();
//   bool isLoading = false;

//   // 🔹 회원가입 API 호출
//   Future<void> _signUp() async {
//     final email = emailController.text.trim();
//     final name = nameController.text.trim();
//     final password = passwordController.text.trim();
//     final passwordConfirm = passwordConfirmController.text.trim();

//     // 입력 체크
//     if (email.isEmpty ||
//         name.isEmpty ||
//         password.isEmpty ||
//         passwordConfirm.isEmpty) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('모든 항목을 입력해주세요')),
//       );
//       return;
//     }

//     if (password != passwordConfirm) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('비밀번호와 확인이 일치하지 않습니다')),
//       );
//       return;
//     }

//     setState(() => isLoading = true);

//     try {
//       // 🔹 api_service.dart의 register() 호출
//       final success = await register(email, password, name);

//       if (!context.mounted) return;

//       if (success) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(content: Text('회원가입 성공! 로그인 후 이용해주세요')),
//         );
//         // 회원가입 성공 시 로그인 화면으로 이동
//         Navigator.pushReplacement(
//           context,
//           MaterialPageRoute(builder: (_) => const LoginPage()),
//         );
//       } else {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(content: Text('회원가입 실패: 이메일 중복 또는 서버 오류')),
//         );
//       }
//     } catch (e) {
//       print('[DEBUG] 회원가입 예외: $e');
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('회원가입 중 오류가 발생했습니다')),
//       );
//     } finally {
//       setState(() => isLoading = false);
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     final mainColor = Theme.of(context).colorScheme.primary;

//     return Scaffold(
//       appBar: AppBar(
//         backgroundColor: mainColor,
//         centerTitle: true,
//         title: const Text('회원가입', style: TextStyle(color: Colors.white)),
//         leading: IconButton(
//           icon: const Icon(Icons.arrow_back, color: Colors.white),
//           onPressed: () => Navigator.pop(context),
//         ),
//       ),
//       body: SingleChildScrollView(
//         child: Padding(
//           padding: const EdgeInsets.all(20),
//           child: Column(
//             children: [
//               const SizedBox(height: 40),
//               TextField(
//                 controller: emailController,
//                 decoration: const InputDecoration(labelText: '아이디(이메일)'),
//                 style: const TextStyle(fontSize: 16),
//               ),
//               const SizedBox(height: 10),
//               TextField(
//                 controller: nameController,
//                 decoration: const InputDecoration(labelText: '이름'),
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
//               TextField(
//                 controller: passwordConfirmController,
//                 decoration: const InputDecoration(labelText: '비밀번호 확인'),
//                 obscureText: true,
//                 style: const TextStyle(fontSize: 16),
//               ),
//               const SizedBox(height: 20),
//               ElevatedButton(
//                 style: ElevatedButton.styleFrom(
//                   backgroundColor: mainColor,
//                   minimumSize: const Size(double.infinity, 55),
//                 ),
//                 onPressed: isLoading ? null : _signUp,
//                 child: isLoading
//                     ? const SizedBox(
//                         width: 24,
//                         height: 24,
//                         child: CircularProgressIndicator(color: Colors.white),
//                       )
//                     : const Text('회원가입', style: TextStyle(color: Colors.white)),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }

// lib/features/auth/signup_screen.dart
import 'package:flutter/material.dart';
import 'login_screen.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController passwordConfirmController =
      TextEditingController();
  bool isLoading = false;

  // 🔹 서버 연결 없이 프론트에서만 동작하는 회원가입 버튼 로직
  Future<void> _signUp() async {
    final email = emailController.text.trim();
    final name = nameController.text.trim();
    final password = passwordController.text.trim();
    final passwordConfirm = passwordConfirmController.text.trim();

    if (email.isEmpty ||
        name.isEmpty ||
        password.isEmpty ||
        passwordConfirm.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('모든 항목을 입력해주세요')),
      );
      return;
    }

    if (password != passwordConfirm) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('비밀번호와 확인이 일치하지 않습니다')),
      );
      return;
    }

    setState(() => isLoading = true);

    await Future.delayed(const Duration(seconds: 1)); // 🔹 가짜 로딩 효과

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('회원가입 성공! 로그인 후 이용해주세요')),
    );

    // 🔹 회원가입 성공 시 로그인 화면으로 이동
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );

    setState(() => isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final mainColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: mainColor,
        centerTitle: true,
        title: const Text('회원가입', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const SizedBox(height: 40),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(labelText: '아이디(이메일)'),
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: '이름'),
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
              TextField(
                controller: passwordConfirmController,
                decoration: const InputDecoration(labelText: '비밀번호 확인'),
                obscureText: true,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: mainColor,
                  minimumSize: const Size(double.infinity, 55),
                ),
                onPressed: isLoading ? null : _signUp,
                child: isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(color: Colors.white),
                      )
                    : const Text('회원가입', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
