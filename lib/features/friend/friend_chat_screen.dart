// // C:\Users\82105\KU-meong Store\lib\features\friend\friend_chat_screen.dart
// import 'package:flutter/material.dart';
// import 'package:http/http.dart' as http;
// import '../../core/chat_api.dart';
// import '../../core/base_url.dart';
// import 'friend_screen.dart';

// class FriendChatPage extends StatefulWidget {
//   final String friendName;

//   /// 내 사용자 ID (숫자/UUID 모두 가능) → 헤더 X-User-Id용
//   final String meUserId;

//   /// 친구(상대) ID → URL 파라미터로만 사용
//   final String peerUserId;

//   const FriendChatPage({
//     super.key,
//     required this.friendName,
//     required this.meUserId,
//     required this.peerUserId,
//   });

//   @override
//   State<FriendChatPage> createState() => _FriendChatPageState();
// }

// enum _MenuAction { reload, report, block, leave }

// class _FriendChatPageState extends State<FriendChatPage> {
//   final _controller = TextEditingController();
//   final _scroll = ScrollController();

//   late final ChatApi _api;
//   List<ChatMessageDto> _messages = [];
//   bool _loading = true;
//   String? _error;

//   /// 중복 호출 방지용 플래그/타임스탬프 (디바운스 포함)
//   bool _fetching = false;
//   DateTime? _lastFetchAt;

//   /// 상단 메뉴 동작 중 가드
//   bool _busyAction = false;

//   /// ─────────────────────────────────────────────────────────────
//   /// 서버와 동일 규칙: 숫자 → 마지막 12자리만 사용해 UUID로 정규화
//   /// "00000000-0000-0000-0000-XXXXXXXXXXXX" 형태로 맞춤
//   /// ─────────────────────────────────────────────────────────────
//   static final RegExp _uuidRe =
//       RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
//           caseSensitive: false);

//   // ← 0 패딩 유틸 (ChatApi와 같은 방식)
//   String _leftPadZeros(String s, int total) {
//     final need = total - s.length;
//     if (need <= 0) return s;
//     final b = StringBuffer();
//     for (var i = 0; i < need; i++) {
//       b.writeCharCode(48); // '0'
//     }
//     b.write(s);
//     return b.toString();
//   }

//   String _normalizeId(Object? raw) {
//     final s = (raw ?? '').toString().trim();
//     if (s.isEmpty) return '';
//     if (_uuidRe.hasMatch(s)) return s.toLowerCase();

//     // 숫자만 추출
//     final buf = StringBuffer();
//     for (var i = 0; i < s.length; i++) {
//       final c = s.codeUnitAt(i);
//       if (c >= 48 && c <= 57) buf.writeCharCode(c);
//     }
//     final digits = buf.toString();
//     if (digits.isEmpty) return '';

//     final start = digits.length > 12 ? digits.length - 12 : 0;
//     final last12 = digits.substring(start);
//     final padded = _leftPadZeros(last12, 12); // ← 안전한 12자리 보장
//     return '00000000-0000-0000-0000-$padded';
//   }

//   late final String _meUuid;   // 정규화된 내 ID
//   late final String _peerUuid; // 정규화된 상대 ID

//   @override
//   void initState() {
//     super.initState();

//     // ✅ 먼저 둘 다 정규화
//     _meUuid = _normalizeId(widget.meUserId);
//     _peerUuid = _normalizeId(widget.peerUserId);

//     // ✅ 자기 자신 채팅 가드 (설계상 없지만 혹시 대비)
//     if (_meUuid.isEmpty || _peerUuid.isEmpty || _meUuid == _peerUuid) {
//       WidgetsBinding.instance.addPostFrameCallback((_) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(content: Text('자기 자신과는 대화를 시작할 수 없어요.')),
//         );
//         Navigator.of(context).maybePop();
//       });
//       return;
//     }

//     // ✅ ChatApi에는 오직 "내 ID"만 전달 → 헤더 X-User-Id
//     _api = ChatApi(baseUrl: apiBaseUrl(), meUserId: _meUuid);

