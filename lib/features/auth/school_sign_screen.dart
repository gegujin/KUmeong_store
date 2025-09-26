import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../auth/signup_screen.dart';

class SchoolSignUpPage extends StatefulWidget {
  const SchoolSignUpPage({super.key});

  @override
  State<SchoolSignUpPage> createState() => _SchoolSignUpPageState();
}

class _SchoolSignUpPageState extends State<SchoolSignUpPage> {
  // ---------- 서버 베이스 URL ----------
  // ❗ Android 에뮬레이터면 10.0.2.2 사용 권장
  static const String _base = 'http://127.0.0.1:3000/api/v1';

  final _emailLocalController = TextEditingController(); // '@' 앞부분만 입력
  final _codeController = TextEditingController();

  // UI 상태
  bool isCodeSent = false;   // 코드 전송 여부(문구: 발송하기/재발송하기)
  bool isVerified = false;   // 인증 완료 여부
  bool _codeExpired = false; // 타이머 만료 여부
  bool _cooldownActive = false;

  // 타이머
  Timer? _codeTimer;
  Timer? _cooldownTimer;

  // 남은 시간
  Duration _remain = Duration.zero;
  Duration _cooldownRemain = Duration.zero;

  // 서버 응답 기반 TTL/쿨다운
  int _lastTtlSec = 180;
  DateTime? _nextSendAt; // 서버가 보내준 다음 발송 가능 시각

  @override
  void dispose() {
    _emailLocalController.dispose();
    _codeController.dispose();
    _codeTimer?.cancel();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  String get _fullEmail => '${_emailLocalController.text.trim()}@kku.ac.kr';

  // =======================
  // 타이머: 코드 TTL
  // =======================
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

  // =======================
  // 타이머: 쿨다운
  // =======================
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

  // =======================
  // API: send
  // =======================
  Future<void> _sendCode() async {
    final local = _emailLocalController.text.trim();
    if (local.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('학교 이메일을 입력해 주세요.')),
      );
      return;
    }
    if (_cooldownActive) {
      // 버튼 비활성일 때 오동작 방지
      return;
    }

    try {
      final resp = await http.post(
        Uri.parse('$_base/university/email/send'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': _fullEmail}),
      );

      final raw = jsonDecode(resp.body);
      final data = raw['data'] ?? raw; // 래핑/평면 응답 모두 대응

      // 쿨다운 케이스
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
        // 메일 발송 실패 등
        final reason = data['reason']?.toString() ?? 'unknown';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('인증번호 발송 실패 ($reason)')),
        );
        return;
      }

      // 정상: TTL/쿨다운 반영
      final ttlSec = (data['ttlSec'] ?? 180) as int;
      _lastTtlSec = ttlSec;
      final nextIso = (data['nextSendAt'] ?? '') as String;
      if (nextIso.isNotEmpty) {
        final next = DateTime.tryParse(nextIso);
        if (next != null) _startCooldownTimer(next);
      }

      // DEV 환경이면 devCode 내려옴 → 자동 채우기(테스트 편의)
      final devCode = data['devCode'];
      if (devCode is String && devCode.isNotEmpty) {
        _codeController.text = devCode;
      }

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

  // =======================
  // API: verify
  // =======================
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
        setState(() => isVerified = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('이메일 인증이 완료되었습니다.')),
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
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
    return '$mm:$ss'; // 예: 02:59
  }

  String get _cooldownText {
    final mm = _cooldownRemain.inMinutes.remainder(60).toString().padLeft(2, '0');
    final ss = _cooldownRemain.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$mm:$ss';
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

                    // 전송 / 재전송 버튼 + 쿨다운 남은시간
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _cooldownActive ? Colors.grey : mainColor,
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

      // 하단 "다음" 버튼 (기존 흐름 유지)
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
                // 기존 로직 유지(필요시 isVerified 체크를 걸어 UX 강화 가능)
                // if (!isVerified) return;
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
