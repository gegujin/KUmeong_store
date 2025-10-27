// C:\Users\82105\KU-meong Store\lib\features\friend\friend_plus_screen.dart
import 'package:flutter/material.dart';
import '../../core/network/http_client.dart'; // ✅ HttpX 사용

class FriendPlusPage extends StatefulWidget {
  /// 부모에서 이미 가지고 있는(화면에 표시 중인) 친구 "이름" 목록
  /// 실제로는 id 목록이 안전하지만, 기존 시그니처를 유지한다.
  final List<String> currentFriends;

  const FriendPlusPage({super.key, required this.currentFriends});

  @override
  State<FriendPlusPage> createState() => _FriendPlusPageState();
}

class _FriendPlusPageState extends State<FriendPlusPage> {
  final _emailCtrl = TextEditingController();

  bool _loading = false;
  String? _errorText;

  bool get _inputValid => _emailCtrl.text.trim().isNotEmpty;

  // 간단 이메일/UUID 판별
  static final _uuidRe = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
    caseSensitive: false,
  );
  static bool _looksLikeEmail(String s) => s.contains('@');

  Future<void> _addFriend() async {
    final raw = _emailCtrl.text.trim();
    if (raw.isEmpty) {
      setState(() => _errorText = '아이디 또는 학교 이메일을 입력하세요.');
      return;
    }

    // 간단한 중복 가드(부모가 이름 리스트를 주는 구조라 제한적임)
    if (widget.currentFriends.any(
      (name) => name.trim().toLowerCase() == raw.toLowerCase(),
    )) {
      setState(() => _errorText = '이미 친구 목록에 있는 사용자예요.');
      return;
    }

    setState(() {
      _loading = true;
      _errorText = null;
    });
    try {
      if (_uuidRe.hasMatch(raw)) {
        // UUID는 바로 전송
        await HttpX.postJson('/friends/requests', {'toUserId': raw.toLowerCase()});
      } else {
        // 이메일/닉네임 등 → lookup으로 id 확보
        final q = raw.toLowerCase();
        // 서버 구현차를 흡수: q 또는 email 둘 다 시도
        Map<String, dynamic> user;
        try {
          user = await HttpX.get('/users/lookup', query: {'q': q});
        } catch (_) {
          user = await HttpX.get('/users/lookup', query: {'email': q});
        }
        final data = (user['data'] is Map) ? user['data'] as Map : user;
        final toUserId = (data['id'] ?? data['userId'] ?? data['uuid'] ?? '').toString();
        if (toUserId.isEmpty) throw Exception('해당 사용자를 찾을 수 없습니다.');
        await HttpX.postJson('/friends/requests', {'toUserId': toUserId});
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('친구 요청 전송: $raw')));

      // 부모에 표시용으로 입력 문자열을 그대로 반환
      Navigator.pop(context, raw);
    } on ApiException catch (e) {
      // 서버에서 내려준 메시지 노출
      setState(() {
        _errorText = e.message.isNotEmpty ? e.message : '친구 요청 실패 (HTTP ${e.status ?? '-'})';
      });
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
                  '친구의 아이디(UUID) 또는 학교 이메일을 입력하세요.\n예: user@kku.ac.kr',
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
                    hintText: '아이디(UUID) 또는 이메일 입력 (@kku.ac.kr)',
                    prefixIcon: const Icon(Icons.alternate_email),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
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
                    label: Text(_loading ? '전송 중...' : '추가하기'),
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
