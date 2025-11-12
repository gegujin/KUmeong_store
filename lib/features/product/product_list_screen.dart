import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

// (유지) 하단바/마이페이지/홈
import 'package:kumeong_store/core/widgets/app_bottom_nav.dart';
import '../mypage/mypage_screen.dart';
import '../home/home_screen.dart';

// ✅ 추가: 공통 baseUrl 유틸과 라우팅
import 'package:kumeong_store/core/base_url.dart';            // apiUrl()
import 'package:kumeong_store/core/router/route_names.dart' as R;
import 'package:go_router/go_router.dart';

// ───────────────────────────────────────────────────────────
// 공통: API 베이스 URL 빌더 (프로젝트 규칙의 apiUrl 사용)
// ───────────────────────────────────────────────────────────
String _apiUrl(String path) {
  return apiUrl(path); // ← core/base_url.dart의 apiUrl 사용
}

// ───────────────────────────────────────────────────────────
// 상품 페이지 (하위 카테고리 기준 목록)
// ───────────────────────────────────────────────────────────
class ProductPage extends StatefulWidget {
  final String mainCategory; // 상위 카테고리
  final String subCategory;  // 하위 카테고리

  const ProductPage({
    super.key,
    required this.mainCategory,
    required this.subCategory,
  });

  @override
  State<ProductPage> createState() => _ProductPageState();
}

class _ProductPageState extends State<ProductPage> {
  bool _loading = true;
  String? _error;

  // id, title, priceWon, thumbnailUrl, locationText, favoriteCount, views, createdAt
  List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Uri _buildUri({
    required String main,
    required String sub,
    int page = 1,
    int limit = 20,
  }) {
    // ⚠️ 백엔드 쿼리 키가 다르면 여기 변경
    final params = {
      'categoryMain': main,
      'categorySub': sub,
      'page': '$page',
      'limit': '$limit',
      'sort': 'createdAt,DESC',
    };
    final q = params.entries
        .map((e) =>
            '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}')
        .join('&');
    return Uri.parse(_apiUrl('/products?$q'));
  }

