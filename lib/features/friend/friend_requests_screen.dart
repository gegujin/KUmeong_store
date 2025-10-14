// C:\Users\82105\KU-meong Store\lib\features\friend\friend_requests_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../../core/base_url.dart';
import 'dto.dart';

class FriendRequestsScreen extends StatefulWidget {
  final String meUserId; // 👈 로그인한 내 UUID

  const FriendRequestsScreen({
    super.key,
    required this.meUserId,
  });

  @override
  State<FriendRequestsScreen> createState() => _FriendRequestsScreenState();
}


class _FriendRequestsScreenState extends State<FriendRequestsScreen> {
  bool _loading = true;
  String? _error;
  List<FriendRequestItem> _received = [];
  List<FriendRequestItem> _sent = [];

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<Map<String, String>> _authHeaders() async {
    // TODO: JWT로 교체 시 Authorization 사용
    return {
      'Content-Type': 'application/json',
      'X-User-Id': widget.meUserId, // 👈 내 UUID를 임시로 전달
    };
  }


  // box: incoming | outgoing
  Future<List<FriendRequestItem>> _fetchBox(String box) async {
    final uri = apiUrl('/friends/requests');
    final res = await http
        .get(uri, headers: await _authHeaders())
        .timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) {
      throw Exception('요청함($box) 로드 실패 ${res.statusCode}');
    }
    final j = jsonDecode(res.body);
    final list = (j is Map) ? (j['data'] as List? ?? []) : (j as List? ?? []);
    return list
        .map<FriendRequestItem>(
            (e) => FriendRequestItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final received = await _fetchBox('incoming');
      final sent = await _fetchBox('outgoing');
      if (!mounted) return;
      setState(() {
        _received = received.where((e) => e.status == 'pending').toList();
        _sent = sent.where((e) => e.status == 'pending').toList();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<String?> _postAction(String path) async {
    try {
      final uri = apiUrl('/friends/requests');
      final res = await http
          .post(uri, headers: await _authHeaders())
          .timeout(const Duration(seconds: 15));
      if (res.statusCode < 200 || res.statusCode >= 300) {
        try {
          final j = jsonDecode(res.body);
          final msg = (j is Map && j['message'] != null)
              ? j['message'].toString()
              : '실패 (${res.statusCode})';
          return msg;
        } catch (_) {
          return '실패 (${res.statusCode})';
        }
      }
      await _refresh();
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    final m = ScaffoldMessenger.maybeOf(context);
    m?.hideCurrentSnackBar();
    m?.showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _showSendDialog() async {
    final controller = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('친구 요청 보내기'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: '상대 학교 이메일',
            hintText: '예) 11@kku.ac.kr',
          ),
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.maybePop(ctx),
            child: const Text('닫기'),
          ),
          FilledButton(
            onPressed: () async {
              final email = controller.text.trim();
              if (email.isEmpty) {
                _toast('이메일을 입력하세요.');
                return;
              }
              // ✅ 백엔드가 이메일을 받아 내부에서 toUserId 조회
              final uri = apiUrl('/friends/requests');
              final res = await http.post(
                uri,
                headers: await _authHeaders(),
                body: jsonEncode({'targetEmail': email}),
              );
              if (res.statusCode < 200 || res.statusCode >= 300) {
                String msg = '요청 실패 (${res.statusCode})';
                try {
                  final j = jsonDecode(res.body);
                  msg = (j is Map && j['message'] != null)
                      ? j['message'].toString()
                      : msg;
                } catch (_) {}
                _toast(msg);
                return;
              }
              _toast('요청을 보냈어요.');
              if (mounted) Navigator.maybePop(ctx);
              await _refresh();
            },
            child: const Text('보내기'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('친구 요청함')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('불러오기 실패\n$_error'))
              : RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView(
                    children: [
                      const _SectionHeader('받은 요청'),
                      ..._received.map(
                        (e) => ListTile(
                          leading: const Icon(Icons.mail),
                          // ✅ 보낸 사람 → 나 (email/loginId 우선)
                          title: Text('${e.displaySender} → 나'),
                          subtitle: Text('요청일: ${e.createdAt}'),
                          trailing: Wrap(
                            spacing: 8,
                            children: [
                              OutlinedButton(
                                onPressed: () async {
                                  final err = await _postAction(
                                      '/v1/friends/requests/${e.id}/reject');
                                  if (err != null) _toast(err);
                                },
                                child: const Text('거절'),
                              ),
                              FilledButton(
                                onPressed: () async {
                                  final err = await _postAction(
                                      '/v1/friends/requests/${e.id}/accept');
                                  if (err != null) _toast(err);
                                },
                                child: const Text('수락'),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const _SectionHeader('보낸 요청'),
                      ..._sent.map(
                        (e) => ListTile(
                          leading: const Icon(Icons.outgoing_mail),
                          // ✅ 나 → 받는 사람 (email/loginId 우선)
                          title: Text('나 → ${e.displayReceiver}'),
                          subtitle: Text('요청일: ${e.createdAt}'),
                          trailing: TextButton(
                            onPressed: () async {
                              final err = await _postAction(
                                  '/v1/friends/requests/${e.id}/cancel');
                              if (err != null) _toast(err);
                            },
                            child: const Text('취소'),
                          ),
                        ),
                      ),
                      if (_received.isEmpty && _sent.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(child: Text('대기 중인 요청이 없어요.')),
                        ),
                    ],
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showSendDialog,
        label: const Text('요청 보내기'),
        icon: const Icon(Icons.person_add_alt),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
        child: Text(title, style: Theme.of(context).textTheme.titleMedium),
      );
}
