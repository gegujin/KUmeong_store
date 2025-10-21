// lib/features/mypage/heart_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kumeong_store/core/router/route_names.dart' as R;
import 'package:kumeong_store/core/widgets/app_bottom_nav.dart'; // 하단바(전역으로 붙어 있으면 주석 OK)

class HeartPage extends StatefulWidget {
  const HeartPage({super.key});

  @override
  State<HeartPage> createState() => _HeartPageState();
}

class _HeartPageState extends State<HeartPage> {
  // 더미 데이터 (productId 추가)
  List<Map<String, dynamic>> likedProducts = [
    {
      'productId': 'p-willson-ball', // ✅ 상세 이동에 사용할 ID
      'title': 'Willson 농구공 팝니다',
      'location': '신촌운동장',
      'time': '2일전',
      'likes': 1,
      'views': 5,
      'price': '25,000원',
      'isLiked': true,
    },
    {
      'productId': 'p-cs-hoodie',
      'title': '컴공 과잠 팝니다',
      'location': '모시래마을',
      'time': '3일전',
      'likes': 1,
      'views': 5,
      'price': '30,000원',
      'isLiked': true,
    },
  ];

  void _toggleLike(int index) {
    setState(() {
      if (likedProducts[index]['isLiked']) {
        likedProducts[index]['isLiked'] = false;
        likedProducts[index]['likes'] =
            (likedProducts[index]['likes'] as int) - 1;
      } else {
        likedProducts[index]['isLiked'] = true;
        likedProducts[index]['likes'] =
            (likedProducts[index]['likes'] as int) + 1;
      }
    });
  }

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
      body: likedProducts.isEmpty
          ? const Center(child: Text("아직 좋아요한 상품이 없습니다."))
          : ListView.builder(
              itemCount: likedProducts.length,
              itemBuilder: (_, index) {
                final product = likedProducts[index];
                return InkWell(
                  onTap: () {
                    // ✅ 상품 상세로 이동
                    final productId =
                        (product['productId'] as String?) ?? 'demo-product';
                    context.pushNamed(
                      R.RouteNames.productDetail,              // /home/product/:productId
                      pathParameters: {'productId': productId},
                      // extra: 초기 Product 객체를 넘길 경우 여기에 전달 가능
                    );
                  },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 상품 이미지 (더미)
                        Container(
                          width: 80,
                          height: 80,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(width: 10),

                        // 상품 정보
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 제목 + 하트
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      product['title'] as String? ?? '',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () => _toggleLike(index),
                                    child: Icon(
                                      (product['isLiked'] as bool? ?? false)
                                          ? Icons.favorite
                                          : Icons.favorite_border,
                                      color:
                                          (product['isLiked'] as bool? ?? false)
                                              ? Colors.red
                                              : Colors.grey,
                                      size: 22,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),

                              // 위치 & 시간
                              Text(
                                '${product['location']} | ${product['time']}',
                                style: const TextStyle(color: Colors.grey),
                              ),
                              const SizedBox(height: 4),

                              // 가격 + 찜/조회수
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('가격 ${product['price']}'),
                                  Text(
                                    '찜 ${product['likes']} 조회수 ${product['views']}',
                                    style: const TextStyle(color: Colors.grey),
                                  ),
                                ],
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
      // bottomNavigationBar: const AppBottomNav(currentIndex: 2),
    );
  }
}
