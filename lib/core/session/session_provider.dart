// lib/core/session/session_provider.dart
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:kumeong_store/core/network/http_client.dart'; // HttpX

/// 세션 스테이트
class SessionState {
  final String? token; // HttpX가 SharedPreferences에서 읽어가는 토큰
  final Map<String, dynamic>? me;

  const SessionState({this.token, this.me});

  bool get isAuthed => (token != null && token!.isNotEmpty) && me != null;

  /// 레거시 호환: { token | accessToken, me }
  factory SessionState.fromJson(Map<String, dynamic> j) {
    final t = (j['token'] ?? j['accessToken']) as String?;
    final me = j['me'] is Map<String, dynamic> ? j['me'] as Map<String, dynamic> : null;
    return SessionState(token: t, me: me);
  }

  /// ✅ dual-write: accessToken과 token을 함께 기록해 HttpX 호환 보장
  Map<String, dynamic> toJson() => {
        'accessToken': token,
        'token': token,
        'me': me,
      };

  SessionState copyWith({String? token, Map<String, dynamic>? me}) =>
      SessionState(token: token ?? this.token, me: me ?? this.me);
}

/// Riverpod v3: Notifier 기반
class SessionNotifier extends Notifier<SessionState> {
  bool _initialized = false;

  @override
  SessionState build() {
    if (!_initialized) {
      _initialized = true;
      // 비동기 복원
      Future.microtask(loadFromStorage);
    }
    return const SessionState();
  }

  /// 앱 부팅 시 저장된 토큰 복원 후 /auth/me 검증
  Future<void> loadFromStorage() async {
    final sp = await SharedPreferences.getInstance();

    // v1(JSON) 우선
    final raw = sp.getString('session.v1');
    if (raw != null && raw.isNotEmpty) {
      try {
        final j = jsonDecode(raw) as Map<String, dynamic>;
        final s = SessionState.fromJson(j);
        final tok = s.token;
        if (tok != null && tok.isNotEmpty) {
          await setTokenAndFetchMe(tok);
          return;
        }
      } catch (_) {
        // 손상된 JSON은 무시
      }
    }

    // 레거시 단일 키(accessToken)
    final legacy = sp.getString('accessToken');
    if (legacy != null && legacy.isNotEmpty) {
      await setTokenAndFetchMe(legacy);
    }
  }

  /// 로그인 직후: 토큰 저장 → /auth/me 로 내 정보 로드 → 세션 확정
  Future<void> setTokenAndFetchMe(String token) async {
    // 1) 저장 (HttpX는 SharedPreferences에서 토큰을 자동 로드함)
    await _saveTokenOnly(token);

    // 2) /auth/me 호출로 me 로드 (서버 스키마: {user} 또는 {data} 또는 루트)
    Map<String, dynamic> me;
    try {
      final j = await HttpX.get('/auth/me'); // withAuth=true 기본
      me = _extractMe(j);
    } catch (e) {
      await signOut();
      rethrow;
    }

    // 3) 메모리 반영
    state = SessionState(token: token, me: me);

    // 4) 로컬 저장 (v1 JSON 단일화)
    await _saveFullSession(state);

    // 레거시 키 정리(선택): 개별 accessToken 키는 제거하되,
    // session.v1 내부에는 accessToken 필드를 유지하므로 HttpX와 호환됨.
    final sp = await SharedPreferences.getInstance();
    await sp.remove('accessToken');
  }

  /// me만 갱신
  Future<void> refreshMe() async {
    final tok = state.token;
    if (tok == null || tok.isEmpty) return;
    try {
      final j = await HttpX.get('/auth/me');
      final me = _extractMe(j);
      state = state.copyWith(me: me);
      await _saveFullSession(state);
    } catch (_) {
      // 실패해도 세션은 유지 (정책에 따라 signOut으로 바꿀 수 있음)
    }
  }

  /// 로그아웃(로컬 정리)
  Future<void> signOut() async {
    state = const SessionState();
    final sp = await SharedPreferences.getInstance();
    await sp.remove('session.v1');
    await sp.remove('accessToken'); // 레거시 키 정리
  }

  // ───────────────────────── 내부 헬퍼 ─────────────────────────

  Future<void> _saveTokenOnly(String token) async {
    final sp = await SharedPreferences.getInstance();
    // ✅ dual-write: HttpX._loadToken()이 어떤 키를 읽어도 되게 보장
    await sp.setString(
        'session.v1',
        jsonEncode({
          'accessToken': token,
          'token': token,
        }));
  }

  Future<void> _saveFullSession(SessionState s) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString('session.v1', jsonEncode(s.toJson()));
  }

  Map<String, dynamic> _extractMe(Map<String, dynamic> j) {
    // 서버 응답 케이스: { ok, user:{...} } | { ok, data:{...} } | { ... }
    final raw = (j['user'] ?? j['data'] ?? j);
    if (raw is Map<String, dynamic>) return raw;
    // 안전망: 타입이 다르면 빈 맵
    return <String, dynamic>{};
  }
}

/// Provider
final NotifierProvider<SessionNotifier, SessionState> sessionProvider =
    NotifierProvider<SessionNotifier, SessionState>(SessionNotifier.new);
