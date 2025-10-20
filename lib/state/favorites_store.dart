// lib/state/favorites_store.dart
import 'dart:convert'; // ✅ jsonEncode / jsonDecode 사용
import 'package:flutter/foundation.dart';
import 'package:kumeong_store/api_service.dart';
import 'package:kumeong_store/models/post.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
      await sp.setString(_kFavCounts, _encodeCounts(counts));
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

  // ✅ JSON 안전 인코딩
  String _encodeCounts(Map<String, int> m) => jsonEncode(m);
  Map<String, int> _decodeCounts(String? s) {
    if (s == null || s.isEmpty) return {};
    try {
      final map = Map<String, dynamic>.from(jsonDecode(s));
      return map.map((k, v) => MapEntry(k, (v is num) ? v.toInt() : 0));
    } catch (_) {
      return {};
    }
  }

  /// 앱 시작 시 1회 서버에서 즐겨찾기 목록을 끌어와 seed
  Future<void> initFromServerOnce() async {
    if (_inited) return;
    // 1) 로컬 seed (새로고침 직후 0으로 보이지 않게)
    await loadFromStorage();
    notifyListeners();
    // 2) 서버 최신 반영(되면 로컬 저장으로 덮어씀)
    await refreshFromServer();
    _inited = true;
  }

  /// 서버에서 관심목록을 다시 읽어들여 store를 통째로 교체
  Future<void> refreshFromServer() async {
    final items = await fetchMyFavoriteItems(page: 1, limit: 200); // 필요 시 늘리기
    replaceAll(items);
  }

  /// 외부에서 받은 Product 리스트로 store를 통째로 교체
  void replaceAll(List<Product> products) {
    favoriteIds
      ..clear()
      ..addAll(products.map((e) => e.id));
    counts
      ..clear()
      ..addAll({
        for (final p in products)
          p.id: (p.favoriteCount is int ? p.favoriteCount : 0) ?? 0
      });
    notifyListeners();
    _saveToStorage(); // 저장
  }

  /// 낙관적 토글 적용 (현재 상태/카운트를 기준으로 미리 반영)
  /// - 연타/중복 액션이면 무시
  /// - 반환값: 적용된 nextFavorited
  bool toggleOptimistic(String id,
      {required bool currentFavorited, required int currentCount}) {
    if (isPending(id)) return currentFavorited; // 이미 요청 중이면 무시
    _markPending(id);

    final next = !currentFavorited;
    if (next) {
      favoriteIds.add(id);
      counts[id] = (currentCount) + 1;
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
}