  Future<void> _fetch() async {
    try {
      final uri = _buildUri(
        main: widget.mainCategory,
        sub: widget.subCategory,
      );
      final resp = await http.get(uri, headers: {
        'Content-Type': 'application/json',
        // 필요 시 토큰 주입:
        // 'Authorization': 'Bearer ${await TokenStorage.getAccessToken()}',
      });

      if (resp.statusCode != 200) {
        throw Exception('상품 조회 실패 (${resp.statusCode})');
      }

      final decoded = jsonDecode(resp.body);
      // { success, data: [...] } 또는 바로 [...]
      final List list = (decoded is Map && decoded['data'] is List)
          ? decoded['data'] as List
          : (decoded as List);

      final normalized = list.map<Map<String, dynamic>>((raw) {
        final m = (raw as Map);
        final imageUrls =
            (m['imageUrls'] is List) ? (m['imageUrls'] as List) : const [];
        final thumb =
            (m['thumbnailUrl'] ?? (imageUrls.isNotEmpty ? imageUrls.first : ''))
                .toString();

        return {
          'id': m['id'] ?? m['_id'],
          'title': m['title'] ?? m['name'] ?? '',
          'priceWon': m['priceWon'] ?? m['price'] ?? 0,
          'thumbnailUrl': thumb,
          'locationText': m['locationText'] ?? m['location'] ?? '미정',
          'favoriteCount': m['favoriteCount'] ?? m['favorites'] ?? 0,
          'views': m['views'] ?? m['viewCount'] ?? 0,
          'createdAt': m['createdAt'] ?? '',
        };
      }).toList();

      if (!mounted) return;
      setState(() {
        _items = normalized;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '목록을 불러오는 중 오류가 발생했습니다: $e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final mainColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: mainColor,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '${widget.mainCategory} > ${widget.subCategory}',
          style: const TextStyle(color: Colors.white),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _items.isEmpty
                  ? const Center(child: Text('등록된 상품이 없습니다.'))
                  : ListView.builder(
                      itemCount: _items.length,
                      itemBuilder: (_, index) {
                        final p = _items[index];
                        final id = (p['id'] ?? '').toString();
                        final thumb = (p['thumbnailUrl'] ?? '').toString();
                        final title = (p['title'] ?? '').toString();
                        final price = p['priceWon'] ?? p['price'] ?? 0;
                        final loc = (p['locationText'] ?? '미정').toString();
                        final fav = p['favoriteCount'] ?? 0;
                        final views = p['views'] ?? 0;
                        final createdAt = DateTime.tryParse(
                              (p['createdAt'] ?? '').toString(),
                            ) ??
                            DateTime.now();

                        return InkWell(
                          onTap: () {
                            if (id.isEmpty) return;
                            // ✅ 상세 페이지로 네임드 라우팅
                            context.pushNamed(
                              R.RouteNames.productDetail,
                              pathParameters: {'productId': id},
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            child: Row(
                              children: [
                                // 썸네일
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: thumb.isNotEmpty
                                      ? Image.network(
                                          thumb,
                                          width: 80,
                                          height: 80,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) =>
                                              Container(
                                            width: 80,
                                            height: 80,
                                            color: Colors.grey[300],
                                            child: const Icon(
                                                Icons.image_not_supported),
                                          ),
                                        )
                                      : Container(
                                          width: 80,
                                          height: 80,
                                          color: Colors.grey[300],
                                          child: const Icon(Icons.image),
                                        ),
                                ),
                                const SizedBox(width: 12),
                                // 텍스트
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
                                            fontSize: 16),
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            '$loc | ${_timeAgo(createdAt)}',
                                            style: const TextStyle(
                                                color: Colors.grey),
                                          ),
                                          Text(
                                            '찜 $fav  조회수 $views',
                                            style: const TextStyle(
                                                color: Colors.grey),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        _formatPrice(price),
                                        style: const TextStyle(fontSize: 15),
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
  }

  String _formatPrice(dynamic price) {
    try {
      final v = (price is num) ? price.toInt() : int.parse(price.toString());
      return '가격 ${_comma(v)}원';
    } catch (_) {
      return '가격 -';
    }
  }

  String _comma(int n) {
    final s = n.toString();
    final List<String> out = [];
    int count = 0;
    for (int i = s.length - 1; i >= 0; i--) {
      out.add(s[i]);
      count++;
      if (count == 3 && i != 0) {
        out.add(',');
        count = 0;
      }
    }
    return out.reversed.join();
  }

  String _timeAgo(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inDays >= 1) return '${diff.inDays}일 전';
    if (diff.inHours >= 1) return '${diff.inHours}시간 전';
    if (diff.inMinutes >= 1) return '${diff.inMinutes}분 전';
    return '방금 전';
  }
}

// ───────────────────────────────────────────────────────────
// 카테고리 페이지
// ───────────────────────────────────────────────────────────
class CategoryPage extends StatefulWidget {
  const CategoryPage({super.key});

  @override
  State<CategoryPage> createState() => _CategoryPageState();
}

class _CategoryPageState extends State<CategoryPage> {
  static const Map<String, List<String>> categories = {
    '디지털기기': ['스마트폰', '태블릿/노트북', '데스크탑/모니터', '카메라/촬영장비', '게임기기', '웨어러블/주변기기'],
    '가전제품': ['TV/모니터', '냉장고', '세탁기/청소기', '에어컨/공기청정기', '주방가전', '뷰티가전'],
    '의류/패션': ['남성의류', '여성의류', '아동의류', '신발', '가방', '액세서리'],
    '가구/인테리어': ['침대/매트리스', '책상/의자', '소파', '수납/테이블', '조명/인테리어 소품'],
    '생활/주방': ['주방용품', '청소/세탁용품', '욕실/수납용품', '생활잡화', '기타 생활소품'],
    '유아/아동': ['유아의류', '장난감', '유모차/카시트', '육아용품', '침구/가구'],
    '취미/게임/음반': ['게임', '운동용품', '음반/LP', '악기', '아웃도어용품'],
    '도서/문구': ['소설/에세이', '참고서/전공서적', '만화책', '문구/사무용품', '기타 도서류'],
    '반려동물': ['사료/간식', '장난감/용품', '이동장/하우스', '의류/목줄', '기타 반려용품'],
    '기타 중고물품': ['티켓/상품권', '피규어/프라모델', '공구/작업도구', '수집품', '기타'],
  };

  String selectedCategory = categories.keys.first;

  @override
  Widget build(BuildContext context) {
    final mainColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: mainColor,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const HomePage()),
            );
          },
        ),
        title: const Text('카테고리', style: TextStyle(color: Colors.white)),
      ),
      body: Row(
        children: [
          // 상위 카테고리
          Expanded(
            flex: 1,
            child: ListView(
              children: categories.keys.map((key) {
                return ListTile(
                  title: Text(key),
                  selected: key == selectedCategory,
                  selectedTileColor: Colors.grey[300],
                  onTap: () {
                    setState(() {
                      selectedCategory = key;
                    });
                  },
                );
              }).toList(),
            ),
          ),
          // 하위 카테고리
          Expanded(
            flex: 2,
            child: ListView(
              children: categories[selectedCategory]!
                  .map(
                    (sub) => ListTile(
                      title: Text(sub),
                      onTap: () {
                        // ✅ 더미 리스트 제거: 실제 카테고리만 넘김
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ProductPage(
                              mainCategory: selectedCategory,
                              subCategory: sub,
                            ),
                          ),
                        );
                      },
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
      // (선택) 하단 네비 유지 시:
      // bottomNavigationBar: const AppBottomNav(currentIndex: 0),
    );
  }
}
