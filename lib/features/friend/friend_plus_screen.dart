// C:\Users\82105\KU-meong Store\lib\features\friend\friend_plus_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../core/base_url.dart';

/// 부모에서 이미 가지고 있는(화면에 표시 중인) 친구 이름 목록
/// - 실제로는 "id 리스트"를 쓰는 게 안전하지만, 기존 시그니처 유지
class FriendPlusPage extends StatefulWidget {
  final List<String> currentFriends;

  const FriendPlusPage({super.key, required this.currentFriends});

  @override
  State<FriendPlusPage> createState() => _FriendPlusPageState();
}

class _FriendPlusPageState extends State<FriendPlusPage> {
  final _emailCtrl = TextEditingController();

  bool _loading = false;
  String? _errorText;

  /// TODO: 실제 로그인 토큰 주입(Provider/Storage 등)
  Future<Map<String, String>> _authHeaders() async {
    final token = ''; // e.g., await SecureStore.read('accessToken');
    return {
      'Content-Type': 'application/json',
      if (token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  bool get _inputValid => _emailCtrl.text.trim().isNotEmpty;

  Future<void> _addFriend() async {
    final raw = _emailCtrl.text.trim();
    if (raw.isEmpty) {
      setState(() => _errorText = '아이디 또는 학교 이메일을 입력하세요.');
      return;
    }

    setState(() {
      _loading = true;
      _errorText = null;
    });

    try {
      final headers = await _authHeaders();

      // ✅ 이메일로 바로 요청 생성 (백엔드가 내부에서 사용자 조회)
      final uri = apiUrl('/friends/requests');
      final body = jsonEncode({'targetEmail': raw.toLowerCase()});

      final resp = await http
          .post(uri, headers: headers, body: body)
          .timeout(const Duration(seconds: 10));

      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        String msg = '친구 요청 전송 실패(${resp.statusCode})';
        try {
          final j = jsonDecode(resp.body);
          msg = (j is Map && j['message'] != null) ? j['message'].toString() : msg;
        } catch (_) {}
        throw Exception(msg);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('친구 요청 전송: $raw')));
      // 부모에 표시용으로 입력 문자열을 그대로 반환
      Navigator.pop(context, raw);
    } catch (e) {
      setState(() {
        _errorText = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mainColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: mainColor,
        title: const Text('친구 추가', style: TextStyle(color: Colors.white)),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          TextButton(
            onPressed: _loading ? null : () => Navigator.pop(context, null),
            child: const Text('닫기', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '친구의 아이디 또는 학교 이메일을 입력하세요.\n예: B@kku.ac.kr',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),

                // 입력
                TextField(
                  controller: _emailCtrl,
                  enabled: !_loading,
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    hintText: '아이디 또는 이메일 입력 (@kku.ac.kr)',
                    prefixIcon: const Icon(Icons.alternate_email),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(25)),
                  ),
                  onChanged: (_) {
                    if (_errorText != null) setState(() => _errorText = null);
                    setState(() {}); // 버튼 활성화 갱신
                  },
                ),
                const SizedBox(height: 12),

                // 에러 메시지
                if (_errorText != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      _errorText!,
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                  ),

                // 추가하기 버튼
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    icon: _loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.person_add_alt_1),
                    onPressed: (!_loading && _inputValid) ? _addFriend : null,
                    label: const Text('추가하기'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// (참고) 서버에서 내려주는 최소 요약 모델(필요시 확장)
class FriendSummary {
  final String id;
  final String name;
  final String email;

  FriendSummary({
    required this.id,
    required this.name,
    required this.email,
  });

  factory FriendSummary.fromJson(Map<String, dynamic> j) {
    return FriendSummary(
      id: (j['id'] ?? j['userId'] ?? j['peerId']).toString(),
      name: (j['name'] ?? j['nickname'] ?? '').toString(),
      email: (j['email'] ?? '').toString(),
    );
  }
}
