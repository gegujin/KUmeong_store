// lib/features/delivery/ku_delivery_signup_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kumeong_store/core/router/route_names.dart' as R;

// KU대리 브랜드 색상
const Color kuInfo = Color(0xFF147AD6);

class KuDeliverySignupPage extends StatefulWidget {
  const KuDeliverySignupPage({super.key});

  @override
  State<KuDeliverySignupPage> createState() => _KuDeliverySignupPageState();
}

class _KuDeliverySignupPageState extends State<KuDeliverySignupPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _otherTransportController =
      TextEditingController();

  bool isCodeSent = false;
  bool isVerified = false;

  /// 라디오 선택 값: "도보" / "자전거" / "오토바이" / "기타" / null
  String? selectedTransport;

  /// "기타"일 때만 사용하는 실제 입력값
  String? _otherTransport;

  // 이메일 인증번호 발송
  void _sendCode() {
    if (_emailController.text.trim().toLowerCase().endsWith("@kku.ac.kr")) {
      setState(() => isCodeSent = true);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("인증번호가 발송되었습니다.")),
      );
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("학교 이메일(@kku.ac.kr)만 가능합니다.")),
      );
    }
  }

  // 인증번호 확인 (데모)
  void _verifyCode() {
    setState(() => isVerified = true);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("이메일 인증이 완료되었습니다.")),
    );
  }

  // 회원가입 완료
  void _completeSignup() {
    // 키보드 내리기 (UX)
    FocusScope.of(context).unfocus();

    if (!isVerified) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("이메일 인증을 완료해주세요.")),
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

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("회원가입 완료! 이동수단: $finalTransport")),
    );

    // ✅ 라우터로 이동 (교체 이동). 뒤로가기로 가입 페이지 복귀 원하면 pushNamed로.
    context.goNamed(R.RouteNames.kuDeliveryFeed);
    // context.pushNamed(R.RouteNames.kuDeliveryFeed);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _otherTransportController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("KU대리 회원가입"),
        backgroundColor: kuInfo,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: ListView(
          children: [
            // 이메일 인증
            const SizedBox(height: 20),
            const Text(
              "학교 이메일 인증",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: "학교 이메일 (@kku.ac.kr)",
              ),
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendCode(),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _sendCode,
              style: ElevatedButton.styleFrom(backgroundColor: kuInfo),
              child: const Text("인증번호 발송"),
            ),
            if (isCodeSent) ...[
              const SizedBox(height: 10),
              TextField(
                controller: _codeController,
                decoration: const InputDecoration(labelText: "인증번호 입력"),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: _verifyCode,
                style: ElevatedButton.styleFrom(backgroundColor: kuInfo),
                child: const Text("인증하기"),
              ),
            ],

            // 이동수단 선택
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

      // 회원가입 완료 버튼 하단 고정
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          color: Colors.white,
          child: SizedBox(
            height: 56,
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _completeSignup,
              style: ElevatedButton.styleFrom(
                backgroundColor: kuInfo,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
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
