// lib/features/delivery/ku_delivery_signup_screen.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:go_router/go_router.dart';
import 'package:kumeong_store/core/router/route_names.dart' as R;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jwt_decode/jwt_decode.dart';
import 'dart:html' as html; // 웹에서 localStorage 접근용 (웹 빌드에서만 사용됨)

// KU대리 브랜드 색상
const Color kuInfo = Color(0xFF147AD6);

class KuDeliverySignupPage extends StatefulWidget {
  const KuDeliverySignupPage({super.key});

  @override
  State<KuDeliverySignupPage> createState() => _KuDeliverySignupPageState();
}

class _KuDeliverySignupPageState extends State<KuDeliverySignupPage> {
  // ❗ Android 에뮬레이터면 10.0.2.2, 그 외는 백엔드 주소로 교체
  static const String _base = 'http://127.0.0.1:3000/api/v1';

  // ───────── 인증 관련 상태 ─────────
  final TextEditingController _emailLocalController =
      TextEditingController(); // '@' 앞부분만
  final TextEditingController _codeController = TextEditingController();
  bool isCodeSent = false; // 발송 완료
  bool isVerified = false; // 인증 완료
  bool _codeExpired = false; // 코드 만료
  bool _cooldownActive = false;

  String? _verifiedEmail; // 인증 성공한 이메일
  String? _univToken; // 선택: 서버가 주는 univToken(정책에 따라 사용)

  Timer? _codeTimer;
  Timer? _cooldownTimer;
  Duration _remain = Duration.zero;
  Duration _cooldownRemain = Duration.zero;

  int _lastTtlSec = 180;
  DateTime? _nextSendAt;

  bool _emailLocked = false; // 토큰 이메일을 불러오면 true
  String? _loginEmail; // (선택) 전체 이메일 표시용
  bool _signingUp = false; // 가입 중 로딩 플래그

