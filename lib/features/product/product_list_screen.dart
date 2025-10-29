import 'package:flutter/material.dart';
import 'package:kumeong_store/core/widgets/app_bottom_nav.dart'; // 하단바 (미사용이면 삭제해도 OK)
import '../mypage/mypage_screen.dart';
import '../home/home_screen.dart';

import 'package:kumeong_store/api_service.dart'; // fetchProductsByTagCards

// =========================
// 상품 페이지 (태그별 실제 목록)
// =========================
class ProductPage extends StatefulWidget {
  final String category; // 화면에 표시할 하위 카테고리명
  final String tag; // 실제 조회에 사용할 태그

  const ProductPage({
    super.key,
    required this.category,
    required this.tag,
  });

  @override
  State<ProductPage> createState() => _ProductPageState();
}

class _ProductPageState extends State<ProductPage> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _items = [];

  int _page = 1;
  final int _limit = 20;
  bool _hasMore = true;
  final ScrollController _sc = ScrollController();

  @override
  void initState() {
    super.initState();
    _load();
    _sc.addListener(_onScroll);
  }

  @override
  void dispose() {
    _sc.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_hasMore &&
        !_loading &&
        _sc.position.pixels >= _sc.position.maxScrollExtent - 200) {
      _load(next: true);
    }
  }

  Future<void> _load({bool next = false}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = next ? _page + 1 : 1;
      final items = await fetchProductsByTagCards(
        tag: widget.tag,
        page: page,
        limit: _limit,
        sortField: 'createdAt',
        order: 'DESC',
      );

      setState(() {
        if (next) {
          _items.addAll(items);
          _page = page;
        } else {
          _items = items;
          _page = 1;
        }
        _hasMore = items.length >= _limit;
      });
    } catch (e) {
      setState(() {
        _error = '$e';
      });
    } finally {
      setState(() => _loading = false);
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
        title:
            Text(widget.category, style: const TextStyle(color: Colors.white)),
      ),
      body: RefreshIndicator(
        onRefresh: () => _load(next: false),
        child: _error != null
            ? ListView(
                children: [
                  const SizedBox(height: 80),
                  Center(
                      child: Text('불러오기 실패\n$_error',
                          textAlign: TextAlign.center)),
                  const SizedBox(height: 12),
                  Center(
                    child: OutlinedButton(
                      onPressed: () => _load(next: false),
                      child: const Text('다시 시도'),
                    ),
                  ),
                ],
              )
            : ListView.builder(
                controller: _sc,
                itemCount: _items.length + (_loading || _hasMore ? 1 : 0),
                itemBuilder: (_, index) {
                  if (index >= _items.length) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  final m = _items[index];
                  final String title = (m['title'] ?? '') as String;
                  final String? thumb = (m['thumbnailUrl'] as String?);
                  final String loc = (m['locationText'] ?? '미정') as String;
                  final String timeText = (m['timeText'] ?? '') as String;
                  final int fav = _asInt(m['favoriteCount']);
                  final int views = _asInt(m['views']);
                  final String priceText = _fmtWon(m['priceWon']);
                  final String id = (m['id'] ?? '') as String;

                  return InkWell(
                    onTap: () {
                      // TODO: 상품 상세 라우팅 연결
                      // 예) context.goNamed(R.RouteNames.productDetail, pathParameters: {'id': id});
                      debugPrint('$title 클릭됨 (id=$id)');
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      child: Row(
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            clipBehavior: Clip.hardEdge,
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: (thumb != null && thumb.isNotEmpty)
                                ? Image.network(thumb, fit: BoxFit.cover)
                                : const Icon(Icons.image, color: Colors.grey),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      '$loc | $timeText',
                                      style:
                                          const TextStyle(color: Colors.grey),
                                    ),
                                    Text(
                                      '찜 $fav  조회수 $views',
                                      style:
                                          const TextStyle(color: Colors.grey),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text('가격 $priceText'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }

  int _asInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String && v.isNotEmpty) {
      final s = v.replaceAll(RegExp(r'[, ]'), '');
      return int.tryParse(s) ?? 0;
    }
    return 0;
  }

  String _fmtWon(dynamic value) {
    if (value == null) return '0원';
    try {
      final n = (value is num) ? value : num.parse(value.toString());
      return '${_comma(n)}원';
    } catch (_) {
      return '$value원';
    }
  }

  String _comma(num n) {
    final s = n.toStringAsFixed(0);
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      final idx = s.length - i;
      buf.write(s[i]);
      if (idx > 1 && (idx - 1) % 3 == 0) buf.write(',');
    }
    return buf.toString();
  }
}

// =========================
// 카테고리 페이지 (태그 → 목록 이동)
// =========================
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
          // 하위 카테고리 (탭 → 태그로 변환 → 목록 화면)
          Expanded(
            flex: 2,
            child: ListView(
              children: categories[selectedCategory]!
                  .map(
                    (sub) => ListTile(
                      title: Text(sub),
                      onTap: () {
                        final tag = _tagFor(selectedCategory, sub);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ProductPage(
                              category: sub,
                              tag: tag,
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
    );
  }

  // 하위 카테고리명을 태그 키로 변환하는 규칙
  // 서버의 태그 스키마에 맞게 필요 시 보정
  String _tagFor(String top, String sub) {
    // 예: '태블릿/노트북' -> '태블릿-노트북' (슬래시/쉼표 제거, 공백 → 하이픈)
    var t = sub
        .toLowerCase()
        .replaceAll(RegExp(r'[\/\|,]+'), ' ')
        .replaceAll(RegExp(r'\s+'), '-')
        .replaceAll(RegExp(r'[^a-z0-9\-ㄱ-ㅎ가-힣]'), '');
    if (t.isEmpty) t = sub;
    return t;
  }
}
