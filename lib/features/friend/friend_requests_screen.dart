// C:\Users\82105\KU-meong Store\lib\features\friend\friend_requests_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:kumeong_store/core/network/http_client.dart'; // ApiException, HttpX.me()
import 'package:kumeong_store/features/friend/data/friends_api.dart'; // friendsApi, FriendRequestRow, FriendRequestBox
import 'package:kumeong_store/features/friend/friend_chat_screen.dart'; // FriendChatPage

class FriendRequestsScreen extends ConsumerStatefulWidget {
  // 현재 화면에선 직접 사용하지 않지만 라우팅 규격 유지용
  final String meUserId;

  const FriendRequestsScreen({
    super.key,
    required this.meUserId,
  });

  @override
  ConsumerState<FriendRequestsScreen> createState() =>
      _FriendRequestsScreenState();
}

class _FriendRequestsScreenState extends ConsumerState<FriendRequestsScreen> {
  bool _loading = true;
  String? _error;
  bool _busy = false; // 🔒 중복 탭 방지

  List<FriendRequestRow> _received = [];
  List<FriendRequestRow> _sent = [];

  String? _meUserId;

  @override
  void initState() {
    super.initState();
    _loadMe(); // ✅ 내 id 가져오기
    _refresh();
  }

  Future<void> _loadMe() async {
    final me = await HttpX.me(); // { id, email, ... } or null
    if (!mounted) return;
    setState(() {
      _meUserId = (me?['id'] ?? '').toString();
    });
  }

  // 사람이 읽기 쉬운 에러 메시지 추출
  String _extractErrMsg(Object e, {String fallback = '요청 처리 중 오류가 발생했어요.'}) {
    if (e is ApiException) {
      final preview = e.bodyPreview;

      // bodyPreview에서 서버 메시지 추출 시도
      if (preview != null && preview.isNotEmpty) {
        try {
          final decoded = jsonDecode(preview);
          if (decoded is Map<String, dynamic>) {
            final err = decoded['error'];
            if (err is Map &&
                err['message'] is String &&
                (err['message'] as String).isNotEmpty) {
              return err['message'] as String;
            }
            if (decoded['message'] is String &&
                (decoded['message'] as String).isNotEmpty) {
              return decoded['message'] as String;
            }
          }
        } catch (_) {
          // JSON이 아니면 원문 일부를 노출
          final t = preview.trim();
          if (t.isNotEmpty)
            return t.length > 200 ? '${t.substring(0, 200)}…' : t;
        }
      }

      // 최종 폴백: ApiException 기본 메시지 또는 상태코드
      return (e.message.isNotEmpty) ? e.message : 'HTTP ${e.status ?? ''} 오류';
    }
    return fallback;
  }