//     _loadInitial();
//   }

//   @override
//   void dispose() {
//     _controller.dispose();
//     _scroll.dispose();
//     super.dispose();
//   }

//   Future<void> _loadInitial() async {
//     if (_fetching) return;

//     // 500ms 디바운스
//     final now = DateTime.now();
//     if (_lastFetchAt != null &&
//         now.difference(_lastFetchAt!) < const Duration(milliseconds: 500)) {
//       return;
//     }
//     _fetching = true;
//     _lastFetchAt = now;

//     if (mounted) {
//       setState(() {
//         _loading = true;
//         _error = null;
//       });
//     }

//     try {
//       final fetched = await _api.fetchMessagesWithPeer(_peerUuid);
//       fetched.sort((a, b) => a.createdAt.compareTo(b.createdAt));
//       if (mounted) {
//         setState(() {
//           _messages = fetched;
//         });
//       }

//       // 스크롤 맨 아래로
//       await Future.delayed(const Duration(milliseconds: 20));
//       if (_scroll.hasClients) {
//         _scroll.jumpTo(_scroll.position.maxScrollExtent);
//       }

//       // 읽음 처리(실패해도 무시)
//       if (_messages.isNotEmpty) {
//         _api.markReadUpTo(_peerUuid, _messages.last.id).catchError((_) {});
//       }
//     } catch (e) {
//       if (mounted) {
//         setState(() =>
//             _error = '메시지 불러오기 실패: $e\n(me=$_meUuid, peer=$_peerUuid)');
//       }
//     } finally {
//       _fetching = false;
//       if (mounted) setState(() => _loading = false);
//     }
//   }

//   Future<void> _send() async {
//     final text = _controller.text.trim();
//     if (text.isEmpty) return;
//     _controller.clear();

//     try {
//       // ✅ 전송 직후 재-GET 없이 즉시 append
//       final saved = await _api.sendToPeer(_peerUuid, text);
//       if (mounted) {
//         setState(() => _messages.add(saved));
//       }

//       // 스크롤 맨 아래로
//       await Future.delayed(const Duration(milliseconds: 20));
//       if (_scroll.hasClients) {
//         _scroll.jumpTo(_scroll.position.maxScrollExtent);
//       }

//       // 선택: 보낸 뒤 읽음 처리(실패해도 무시)
//       _api.markReadUpTo(_peerUuid, saved.id).catchError((_) {});
//     } catch (e) {
//       if (!mounted) return;
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('메시지 전송 실패: $e')),
//       );
//     }
//   }

//   // ====== 상단 더보기 메뉴 처리 ======
//   Future<void> _onSelectMenu(_MenuAction action) async {
//     if (_busyAction) return;
//     switch (action) {
//       case _MenuAction.reload:
//         await _loadInitial();
//         break;
//       case _MenuAction.report:
//         await _reportPeer();
//         break;
//       case _MenuAction.block:
//         await _blockPeer();
//         break;
//       case _MenuAction.leave:
//         final ok = await _confirm(
//           title: '채팅방 나가기',
//           message: '이 대화방의 전체 대화 내용이 삭제됩니다.\n정말 나가시겠어요?',
//           confirmText: '나가기',
//         );
//         if (ok == true) {
//           await _leaveChat();
//         }
//         break;
//     }
//   }

//   bool _ok(int s) => s >= 200 && s < 300;

//   Future<void> _reportPeer() async {
//     if (_busyAction) return;
//     _busyAction = true;
//     try {
//       final url = Uri.parse('${apiBaseUrl()}/chats/$_peerUuid/report');
//       final r = await http.post(
//         url,
//         headers: {
//           'Content-Type': 'application/json',
//           'X-User-Id': _meUuid,
//         },
//         body: '{"reason":"abuse"}',
//       );
//       if (_ok(r.statusCode)) {
//         _toast('신고가 접수되었습니다.');
//       } else {
//         _toast('신고 실패 (${r.statusCode})');
//       }
//     } catch (e) {
//       _toast('신고 중 오류: $e');
//     } finally {
//       _busyAction = false;
//     }
//   }

