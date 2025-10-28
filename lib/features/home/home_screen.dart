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

  /// ✅ 비동기 로딩 구조
  Future<void> _loadTokenAndProducts() async {
    if (kIsWeb) {
      token = html.window.localStorage['accessToken'];
    } else {
      final prefs = await SharedPreferences.getInstance();
      token = prefs.getString('accessToken');
    }

    final products = <Map<String, dynamic>>[_toHomeMap(demoProduct)];

    if (token != null) {
      try {
        final productsFromApi = await fetchProducts(token!); // 실제 호출
        products.addAll(productsFromApi.map(_toHomeMap));
      } catch (e) {
        debugPrint('상품 불러오기 오류: $e');
      }
    }

    setState(() {
      allProducts = products;
    });
  }

  void _toggleLike(int index) {
    setState(() {
      final liked = (allProducts[index]['isLiked'] ?? false) as bool;
      final likes = allProducts[index]['likes'] as int? ?? 0;
      allProducts[index]['isLiked'] = !liked;
      allProducts[index]['likes'] = liked ? likes - 1 : likes + 1;
    });
  }

  void _toggleFabMenu() {
    setState(() => _isMenuOpen = !_isMenuOpen);
  }

  Map<String, dynamic> _toHomeMap(dynamic src) {
    if (src is Product) return src.toMapForHome();

    if (src is Map) {
      final m = Map<String, dynamic>.from(src);

      // imageUrls 정규화
      List<String> imageUrls = [];
      if (m['imageUrls'] is List) {
        imageUrls = List<String>.from(
          (m['imageUrls'] as List)
              .where((e) => e != null)
              .map((e) => e.toString()),
        );
      } else if (m['images'] is List) {
        imageUrls = (m['images'] as List)
            .map((e) {
              if (e is String) return e;
              if (e is Map) {
                final url = e['url'] ?? e['path'] ?? e['src'];
                return url?.toString() ?? '';
              }
              return '';
            })
            .where((s) => s.isNotEmpty)
            .map((s) => s.toString())
            .toList();
      } else if (m['imageUrl'] != null) {
        imageUrls = [m['imageUrl'].toString()];
      }

      // 위치 정규화
      dynamic location = m['location'];
      if (location == null || (location is String && location.isEmpty)) {
        final locName = m['locationName'] ??
            (m['seller'] is Map ? (m['seller'] as Map)['locationName'] : null);
        if (locName != null && locName.toString().isNotEmpty) {
          location = {'name': locName.toString()};
        }
      }

      final price = m['price'] ?? m['amount'] ?? m['totalPrice'] ?? 0;
      final time = m['time'] ?? m['createdAt'] ?? m['updatedAt'] ?? '';
      final likes = m['likes'] ??
          m['favoriteCount'] ??
          m['favorites'] ??
          m['favCount'] ??
          0;
      final views = m['views'] ?? m['viewCount'] ?? 0;

      int _toInt(dynamic v) =>
          (v is num) ? v.toInt() : int.tryParse(v?.toString() ?? '') ?? 0;

      return {
        'id':
            m['id'] ?? m['productId'] ?? m['uuid'] ?? m['postId'] ?? 'unknown',
        'title': m['title'] ?? m['name'] ?? m['subject'] ?? '',
        'imageUrls': imageUrls,
        'location': location ?? '위치 정보 없음',
        'time': time.toString(),
        'price': price,
        'isLiked': (m['isLiked'] ?? m['favorited'] ?? false) == true,
        'likes': _toInt(likes),
        'views': _toInt(views),
        'seller': m['seller'], // 위치 폴백용으로 남겨둠
      };
    }

    // 알 수 없는 타입
    return {
      'id': 'unknown',
      'title': '',
      'imageUrls': const <String>[],
      'location': '위치 정보 없음',
      'time': '',
      'price': 0,
      'isLiked': false,
      'likes': 0,
      'views': 0,
    };
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
              final liked = (product['isLiked'] ?? false) as bool;

              final imageUrl = (product['imageUrls'] != null &&
                      (product['imageUrls'] as List).isNotEmpty)
                  ? (product['imageUrls'] as List).first
                  : null;

              final title = product['title'] as String? ?? '';

              /// ✅ locationName이 비어있으면 seller.locationName 사용
              final locationValue = product['location'];
              String location = '';
              if (locationValue is Map) {
                location = (locationValue['name']?.toString().isNotEmpty ??
                        false)
                    ? locationValue['name']
                    : (locationValue['locationName']?.toString().isNotEmpty ??
                            false)
                        ? locationValue['locationName']
                        : (product['seller']?['locationName']
                                    ?.toString()
                                    .isNotEmpty ??
                                false)
                            ? product['seller']['locationName']
                            : '위치 정보 없음';
              } else if (locationValue is String && locationValue.isNotEmpty) {
                location = locationValue;
              } else {
                location = (product['seller']?['locationName']
                            ?.toString()
                            .isNotEmpty ??
                        false)
                    ? product['seller']['locationName']
                    : '위치 정보 없음';
              }

              final time = product['time'] as String? ?? '';
              final price = product['price']?.toString() ?? '0원';

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
                                Text('가격 $price'),
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

          /// ✅ FAB 외부 탭 시 닫기
          if (_isMenuOpen)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _toggleFabMenu,
                child: const SizedBox.shrink(),
              ),
            ),

          /// ✅ FAB 메뉴 (충돌 해결본)
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
                        // ✅ 게이트 라우트로 진입 → membership 확인 후 자동 분기
                        context.goNamed(R.RouteNames.kuDeliveryEntry);
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

                        /// ✅ 등록된 상품 즉시 반영
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
}
