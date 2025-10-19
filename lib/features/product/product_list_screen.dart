import 'package:flutter/material.dart';
import 'package:kumeong_store/core/widgets/app_bottom_nav.dart'; // 하단바
import 'package:kumeong_store/utils/storage.dart';
import 'package:kumeong_store/models/post.dart';
import 'package:kumeong_store/api_service.dart';
import '../home/home_screen.dart';

// =========================
// 상품 목록 페이지 (실데이터 연동)
// =========================
class ProductPage extends StatefulWidget {
  /// 전달받는 category는 가능한 한 "대분류 > 소분류" 풀 경로 문자열로 넘겨주세요.
  /// (예: "의류/패션 > 남성의류")
  final String category;
  const ProductPage({super.key, required this.category});

  @override
  State<ProductPage> createState() => _ProductPageState();
}

class _ProductPageState extends State<ProductPage> {
  final List<Product> _items = [];
  bool _loading = true;
  bool _error = false;
  int _page = 1;
  bool _hasMore = true;
  late final ScrollController _sc;

  @override
  void initState() {
    super.initState();
    _sc = ScrollController()..addListener(_onScroll);
    _load(reset: true);
  }

  @override
  void dispose() {
    _sc.removeListener(_onScroll);
    _sc.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_hasMore || _loading) return;
    if (_sc.position.pixels >= _sc.position.maxScrollExtent - 200) {
      _load();
    }
  }

  Future<void> _load({bool reset = false}) async {
    setState(() {
      _loading = true;
      _error = false;
    });
    try {
      final token = await TokenStorage.getToken();
      if (token == null || token.isEmpty) {
        setState(() {
          _loading = false;
          _error = true;
        });
        return;
      }
      final nextPage = reset ? 1 : _page + 1;
      // 공백/줄바꿈 정리
      final fullCat = widget.category
          .replaceAll('\n', ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();

      // 1차: 풀 경로로 조회 (DB가 "의류/패션 > 남성의류"로 저장된 경우 매칭)
      var fetched = await fetchProducts(
        token,
        category: fullCat,
        page: nextPage,
        limit: 20,
        sortField: 'createdAt',
        order: 'DESC',
      );

      // 2차(자동 폴백): 결과가 없고 '>'가 있다면 소분류만으로 재조회
      if (reset && fetched.isEmpty && fullCat.contains('>')) {
        final subOnly = fullCat.split('>').last.trim();
        fetched = await fetchProducts(
          token,
          category: subOnly,
          page: nextPage,
          limit: 20,
          sortField: 'createdAt',
          order: 'DESC',
        );
      }
      setState(() {
        if (reset) _items.clear();
        _items.addAll(fetched);
        _page = nextPage;
        _hasMore = fetched.length >= 20;
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _loading = false;
        _error = true;
      });
    }
  }

  Future<void> _refresh() async => _load(reset: true);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // 앱바 표시는 깔끔하게: "대분류 > 소분류"가 들어와도 타이틀은 소분류만
    final displayTitle = widget.category.contains('>')
        ? widget.category.split('>').last.trim()
        : widget.category.trim();
    return Scaffold(
      appBar: AppBar(
        backgroundColor: cs.primary,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title:
            Text('#$displayTitle', style: const TextStyle(color: Colors.white)),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: _error
            ? ListView(children: const [
                SizedBox(height: 200),
                Center(child: Text('불러오기 실패'))
              ])
            : ListView.separated(
                controller: _sc,
                itemCount: _items.length + (_loading || _hasMore ? 1 : 0),
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  if (index >= _items.length) {
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  final p = _items[index];
                  return HomeStyleProductCard(
                    product: p,
                    onTap: () {
                      // TODO: 상세 페이지 라우팅 연결
                    },
                  );
                },
              ),
      ),
    );
  }
}

/// =========================
/// 홈 화면과 동일한 카드 스타일
/// =========================
class HomeStyleProductCard extends StatelessWidget {
  const HomeStyleProductCard({super.key, required this.product, this.onTap});
  final Product product;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final m = product
        .toMapForHome(); // title, location, time, priceWon/price, likes, views, thumbnailUrl
    final thumb = (m['thumbnailUrl'] as String?);
    final price = m['priceWon'] ?? m['price'] ?? 0;

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 이미지
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: 96,
                height: 96,
                color: cs.surfaceVariant,
                child: thumb != null && thumb.isNotEmpty
                    ? Image.network(thumb, fit: BoxFit.cover)
                    : const Icon(Icons.image_not_supported),
              ),
            ),
            const SizedBox(width: 12),
            // 텍스트들
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    m['title'] ?? product.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          '${m['location']} · ${m['time']}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: cs.onSurfaceVariant),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '찜 ${m['likes']}  조회수 ${m['views']}',
                        style: TextStyle(color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '₩${_formatPrice(price)}',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatPrice(dynamic v) {
  final n = v is num ? v.toInt() : int.tryParse('$v') ?? 0;
  final s = n.toString();
  final buf = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    final idx = s.length - i;
    buf.write(s[i]);
    if (idx > 1 && idx % 3 == 1) buf.write(',');
  }
  return buf.toString();
}

// =========================
// 카테고리 페이지
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
                context, MaterialPageRoute(builder: (_) => const HomePage()));
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
                  onTap: () => setState(() => selectedCategory = key),
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
                      onTap: () async {
                        // ✅ 풀 경로로 넘겨서 DB에 "대분류 > 소분류"로 저장된 데이터도 바로 매칭
                        final fullCat = '$selectedCategory > $sub';
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ProductPage(category: fullCat),
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
}
