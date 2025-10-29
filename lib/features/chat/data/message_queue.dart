// lib/features/chat/chat_room_screen.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kumeong_store/features/chat/data/chats_api.dart';
// NOTE: KuColors/DeliveryStatusArgs/message_queue 의존성 제거

enum PayMethod { none, escrow, direct }

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({
    super.key,
    required this.partnerName,
    this.roomId,
    this.isKuDelivery = false,
    this.securePaid = false,
    this.extra, // { isTrade:true, productMini:{id,title,priceWon,thumb} }
  });

  final String partnerName;
  final String? roomId;
  final bool isKuDelivery;
  final bool securePaid;
  final Map<String, dynamic>? extra;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> with WidgetsBindingObserver {
  static final RegExp _uuidRe = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );
  bool _looksLikeUuid(String? s) => s != null && _uuidRe.hasMatch(s.trim());

  final _textCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  late PayMethod _payMethod;
  late bool _securePaid;
  late bool _tradeStarted;

  bool get _showDeliveryPanel => _payMethod == PayMethod.escrow;
  bool get _showConfirmButton => _payMethod == PayMethod.escrow && _securePaid;
  bool get _showPayButton => !_tradeStarted;

  final _demoMessages = <_ChatMessage>[
    _ChatMessage(text: '안녕하세요! 아직 구매 가능할까요?', isMe: true),
    _ChatMessage(text: '네 가능해요 🙌', isMe: false),
  ];

  late final bool _serverMode;
  late final ChatApi _api;
  List<ChatMessage> _serverMessages = [];
  String? _meUserId;
  bool _loading = false;
  String? _error;

  Timer? _readDebounce;
  Timer? _pollTimer;
  Duration _pollInterval = const Duration(milliseconds: 2500);
  int _pollErrorCount = 0;

  String _normalizeText(String s) => s.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();

  Future<String?> _loadMeId() async {
    try {
      final sp = await SharedPreferences.getInstance();
      final raw = sp.getString('session.v1');
      if (raw != null && raw.isNotEmpty) {
        final j = jsonDecode(raw);
        if (j is Map) {
          final me = (j['me'] as Map?) ?? (j['user'] as Map?);
          final id = me?['id']?.toString();
          if (id != null && id.isNotEmpty) return id.toLowerCase();
        }
      }
    } catch (_) {}
    return null;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _api = ChatApi(meUserId: 'me');

    _securePaid = widget.securePaid;
    if (widget.isKuDelivery) {
      _payMethod = PayMethod.escrow;
    } else if (_securePaid) {
      _payMethod = PayMethod.direct;
    } else {
      _payMethod = PayMethod.none;
    }
    _tradeStarted = _payMethod != PayMethod.none || _securePaid;

    _serverMode = (widget.roomId != null && widget.roomId!.trim().isNotEmpty);
    if (_serverMode) {
      _bootstrapServerChat();
      _startPolling();
      _scrollCtrl.addListener(() {
        if (_isAtBottom()) _scheduleMarkRead();
      });
    }
  }

  @override
  void dispose() {
    _readDebounce?.cancel();
    _pollTimer?.cancel();
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_serverMode) return;
    if (state == AppLifecycleState.resumed) {
      _startPolling();
      _scheduleMarkRead();
    } else {
      _stopPolling();
      _scheduleMarkRead();
    }
  }

  Future<void> _bootstrapServerChat() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _meUserId = await _loadMeId();
      final rid = widget.roomId!;
      final msgs = await _api.fetchMessagesSinceSeq(roomId: rid, sinceSeq: 0, limit: 50);
      msgs.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      setState(() => _serverMessages = msgs);
      await _api.markRead(roomId: rid, lastMessageId: msgs.isNotEmpty ? msgs.last.id : null);
      _jumpBottom();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _startPolling() {
    _stopPolling();
    _pollTimer = Timer.periodic(_pollInterval, (_) async {
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
      if (_pollErrorCount > 0) {
        _pollErrorCount = 0;
        if (_pollInterval > const Duration(milliseconds: 2500)) {
          _pollInterval = const Duration(milliseconds: 2500);
          _startPolling();
        }
      }
    } catch (_) {
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

  Future<void> _reload() async {
    if (!_serverMode) return;
    final since = _serverMessages.isEmpty ? 0 : _serverMessages.last.seq;
    final fetched = await _api.fetchMessagesSinceSeq(
      roomId: widget.roomId!,
      sinceSeq: since,
      limit: 50,
    );
    if (fetched.isNotEmpty && mounted) {
      fetched.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      setState(() => _serverMessages.addAll(fetched));
      _jumpBottom();
      _scheduleMarkRead();
    }
  }

  Future<void> _send() async {
    final txt = _textCtrl.text.trim();
    if (txt.isEmpty) return;
    _textCtrl.clear();

    if (_serverMode) {
      try {
        await _api.sendMessage(roomId: widget.roomId!, text: txt);
        // 전송 후 즉시 재로딩(큐 의존 제거)
        await _reload();
        _scrollToBottom();
      } catch (e) {
        _toast('전송 실패: $e');
      }
      return;
    }

    setState(() {
      _demoMessages.add(_ChatMessage(text: txt, isMe: true, ts: DateTime.now()));
    });
    _scrollToBottom();
  }

  bool _isAtBottom() {
    if (!_scrollCtrl.hasClients) return false;
    final p = _scrollCtrl.position;
    return p.pixels >= (p.maxScrollExtent - 12);
  }

  void _scheduleMarkRead() {
    if (!_serverMode || _serverMessages.isEmpty) return;
    _readDebounce?.cancel();
    _readDebounce = Timer(const Duration(milliseconds: 400), _markReadNow);
  }

  Future<void> _markReadNow() async {
    if (!_serverMode || _serverMessages.isEmpty) return;
    try {
      await _api.markRead(
        roomId: widget.roomId!,
        lastMessageId: _serverMessages.last.id,
      );
    } catch (_) {}
  }

  void _jumpBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
      }
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent + 80,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _openAttachSheet() {
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      backgroundColor: cs.surface,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        Widget item(IconData icon, String label, VoidCallback onTap) {
          return InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              Navigator.of(ctx).pop();
              onTap();
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: cs.primary.withOpacity(.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, color: cs.primary),
                  ),
                  const SizedBox(width: 12),
                  Text(label, style: const TextStyle(fontSize: 16)),
                ],
              ),
            ),
          );
        }

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                item(Icons.photo_library_outlined, '앨범', () => _toast('앨범 열기')),
                item(Icons.photo_camera_outlined, '카메라', () => _toast('카메라 열기')),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  void _goToDeliveryStatus() {
    // 타입 의존 없이 Map extra로 전달
    final args = {
      'orderId': widget.roomId ?? 'room-demo',
      'categoryName': '의류',
      'productTitle': 'K 로고 스타디움 점퍼',
      'imageUrl': null,
      'price': 30000,
      'startName': '옥손빌 S동',
      'endName': '베스트마트',
      'etaMinutes': 17,
      'moveTypeText': '도보로 이동중',
      // 좌표/경로는 필요 시 내부에서 파싱
    };
    context.push('/delivery/status', extra: args);
  }

  Future<void> _goTradeMethod() async {
    final raw = widget.extra?['productMini'];
    final Map<String, dynamic>? p = (raw is Map) ? Map<String, dynamic>.from(raw as Map) : null;
    final productId = (p?['id'] ?? '').toString();

    if (!_looksLikeUuid(productId)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('상품 ID가 올바르지 않습니다. (UUID 필요)')),
        );
      }
      return;
    }

    try {
      await _api.ensureTradeRoom(productId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('거래방 생성 실패: $e')),
        );
      }
      return;
    }

    if (!mounted) return;
    await context.pushNamed(
      'tradeConfirm',
      queryParameters: {'roomId': widget.roomId ?? '', 'productId': productId},
    );
  }

  Widget _buildTradeHeader() {
    if (widget.extra?['isTrade'] == true) {
      final raw = widget.extra?['productMini'];
      final Map<String, dynamic>? p = (raw is Map) ? Map<String, dynamic>.from(raw as Map) : null;

      final thumb = (p?['thumb'] ?? '').toString();
      final title = (p?['title'] ?? '상품').toString();
      final price = p?['priceWon'];
      final priceText = (price is num) ? '${price.toInt()}원' : '${price ?? 0}원';
      final productId = (p?['id'] ?? '').toString();

      final cs = Theme.of(context).colorScheme;

      return Card(
        margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
        child: ListTile(
          leading: thumb.isNotEmpty
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.network(thumb, width: 44, height: 44, fit: BoxFit.cover),
                )
              : const Icon(Icons.shopping_bag),
          title: Text(title),
          subtitle: Text(priceText),
          trailing: FilledButton(
            onPressed: productId.isEmpty
                ? null
                : () async {
                    if (!_looksLikeUuid(productId)) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('상품 ID가 올바르지 않습니다. (UUID 필요)')),
                        );
                      }
                      return;
                    }
                    try {
                      await _api.ensureTradeRoom(productId);
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('거래방 생성 실패: $e')),
                        );
                      }
                      return;
                    }
                    if (!mounted) return;
                    context.pushNamed(
                      'tradeConfirm',
                      queryParameters: {'productId': productId, 'roomId': widget.roomId ?? ''},
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
    final cs = Theme.of(context).colorScheme;

    if (_serverMode && _loading && _serverMessages.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_serverMode && _error != null && _serverMessages.isEmpty) {
      return Scaffold(body: Center(child: Text('채팅을 불러오지 못했습니다: $_error')));
    }

    // 서버 메시지만 사용(큐 의존 제거)
    final List<_ChatMessage> items = _serverMode
        ? _serverMessages
            .map((m) => _ChatMessage(
                  text: m.text,
                  isMe: (_meUserId != null) && (m.senderId.toLowerCase() == _meUserId),
                  ts: m.timestamp,
                ))
            .toList()
        : _demoMessages;

    return Scaffold(
      backgroundColor: cs.background,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Text(widget.partnerName),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () async {
            if (_serverMode && _serverMessages.isNotEmpty) {
              try {
                await _api.markRead(
                  roomId: widget.roomId!,
                  lastMessageId: _serverMessages.last.id,
                );
              } catch (_) {}
            }
            if (!mounted) return;
            context.pop();
          },
          tooltip: '뒤로',
        ),
      ),
      body: Column(
        children: [
          _buildTradeHeader(),
          Expanded(
            child: ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.all(12),
              itemCount: items.length,
              itemBuilder: (context, i) => _MessageBubble(message: items[i]),
            ),
          ),
          if (_showDeliveryPanel) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: _ProgressPanel(
                showConfirm: _showConfirmButton,
                onTrack: _goToDeliveryStatus,
                onConfirm: _onConfirmPurchase,
              ),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _InputBar(controller: _textCtrl, onSend: _send, onAttach: _openAttachSheet),
              const SizedBox(height: 10),
              if (_showPayButton)
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    onPressed: _goTradeMethod,
                    child: const Text('거래 진행하기'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _onConfirmPurchase() {
    setState(() {
      _payMethod = PayMethod.none;
      _securePaid = false;
      _tradeStarted = true;
    });
    _toast('구매 확정되었습니다.');
  }
}

class _ProgressPanel extends StatelessWidget {
  const _ProgressPanel({
    required this.showConfirm,
    required this.onTrack,
    required this.onConfirm,
  });

  final bool showConfirm;
  final VoidCallback onTrack;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.primaryContainer),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '거래가 진행 중입니다.\n구매 확정을 하시면 버튼을 눌러주세요.\n(구매 확정은 3일 뒤 자동 확정됩니다.)',
            style: TextStyle(color: cs.onBackground),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onTrack,
                  child: Text('배달 현황', style: TextStyle(color: cs.onBackground)),
                ),
              ),
              const SizedBox(width: 12),
              if (showConfirm)
                Expanded(
                  child: OutlinedButton(
                    onPressed: onConfirm,
                    child: Text('구매 확정', style: TextStyle(color: cs.onBackground)),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  const _InputBar({required this.controller, required this.onSend, required this.onAttach});
  final TextEditingController controller;
  final VoidCallback onSend;
  final VoidCallback onAttach;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.primaryContainer),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          IconButton(onPressed: onAttach, icon: const Icon(Icons.add)),
          const SizedBox(width: 4),
          Expanded(
            child: TextField(
              controller: controller,
              minLines: 1,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: '메시지 입력',
                isDense: true,
                border: InputBorder.none,
              ),
              onSubmitted: (_) => onSend(),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(onPressed: onSend, icon: const Icon(Icons.send)),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});
  final _ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isMe = message.isMe;

    final bubble = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      margin: EdgeInsets.only(left: isMe ? 48 : 8, right: isMe ? 8 : 48, bottom: 8),
      decoration: BoxDecoration(
        color: isMe ? cs.primary.withOpacity(.14) : cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.primary.withOpacity(.35)),
      ),
      child: Flexible(
        child: Text(message.text, style: TextStyle(color: cs.onBackground)),
      ),
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: [
        if (!isMe)
          const Padding(
            padding: EdgeInsets.only(left: 8, right: 8, top: 2),
            child: CircleAvatar(radius: 16, backgroundColor: Colors.grey),
          ),
        Flexible(child: bubble),
      ],
    );
  }
}

class _ChatMessage {
  _ChatMessage({required this.text, required this.isMe, this.ts});
  final String text;
  final bool isMe;
  final DateTime? ts;
}
