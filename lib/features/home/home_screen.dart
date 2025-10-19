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

  @override
  void initState() {
    super.initState();
    _loadTokenAndProducts();
  }

  // =========================
  // ✅ [추가] 헬퍼들
  // =========================

  // 상대경로(/uploads/...) → 절대 URL
  String? _absUrl(String? p) {
    if (p == null || p.isEmpty) return null;
    if (p.startsWith('http')) return p;
    if (p.startsWith('/uploads/')) return 'http://localhost:3000$p';
    return p;
  }

  // 숫자 → "n원"
  String _formatWon(dynamic v) {
    final n = (v is num) ? v.toInt() : int.tryParse('$v') ?? 0;
    return '${n.toString()}원';
  }

  // createdAt → “방금 전/분/시간/일 전”
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

  // 서버 product JSON → 홈 카드용 표준 Map
  Map<String, dynamic> _normalizeServerProduct(Map<String, dynamic> p) {
    // 이미지
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

    // 위치/가격/시간
    final loc =
        p['location'] ?? p['locationText'] ?? p['seller']?['locationName'];
    final price = p['price'] ?? p['priceWon'] ?? 0;

    return {
      'id': p['id'] ?? p['_id'] ?? '',
      'title': p['title'] ?? '',
      'imageUrls': images, // ✅ 카드가 기대하는 키
      'thumbnailUrl': thumb,
      'location':
          (loc is String && loc.isNotEmpty) ? loc : '위치 정보 없음', // ✅ 위치 기본값
      'time': _relativeTime(p['createdAt']?.toString()), // ✅ 상대시간
      'price': price, // 숫자 보관(표시할 때 포맷)
      'likes': p['likes'] ?? 0,
      'views': p['views'] ?? 0,

      // ✅ 추가: 서버가 주면 그대로, 없으면 false
      'isFavorited': p['isFavorited'] == true,
    };
  }

  // 서버 목록을 직접 호출하는 fallback
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

  /// ✅ 수정 ①: 비동기 로딩 구조 + 표준화 + fallback
  Future<void> _loadTokenAndProducts() async {
    if (kIsWeb) {
      token = html.window.localStorage['accessToken'];
    } else {
      final prefs = await SharedPreferences.getInstance();
      token = prefs.getString('accessToken');
    }

    final products = <Map<String, dynamic>>[demoProduct.toMapForHome()];

    bool added = false;
    if (token != null) {
      try {
        // 기존 API 클라이언트 사용
        final productsFromApi = await fetchProducts(token!); // List<Product>
        if (productsFromApi.isNotEmpty) {
          products.addAll(productsFromApi.map((p) {
            final m = p.toMapForHome();
            // ✅ 누락키 보정: 이미지/가격/위치/시간
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
              // ✅ 추가
              'isFavorited': m['isFavorited'] == true,
            };
          }));
          added = true;
        }
      } catch (e) {
        debugPrint('상품 불러오기 오류: $e');
      }
    }

    // ✅ 실패/빈 목록이면 서버 JSON을 직접 호출해 표준화
    if (!added) {
      try {
        final raw = await _fetchProductsRaw(token);
        products.addAll(raw);
      } catch (e) {
        debugPrint('fallback fetch 오류: $e');
      }
    }

    if (!mounted) return;
    setState(() {
      allProducts = products;
    });
  }

  // ✅ 교체할 코드: 서버 호출로 하트 토글
  Future<void> _toggleLike(int index) async {
    final id = (allProducts[index]['id'] as String?) ?? '';
    if (id.isEmpty) return;

    // 서버에 찜 토글 요청
    final next = await toggleFavoriteById(id); // api_service.dart 함수

    if (next == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인이 필요하거나 요청이 실패했어요.')),
      );
      return;
    }

    // 성공 시 로컬 상태 반영 → 아이콘 즉시 갱신
    setState(() {
      allProducts[index]['isFavorited'] = next;

      // (선택) 좋아요 수도 함께 보정하려면 아래 주석 해제
      // final cur = (allProducts[index]['likes'] as int? ?? 0);
      // allProducts[index]['likes'] = next ? cur + 1 : (cur > 0 ? cur - 1 : 0);
    });
  }

  void _toggleFabMenu() {
    setState(() => _isMenuOpen = !_isMenuOpen);
  }

  @override
  Widget build(BuildContext context) {
    final mainColor = Theme.of(context).colorScheme.primary;

    final filteredProducts = allProducts
        .where((p) => (p['title'] as String)
            .toLowerCase()
            .contains(searchText.toLowerCase()))
        .toList();

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
          ListView.builder(
            padding: const EdgeInsets.only(bottom: 120),
            itemCount: filteredProducts.length,
            itemBuilder: (_, index) {
              final product = filteredProducts[index];
              final liked =
                  (product['isFavorited'] ?? false) as bool; // ✅ 키 이름 통일

              // ✅ 이미지: thumbnailUrl 우선 → imageUrls[0]
              final imageUrl = product['thumbnailUrl'] ??
                  ((product['imageUrls'] != null &&
                          (product['imageUrls'] as List).isNotEmpty)
                      ? (product['imageUrls'] as List).first
                      : null);

              final title = product['title'] as String? ?? '';

              // ✅ 위치: location → locationText → 기본
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

              // ✅ 가격: price → priceWon → 라벨
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: imageUrl != null
                            ? Image.network(
                                imageUrl,
                                width: 80,
                                height: 80,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  width: 80,
                                  height: 80,
                                  color: Colors.grey[300],
                                  child: const Icon(Icons.broken_image,
                                      color: Colors.white70),
                                ),
                              )
                            : Container(
                                width: 80,
                                height: 80,
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
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text('$location | $time',
                                style: const TextStyle(color: Colors.grey)),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('가격 $priceLabel'),
                                Text(
                                  '찜 ${product['likes'] ?? 0} 조회수 ${product['views'] ?? 0}',
                                  style: const TextStyle(color: Colors.grey),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Align(
                              alignment: Alignment.centerRight,
                              child: GestureDetector(
                                onTap: () => _toggleLike(index),
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
          ),

          // ✅ FAB 외부 탭시 닫기 처리
          if (_isMenuOpen)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _toggleFabMenu,
                child: const SizedBox.shrink(),
              ),
            ),

          // ✅ FAB 메뉴
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
                child: _MenuCard(
                  children: [
                    _MenuItem(
                      icon: Icons.delivery_dining,
                      iconColor: kuInfo,
                      label: 'KU대리',
                      onTap: () {
                        _toggleFabMenu();
                        context.pushNamed(R.RouteNames.kuDeliverySignup);
                      },
                    ),
                    const Divider(height: 1, color: Color(0xFFF1F3F5)),
                    _MenuItem(
                      icon: Icons.add_box_outlined,
                      iconColor: Color(0xFFFF6A00),
                      label: '상품 등록',
                      onTap: () async {
                        _toggleFabMenu();
                        if (!mounted) return;
                        final Product? newProduct =
                            await context.pushNamed<Product>(
                          R.RouteNames.productEdit,
                          pathParameters: {'productId': 'demo-product'},
                        );

                        // ✅ 등록 즉시 반영
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

class _MenuCard extends StatelessWidget {
  const _MenuCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 220,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(
                color: Colors.black26, blurRadius: 20, offset: Offset(0, 6)),
          ],
        ),
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(children: children),
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
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
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }
}
