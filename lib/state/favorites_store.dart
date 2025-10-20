// lib/state/favorites_store.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kumeong_store/api_service.dart';

class FavoritesStore extends ChangeNotifier {
  FavoritesStore._();
  static final FavoritesStore instance = FavoritesStore._();

  /// 현재 사용자의 즐겨찾기 상품 id 집합
  final Set<String> favoriteIds = <String>{};

  /// 각 상품의 즐겨찾기 카운트
  final Map<String, int> counts = <String, int>{};

  /// 연타/중복요청 방지용
  final Set<String> _pending = <String>{};

  bool isPending(String id) => _pending.contains(id);
  void _markPending(String id) => _pending.add(id);
  void _clearPending(String id) => _pending.remove(id);

  bool _inited = false;

  // --------- 영속 키 ----------
  static const _kFavIds = 'fav_ids';
  static const _kFavCounts = 'fav_counts_json';

  Future<void> _saveToStorage() async {
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setStringList(_kFavIds, favoriteIds.toList());
      await sp.setString(_kFavCounts, jsonEncode(counts)); // 안전 인코딩
    } catch (_) {}
  }

  Future<void> loadFromStorage() async {
    try {
      final sp = await SharedPreferences.getInstance();
      final ids = sp.getStringList(_kFavIds) ?? const <String>[];
      final cntJson = sp.getString(_kFavCounts);
      final cnts = _decodeCounts(cntJson);
      favoriteIds
        ..clear()
        ..addAll(ids);
      counts
        ..clear()
        ..addAll(cnts);
      notifyListeners();
    } catch (_) {}
  }

  Map<String, int> _decodeCounts(String? s) {
    if (s == null || s.isEmpty) return {};
    try {
      final decoded = jsonDecode(s);
      if (decoded is Map) {
        final map = Map<String, dynamic>.from(decoded);
        return map.map((k, v) => MapEntry(k, (v is num) ? v.toInt() : 0));
      }
      return {};
    } catch (_) {
      return {};
    }
  }

  /// 앱 시작 시 1회 서버에서 즐겨찾기 목록을 끌어와 seed
  Future<void> initFromServerOnce() async {
    if (_inited) return;
    await loadFromStorage();
    try {
      await refreshFromServer();
    } catch (_) {
      // 서버 실패여도 앱은 계속 동작
    } finally {
      _inited = true;
    }
    // 1) 로컬 seed (새로고침 직후 0으로 보이지 않게)
    await loadFromStorage();
    notifyListeners();
    // 2) 서버 최신 반영(되면 로컬 저장으로 덮어씀)
    await refreshFromServer();
    _inited = true;
  }

  /// 서버에서 관심목록을 다시 읽어들여 store를 통째로 교체
  Future<void> refreshFromServer() async {
    try {
      final List<dynamic> items =
          await fetchMyFavoriteItems(page: 1, limit: 200); // 필요 시 확장
      replaceAll(items);
    } catch (e) {
      debugPrint('[FavoritesStore] refreshFromServer failed: $e');
    }
  }

  /// 외부에서 받은 리스트로 store를 통째로 교체 (모델/Map 모두 허용)
  void replaceAll(List<dynamic> items) {
    final ids = <String>[];
    final cnt = <String, int>{};

    for (final it in items) {
      final id = _idOf(it);
      if (id == null || id.isEmpty) continue;
      ids.add(id);
      cnt[id] = _favoriteCountOf(it);
    }

    favoriteIds
      ..clear()
      ..addAll(ids);

    counts
      ..clear()
      ..addAll(cnt);

    notifyListeners();
    _saveToStorage();
  }

  /// 낙관적 토글 적용 (현재 상태/카운트를 기준으로 미리 반영)
  /// - 연타/중복 액션이면 기존 상태 그대로 반환
  /// - 반환값: 적용된 nextFavorited
  bool toggleOptimistic(String id,
      {required bool currentFavorited, required int currentCount}) {
    if (isPending(id)) return currentFavorited; // 이미 요청 중이면 무시
    _markPending(id);

    final next = !currentFavorited;
    if (next) {
      favoriteIds.add(id);
      counts[id] = currentCount + 1;
    } else {
      favoriteIds.remove(id);
      counts[id] = (currentCount > 0 ? currentCount - 1 : 0);
    }
    notifyListeners();
    _saveToStorage();
    return next;
  }

  /// 서버 응답으로 최종 확정. 카운트는 **치환**만!
  void applyServer(String id, {required bool isFavorited, int? favoriteCount}) {
    _clearPending(id);

    if (isFavorited) {
      favoriteIds.add(id);
    } else {
      favoriteIds.remove(id);
    }
    if (favoriteCount != null) {
      counts[id] = favoriteCount; // 덮어쓰기(+= 금지)
    }
    notifyListeners();
    _saveToStorage();
  }

  /// 실패 → 기존 값으로 롤백
  void rollback(String id,
      {required bool previousFavorited, required int previousCount}) {
    _clearPending(id);

    if (previousFavorited) {
      favoriteIds.add(id);
    } else {
      favoriteIds.remove(id);
    }
    counts[id] = previousCount;
    notifyListeners();
    _saveToStorage();
  }

  // ───────────── 퍼블릭 헬퍼 (UI에서 사용하기 쉬운 형태) ─────────────

  bool isFavOf(String id) => favoriteIds.contains(id);
  int favCountOf(String id) => counts[id] ?? 0;

  /// 전체 토글(낙관적→서버확정/실패 롤백 포함)
  // lib/state/favorites_store.dart — toggle() 교체
  Future<void> toggle(String id) async {
    final prevFavorited = isFavOf(id);
    final prevCount = favCountOf(id);

    // 1) 낙관적 적용
    final nextFavorited = toggleOptimistic(
      id,
      currentFavorited: prevFavorited,
      currentCount: prevCount,
    );

    try {
      // 2) 서버 호출 (반환형이 record/Map/dynamic/nullable 여도 안전하게 처리)
      final dynamic r = await toggleFavoriteById(id);

      // ok 추출 (nullable/Map/dynamic 모두 커버)
      final bool ok = (r is Map) ? (r['ok'] == true) : (r?.ok == true) == true;

      if (!ok) {
        // 서버가 실패면 롤백
        rollback(id,
            previousFavorited: prevFavorited, previousCount: prevCount);
        return;
      }

      // isFavorite 추출 (키 다양한 경우 대비)
      final bool isFav = (r is Map)
          ? (r['isFavorite'] == true || r['fav'] == true || r['liked'] == true)
          : (r?.isFavorite == true) ?? nextFavorited;

      // favoriteCount 추출 (num -> int 변환 + 안전 기본값)
      int favCnt;
      if (r is Map) {
        final dyn = (r['favoriteCount'] ?? r['favorites'] ?? r['count']);
        favCnt = (dyn is num)
            ? dyn.toInt()
            : (isFav ? prevCount + 1 : (prevCount > 0 ? prevCount - 1 : 0));
      } else {
        final dyn = r?.favoriteCount;
        favCnt = (dyn is num)
            ? dyn.toInt()
            : (isFav ? prevCount + 1 : (prevCount > 0 ? prevCount - 1 : 0));
      }

      // 3) 서버값으로 확정 반영
      applyServer(id, isFavorited: isFav, favoriteCount: favCnt);
    } catch (_) {
      // 네트워크/예외 → 롤백
      rollback(id, previousFavorited: prevFavorited, previousCount: prevCount);
    }
  }

  // ───────────── 헬퍼: 모델 독립 필드 추출 ─────────────

  /// 다양한 모델(Map/Object)에 대해 id 추출
  String? _idOf(dynamic item) {
    if (item == null) return null;

    if (item is Map) {
      final m = Map<String, dynamic>.from(item);
      final v =
          (m['id'] ?? m['productId'] ?? m['postId'] ?? m['uuid'] ?? m['slug']);
      return v?.toString();
    }

    try {
      final d = item as dynamic;
      final v = (d.id ?? d.productId ?? d.postId ?? d.uuid ?? d.slug);
      return v?.toString();
    } catch (_) {
      return null;
    }
  }

  /// 다양한 키로 favorite count 추출
  int _favoriteCountOf(dynamic item) {
    if (item == null) return 0;

    if (item is Map) {
      final m = Map<String, dynamic>.from(item);
      return _safeInt(m['favoriteCount'] ??
          m['favorites'] ??
          m['favorite_cnt'] ??
          m['likeCount'] ??
          m['likes'] ??
          m['favCount']);
    }

    try {
      final d = item as dynamic;
      final v = (d.favoriteCount ??
          d.favorites ??
          d.favorite_cnt ??
          d.likeCount ??
          d.likes ??
          d.favCount);
      return _safeInt(v);
    } catch (_) {
      return 0;
    }
  }

  /// 어떤 타입이 와도 안전하게 int로 변환
  int _safeInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) {
      final parsed = int.tryParse(v);
      if (parsed != null) return parsed;
      final asDouble = double.tryParse(v);
      if (asDouble != null) return asDouble.toInt();
    }
    return 0;
  }
}
