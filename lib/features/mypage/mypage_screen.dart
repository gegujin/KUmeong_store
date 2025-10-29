import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:kumeong_store/core/widgets/app_bottom_nav.dart';
import 'package:go_router/go_router.dart'; // ⬅️ 네임드 라우트 이동용
import 'package:kumeong_store/core/router/route_names.dart' as R;

// 필요시 유지(포인트/설정은 별도 라우트가 없다면 기존 push 사용)
import '../mypage/point_screen.dart';
import '../settings/settings_screen.dart';

class MyPage extends StatelessWidget {
  /// 서버에서 받아올 별점 값 (기본 4.5)
  final double rating;

  const MyPage({super.key, this.rating = 4.5});

  @override
  Widget build(BuildContext context) {
    final mainColor = Theme.of(context).colorScheme.primary;

    Widget _buildDivider() => const Divider(
          color: Color.fromARGB(255, 226, 226, 226),
          height: 1,
        );

    return Scaffold(
      appBar: AppBar(
        backgroundColor: mainColor,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            // 탭 규칙에 맞춰 홈 루트로 이동시켜도 되고,
            // 단순 뒤로가기 하고 싶으면 Navigator.pop(context)로 바꿔도 됩니다.
            context.goNamed('home'); // ← 홈 루트로 복귀
          },
        ),
        title: const Text('마이페이지', style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white),
            onPressed: () {
              context.pushNamed(
                  R.RouteNames.settings); // ⬅️ MaterialPageRoute 사용 금지
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const CircleAvatar(radius: 40, backgroundColor: Colors.grey),
            const SizedBox(height: 10),
            const Text('사용자 이름', style: TextStyle(fontSize: 20)),
            const SizedBox(height: 10),

            // ⭐ 별점 표시(Indicator)
            Center(
              child: RatingBarIndicator(
                rating: rating,
                itemCount: 5,
                itemSize: 28.0,
                unratedColor: const Color(0xFFE0E0E0),
                itemBuilder: (_, __) =>
                    const Icon(Icons.star, color: Color(0xFFF4A623)),
                direction: Axis.horizontal,
              ),
            ),

            const SizedBox(height: 4),
            Text(
              "$rating / 5.0",
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),

            const SizedBox(height: 20),

            // ▼ 포인트
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    // 포인트 화면이 라우터에 없다면 기존 push 유지
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const PointPage()),
                    );
                  },
                  icon: const Icon(Icons.monetization_on, size: 20),
                  label: const Text('포인트', style: TextStyle(fontSize: 16)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orangeAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    elevation: 3,
                  ),
                ),
                const SizedBox(width: 10),
                const Text('450원', style: TextStyle(fontSize: 16)),
              ],
            ),
            const SizedBox(height: 20),

            // ▼ 목록 (모두 네임드 라우트로 통일)
            // MyPage의 친구목록 ListTile
            ListTile(
              leading: const Icon(Icons.group),
              title: const Text('친구목록'),
              // 기존: context.goNamed(R.RouteNames.friends)
              onTap: () => context.goNamed(R.RouteNames.friends),
            ),
            _buildDivider(),
            ListTile(
              leading: const Icon(Icons.favorite),
              title: const Text('관심목록'),
              onTap: () => context.goNamed('favorites'), // 탭2 루트로 이동
            ),
            _buildDivider(),
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text('최근 본 게시글'),
              onTap: () => context.goNamed('recentPosts'),
            ),
            _buildDivider(),
            ListTile(
              leading: const Icon(Icons.receipt),
              title: const Text('판매내역'),
              onTap: () => context.goNamed('sellHistory'),
            ),
            _buildDivider(),
            ListTile(
              leading: const Icon(Icons.shopping_cart),
              title: const Text('구매내역'),
              onTap: () => context.goNamed('buyHistory'),
            ),
          ],
        ),
      ),
      // ⬇️ 하단바: 탭 인덱스 3(마이)
      // bottomNavigationBar: const AppBottomNav(currentIndex: 3),
    );
  }
}