//   Future<void> _blockPeer() async {
//     if (_busyAction) return;
//     _busyAction = true;
//     try {
//       final url = Uri.parse('${apiBaseUrl()}/chats/$_peerUuid/block');
//       final r = await http.post(
//         url,
//         headers: {
//           'Content-Type': 'application/json',
//           'X-User-Id': _meUuid,
//         },
//       );
//       if (_ok(r.statusCode)) {
//         _toast('상대가 차단되었습니다.');
//       } else {
//         _toast('차단 실패 (${r.statusCode})');
//       }
//     } catch (e) {
//       _toast('차단 중 오류: $e');
//     } finally {
//       _busyAction = false;
//     }
//   }

//   /// 채팅방 나가기: 서버에서 대화/방 삭제 후 친구 목록으로 이동
//   Future<void> _leaveChat() async {
//     if (_busyAction) return;
//     _busyAction = true;
//     try {
//       final url = Uri.parse('${apiBaseUrl()}/chats/$_peerUuid');
//       final r = await http.delete(
//         url,
//         headers: {
//           'X-User-Id': _meUuid,
//         },
//       );
//       if (_ok(r.statusCode)) {
//         if (mounted) {
//           setState(() {
//             _messages.clear();
//           });
//         }
//         _toast('채팅방을 나갔습니다.');
//         if (mounted) {
//           Navigator.of(context).pushAndRemoveUntil(
//             MaterialPageRoute(
//               builder: (_) => FriendScreen(meUserId: widget.meUserId),
//             ),
//             (route) => false,
//           );
//         }
//       } else {
//         _toast('채팅방 나가기 실패 (${r.statusCode})');
//       }
//     } catch (e) {
//       _toast('채팅방 나가기 중 오류: $e');
//     } finally {
//       _busyAction = false;
//     }
//   }

//   Future<bool?> _confirm({
//     required String title,
//     required String message,
//     String confirmText = '확인',
//     String cancelText = '취소',
//   }) {
//     return showDialog<bool>(
//       context: context,
//       builder: (_) => AlertDialog(
//         title: Text(title),
//         content: Text(message),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.of(context).maybePop(false),
//             child: Text(cancelText),
//           ),
//           FilledButton(
//             onPressed: () => Navigator.of(context).maybePop(true),
//             child: Text(confirmText),
//           ),
//         ],
//       ),
//     );
//   }
//   // ======================

