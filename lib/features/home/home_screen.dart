// C:\KUmung_store\lib\features\home\home_screen.dart
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kumeong_store/core/ui/hero_tags.dart';
import 'package:kumeong_store/core/router/route_names.dart' as R;
import 'package:kumeong_store/core/widgets/app_bottom_nav.dart'; // 쓰면 유지, 안 쓰면 제거해도 됨
import '../../core/theme.dart';
import '../../api_service.dart';
import 'package:kumeong_store/state/favorites_store.dart';
import 'package:kumeong_store/utils/storage.dart'; // ★ 토큰 단일 소스
import 'package:http/http.dart' as http;
import 'package:kumeong_store/models/post.dart'; // Product + toMapForHome()
import 'dart:convert'; // ← jsonDecode 사용

const String _apiBase = 'http://localhost:3000/api/v1';
const Color kuInfo = Color(0xFF147AD6);

// ✅ 로컬 데모 상품 (홈 카드 맵 포맷)
const Map<String, dynamic> kDemoProduct = {
  'id': 'demo-product',
  'title': '데모 상품',
  'imageUrls': <String>[],
  'location': '위치 정보 없음',
  'time': '',
  'price': 0,
  'isFavorited': false,
  'favoriteCount': 0,
  'views': 0,
};

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> allProducts = [];
  String searchText = '';
  bool _isMenuOpen = false;
  String? token;
  final FavoritesStore favStore = FavoritesStore.instance;

  @override
  void initState() {
    super.initState();
    // 즐겨찾기 초기화(서버에서 1회 seed) -> 목록 로딩
    favStore.initFromServerOnce().whenComplete(_loadTokenAndProducts);
  }

  // =========================
  // ✅ 헬퍼들
  // =========================
  int _asInt(dynamic v, {int fallback = 0}) {
    if (v is num) return v.toInt();
    if (v is String && v.isNotEmpty) {
      return int.tryParse(v.replaceAll(RegExp(r'[, ]'), '')) ?? fallback;
    }
    return fallback;
  }

  String? _absUrl(String? p) {
    if (p == null || p.isEmpty) return null;
    if (p.startsWith('http')) return p;
    if (p.startsWith('/uploads/')) return 'http://localhost:3000$p';
    return p;
  }

  String _formatWon(dynamic v) {
    final n = (v is num) ? v.toInt() : int.tryParse('$v') ?? 0;
    return '${n.toString()}원';
  }

  String _relativeTime(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    DateTime? dt;
    try {
      dt = DateTime.parse(iso).toLocal();
    } catch (_) {}
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return '방금 전';
    if (diff.inHours < 1) return '${diff.inMinutes}분 전';
    if (diff.inDays < 1) return '${diff.inHours}시간 전';
    return '${diff.inDays}일 전';
  }

  Map<String, dynamic> _normalizeServerProduct(Map<String, dynamic> p) {
    List<String> images = [];
    final rawImages = p['images'] ?? p['imageUrls'] ?? [];
    if (rawImages is List) {
      images = rawImages.map((e) => _absUrl('$e')).whereType<String>().toList();
    } else if (rawImages is String) {
      final a = _absUrl(rawImages);
      if (a != null) images = [a];
    }
    final thumb = _absUrl(p['thumbnailUrl']?.toString()) ??
        (images.isNotEmpty ? images.first : null);

    final loc =
        p['location'] ?? p['locationText'] ?? p['seller']?['locationName'];
    final price = p['price'] ?? p['priceWon'] ?? 0;

    return {
      'id': p['id'] ?? p['_id'] ?? '',
      'title': p['title'] ?? '',
      'imageUrls': images,
      'thumbnailUrl': thumb,
      'location': (loc is String && loc.isNotEmpty) ? loc : '위치 정보 없음',
      'time': _relativeTime(p['createdAt']?.toString()),
      'price': price,
      'favoriteCount':
          _asInt(p['favoriteCount'] ?? p['favCount'] ?? p['likes'] ?? 0),
      'views': p['views'] ?? 0,
      'isFavorited': p['isFavorited'] == true,
    };
  }

  Future<List<Map<String, dynamic>>> _fetchProductsRaw(String? token) async {
    final uri = Uri.parse('$_apiBase/products');
    final res = await http.get(uri, headers: {
      if (token != null) 'Authorization': 'Bearer $token',
    });
    if (res.statusCode < 200 || res.statusCode >= 300) {
      debugPrint('fallback fetch failed: ${res.statusCode} ${res.body}');
      return [];
    }
    final json = jsonDecode(res.body);
    final data = json['data'];
    final list = (data is Map && data['items'] is List)
        ? data['items'] as List
        : (data is List ? data : []);
    return list
        .whereType<Map>()
        .map((m) => _normalizeServerProduct(m.cast<String, dynamic>()))
        .toList();
  }

  // ✅ 토큰 + 상품 로드
  Future<void> _loadTokenAndProducts() async {
    // ★ 토큰은 항상 TokenStorage에서만 읽는다
    token = await TokenStorage.getToken();

    final products = <Map<String, dynamic>>[];
    bool added = false;

    bool isFav(String id) => favStore.favoriteIds.contains(id);
    int favCnt(String id, int? local) => favStore.counts[id] ?? (local ?? 0);

    if (token != null) {
      try {
        // api_service.fetchProducts → List<Product>
        final productsFromApi = await fetchProducts(token!);
        if (productsFromApi.isNotEmpty) {
          products.addAll(productsFromApi.map((p) {
            final m = p.toMapForHome(); // models/post.dart 확장 메서드
            final imgList = (m['imageUrls'] is List &&
                    (m['imageUrls'] as List).isNotEmpty)
                ? (m['imageUrls'] as List).map((e) => _absUrl('$e')).toList()
                : (m['images'] is List && (m['images'] as List).isNotEmpty)
                    ? (m['images'] as List).map((e) => _absUrl('$e')).toList()
                    : (m['thumbnailUrl'] != null
                            ? [_absUrl(m['thumbnailUrl'])]
                            : <String?>[])
                        .whereType<String>()
                        .toList();
            final thumb = m['thumbnailUrl'] != null
                ? _absUrl('${m['thumbnailUrl']}')
                : (imgList.isNotEmpty ? imgList.first : null);

            return {
              ...m,
              'imageUrls': imgList,
              'thumbnailUrl': thumb,
              'price': m['price'] ?? m['priceWon'] ?? 0,
              'location': m['location'] ?? m['locationText'] ?? '위치 정보 없음',
              'time': m['time'] ?? _relativeTime(m['createdAt']?.toString()),
              'isFavorited': isFav(m['id']),
              'favoriteCount': favCnt(
                m['id'],
                _asInt(m['favoriteCount'] ?? m['likes'] ?? 0),
              ),
            };
          }));
          added = true;
        }
      } catch (e) {
        debugPrint('상품 불러오기 오류: $e');
      }
    }

    // 서버 표준 파서 폴백
    if (!added) {
      try {
        final raw = await _fetchProductsRaw(token);
        products.addAll(raw.map((m) => {
              ...m,
              'isFavorited': isFav(m['id']),
              'favoriteCount': favCnt(
                m['id'],
                _asInt(m['favoriteCount'] ?? m['likes'] ?? 0),
              ),
            }));
      } catch (e) {
        debugPrint('fallback fetch 오류: $e');
      }
    }

    // 아무것도 없으면 데모 1개
    if (products.isEmpty) {
      products.add(kDemoProduct);
    }

    if (!mounted) return;
    setState(() {
      allProducts = products;
    });

    // 마지막에 즐겨찾기 동기화(카운트 최신화)
    await favStore.refreshFromServer();
  }

  Future<void> _toggleLikeById(String productId) async {
    if (productId.isEmpty) return;

    // 연타 방지용 낙관적 업데이트
    final prevFav = favStore.favoriteIds.contains(productId);
    final prevCnt = favStore.counts[productId] ??
        _asInt(
          allProducts.firstWhere(
                (p) => p['id'] == productId,
                orElse: () => const {},
              )['favoriteCount'] ??
              0,
        );

    favStore.toggleOptimistic(
      productId,
      currentFavorited: prevFav,
      currentCount: prevCnt,
    );
    setState(() {});

    try {
      final res = await toggleFavoriteDetailed(
        productId,
        currentlyFavorited: prevFav, // ← 현재 상태 전달(이미 찜이면 언찜 분기)
      );
      favStore.applyServer(
        productId,
        isFavorited: res.isFavorited,
        favoriteCount: res.favoriteCount,
      );
      setState(() {});
    } catch (e) {
      // 롤백
      favStore.rollback(
        productId,
        previousFavorited: prevFav,
        previousCount: prevCnt,
      );
      setState(() {});
      final msg =
          '$e' == 'Exception: 401' ? '로그인이 필요합니다. 다시 로그인해주세요.' : '찜 토글 실패: $e';
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  // 🔼 상세에서 돌아올 때 받은 최신 조회수로 리스트 갱신
  void _applyReturnedViews(String productId, int views) {
    final idx = allProducts.indexWhere((p) => (p['id'] ?? '') == productId);
    if (idx == -1) return;
    setState(() {
      allProducts[idx] = {
        ...allProducts[idx],
        'views': views,
      };
    });
  }

  void _toggleFabMenu() => setState(() => _isMenuOpen = !_isMenuOpen);

  // ✅ FAB 메뉴 아이템 빌더
  Widget _buildMenuItem({
    required IconData icon,
    required Color iconColor,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 26),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mainColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: mainColor,
        title: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.menu, color: Colors.white),
              onPressed: () => context.pushNamed(R.RouteNames.categories),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                decoration: InputDecoration(
                  hintText: '상품 검색',
                  fillColor: Colors.white,
                  filled: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(3)),
                ),
                onChanged: (v) => setState(() => searchText = v),
              ),
            ),
            const SizedBox(width: 10),
            IconButton(
              icon: const Icon(Icons.notifications, color: Colors.white),
              onPressed: () => context.pushNamed(R.RouteNames.alarms),
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          // 즐겨찾기 스토어가 바뀌면 자동 리빌드
          AnimatedBuilder(
            animation: favStore,
            builder: (context, _) {
              final filteredProducts = allProducts
                  .map((p) {
                    final id = (p['id'] ?? '') as String;
                    return {
                      ...p,
                      // 상태/카운트는 Store 우선
                      'isFavorited': favStore.favoriteIds.contains(id),
                      'favoriteCount': _asInt(
                        favStore.counts[id] ??
                            p['favoriteCount'] ??
                            p['likes'] ??
                            0,
                      ),
                    };
                  })
                  .where((p) => (p['title'] as String)
                      .toLowerCase()
                      .contains(searchText.toLowerCase()))
                  .toList();

              return ListView.builder(
                padding: const EdgeInsets.only(bottom: 120),
                itemCount: filteredProducts.length,
                itemBuilder: (_, index) {
                  final product = filteredProducts[index];
                  final liked = (product['isFavorited'] ?? false) as bool;

                  final imageUrl = product['thumbnailUrl'] ??
                      ((product['imageUrls'] != null &&
                              (product['imageUrls'] as List).isNotEmpty)
                          ? (product['imageUrls'] as List).first
                          : null);

                  final title = product['title'] as String? ?? '';

                  String location = '';
                  final lv = product['location'];
                  if (lv is String && lv.isNotEmpty) {
                    location = lv;
                  } else if ((product['locationText']?.toString().isNotEmpty ??
                      false)) {
                    location = product['locationText'];
                  } else {
                    location = '위치 정보 없음';
                  }

                  final time = product['time'] as String? ?? '';
                  final priceLabel =
                      _formatWon(product['price'] ?? product['priceWon'] ?? 0);

                  return InkWell(
                    onTap: () async {
                      final id = (product['id'] as String?) ?? '';
                      final result = await context.pushNamed<Map>(
                        R.RouteNames.productDetail,
                        pathParameters: {
                          'productId': id.isEmpty ? 'demo-product' : id
                        },
                      );

                      if (!mounted) return;
                      if (id.isEmpty || id.startsWith('demo-')) return;

                      if (result is Map &&
                          result['productId'] == id &&
                          result['views'] != null) {
                        final newViews = (result['views'] is num)
                            ? (result['views'] as num).toInt()
                            : int.tryParse('${result['views']}') ?? 0;
                        _applyReturnedViews(id, newViews);
                      }
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
                                    errorBuilder: (_, __, ___) => Container(
                                      width: 100,
                                      height: 100,
                                      color: Colors.grey[300],
                                      child: const Icon(Icons.broken_image,
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
                              crossAxisAlignment: CrossAxisAlignment.start,
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
                                    // 가격 굵게
                                    Text.rich(
                                      TextSpan(
                                        children: [
                                          const TextSpan(text: '가격 '),
                                          TextSpan(
                                            text: priceLabel,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w700),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      '찜 ${product['favoriteCount'] ?? product['likes'] ?? 0}  조회수 ${product['views'] ?? 0}',
                                      style:
                                          const TextStyle(color: Colors.grey),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: GestureDetector(
                                    onTap: () {
                                      final id = product['id'] as String? ?? '';
                                      if (id.isEmpty ||
                                          id.startsWith('demo-')) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                            content:
                                                Text('데모 항목은 찜을 지원하지 않습니다.'),
                                          ),
                                        );
                                        return;
                                      }
                                      _toggleLikeById(id);
                                    },
                                    child: Icon(
                                      liked
                                          ? Icons.favorite
                                          : Icons.favorite_border,
                                      color: liked ? Colors.red : Colors.grey,
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
              );
            },
          ),

          // ✅ FAB 외부 탭시 닫기 처리
          Positioned.fill(
            child: IgnorePointer(
              ignoring: !_isMenuOpen,
              child: AnimatedOpacity(
                opacity: _isMenuOpen ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 150),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _toggleFabMenu,
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          ),

          // ✅ FAB 메뉴 (인라인 UI)
          AnimatedPositioned(
            duration: const Duration(milliseconds: 250),
            right: 16,
            bottom: _isMenuOpen ? 100 : 80,
            curve: Curves.easeOut,
            child: IgnorePointer(
              ignoring: !_isMenuOpen,
              child: AnimatedOpacity(
                opacity: _isMenuOpen ? 1 : 0,
                duration: const Duration(milliseconds: 200),
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    width: 220,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: const [
                        BoxShadow(
                            color: Colors.black26,
                            blurRadius: 20,
                            offset: Offset(0, 6)),
                      ],
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildMenuItem(
                          icon: Icons.delivery_dining,
                          iconColor: kuInfo,
                          label: 'KU대리',
                          onTap: () {
                            _toggleFabMenu();
                            // 게이트 라우트 → membership 확인 후 자동 분기
                            context.goNamed(R.RouteNames.kuDeliveryEntry);
                          },
                        ),
                        const Divider(height: 1, color: Color(0xFFF1F3F5)),
                        _buildMenuItem(
                          icon: Icons.add_box_outlined,
                          iconColor: const Color(0xFFFF6A00),
                          label: '상품 등록',
                          onTap: () async {
                            _toggleFabMenu();
                            if (!mounted) return;

                            // Product를 반환하면 바로 맵 변환해 prepend
                            final Product? newProduct =
                                await context.pushNamed<Product>(
                              R.RouteNames.productEdit,
                              pathParameters: {'productId': 'demo-product'},
                            );

                            if (newProduct != null && mounted) {
                              setState(() {
                                final newMap = newProduct.toMapForHome();
                                allProducts.insert(0, newMap);
                              });
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: HeroMode(
        enabled: (ModalRoute.of(context)?.isFirst ?? true),
        child: FloatingActionButton(
          heroTag: heroTagFab('home'),
          backgroundColor: mainColor,
          onPressed: _toggleFabMenu,
          child:
              Icon(_isMenuOpen ? Icons.close : Icons.add, color: Colors.white),
        ),
      ),
    );
  }
}
