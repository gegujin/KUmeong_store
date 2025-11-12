// lib/features/mypage/heart_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:kumeong_store/api_service.dart'; // fetchMyFavoriteItems, toggleFavoriteDetailed, fetchProductById
import 'package:kumeong_store/models/post.dart'; // Product + extension toMapForHome()
import 'package:kumeong_store/core/router/route_names.dart' as R;
import 'package:kumeong_store/state/favorites_store.dart'; // FavoritesStore

class HeartPage extends StatefulWidget {
  const HeartPage({super.key});

  @override
  State<HeartPage> createState() => _HeartPageState();
}

class _HeartPageState extends State<HeartPage> {
  final FavoritesStore favStore = FavoritesStore.instance;

  bool _loading = true;
  bool _syncing = false; // ✅ 로딩/동기화 중 가드
  String? _error;

  /// Home과 동일한 카드 데이터 형태를 유지하는 리스트
  /// - id, title, imageUrls/thumbnailUrl, location/locationText, time, price/priceWon, views
  /// - isFavorited, favoriteCount
  List<Map<String, dynamic>> _items = [];

  late final VoidCallback _favListener;

  // -------------------------------
  // Home과 동일한 표시 유틸
  // -------------------------------
  String _formatWon(dynamic v) {
    final n = (v is num) ? v.toInt() : int.tryParse('$v') ?? 0;
    return '${n.toString()}원';
  }

  int _asInt(dynamic v, {int fallback = 0}) {
    if (v is num) return v.toInt();
    if (v is String && v.isNotEmpty) {
      return int.tryParse(v.replaceAll(RegExp(r'[, ]'), '')) ?? fallback;
    }
    return fallback;
  }

  // -------------------------------
  // 데이터 로딩
  // -------------------------------
  @override
  void initState() {
    super.initState();
    _loadFavorites();
    _favListener = _onFavChanged;
    favStore.addListener(_favListener);
  }

  @override
  void dispose() {
    favStore.removeListener(_favListener);
    super.dispose();
  }

