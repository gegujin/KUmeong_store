import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kumeong_store/core/router/route_names.dart' as R;
import 'package:kumeong_store/api_service.dart'; // register(email, password, name, {univToken})

class SignUpPage extends StatefulWidget {
  const SignUpPage({
    super.key,
    this.prefillEmail,
    this.univToken,
    this.lockEmail = false,
  });

  final String? prefillEmail; // 학교 인증 이메일
  final String? univToken;    // 학교 인증 토큰(JWT)
  final bool lockEmail;       // 이메일 수정 불가 여부

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController passwordConfirmController = TextEditingController();
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    if ((widget.prefillEmail ?? '').isNotEmpty) {
      emailController.text = widget.prefillEmail!.trim().toLowerCase(); // ✅ 소문자 고정
    }
  }

  Future<void> _signUp() async {
    final email = emailController.text.trim().toLowerCase(); // ✅ 소문자 고정
    final name = nameController.text.trim();
    final password = passwordController.text.trim();
    final passwordConfirm = passwordConfirmController.text.trim();

    if (email.isEmpty || name.isEmpty || password.isEmpty || passwordConfirm.isEmpty) {
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

    // ✅ 학교 인증 토큰이 있어야 가입 진행 (백엔드와 동일 정책)
    if ((widget.univToken ?? '').isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('학교 이메일 인증 후 가입해 주세요')),
      );
      return;
    }

    setState(() => isLoading = true);
    try {
      final token = await register(
        email,
        password,
        name,
        univToken: widget.univToken, // ✅ 반드시 함께 전달
      );

      if (!mounted) return;

      if (token != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('회원가입 성공! 로그인 화면으로 이동')),
        );
        context.goNamed(R.RouteNames.login);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('회원가입 실패: 이메일/인증 상태를 확인해주세요')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('회원가입 중 오류 발생: ${e.toString()}')),
      );
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mainColor = Theme.of(context).colorScheme.primary;
    final hasUnivToken = (widget.univToken ?? '').isNotEmpty;

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
              const SizedBox(height: 16),

              if (hasUnivToken)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.withOpacity(0.25)),
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.verified, color: Colors.green),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text('학교 이메일 인증 완료: 해당 이메일로만 가입이 가능합니다.',
                            style: TextStyle(color: Colors.green)),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 8),

              // ✅ 이메일 잠금: readOnly 대신 enabled로 완전 비활성(색도 잠금 느낌)
              TextField(
                controller: emailController,
                enabled: !widget.lockEmail, // true면 수정 가능, false면 완전 잠금
                decoration: InputDecoration(
                  labelText: '아이디(이메일)',
                  suffixIcon: widget.lockEmail
                      ? const Tooltip(
                          message: '학교 인증 이메일로 고정되었습니다',
                          child: Icon(Icons.lock, size: 20),
                        )
                      : null,
                ),
                style: const TextStyle(fontSize: 16),
                keyboardType: TextInputType.emailAddress,
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
