// lib/features/friend/friend_chat_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import '../chat/data/chats_api.dart'; // ChatApi, ChatMessage
import 'package:go_router/go_router.dart';
import 'package:kumeong_store/core/router/route_names.dart' as R;
import 'package:uuid/uuid.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// roomId 기반 채팅 화면
class FriendChatPage extends ConsumerStatefulWidget {
  final String friendName;

  /// 숫자/UUID 모두 가능 → 서버 헤더 X-User-Id 용
  final String meUserId;

  /// REST만 사용, roomId
  final String roomId;

  /// ✅ TRADE 화면 분기 및 부가 데이터 전달용(선택)
  /// 예: { 'isTrade': true, 'productMini': { id,title,priceWon,thumb } }
  final Map<String, dynamic>? extra;

  const FriendChatPage({
    super.key,
    required this.friendName,
    required this.meUserId,
    required this.roomId,
    this.extra,
  });

  @override
  ConsumerState<FriendChatPage> createState() => _FriendChatPageState();
}

enum _MenuAction { reload, leave }

class _FriendChatPageState extends ConsumerState<FriendChatPage> with WidgetsBindingObserver {
  final _controller = TextEditingController();
  final _scroll = ScrollController();

  late final ChatApi _api;
  final List<ChatMessage> _messages = [];
  final Map<String, int> _pendingIndexByClientId = {}; // clientMessageId -> index
  final Set<String> _messageIds = <String>{};

  bool _loading = true;
  String? _error;
  bool _fetching = false;
  DateTime? _lastFetchAt;

  // ---- 읽음 디바운스 ----
  Timer? _readDebounce;

  // ---- 마지막 전송 텍스트 (중복 전송 방지) ----
  String _lastSentNorm = '';

  // ---- 폴링(REST) ----
  Timer? _pollTimer;
  Duration _pollInterval = const Duration(milliseconds: 2500);
  int _pollErrorCount = 0;
  AppLifecycleState _lastLifecycle = AppLifecycleState.resumed;

