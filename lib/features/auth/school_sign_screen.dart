import 'dart:async';
import 'package:flutter/material.dart';
import '../auth/signup_screen.dart';

class SchoolSignUpPage extends StatefulWidget {
  const SchoolSignUpPage({super.key});

  @override
  State<SchoolSignUpPage> createState() => _SchoolSignUpPageState();
}

class _SchoolSignUpPageState extends State<SchoolSignUpPage> {
  final _emailLocalController = TextEditingController(); // '@' 앞부분만 입력
  final _codeController = TextEditingController();

  static const _codeTtl = Duration(minutes: 3);

  bool isCodeSent = false;   // 코드 전송 여부(문구: 발송하기/재발송하기)
  bool isVerified = false;   // 인증 완료 여부
  bool _codeExpired = false; // 타이머 만료 여부

  Timer? _codeTimer;
  Duration _remain = Duration.zero;

  @override
  void dispose() {
    _emailLocalController.dispose();
    _codeController.dispose();
    _codeTimer?.cancel();
    super.dispose();
  }

  String get _fullEmail => '${_emailLocalController.text.trim()}@kku.ac.kr';

  void _startCodeTimer() {
    _codeTimer?.cancel();
    setState(() {
      _remain = _codeTtl;
      _codeExpired = false;
    });
    _codeTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_remain.inSeconds <= 1) {
        t.cancel();
        setState(() {
          _remain = Duration.zero;
          _codeExpired = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('인증번호 유효시간(3분)이 만료되었습니다. 재발송해 주세요.')),
        );
      } else {
        setState(() {
          _remain -= const Duration(seconds: 1);
        });
      }
    });
  }

  void _sendCode() {
    if (_emailLocalController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('학교 이메일을 입력해 주세요.')),
      );
      return;
    }
    if (!isCodeSent) {
      setState(() => isCodeSent = true);
    }
    _startCodeTimer(); // 전송/재전송 시 타이머 리셋
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('인증번호가 $_fullEmail 으로 발송되었습니다.')),
    );
  }

  void _verifyCode() {
    if (_codeController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('인증번호를 입력해 주세요.')),
      );
      return;
    }
    if (_codeExpired) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('인증번호가 만료되었습니다. 재발송해 주세요.')),
      );
      return;
    }
    setState(() => isVerified = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('이메일 인증이 완료되었습니다.')),
    );
  }

  String get _timerText {
    final mm = _remain.inMinutes.remainder(60).toString().padLeft(2, '0');
    final ss = _remain.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$mm:$ss'; // 예: 02:59
  }

  @override
  Widget build(BuildContext context) {
    final mainColor = Theme.of(context).colorScheme.primary;
    final hintStyle = Theme.of(context).inputDecorationTheme.hintStyle
        ?? TextStyle(color: Theme.of(context).hintColor);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: mainColor,
        centerTitle: true,
        title: const Text('학교 인증', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight - 20),
              child: IntrinsicHeight(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center, // ★ 세로 중앙 배치
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 이메일 입력
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _emailLocalController,
                            decoration: const InputDecoration(
                              labelText: '학교 이메일',
                              hintText: '예) 20201234',
                            ),
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.send,
                            onSubmitted: (_) => _sendCode(),
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text('@kku.ac.kr'),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // 전송 / 재전송 버튼
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: mainColor,
                        minimumSize: const Size(double.infinity, 48),
                      ),
                      onPressed: _sendCode,
                      child: Text(
                        isCodeSent ? '인증번호 재발송하기' : '인증번호 발송하기',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),

                    // 인증번호 입력 + 우측 타이머(힌트처럼 흐릿)
                    if (isCodeSent) ...[
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _codeController,
                              decoration: const InputDecoration(labelText: '인증번호 입력'),
                              keyboardType: TextInputType.number,
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // 힌트 텍스트처럼 흐릿한 타이머
                          Text(
                            _codeExpired ? '만료됨' : _timerText,
                            style: hintStyle,
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: mainColor,
                              minimumSize: const Size(100, 48),
                            ),
                            onPressed: _codeExpired ? null : _verifyCode,
                            child: const Text('인증하기', style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      ),
                    ],

                    const SizedBox(height: 24),

                    // 인증 완료 안내
                    if (isVerified)
                      Row(
                        children: const [
                          Icon(Icons.check_circle, color: Colors.green),
                          SizedBox(width: 8),
                          Text('이메일 인증 완료', style: TextStyle(color: Colors.green)),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),

      // 하단 "다음" 버튼 (원하면 isVerified 체크 조건을 걸어도 됨)
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: SizedBox(
            height: 55,
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: mainColor),
              onPressed: () {
                // if (!isVerified) return; // 필요 시 활성화
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SignUpPage()),
                );
              },
              child: const Text('다음', style: TextStyle(color: Colors.white)),
            ),
          ),
        ),
      ),
    );
  }
}
