import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kumeong_store/models/post.dart';
import 'package:kumeong_store/core/ui/hero_tags.dart';
import 'package:kumeong_store/core/router/route_names.dart' as R;

import '../product/product_list_screen.dart';
import '../home/alarm_screen.dart';
import '../mypage/mypage_screen.dart';
import 'package:kumeong_store/core/widgets/app_bottom_nav.dart';
import '../../core/theme.dart';
import '../../api_service.dart';
import 'package:kumeong_store/state/favorites_store.dart';
import 'dart:html' as html; // Web 전용 localStorage
import 'package:http/http.dart' as http;

const String _apiBase = 'http://localhost:3000/api/v1';
const Color kuInfo = Color(0xFF147AD6);

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
      'likes': p['likes'] ?? 0,
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

  Future<void> _loadTokenAndProducts() async {
    if (kIsWeb) {
      token = html.window.localStorage['accessToken'];
    } else {
      final prefs = await SharedPreferences.getInstance();
      token = prefs.getString('accessToken');
    }

    final products = <Map<String, dynamic>>[];
    bool added = false;

    bool isFav(String id) => favStore.favoriteIds.contains(id);
    int? favCnt(String id, int? local) => favStore.counts[id] ?? local;

    if (token != null) {
      try {
        final productsFromApi = await fetchProducts(token!); // List<Product>
        if (productsFromApi.isNotEmpty) {
          products.addAll(productsFromApi.map((p) {
            final m = p.toMapForHome();
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

    if (products.isEmpty) {
      products.add(demoProduct.toMapForHome()); // 서버 비었을 때만 데모 추가
    }

    if (!mounted) return;
    setState(() {
      allProducts = products;
    });
    await favStore.refreshFromServer();
  }

  Future<void> _toggleLikeById(String productId) async {
    if (productId.isEmpty) return;
    // 연타 방지
    final prevFav = favStore.favoriteIds.contains(productId);
    final prevCnt = favStore.counts[productId] ??
        _asInt(allProducts.firstWhere((p) => p['id'] == productId,
                orElse: () => const {})['favoriteCount'] ??
            0);
    favStore.toggleOptimistic(
      productId,
      currentFavorited: prevFav,
      currentCount: prevCnt,
    );
    setState(() {}); // 리빌드

    try {
      final res = await toggleFavoriteDetailed(productId); // 서버 최종값
      favStore.applyServer(
        productId,
        isFavorited: res.isFavorited,
        favoriteCount: res.favoriteCount, // 있으면 치환
      );
      setState(() {});
    } catch (e) {
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

  void _toggleFabMenu() => setState(() => _isMenuOpen = !_isMenuOpen);

  // ✅ FAB 메뉴 아이템 빌더(메서드)
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
                      'favoriteCount': favStore.counts[id] ??
                          p['favoriteCount'] ??
                          p['likes'] ??
                          0,
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
                    onTap: () {
                      context.pushNamed(
                        R.RouteNames.productDetail,
                        pathParameters: {
                          'productId': product['id'] ?? 'demo-product'
                        },
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
                                    // 가격 굵게(카테고리 UI 느낌)
                                    Text.rich(
                                      TextSpan(
                                        children: [
                                          const TextSpan(text: '가격 '),
                                          TextSpan(
                                            text: priceLabel,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                            ),
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
                                      if (id.isEmpty || id.startsWith('p-')) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                              content:
                                                  Text('데모 항목은 찜을 지원하지 않습니다.')),
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

          // ✅ FAB 외부 탭시 닫기 처리 (항상 존재 + 투명/무시로 제어)
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
                          offset: Offset(0, 6),
                        ),
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
                            context.pushNamed(R.RouteNames.kuDeliverySignup);
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
          child: Icon(
            _isMenuOpen ? Icons.close : Icons.add,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
