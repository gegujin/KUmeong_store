import 'package:flutter/material.dart';
import 'package:kumeong_store/core/widgets/app_bottom_nav.dart'; // 하단바
import '../mypage/mypage_screen.dart';
import '../home/home_screen.dart';

// =========================
// 상품 페이지
// =========================
class ProductPage extends StatelessWidget {
  final String category; // 선택된 하위 카테고리
  final List<String> products;

  const ProductPage({
    super.key,
    required this.category,
    required this.products,
  });

  @override
  Widget build(BuildContext context) {
    final mainColor = Theme.of(context).colorScheme.primary; // 색상 변경

    return Scaffold(
      appBar: AppBar(
        backgroundColor: mainColor,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: Text(category, style: const TextStyle(color: Colors.white)),
      ),
      body: ListView.builder(
        itemCount: products.length,
        itemBuilder: (_, index) {
          final productName = products[index];
          return InkWell(
            onTap: () {
              print('$productName 클릭됨');
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    color: Colors.grey[300],
                  ), // 상품 이미지
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          productName,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: const [
                            Text(
                              '000 | 0일전',
                              style: TextStyle(color: Colors.grey),
                            ),
                            Text(
                              '찜 0  조회수 0',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Text('가격 00,000원'),
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
    final mainColor = Theme.of(context).colorScheme.primary; // 색상 변경

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
                        // 더미 상품 예시
                        List<String> exampleProducts = List.generate(
                          5,
                          (index) => '$sub 상품 ${index + 1}',
                        );

                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ProductPage(
                              category: sub,
                              products: exampleProducts,
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
}