  Future<void> _loadFavorites() async {
    setState(() {
      _loading = true;
      _error = null;
      _syncing = true; // ✅ 리스너 차단
    });

    try {
      // 서버 limit과 통일(응답이 100이면 100으로 통일 추천)
      final products = await fetchMyFavoriteItems(page: 1, limit: 100);

      // 1) 서버 기준으로 Store 갱신 (리스너는 _syncing으로 무시됨)
      favStore.replaceAll(products);

      // 2) 덮어쓰기 + dedupe
      final seen = <String>{};
      final mapped = <Map<String, dynamic>>[];
      for (final p in products) {
        final m = p.toMapForHome();
        final imgList = (m['imageUrls'] is List)
            ? List<String>.from(m['imageUrls'])
            : const <String>[];
        final thumb = (m['thumbnailUrl'] as String?) ??
            (imgList.isNotEmpty ? imgList.first : null);

        final id = (m['id'] ?? '') as String;
        if (id.isEmpty || !seen.add(id)) continue;

        mapped.add({
          ...m,
          'imageUrls': imgList,
          'thumbnailUrl': thumb,
          'price': m['price'] ?? m['priceWon'] ?? 0,
          'location': m['location'] ?? m['locationText'] ?? '위치 정보 없음',
          'isFavorited': true,
          'favoriteCount': favStore.counts[id] ?? p.favoriteCount ?? 0,
        });
      }

      setState(() {
        _items = mapped; // ✅ 항상 갈아끼우기
      });
    } catch (e) {
      setState(() {
        _error = '관심목록을 불러오지 못했어요: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _syncing = false; // ✅ 리스너 재개
        });
      }
    }
  }

  /// 스토어가 변하면 즉시 UI에 반영:
  /// - 제거된 id는 카드에서 제거
  /// - 추가된 id는 fetchProductById로 단건 조회 후 카드 추가
  Future<void> _onFavChanged() async {
    if (!mounted) return;
    if (_syncing) return; // ✅ 로딩/동기화 중엔 스킵

    final have =
        _items.map((e) => e['id'] as String?).whereType<String>().toSet();
    final want = favStore.favoriteIds;

    // 제거
    final toRemove = have.difference(want);
    if (toRemove.isNotEmpty) {
      setState(() {
        _items.removeWhere((e) => toRemove.contains(e['id']));
      });
    }

    // 추가
    final toAdd = want.difference(have);
    for (final id in toAdd) {
      // ✅ 혹시 사이에 들어왔으면 스킵
      if (_items.any((e) => e['id'] == id)) continue;

      final p = await fetchProductById(id);
      if (p == null) continue;
      final m = p.toMapForHome();
      final imgList = (m['imageUrls'] is List)
          ? List<String>.from(m['imageUrls'])
          : const <String>[];
      final thumb = (m['thumbnailUrl'] as String?) ??
          (imgList.isNotEmpty ? imgList.first : null);
      final map = {
        ...m,
        'imageUrls': imgList,
        'thumbnailUrl': thumb,
        'price': m['price'] ?? m['priceWon'] ?? 0,
        'location': m['location'] ?? m['locationText'] ?? '위치 정보 없음',
        'isFavorited': true,
        'favoriteCount': favStore.counts[id] ?? 0,
      };

      if (!mounted) return;
      // ✅ 최종 삽입 직전에도 한 번 더 체크
      if (_items.any((e) => e['id'] == id)) continue;

      setState(() {
        _items.insert(0, map);
      });
    }
  }

  // -------------------------------
  // 토글 (Home와 동일한 낙관적 흐름 + 관심목록에서는 false면 즉시 제거)
  // -------------------------------
  Future<void> _toggleFavorite(String productId) async {
    if (productId.isEmpty) return;

    // 연타 방지
    if (favStore.isPending(productId)) return;

    // 현재 카드의 집계값을 스토어 기준으로 읽어 낙관적 처리
    final prevFav = favStore.favoriteIds.contains(productId);
    final idx = _items.indexWhere((e) => e['id'] == productId);
    final prevCnt = favStore.counts[productId] ??
        (idx >= 0 ? _asInt(_items[idx]['favoriteCount'] ?? 0) : 0);

    // 낙관적 반영
    favStore.toggleOptimistic(
      productId,
      currentFavorited: prevFav,
      currentCount: prevCnt,
    );

    if (!mounted) return;
    setState(() {});

    try {
      final res = await toggleFavoriteDetailed(
        productId,
        currentlyFavorited: prevFav,
      );
      favStore.applyServer(
        productId,
        isFavorited: res.isFavorited,
        favoriteCount: res.favoriteCount,
      );

      // 관심목록 페이지: 언찜되면 즉시 목록에서 제거
      if (!res.isFavorited) {
        setState(() => _items.removeWhere((e) => e['id'] == productId));
      } else {
        // 찜 유지 시 카드의 집계 숫자도 갱신
        setState(() {
          final idx = _items.indexWhere((e) => e['id'] == productId);
          if (idx >= 0) {
            _items[idx]['favoriteCount'] =
                favStore.counts[productId] ?? res.favoriteCount ?? prevCnt;
          }
        });
      }
    } catch (e) {
      // 실패 → 롤백
      favStore.rollback(
        productId,
        previousFavorited: prevFav,
        previousCount: prevCnt,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text('$e' == 'Exception: 401' ? '로그인이 필요합니다.' : '찜 토글 실패: $e')),
      );
      setState(() {});
    }
  }

  // -------------------------------
  // UI (Home의 리스트 아이템과 동일한 구성)
  // -------------------------------
  @override
  Widget build(BuildContext context) {
    final mainColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: mainColor,
        title: const Text('관심목록', style: TextStyle(color: Colors.white)),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : AnimatedBuilder(
                  animation: favStore,
                  builder: (_, __) {
                    // 스토어 상태와 병합하여 Home과 동일한 표시값 구성
                    final list = _items
                        .map((p) => {
                              ...p,
                              'isFavorited':
                                  favStore.favoriteIds.contains(p['id']),
                              'favoriteCount': _asInt(
                                favStore.counts[p['id']] ??
                                    p['favoriteCount'] ??
                                    p['likes'] ??
                                    0,
                              ),
                            })
                        .toList();

                    if (list.isEmpty) {
                      return const Center(child: Text('하트한 상품이 없어요.'));
                    }

                    return RefreshIndicator(
                      onRefresh: _loadFavorites,
                      child: ListView.builder(
                        padding: const EdgeInsets.only(bottom: 120),
                        itemCount: list.length,
                        itemBuilder: (_, index) {
                          final product = list[index];
                          final liked =
                              (product['isFavorited'] ?? false) as bool;

                          // 이미지: thumbnailUrl → imageUrls[0]
                          final imageUrl = product['thumbnailUrl'] ??
                              ((product['imageUrls'] != null &&
                                      (product['imageUrls'] as List).isNotEmpty)
                                  ? (product['imageUrls'] as List).first
                                  : null);

                          final title = product['title'] as String? ?? '';

                          // 위치: location → locationText → 기본
                          String location = '';
                          final lv = product['location'];
                          if (lv is String && lv.isNotEmpty) {
                            location = lv;
                          } else if ((product['locationText']
                                  ?.toString()
                                  .isNotEmpty ??
                              false)) {
                            location = product['locationText'];
                          } else {
                            location = '위치 정보 없음';
                          }

                          final time = product['time'] as String? ?? '';

                          // 가격: price → priceWon → 라벨 (Home 동일)
                          final priceLabel = _formatWon(
                              product['price'] ?? product['priceWon'] ?? 0);

                          return InkWell(
                            onTap: () {
                              final id = product['id'] as String? ?? '';
                              if (id.isEmpty) return;
                              context.pushNamed(
                                R.RouteNames.productDetail,
                                pathParameters: {'productId': id},
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: imageUrl != null
                                        ? Image.network(
                                            imageUrl,
                                            width: 100,
                                            height: 100,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) =>
                                                Container(
                                              width: 100,
                                              height: 100,
                                              color: Colors.grey[300],
                                              child: const Icon(
                                                  Icons.broken_image,
                                                  color: Colors.white70),
                                            ),
                                          )
                                        : Container(
                                            width: 100,
                                            height: 100,
                                            color: Colors.grey[300],
                                            child: const Icon(Icons.image,
                                                color: Colors.white70),
                                          ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          '$location | $time',
                                          style: const TextStyle(
                                            color: Colors.grey,
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text.rich(
                                              TextSpan(
                                                children: [
                                                  const TextSpan(text: '가격 '),
                                                  TextSpan(
                                                    text: priceLabel,
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Text(
                                              '찜 ${product['favoriteCount'] ?? product['likes'] ?? 0}  조회수 ${product['views'] ?? 0}',
                                              style: const TextStyle(
                                                  color: Colors.grey),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Align(
                                          alignment: Alignment.centerRight,
                                          child: GestureDetector(
                                            onTap: () {
                                              final id =
                                                  product['id'] as String? ??
                                                      '';
                                              if (id.isEmpty) return;
                                              _toggleFavorite(id);
                                            },
                                            child: Icon(
                                              liked
                                                  ? Icons.favorite
                                                  : Icons.favorite_border,
                                              color: liked
                                                  ? Colors.red
                                                  : Colors.grey,
                                              size: 22,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
    );
  }
}