  // 중복 탭 방지 래퍼
  Future<void> _wrapBusy(Future<void> Function() job) async {
    if (_busy) return;
    if (mounted) setState(() => _busy = true);
    try {
      await job();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final inc = await friendsApi.listRequests(FriendRequestBox.incoming);
      final out = await friendsApi.listRequests(FriendRequestBox.outgoing);
      if (!mounted) return;

      setState(() {
        // ⏱ 최신순 정렬 + pending만 표시
        _received = inc
            .where((e) => e.status.toLowerCase() == 'pending')
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        _sent = out.where((e) => e.status.toLowerCase() == 'pending').toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = _extractErrMsg(e));
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _acceptRow(FriendRequestRow row) async {
    await _wrapBusy(() async {
      try {
        // ✅ ID 기반 수락 → roomId 획득
        final roomId = await friendsApi.acceptById(row.id);

        _toast('요청을 수락했어요.');
        await _refresh();

        // ✅ 채팅방 바로 진입
        if (!mounted) return;

        var meId = _meUserId ?? '';
        if (meId.isEmpty) {
          await _loadMe();
          meId = _meUserId ?? '';
        }
        if (meId.isEmpty) {
          _toast('내 사용자 정보를 불러오지 못했습니다.');
          return;
        }

        // 상대 표시 이름(이메일 마스킹 활용)
        final isIAmReceiver = row.toUserId == meId;
        final rawName =
            isIAmReceiver ? (row.fromEmail ?? '친구') : (row.toEmail ?? '친구');
        final friendName = _maskEmail(rawName);

        // FriendChatPage로 이동 (roomId 전달)
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => FriendChatPage(
              friendName: friendName,
              meUserId: meId,
              roomId: roomId,
            ),
          ),
        );
      } catch (e) {
        _toast(_extractErrMsg(e));
      }
    });
  }

  Future<void> _rejectRow(FriendRequestRow row) async {
    await _wrapBusy(() async {
      try {
        await friendsApi.rejectById(row.id); // ✅ ID 기반
        _toast('요청을 거절했어요.');
        await _refresh();
      } catch (e) {
        _toast(_extractErrMsg(e));
      }
    });
  }

  Future<void> _cancelRow(FriendRequestRow row) async {
    await _wrapBusy(() async {
      try {
        await friendsApi.cancelById(row.id); // ✅ ID 기반
        _toast('요청을 취소했어요.');
        await _refresh();
      } catch (e) {
        _toast(_extractErrMsg(e));
      }
    });
  }

  void _toast(String msg) {
    if (!mounted) return;
    final m = ScaffoldMessenger.maybeOf(context);
    m?.hideCurrentSnackBar();
    m?.showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  // 이메일 간단 마스킹
  String _maskEmail(String? emailOrNull) {
    final s = emailOrNull ?? '';
    if (!s.contains('@')) return s;
    final parts = s.split('@');
    final id = parts.first;
    final dom = parts.last;
    final head = id.length <= 2 ? id : id.substring(0, 2);
    return '$head***@$dom';
  }

  Future<void> _showSendDialog() async {
    final controller = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('친구 요청 보내기'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: '이메일(아이디)',
              hintText: '예) konkuk@kku.ac.kr',
            ),
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
          ),
          actions: [
            TextButton(
              onPressed: _busy ? null : () => Navigator.maybePop(ctx),
              child: const Text('닫기'),
            ),
            FilledButton(
              onPressed: _busy
                  ? null
                  : () async {
                      final email = controller.text.trim();
                      if (email.isEmpty) {
                        _toast('이메일을 입력하세요.');
                        return;
                      }
                      await _wrapBusy(() async {
                        try {
                          // ✅ 서버 라우트: POST /friends/requests/by-email
                          await friendsApi.requestByEmail(email);
                          _toast('요청을 보냈어요.');
                          if (mounted) Navigator.maybePop(ctx);
                          await _refresh();
                        } catch (e) {
                          _toast(_extractErrMsg(e));
                        }
                      });
                    },
              child: const Text('보내기'),
            ),
          ],
        ),
      ),
    );
  }

  String _fmtIso(DateTime d) {
    // 간단 표시용. 필요하면 timeago/intl로 개선 가능
    return d.toLocal().toString().split('.').first;
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
                      if (_received.isEmpty)
                        const Padding(
                          padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
                          child: Text('받은 대기 요청이 없어요.'),
                        ),
                      for (final e in _received)
                        ListTile(
                          leading: const Icon(Icons.mail),
                          // 보낸 사람 → 나
                          title: Text(
                            '${_maskEmail(e.fromEmail).isEmpty ? e.fromUserId : _maskEmail(e.fromEmail)} → 나',
                          ),
                          subtitle: Text('요청일: ${_fmtIso(e.createdAt)}'),
                          trailing: Wrap(
                            spacing: 8,
                            children: [
                              OutlinedButton(
                                onPressed:
                                    _busy ? null : () => _rejectRow(e), // 거절
                                child: const Text('거절'),
                              ),
                              FilledButton(
                                onPressed:
                                    _busy ? null : () => _acceptRow(e), // 수락
                                child: const Text('수락'),
                              ),
                            ],
                          ),
                        ),
                      const _SectionHeader('보낸 요청'),
                      if (_sent.isEmpty)
                        const Padding(
                          padding: EdgeInsets.fromLTRB(16, 8, 16, 24),
                          child: Text('보낸 대기 요청이 없어요.'),
                        ),
                      for (final e in _sent)
                        ListTile(
                          leading: const Icon(Icons.outgoing_mail),
                          // 나 → 받는 사람
                          title: Text(
                            '나 → ${_maskEmail(e.toEmail).isEmpty ? e.toUserId : _maskEmail(e.toEmail)}',
                          ),
                          subtitle: Text('요청일: ${_fmtIso(e.createdAt)}'),
                          trailing: TextButton(
                            onPressed: _busy ? null : () => _cancelRow(e), // 취소
                            child: const Text('취소'),
                          ),
                        ),
                    ],
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _busy ? null : _showSendDialog,
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
