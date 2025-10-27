// lib/features/friend/friend_chat_screen.dart
import 'package:flutter/material.dart';
import '../chat/data/chats_api.dart'; // ChatApi, ChatMessage
import '../friend/friend_screen.dart';

/// roomId 기반 채팅 화면
class FriendChatPage extends StatefulWidget {
  final String friendName;

  /// 숫자/UUID 모두 가능 → 서버 헤더 X-User-Id 용
  final String meUserId;

  /// REST/WS 모두 roomId 사용
  final String roomId;

  const FriendChatPage({
    super.key,
    required this.friendName,
    required this.meUserId,
    required this.roomId,
  });

  @override
  State<FriendChatPage> createState() => _FriendChatPageState();
}

enum _MenuAction { reload, leave }

class _FriendChatPageState extends State<FriendChatPage> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();

  late final ChatApi _api;
  List<ChatMessage> _messages = [];
  final Set<String> _messageIds = <String>{};
  bool _loading = true;
  String? _error;

  bool _fetching = false;
  DateTime? _lastFetchAt;

  // ── UUID 정규화(서버 규칙과 동일) ──
  static final RegExp _uuidRe = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
    caseSensitive: false,
  );

  String _leftPadZeros(String s, int total) {
    final need = total - s.length;
    if (need <= 0) return s;
    final b = StringBuffer();
    for (var i = 0; i < need; i++) {
      b.writeCharCode(48);
    }
    b.write(s);
    return b.toString();
  }

  String _normalizeId(Object? raw) {
    final s = (raw ?? '').toString().trim();
    if (s.isEmpty) return '';
    if (_uuidRe.hasMatch(s)) return s.toLowerCase();

    // 숫자만 추출 → 마지막 12자리 UUID 꼬리로 변환
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      final c = s.codeUnitAt(i);
      if (c >= 48 && c <= 57) buf.writeCharCode(c);
    }
    final digits = buf.toString();
    if (digits.isEmpty) return '';

    final start = digits.length > 12 ? digits.length - 12 : 0;
    final last12 = digits.substring(start);
    final padded = _leftPadZeros(last12, 12);
    return '00000000-0000-0000-0000-$padded';
  }

  late final String _meUuid;

  @override
  void initState() {
    super.initState();

    // ChatApi는 userId 필요
    _meUuid = _normalizeId(widget.meUserId);
    if (_meUuid.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('올바르지 않은 사용자 ID입니다.')),
        );
        Navigator.of(context).maybePop();
      });
      return;
    }

    _api = ChatApi(_meUuid);
    _loadInitial();
  }

  // ✅ 마지막 메시지까지 읽음 커서를 보장하는 유틸 (뒤로가기/종료 직전 호출)
  Future<void> _markReadLatest() async {
    if (_messages.isEmpty) return;
    try {
      await _api.markRead(
        roomId: widget.roomId,
        lastMessageId: _messages.last.id,
      );
    } catch (_) {
      // 실패는 무시(낙관적 처리)
    }
  }

  @override
  void dispose() {
    // ✅ 안전망: 화면 dispose 직전에도 읽음 커서 시도 (fire-and-forget)
    _markReadLatest();
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
    // ✅ 친구목록 갱신 트리거
    try {
      //context.findAncestorStateOfType<FriendScreenState>()?.refreshUnreadAll();
    } catch (_) {}
  }

  Future<void> _loadInitial() async {
    if (_fetching) return;

    final now = DateTime.now();
    if (_lastFetchAt != null && now.difference(_lastFetchAt!) < const Duration(milliseconds: 500)) {
      return;
    }
    _fetching = true;
    _lastFetchAt = now;

    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      // sinceSeq=0 → 최근 limit개
      final fetched = await _api.fetchMessagesSinceSeq(
        roomId: widget.roomId,
        sinceSeq: 0,
        limit: 50,
      );
      fetched.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      if (mounted) {
        setState(() {
          _messages = fetched;
          _messageIds
            ..clear()
            ..addAll(fetched.map((e) => e.id));
        });
      }

      await Future.delayed(const Duration(milliseconds: 20));
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }

      // ✅ 읽음 처리(실패 무시) → 유틸 사용으로 통일
      await _markReadLatest();
    } catch (e) {
      if (mounted) setState(() => _error = '메시지 불러오기 실패: $e');
    } finally {
      _fetching = false;
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _reload() async {
    if (_fetching) return;
    _fetching = true;
    if (mounted) setState(() => _error = null);

    try {
      final since = _messages.isEmpty ? 0 : _messages.last.seq;
      final fetched = await _api.fetchMessagesSinceSeq(
        roomId: widget.roomId,
        sinceSeq: since,
        limit: 50,
      );
      if (fetched.isNotEmpty && mounted) {
        // 중복 제거 병합
        final newOnes = fetched.where((m) => !_messageIds.contains(m.id)).toList()
          ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
        if (newOnes.isNotEmpty) {
          setState(() {
            _messages.addAll(newOnes);
            _messageIds.addAll(newOnes.map((e) => e.id));
          });
          await Future.delayed(const Duration(milliseconds: 20));
          if (_scroll.hasClients) {
            _scroll.jumpTo(_scroll.position.maxScrollExtent);
          }
          // 읽음 커서(실패 무시)
          _api.markRead(roomId: widget.roomId, lastMessageId: _messages.last.id).catchError((_) {});
        }
      }
    } catch (e) {
      if (mounted) setState(() => _error = '새 메시지 불러오기 실패: $e');
    } finally {
      _fetching = false;
    }
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();

    try {
      final saved = await _api.sendMessage(
        roomId: widget.roomId,
        text: text,
      );
      if (!mounted) return;

      setState(() {
        _messages.add(saved);
        _messageIds.add(saved.id);
      });

      await Future.delayed(const Duration(milliseconds: 20));
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }

      // 보낸 뒤에도 내 읽음 커서를 마지막으로(실패 무시)
      _api.markRead(roomId: widget.roomId, lastMessageId: saved.id).catchError((_) {});

      // 서버 시퀀스/다른 기기 메세지 동기화
      await _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('메시지 전송 실패: $e')),
      );
    }
  }

  Future<void> _onSelectMenu(_MenuAction action) async {
    switch (action) {
      case _MenuAction.reload:
        await _loadInitial();
        break;
      case _MenuAction.leave:
        final ok = await _confirm(
          title: '채팅방 나가기',
          message: '이 대화방의 전체 대화 내용이 삭제됩니다.\n정말 나가시겠어요?',
          confirmText: '나가기',
        );
        if (ok == true && mounted) {
          // ✅ 나가기 직전에도 읽음 커서 보장
          await _markReadLatest();
          // 목록 갱신 신호만 위로 — Detail이 이어서 List까지 pop(true) 처리
          Navigator.of(context).pop(true);
        }
        break;
    }
  }

  Future<bool?> _confirm({
    required String title,
    required String message,
    String confirmText = '확인',
    String cancelText = '취소',
  }) {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).maybePop(false),
            child: Text(cancelText),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).maybePop(true),
            child: Text(confirmText),
          ),
        ],
      ),
    );
  }

  Widget _buildBubble(ChatMessage m) {
    final mainColor = Theme.of(context).colorScheme.primary;
    final isMine = _normalizeId(m.senderId) == _meUuid;

    final bubble = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      constraints: const BoxConstraints(maxWidth: 280),
      decoration: BoxDecoration(
        color: isMine ? mainColor : Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        m.text,
        style: TextStyle(
          color: isMine ? Colors.white : Colors.black87,
          fontSize: 16,
        ),
      ),
    );

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: bubble,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mainColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () async {
            // ✅ 뒤로가기 버튼으로 나갈 때도 읽음 커서 보장
            await _markReadLatest();
            if (!mounted) return;
            Navigator.of(context).pop(true); // ← 읽음 갱신 신호
          },
        ),
        title: Text(widget.friendName),
        backgroundColor: mainColor,
        foregroundColor: Colors.white,
        actions: [
          PopupMenuButton<_MenuAction>(
            tooltip: '더보기',
            onSelected: _onSelectMenu,
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: _MenuAction.reload,
                child: ListTile(
                  leading: Icon(Icons.refresh),
                  title: Text('새로고침'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuDivider(),
              PopupMenuItem(
                value: _MenuAction.leave,
                child: ListTile(
                  leading: Icon(Icons.logout),
                  title: Text('채팅방 나가기'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: WillPopScope(
        onWillPop: () async {
          // ✅ 물리/제스처 뒤로가기로 나갈 때도 읽음 커서 보장
          await _markReadLatest();
          if (!mounted) return false;
          Navigator.of(context).pop(true); // ← 동일 신호
          return false; // 우리가 직접 pop 했음
        },
        child: Column(
          children: [
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(_error!, textAlign: TextAlign.center),
                          ),
                        )
                      : ListView.builder(
                          controller: _scroll,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          itemCount: _messages.length,
                          itemBuilder: (_, i) => _buildBubble(_messages[i]),
                        ),
            ),
            // 입력 영역
            SafeArea(
              top: false,
              child: Row(
                children: [
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: const InputDecoration(
                        hintText: '메시지 입력...',
                        border: OutlineInputBorder(),
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.send),
                    onPressed: _send,
                  ),
                  const SizedBox(width: 6),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