  Future<void> _debugPrintTokenInfo(String token) async {
    try {
      final payload = Jwt.parseJwt(token);
      final exp = payload['exp'];
      final iss = payload['iss'];
      final aud = payload['aud'];
      final sub = payload['sub'] ?? payload['userId'] ?? payload['id'];
      final email = payload['email'];

      DateTime? expDt;
      if (exp is int) {
        expDt = DateTime.fromMillisecondsSinceEpoch(exp * 1000, isUtc: true)
            .toLocal();
      }

      debugPrint('=== [JWT DEBUG] =================================');
      debugPrint('sub: $sub, email: $email');
      debugPrint('iss: $iss | aud: $aud');
      debugPrint('exp: $exp (${expDt?.toIso8601String() ?? 'n/a'})');
      debugPrint('now: ${DateTime.now().toIso8601String()}');
      if (expDt != null && DateTime.now().isAfter(expDt)) {
        debugPrint('⚠️ 토큰 만료로 보임');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('토큰이 만료되었을 수 있어요 (재로그인 필요)')),
          );
        }
      }
      debugPrint('================================================');
    } catch (e) {
      debugPrint('[JWT DEBUG] payload decode 실패: $e');
    }
  }

  Future<void> _probeMembership(String token) async {
    try {
      final uri = Uri.parse('$_base/delivery/membership');
      final resp = await http.get(uri, headers: {
        'Authorization': 'Bearer $token',
      });
      debugPrint(
          '[PROBE] GET /delivery/membership -> ${resp.statusCode} ${resp.body}');
      if (resp.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('JWT 가드 통과 OK (membership 200)')),
          );
        }
      } else if (resp.statusCode == 401) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('JWT 가드 통과 실패: 401 (토큰/설정 확인)')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('membership 응답: ${resp.statusCode}')),
          );
        }
      }
    } catch (e) {
      debugPrint('[PROBE] membership 오류: $e');
    }
  }

  void _debugPrintSignupReq(String token, String email, String transport) {
    final short = token.length > 24 ? token.substring(0, 24) : token;
    debugPrint('[SIGNUP] Authorization: Bearer $short... (redacted)');
    debugPrint(
        '[SIGNUP] Body: { email: $email, transport: $transport${_univToken != null ? ', univToken: ***' : ''} }');
  }

  // 로그인 토큰에서 email 추출하여 로컬파트 자동 채우기
  Future<void> _prefillEmailFromAuth() async {
    try {
      String? token;
      if (kIsWeb) {
        token = html.window.localStorage['accessToken'] ??
            html.window.localStorage['jwt'] ??
            html.window.localStorage['token'];
      } else {
        final prefs = await SharedPreferences.getInstance();
        token = prefs.getString('accessToken') ??
            prefs.getString('jwt') ??
            prefs.getString('token');
      }
      if (token == null || token.isEmpty) return;

      final payload = Jwt.parseJwt(token);
      final rawEmail = (payload['email'] ?? payload['sub'] ?? '').toString();
      if (rawEmail.isEmpty) return;

      final at = rawEmail.indexOf('@');
      if (!mounted || at <= 0) return;

      final local = rawEmail.substring(0, at);

      setState(() {
        _loginEmail = rawEmail;
        _emailLocalController.text = local;
        _emailLocked = true; // ✅ 여기서 고정!
      });
    } catch (_) {
      // 무시
    }
  }

  // ✅ ADDED: 이미 KU대리 멤버면 화면 들어오자마자 리스트로 보냄
  Future<void> _redirectIfAlreadyMember() async {
    try {
      final token = await _getAccessToken();
      if (token == null || token.isEmpty) return;

      final resp = await http.get(
        Uri.parse('$_base/delivery/membership'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body) as Map<String, dynamic>;
        final isMember = body['isMember'] == true;
        if (!mounted) return;
        if (isMember) {
          context.goNamed(R.RouteNames.kuDeliveryFeed); // ← 리스트 라우트 이름 맞춰 쓰기
        }
      }
    } catch (_) {
      // 네트워크 에러 시 조용히 무시 (회원가입 화면 유지)
    }
  }

  @override
  void initState() {
    super.initState();
    // 첫 렌더 이후 자동 프리필 + 멤버십 체크
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _prefillEmailFromAuth();
      _redirectIfAlreadyMember(); // ✅ ADDED
    });
  }

  // ───────── 이동수단 선택 상태 ─────────
  /// 라디오 선택 값: "도보" / "자전거" / "오토바이" / "기타" / null
  String? selectedTransport;
  final TextEditingController _otherTransportController =
      TextEditingController();
  String? _otherTransport;

  @override
  void dispose() {
    _emailLocalController.dispose();
    _codeController.dispose();
    _otherTransportController.dispose();
    _codeTimer?.cancel();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  String get _fullEmail => '${_emailLocalController.text.trim()}@kku.ac.kr';

  // === 코드 TTL 타이머 ===
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

  // === 쿨다운 타이머 ===
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

  // === 인증번호 발송 ===
  Future<void> _sendCode() async {
    final local = _emailLocalController.text.trim();
    if (local.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('학교 이메일을 입력해 주세요.')),
      );
      return;
    }
    if (_cooldownActive) return;

    // 재발송 시 인증 상태 초기화 (선택)
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

  // === 인증번호 확인 ===
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
        final token = (data['univToken'] ?? '') as String;
        setState(() {
          isVerified = true;
          _verifiedEmail = _fullEmail;
          _univToken = token.isNotEmpty ? token : null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('이메일 인증이 완료되었습니다. 아래에서 이동수단을 선택하고 가입을 마치세요.')),
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

  // === 최종 가입 완료 ===
  Future<void> _completeSignup() async {
    FocusScope.of(context).unfocus();

    if (!isVerified || _verifiedEmail == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('먼저 학교 이메일 인증을 완료해 주세요.')),
      );
      return;
    }

    // 최종 이동수단 확정
    String? finalTransport;
    if (selectedTransport == null) {
      finalTransport = null;
    } else if (selectedTransport == "기타") {
      final text = (_otherTransport ?? _otherTransportController.text).trim();
      finalTransport = text.isEmpty ? null : text;
    } else {
      finalTransport = selectedTransport;
    }

    if (finalTransport == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("이동수단을 선택(또는 입력)해주세요.")),
      );
      return;
    }

    if (_signingUp) return; // 중복 요청 방지
    setState(() => _signingUp = true);

    try {
      final token = await _getAccessToken();
      if (token == null || token.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('로그인이 필요합니다. 다시 로그인해주세요.')),
        );
        setState(() => _signingUp = false);
        return;
      }

      // ✅ 가입 전 디버그 체크 (토큰/가드)
      await _debugPrintTokenInfo(token);
      await _probeMembership(token);
      _debugPrintSignupReq(token, _verifiedEmail!, finalTransport!);

      // ✅ 실제 가입 요청 (단 한 번)
      final resp = await http.post(
        Uri.parse('$_base/delivery/signup'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'email': _verifiedEmail, // 예: student@kku.ac.kr
          'transport': finalTransport, // 예: 도보/자전거/오토바이/기타
          if (_univToken != null) 'univToken': _univToken,
        }),
      );

      debugPrint(
          '[SIGNUP] RESP ${resp.statusCode} ${resp.reasonPhrase} ${resp.body}');

      final raw = jsonDecode(resp.body);
      final data = raw['data'] ?? raw;

      if (resp.statusCode >= 200 &&
          resp.statusCode < 300 &&
          (data['ok'] == true)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('KU대리 가입이 완료되었습니다.')),
        );
        context.goNamed(R.RouteNames.kuDeliveryFeed); // ← 리스트 라우트 이름 맞춰 쓰기
      } else if (resp.statusCode == 409) {
        // ✅ 이미 가입된 경우도 부드럽게 넘김(선택)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('이미 KU대리 멤버입니다.')),
        );
        if (mounted) context.goNamed(R.RouteNames.kuDeliveryFeed);
      } else {
        final msg = (data['message'] ?? data['reason'] ?? '가입 실패').toString();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('가입 실패: $msg')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('네트워크 오류가 발생했습니다.')),
      );
    } finally {
      if (mounted) setState(() => _signingUp = false);
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

  // 토큰 읽기 유틸 추가
  Future<String?> _getAccessToken() async {
    if (kIsWeb) {
      return html.window.localStorage['accessToken'] ??
          html.window.localStorage['jwt'] ??
          html.window.localStorage['token'];
    } else {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('accessToken') ??
          prefs.getString('jwt') ??
          prefs.getString('token');
    }
  }

  @override
  Widget build(BuildContext context) {
    final mainColor = kuInfo;
    final hintStyle = Theme.of(context).inputDecorationTheme.hintStyle ??
        TextStyle(color: Theme.of(context).hintColor);

    return Scaffold(
      appBar: AppBar(
        title: const Text("KU대리 회원가입"),
        backgroundColor: mainColor,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: ListView(
          children: [
            const SizedBox(height: 20),

            // ───────── 학교 이메일 인증 영역 (SchoolSignUp 스타일) ─────────
            const Text(
              "학교 이메일 인증",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _emailLocalController,
                    enabled: !_emailLocked, // ✅ 잠그면 비활성화(회색)
                    decoration: InputDecoration(
                      labelText: '학교 이메일',
                      hintText: '예) 20201234',
                      // helperText 제거 ✅
                      suffixIcon: _emailLocked
                          ? const Icon(Icons.lock, size: 18, color: Colors.grey)
                          : null, // 잠금 아이콘은 유지
                    ),
                    keyboardType: TextInputType.emailAddress,
                    // 비활성화 시 onSubmitted는 동작하지 않으므로 굳이 처리할 필요 없음
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
                const SizedBox(width: 8),
                const Text('@kku.ac.kr'),
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
                      decoration: const InputDecoration(labelText: '인증번호 입력'),
                      keyboardType: TextInputType.number,
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(_codeExpired ? '만료됨' : _timerText, style: hintStyle),
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

            const SizedBox(height: 12),
            if (isVerified)
              Row(
                children: const [
                  Icon(Icons.check_circle, color: Colors.green),
                  SizedBox(width: 8),
                  Text('이메일 인증 완료', style: TextStyle(color: Colors.green)),
                ],
              ),

            // ───────── 이동수단 선택 ─────────
            const SizedBox(height: 30),
            const Text(
              "이동수단 선택",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            RadioListTile<String>(
              title: const Text("도보"),
              value: "도보",
              groupValue: selectedTransport,
              onChanged: (value) => setState(() => selectedTransport = value),
            ),
            RadioListTile<String>(
              title: const Text("자전거"),
              value: "자전거",
              groupValue: selectedTransport,
              onChanged: (value) => setState(() => selectedTransport = value),
            ),
            RadioListTile<String>(
              title: const Text("오토바이"),
              value: "오토바이",
              groupValue: selectedTransport,
              onChanged: (value) => setState(() => selectedTransport = value),
            ),
            RadioListTile<String>(
              title: const Text("기타"),
              value: "기타",
              groupValue: selectedTransport,
              onChanged: (value) => setState(() => selectedTransport = value),
            ),
            if (selectedTransport == "기타") ...[
              const SizedBox(height: 10),
              TextField(
                controller: _otherTransportController,
                decoration: const InputDecoration(
                  labelText: "기타 이동수단을 입력하세요",
                ),
                onChanged: (value) => _otherTransport = value,
              ),
            ],

            const SizedBox(height: 120),
          ],
        ),
      ),

      // 하단 가입 완료 버튼 (인증 완료 + 이동수단 선택 후 활성화)
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          color: Colors.white,
          child: SizedBox(
            height: 56,
            width: double.infinity,
            child: ElevatedButton(
              onPressed: (isVerified && _verifiedEmail != null && !_signingUp)
                  ? _completeSignup
                  : null,
              child: _signingUp
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text(
                      "회원가입 완료",
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
