// C:\Users\82105\KU-meong Store\lib\features\auth\school_sign_screen.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../auth/signup_screen.dart';
import 'package:kumeong_store/core/utils/email.dart';

class SchoolSignUpPage extends StatefulWidget {
  const SchoolSignUpPage({super.key});

  @override
  State<SchoolSignUpPage> createState() => _SchoolSignUpPageState();
}

class _SchoolSignUpPageState extends State<SchoolSignUpPage> {
  // ❗ Android 에뮬레이터면 10.0.2.2 사용
  static const String _base = 'http://127.0.0.1:3000/api/v1';

  // 전체 이메일 주소 입력용 컨트롤러
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();

  bool isCodeSent = false; // 발송 완료
  bool isVerified = false; // 인증 완료
  bool _codeExpired = false; // 코드 만료
  bool _cooldownActive = false;

  // 인증 성공 후 다음 화면으로 넘길 값
  String? _verifiedEmail;
  String? _univToken;

  // 타이머들
  Timer? _codeTimer;
  Timer? _cooldownTimer;
  Duration _remain = Duration.zero;
  Duration _cooldownRemain = Duration.zero;

  int _lastTtlSec = 180;
  DateTime? _nextSendAt;

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _codeTimer?.cancel();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  // normalizeEmail은 기존 유틸 그대로 사용
  String get _fullEmail => normalizeEmail(_emailController.text.trim());

  // 간단 이메일 형식 체크 (프론트단 기본 검증)
  bool _looksLikeEmail(String value) {
    final v = value.trim();
    if (v.isEmpty) return false;
    if (!v.contains('@')) return false;
    if (!v.contains('.')) return false;
    return true;
  }