  // ── UUID 정규화(서버 규칙과 동일) ──
  static final RegExp _uuidRe = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
    caseSensitive: false,
  );

  String _leftPadZeros(String s, int total) {
    final need = total - s.length;
    if (need <= 0) return s;
    final b = StringBuffer();
    for (var i = 0; i < need; i++) b.writeCharCode(48);
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

  String _normalizeText(String s) => s.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();

  late final String _meUuid;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

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

    // ✅ chats_api.dart 가정: ChatApi({required String meUserId})
    _api = ChatApi(meUserId: _meUuid);

    // 스크롤이 바닥 닿으면 디바운스 읽음 처리
    _scroll.addListener(() {
      if (_isAtBottom()) _scheduleMarkRead();
    });

    _loadInitial();
    _startPolling(); // ✅ 폴링 시작
  }

  @override
  void dispose() {
    // ✅ 안전망: 화면 dispose 직전에도 한 번 시도 (fire-and-forget)
    // ignore: discarded_futures
    _markReadLatest();
    _readDebounce?.cancel();
    _controller.dispose();
    _scroll.dispose();
    _stopPolling(); // ✅ 폴링 정지
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // 앱 비활성/백그라운드 전환 직전
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lastLifecycle = state;
    if (state == AppLifecycleState.resumed) {
      _startPolling();
      _scheduleMarkRead();
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _stopPolling();
      _scheduleMarkRead();
    }
  }

  // ---- 폴링 유틸 ----
  void _startPolling() {
    _stopPolling();
    _pollTimer = Timer.periodic(_pollInterval, (_) async {
      // 바닥일 때만 증분 로드 → 위로 스크롤해 과거 대화 읽는 중이면 방해하지 않음
      if (!_isAtBottom()) return;
      await _safeReloadWithBackoff();
    });
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> _safeReloadWithBackoff() async {
    try {
      await _reload();
      // 성공했으면 백오프 리셋 + 기본 주기(2.5s)로 복귀
      if (_pollErrorCount > 0) {
        _pollErrorCount = 0;
        if (_pollInterval > const Duration(milliseconds: 2500)) {
          _pollInterval = const Duration(milliseconds: 2500);
          _startPolling(); // 주기 반영하려면 재시작
        }
      }
    } catch (_) {
      // 에러 누적에 따라 2.5s → 5s → 10s → 최대 20s로 점진적 증가
      _pollErrorCount++;
      final nextMs = switch (_pollErrorCount) {
        1 => 5000,
        2 => 10000,
        _ => 20000,
      };
      if (_pollInterval.inMilliseconds != nextMs) {
        _pollInterval = Duration(milliseconds: nextMs);
        _startPolling();
      }
    }
  }

  // ---- 초기 로드 ----
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
      if (!mounted) return;

      setState(() {
        _messages
          ..clear()
          ..addAll(fetched);
        _messageIds
          ..clear()
          ..addAll(fetched.map((e) => e.id));
      });

      // 하단으로 스크롤
      await Future.delayed(const Duration(milliseconds: 20));
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }

      // ✅ 진입 직후 읽음 처리(디바운스)
      _scheduleMarkRead();
    } catch (e) {
      if (mounted) setState(() => _error = '메시지 불러오기 실패: $e');
    } finally {
      _fetching = false;
      if (mounted) setState(() => _loading = false);
    }
  }

  // ---- 새로고침(증분) ----
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

          // ✅ 최신까지 내려왔으면 읽음 처리(디바운스)
          _scheduleMarkRead();
        }
      }
    } catch (e) {
      if (mounted) setState(() => _error = '새 메시지 불러오기 실패: $e');
      rethrow; // 백오프 판단용
    } finally {
      _fetching = false;
    }
  }

  // ---- 전송 (펜딩/매칭/중복 방지) ----
  Future<void> _send() async {
    final raw = _controller.text;
    final text = raw.trim();
    if (text.isEmpty) return;

    final nowNorm = _normalizeText(text);
    // ✅ 마지막 전송 텍스트와 동일하면 스킵 (탭 연타 방지)
    if (_lastSentNorm == nowNorm) {
      return;
    }

    // 입력창 즉시 비우기
    _controller.clear();

    // ✅ 1) 로컬 펜딩 추가
    final clientId = const Uuid().v4();
    final pending = ChatMessage(
      id: 'pending:$clientId', // 펜딩 표시용
      roomId: widget.roomId,
      senderId: _meUuid,
      text: text,
      timestamp: DateTime.now(),
      seq: (_messages.isNotEmpty ? _messages.last.seq + 1 : 1), // 임시 seq
      readByMe: true,
      clientMessageId: clientId,
    );

    setState(() {
      _messages.add(pending);
      _messageIds.add(pending.id);
      _pendingIndexByClientId[clientId] = _messages.length - 1;
      _lastSentNorm = nowNorm;
    });
    _scrollToBottom();

    try {
      // ✅ 2) 서버 전송 (clientMessageId 포함)
      final saved = await _api.sendMessage(
        roomId: widget.roomId,
        text: text,
        clientMessageId: clientId,
      );

      // ✅ 3) 응답 매칭(펜딩→확정 치환)
      final idx = _pendingIndexByClientId.remove(clientId);
      if (!mounted) return;

      if (idx != null && idx >= 0 && idx < _messages.length) {
        setState(() {
          _messages[idx] = saved; // 서버가 준 id/seq/createdAt 반영
          _messageIds.add(saved.id);
        });
      } else {
        // 펜딩 인덱스 못찾으면 그냥 뒤에 붙임(이중표시는 아님)
        setState(() {
          _messages.add(saved);
          _messageIds.add(saved.id);
        });
      }

      _scrollToBottom();

      // 서버 시퀀스/다른 기기 메세지 동기화
      await _reload();
    } catch (e) {
      // 실패 시: 펜딩 취소/에러 상태 표시
      final idx = _pendingIndexByClientId.remove(clientId);
      if (!mounted) return;
      if (idx != null && idx >= 0 && idx < _messages.length) {
        setState(() {
          _messageIds.remove(_messages[idx].id);
          _messages.removeAt(idx);
        });
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('메시지 전송 실패: $e')),
      );
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent + 80,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ---- 읽음 처리 유틸 ----
  bool _isAtBottom() {
    if (!_scroll.hasClients) return false;
    final p = _scroll.position;
    // 약간의 여유(12px) 범위 내면 바닥으로 간주
    return p.pixels >= (p.maxScrollExtent - 12);
  }

  void _scheduleMarkRead() {
    if (_messages.isEmpty) return;
    _readDebounce?.cancel();
    _readDebounce = Timer(const Duration(milliseconds: 400), _markReadNow);
  }

  Future<void> _markReadNow() async {
    if (_messages.isEmpty) return;
    try {
      // lastMessageId 생략 시 서버가 최신으로 올릴 수 있게 구현되어 있다면:
      // await _api.markRead(widget.roomId);
      // 확실하게 마지막까지 보장하려면 id 지정:
      await _api.markRead(
        roomId: widget.roomId,
        lastMessageId: _messages.last.id,
      );
    } catch (_) {
      // 실패는 무시(낙관적 처리)
    }
  }

  // ✅ 뒤로가기/종료 직전 “최신” 보장용
  Future<void> _markReadLatest() async {
    if (_messages.isEmpty) return;
    try {
      await _api.markRead(
        roomId: widget.roomId,
        lastMessageId: _messages.last.id,
      );
    } catch (_) {}
  }

  // ---- 메뉴 ----
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
          await _markReadLatest(); // ✅ 나가기 직전
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

  // ---- UI ----
  bool _isPending(ChatMessage m) => m.id.startsWith('pending:');

  Widget _buildBubble(ChatMessage m) {
    final mainColor = Theme.of(context).colorScheme.primary;
    final isMine = _normalizeId(m.senderId) == _meUuid;
    final pending = _isPending(m);

    final bubble = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      constraints: const BoxConstraints(maxWidth: 280),
      decoration: BoxDecoration(
        color: isMine ? mainColor : Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
        border: pending ? Border.all(width: 1.2, color: Colors.white) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              m.text,
              style: TextStyle(
                color: isMine ? Colors.white : Colors.black87,
                fontSize: 16,
              ),
            ),
          ),
          if (pending) ...[
            const SizedBox(width: 6),
            const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ],
        ],
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

  Widget _buildHeader() {
    if (widget.extra?['isTrade'] == true) {
      final raw = widget.extra?['productMini'];
      final Map<String, dynamic>? p = (raw is Map) ? Map<String, dynamic>.from(raw as Map) : null;

      final thumb = (p?['thumb'] ?? '').toString();
      final title = (p?['title'] ?? '상품').toString();
      final price = p?['priceWon'];
      final priceText = (price is num) ? '${price.toInt()}원' : '${price ?? 0}원';
      final productId = (p?['id'] ?? '').toString();

      return Card(
        margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
        child: ListTile(
          leading: thumb.isNotEmpty
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.network(
                    thumb,
                    width: 44,
                    height: 44,
                    fit: BoxFit.cover,
                  ),
                )
              : const Icon(Icons.shopping_bag),
          title: Text(title),
          subtitle: Text(priceText),
          trailing: FilledButton(
            onPressed: productId.isEmpty
                ? null
                : () {
                    context.pushNamed(
                      R.RouteNames.tradeConfirm,
                      queryParameters: {
                        'productId': productId,
                        'roomId': widget.roomId,
                      },
                    );
                  },
            child: const Text('거래 진행'),
          ),
        ),
      );
    }
    return const SizedBox.shrink();
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
            Navigator.of(context).pop(true);
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
          // ✅ 물리/제스처 뒤로가기 시에도 보장
          await _markReadLatest();
          if (!mounted) return false;
          Navigator.of(context).pop(true);
          return false; // 우리가 직접 pop 처리
        },
        child: Column(
          children: [
            _buildHeader(),
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
                      : NotificationListener<ScrollEndNotification>(
                          onNotification: (_) {
                            if (_isAtBottom()) _scheduleMarkRead(); // ✅ 바닥 도달
                            return false;
                          },
                          child: ListView.builder(
                            controller: _scroll,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            itemCount: _messages.length,
                            itemBuilder: (_, i) => _buildBubble(_messages[i]),
                          ),
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