//   // ====== 첨부 시트 ======
//   void _openAttachSheet() {
//     showModalBottomSheet(
//       context: context,
//       showDragHandle: true,
//       useSafeArea: true,
//       builder: (_) {
//         return SafeArea(
//           child: Padding(
//             padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
//             child: Column(
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 _sheetItem(
//                   Icons.photo_library_outlined,
//                   '앨범',
//                   () => _toast('앨범 열기'),
//                 ),
//                 _sheetItem(
//                   Icons.photo_camera_outlined,
//                   '카메라',
//                   () => _toast('카메라 열기'),
//                 ),
//                 const SizedBox(height: 8),
//               ],
//             ),
//           ),
//         );
//       },
//     );
//   }

//   Widget _sheetItem(IconData icon, String label, VoidCallback onTap) {
//     final c = Theme.of(context).colorScheme;
//     return ListTile(
//       leading: Icon(icon, color: c.primary),
//       title: Text(label),
//       onTap: () {
//         Navigator.of(context).maybePop();
//         onTap();
//       },
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//     );
//   }

//   void _toast(String msg) {
//     ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
//   }
//   // ======================

//   Widget _buildBubble(ChatMessageDto m) {
//     final mainColor = Theme.of(context).colorScheme.primary;

//     // ✅ 서버와 동일 규칙으로 비교 (정규화된 UUID만 비교)
//     final senderId = _normalizeId(m.senderId);
//     final isMine = senderId == _meUuid;

//     final bubble = Container(
//       padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
//       constraints: const BoxConstraints(maxWidth: 280),
//       decoration: BoxDecoration(
//         color: isMine ? mainColor : Colors.grey[200],
//         borderRadius: BorderRadius.circular(12),
//       ),
//       child: Text(
//         m.content,
//         style: TextStyle(
//           color: isMine ? Colors.white : Colors.black87,
//           fontSize: 16,
//         ),
//       ),
//     );

//     return Align(
//       alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
//       child: Padding(
//         padding: const EdgeInsets.symmetric(vertical: 4),
//         child: bubble,
//       ),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     final mainColor = Theme.of(context).colorScheme.primary;

//     return Scaffold(
//       appBar: AppBar(
//         title: Text(widget.friendName),
//         backgroundColor: mainColor,
//         foregroundColor: Colors.white,
//         actions: [
//           PopupMenuButton<_MenuAction>(
//             tooltip: '더보기',
//             onSelected: _onSelectMenu,
//             itemBuilder: (context) => const [
//               PopupMenuItem(
//                 value: _MenuAction.reload,
//                 child: ListTile(
//                   leading: Icon(Icons.refresh),
//                   title: Text('새로고침'),
//                   contentPadding: EdgeInsets.zero,
//                 ),
//               ),
//               PopupMenuItem(
//                 value: _MenuAction.report,
//                 child: ListTile(
//                   leading: Icon(Icons.flag_outlined),
//                   title: Text('신고하기'),
//                   contentPadding: EdgeInsets.zero,
//                 ),
//               ),
//               PopupMenuItem(
//                 value: _MenuAction.block,
//                 child: ListTile(
//                   leading: Icon(Icons.block),
//                   title: Text('차단하기'),
//                   contentPadding: EdgeInsets.zero,
//                 ),
//               ),
//               PopupMenuDivider(),
//               PopupMenuItem(
//                 value: _MenuAction.leave,
//                 child: ListTile(
//                   leading: Icon(Icons.logout),
//                   title: Text('채팅방 나가기'),
//                   contentPadding: EdgeInsets.zero,
//                 ),
//               ),
//             ],
//           ),
//         ],
//       ),
//       body: Column(
//         children: [
//           Expanded(
//             child: _loading
//                 ? const Center(child: CircularProgressIndicator())
//                 : _error != null
//                     ? Center(
//                         child: Padding(
//                           padding: const EdgeInsets.all(16),
//                           child: Text(_error!, textAlign: TextAlign.center),
//                         ),
//                       )
//                     : ListView.builder(
//                         controller: _scroll,
//                         padding: const EdgeInsets.symmetric(
//                             horizontal: 12, vertical: 8),
//                         itemCount: _messages.length,
//                         itemBuilder: (_, i) => _buildBubble(_messages[i]),
//                       ),
//           ),
//           // 입력 영역
//           SafeArea(
//             top: false,
//             child: Row(
//               children: [
//                 const SizedBox(width: 8),
//                 // 첨부(+ 버튼)
//                 IconButton(
//                   icon: const Icon(Icons.add_circle_outline),
//                   tooltip: '첨부',
//                   onPressed: _openAttachSheet,
//                 ),
//                 Expanded(
//                   child: TextField(
//                     controller: _controller,
//                     decoration: const InputDecoration(
//                       hintText: '메시지 입력...',
//                       border: OutlineInputBorder(),
//                       isDense: true,
//                       contentPadding:
//                           EdgeInsets.symmetric(horizontal: 12, vertical: 12),
//                     ),
//                     onSubmitted: (_) => _send(),
//                   ),
//                 ),
//                 const SizedBox(width: 8),
//                 IconButton(
//                   icon: const Icon(Icons.send),
//                   onPressed: _send,
//                 ),
//                 const SizedBox(width: 6),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }



// C:\Users\82105\KU-meong Store\lib\features\friend\friend_chat_screen.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../core/chat_api.dart';
import '../../core/base_url.dart';
import 'friend_screen.dart';

class FriendChatPage extends StatefulWidget {
  final String friendName;
  final String meUserId;   // 숫자/UUID 모두 가능 → 헤더 X-User-Id용
  final String peerUserId; // URL 파라미터로만 사용

  const FriendChatPage({
    super.key,
    required this.friendName,
    required this.meUserId,
    required this.peerUserId,
  });

  @override
  State<FriendChatPage> createState() => _FriendChatPageState();
}

enum _MenuAction { reload, report, block, leave }

class _FriendChatPageState extends State<FriendChatPage> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();

  late final ChatApi _api;
  List<ChatMessageDto> _messages = [];
  bool _loading = true;
  String? _error;

  bool _fetching = false;
  DateTime? _lastFetchAt;
  bool _busyAction = false;

  // ───────────────── UUID 정규화 유틸 ─────────────────
  static final RegExp _uuidRe = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
    caseSensitive: false,
  );

  String _leftPadZeros(String s, int total) {
    final need = total - s.length;
    if (need <= 0) return s;
    final b = StringBuffer();
    for (var i = 0; i < need; i++) {
      b.writeCharCode(48); // '0'
    }
    b.write(s);
    return b.toString();
  }

  String _normalizeId(Object? raw) {
    final s = (raw ?? '').toString().trim();
    if (s.isEmpty) return '';
    if (_uuidRe.hasMatch(s)) return s.toLowerCase();

    // 숫자만 추출
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

  late final String _meUuid;   // 정규화된 내 ID
  late final String _peerUuid; // 정규화된 상대 ID

  @override
  void initState() {
    super.initState();

    _meUuid = _normalizeId(widget.meUserId);
    _peerUuid = _normalizeId(widget.peerUserId);

    // 자기 자신 채팅 가드(설계상 없지만 혹시 대비)
    if (_meUuid.isEmpty || _peerUuid.isEmpty || _meUuid == _peerUuid) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('자기 자신과는 대화를 시작할 수 없어요.')),
        );
        Navigator.of(context).maybePop();
      });
      return;
    }

    _api = ChatApi(baseUrl: apiBaseUrl(), meUserId: _meUuid);
    _loadInitial();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _loadInitial() async {
    if (_fetching) return;

    final now = DateTime.now();
    if (_lastFetchAt != null &&
        now.difference(_lastFetchAt!) < const Duration(milliseconds: 500)) {
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
      final fetched = await _api.fetchMessagesWithPeer(_peerUuid);
      fetched.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      if (mounted) {
        setState(() => _messages = fetched);
      }

      await Future.delayed(const Duration(milliseconds: 20));
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }

      // 내가 받은 메시지들은 읽음 처리(실패해도 무시)
      if (_messages.isNotEmpty) {
        _api.markReadUpTo(_peerUuid, _messages.last.id).catchError((_) {});
      }
    } catch (e) {
      if (mounted) {
        setState(() =>
            _error = '메시지 불러오기 실패: $e\n(me=$_meUuid, peer=$_peerUuid)');
      }
    } finally {
      _fetching = false;
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();

    try {
      // 저장된 메시지(대개 readByPeer=false/null)를 즉시 append
      final saved = await _api.sendToPeer(_peerUuid, text);
      if (mounted) {
        setState(() => _messages.add(saved));
      }

      await Future.delayed(const Duration(milliseconds: 20));
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }

      // 선택: 보낸 뒤에도 내 쪽 읽음 커서를 업데이트(무시 가능)
      _api.markReadUpTo(_peerUuid, saved.id).catchError((_) {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('메시지 전송 실패: $e')),
      );
    }
  }

  // ====== 상단 더보기 메뉴 처리 ======
  Future<void> _onSelectMenu(_MenuAction action) async {
    if (_busyAction) return;
    switch (action) {
      case _MenuAction.reload:
        await _loadInitial();
        break;
      case _MenuAction.report:
        await _reportPeer();
        break;
      case _MenuAction.block:
        await _blockPeer();
        break;
      case _MenuAction.leave:
        final ok = await _confirm(
          title: '채팅방 나가기',
          message: '이 대화방의 전체 대화 내용이 삭제됩니다.\n정말 나가시겠어요?',
          confirmText: '나가기',
        );
        if (ok == true) {
          await _leaveChat();
        }
        break;
    }
  }

  bool _ok(int s) => s >= 200 && s < 300;

  Future<void> _reportPeer() async {
    if (_busyAction) return;
    _busyAction = true;
    try {
      final url = Uri.parse('${apiBaseUrl()}/chats/$_peerUuid/report');
      final r = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'X-User-Id': _meUuid,
        },
        body: '{"reason":"abuse"}',
      );
      if (_ok(r.statusCode)) {
        _toast('신고가 접수되었습니다.');
      } else {
        _toast('신고 실패 (${r.statusCode})');
      }
    } catch (e) {
      _toast('신고 중 오류: $e');
    } finally {
      _busyAction = false;
    }
  }

  Future<void> _blockPeer() async {
    if (_busyAction) return;
    _busyAction = true;
    try {
      final url = Uri.parse('${apiBaseUrl()}/chats/$_peerUuid/block');
      final r = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'X-User-Id': _meUuid,
        },
      );
      if (_ok(r.statusCode)) {
        _toast('상대가 차단되었습니다.');
      } else {
        _toast('차단 실패 (${r.statusCode})');
      }
    } catch (e) {
      _toast('차단 중 오류: $e');
    } finally {
      _busyAction = false;
    }
  }

  Future<void> _leaveChat() async {
    if (_busyAction) return;
    _busyAction = true;
    try {
      final url = Uri.parse('${apiBaseUrl()}/chats/$_peerUuid');
      final r = await http.delete(
        url,
        headers: {'X-User-Id': _meUuid},
      );
      if (_ok(r.statusCode)) {
        if (mounted) setState(() => _messages.clear());
        _toast('채팅방을 나갔습니다.');
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (_) => FriendScreen(meUserId: widget.meUserId),
            ),
            (route) => false,
          );
        }
      } else {
        _toast('채팅방 나가기 실패 (${r.statusCode})');
      }
    } catch (e) {
      _toast('채팅방 나가기 중 오류: $e');
    } finally {
      _busyAction = false;
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

  // ======================

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // 🔎 내 메시지가 아직 "상대가 안 읽음"인지 판별
  bool _isUnreadByPeer(ChatMessageDto m) {
    final senderId = _normalizeId(m.senderId);
    final isMine = senderId == _meUuid;
    if (!isMine) return false;
    // readByPeer == true 이면 읽음, 그 외(null/false)는 "안 읽음"
    return !(m.readByPeer ?? false);
  }

  // 💬 말풍선 + (내 메시지일 때) 왼쪽에 '1' 뱃지
  Widget _buildBubble(ChatMessageDto m) {
    final mainColor = Theme.of(context).colorScheme.primary;

    final senderId = _normalizeId(m.senderId);
    final isMine = senderId == _meUuid;
    final unreadByPeer = _isUnreadByPeer(m);

    final bubble = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      constraints: const BoxConstraints(maxWidth: 280),
      decoration: BoxDecoration(
        color: isMine ? mainColor : Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        m.content,
        style: TextStyle(
          color: isMine ? Colors.white : Colors.black87,
          fontSize: 16,
        ),
      ),
    );

    // 카톡 스타일: 내 메시지 줄의 "왼쪽"에 1
    if (isMine) {
      return Align(
        alignment: Alignment.centerRight,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (unreadByPeer)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Text(
                    '1',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blueGrey.shade600,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              bubble,
            ],
          ),
        ),
      );
    }

    // 상대 메시지는 그대로
    return Align(
      alignment: Alignment.centerLeft,
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
              PopupMenuItem(
                value: _MenuAction.report,
                child: ListTile(
                  leading: Icon(Icons.flag_outlined),
                  title: Text('신고하기'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: _MenuAction.block,
                child: ListTile(
                  leading: Icon(Icons.block),
                  title: Text('차단하기'),
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
      body: Column(
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
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
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
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  tooltip: '첨부',
                  onPressed: () {
                    // 필요시 첨부 시트 다시 연결
                  },
                ),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: '메시지 입력...',
                      border: OutlineInputBorder(),
                      isDense: true,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
    );
  }
}