  // --- 코드 TTL 타이머 ---
  void _startCodeTimer(Duration ttl) {
    _codeTimer?.cancel();
    setState(() {
      _remain = ttl;
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
          const SnackBar(content: Text('인증번호 유효시간이 만료되었습니다. 재발송해 주세요.')),
        );
      } else {
        setState(() => _remain -= const Duration(seconds: 1));
      }
    });
  }

  // --- 쿨다운 타이머 ---
  void _startCooldownTimer(DateTime until) {
    _cooldownTimer?.cancel();
    final now = DateTime.now();
    var left = until.difference(now);
    if (left.isNegative) left = Duration.zero;

    setState(() {
      _nextSendAt = until;
      _cooldownActive = left > Duration.zero;
      _cooldownRemain = left;
    });

    if (!_cooldownActive) return;

    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      final now2 = DateTime.now();
      final left2 = until.difference(now2);
      if (left2.isNegative || left2.inSeconds <= 0) {
        t.cancel();
        setState(() {
          _cooldownActive = false;
          _cooldownRemain = Duration.zero;
        });
      } else {
        setState(() => _cooldownRemain = left2);
      }
    });
  }

  // --- 인증번호 발송 ---
  Future<void> _sendCode() async {
    final emailInput = _emailController.text.trim();
    if (emailInput.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이메일 주소를 입력해 주세요.')),
      );
      return;
    }

    if (!_looksLikeEmail(_fullEmail)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이메일 형식을 확인해 주세요.')),
      );
      return;
    }

    if (_cooldownActive) return;

    // 재발송 시 인증 상태 초기화(선택)
    setState(() {
      isVerified = false;
      _verifiedEmail = null;
      _univToken = null;
    });

    try {
      final resp = await http.post(
        Uri.parse('$_base/university/email/send'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': _fullEmail}),
      );

      final raw = jsonDecode(resp.body);
      final data = raw['data'] ?? raw;

      if (data['ok'] == false && data['reason'] == 'cooldown') {
        final nextIso = (data['nextSendAt'] ?? '') as String;
        if (nextIso.isNotEmpty) {
          final next = DateTime.tryParse(nextIso);
          if (next != null) _startCooldownTimer(next);
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('잠시 후 다시 시도해 주세요. (쿨다운 적용)')),
        );
        return;
      }

      if (data['ok'] != true) {
        final reason = data['reason']?.toString() ?? 'unknown';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('인증번호 발송 실패 ($reason)')),
        );
        return;
      }

      final ttlSec = (data['ttlSec'] ?? 180) as int;
      _lastTtlSec = ttlSec;
      final nextIso = (data['nextSendAt'] ?? '') as String;
      if (nextIso.isNotEmpty) {
        final next = DateTime.tryParse(nextIso);
        if (next != null) _startCooldownTimer(next);
      }

      // 🚫 devCode 자동 입력은 의도적으로 무시

      if (!isCodeSent) setState(() => isCodeSent = true);
      _startCodeTimer(Duration(seconds: ttlSec));

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('인증번호가 $_fullEmail 으로 발송되었습니다.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('네트워크 오류가 발생했습니다.')),
      );
    }
  }

  // --- 인증번호 검증 ---
  Future<void> _verifyCode() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
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

    try {
      final resp = await http.post(
        Uri.parse('$_base/university/email/verify'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': _fullEmail, 'code': code}),
      );

      final raw = jsonDecode(resp.body);
      final data = raw['data'] ?? raw;

      if (data['ok'] == true) {
        // ✅ 인증만 완료(화면 이동 X)
        final token = (data['univToken'] ?? '') as String;
        setState(() {
          isVerified = true;
          _verifiedEmail = _fullEmail;
          _univToken = token.isNotEmpty ? token : null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('이메일 인증이 완료되었습니다. "다음"을 눌러 진행하세요.')),
        );
      } else {
        final reason = (data['reason'] ?? '').toString();
        String msg = '인증 실패';
        switch (reason) {
          case 'mismatch':
            msg = '인증번호가 일치하지 않습니다.';
            break;
          case 'expired':
            msg = '인증번호가 만료되었습니다.';
            break;
          case 'too_many':
            msg = '시도 횟수를 초과했습니다. 재발송 후 다시 시도하세요.';
            break;
          case 'not_found':
            msg = '발급된 인증번호가 없습니다. 먼저 발송해주세요.';
            break;
        }
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('네트워크 오류가 발생했습니다.')),
      );
    }
  }

  String get _timerText {
    final mm = _remain.inMinutes.remainder(60).toString().padLeft(2, '0');
    final ss = _remain.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  String get _cooldownText {
    final mm =
        _cooldownRemain.inMinutes.remainder(60).toString().padLeft(2, '0');
    final ss =
        _cooldownRemain.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  @override
  Widget build(BuildContext context) {
    final mainColor = Theme.of(context).colorScheme.primary;
    final hintStyle = Theme.of(context).inputDecorationTheme.hintStyle ??
        TextStyle(color: Theme.of(context).hintColor);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: mainColor,
        centerTitle: true,
        // ⬇ 학교 인증 → 이메일 인증
        title: const Text('이메일 인증', style: TextStyle(color: Colors.white)),
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
              constraints:
                  BoxConstraints(minHeight: constraints.maxHeight - 20),
              child: IntrinsicHeight(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _emailController,
                            decoration: const InputDecoration(
                              labelText: '이메일 주소', // ⬅ 텍스트 변경
                              hintText: '예) example@email.com', // ⬅ 예시 변경
                            ),
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.send,
                            onSubmitted: (_) => _sendCode(),
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                        // 기존: '@kku.ac.kr' 고정 텍스트는 제거
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  _cooldownActive ? Colors.grey : mainColor,
                              minimumSize: const Size(double.infinity, 48),
                            ),
                            onPressed: _cooldownActive ? null : _sendCode,
                            child: Text(
                              isCodeSent ? '인증번호 재발송하기' : '인증번호 발송하기',
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                        ),
                        if (_cooldownActive) ...[
                          const SizedBox(width: 12),
                          Text('쿨다운 $_cooldownText', style: hintStyle),
                        ],
                      ],
                    ),
                    if (isCodeSent) ...[
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _codeController,
                              decoration:
                                  const InputDecoration(labelText: '인증번호 입력'),
                              keyboardType: TextInputType.number,
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(_codeExpired ? '만료됨' : _timerText,
                              style: hintStyle),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: mainColor,
                              minimumSize: const Size(100, 48),
                            ),
                            onPressed: _codeExpired ? null : _verifyCode,
                            child: const Text('인증하기',
                                style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 24),
                    if (isVerified)
                      Row(
                        children: const [
                          Icon(Icons.check_circle, color: Colors.green),
                          SizedBox(width: 8),
                          Text('이메일 인증 완료',
                              style: TextStyle(color: Colors.green)),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),

      // ✅ 하단 "다음" 버튼: 인증 완료 전엔 비활성화, 누르면 가입 화면으로 이동
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: SizedBox(
            height: 55,
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: mainColor),
              onPressed: isVerified && _verifiedEmail != null
                  ? () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SignUpPage(
                            prefillEmail: _verifiedEmail!,
                            // 백엔드에서 아직 university 컨셉을 쓴다면 그대로 유지
                            univToken: _univToken,
                            lockEmail: true,
                          ),
                        ),
                      );
                    }
                  : null, // 🔒 인증 전에는 비활성화
              child: const Text('다음', style: TextStyle(color: Colors.white)),
            ),
          ),
        ),
      ),
    );
  }
}
