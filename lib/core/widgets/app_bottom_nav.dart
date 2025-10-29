// lib/core/widgets/app_bottom_nav.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kumeong_store/core/router/route_names.dart';

class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    super.key,
    required this.currentIndex,
    this.onTap,
  });

  final int currentIndex;
  final void Function(int index)? onTap;

  static const _routeNames = [
    RouteNames.home,
    RouteNames.chat,
    RouteNames.favorites,
    RouteNames.mypage,
  ];

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      currentIndex: currentIndex,
      selectedItemColor: const Color(0xFF2E7D6B),
      unselectedItemColor: Colors.grey,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home), label: '홈'),
        BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline), label: '1:1채팅'),
        BottomNavigationBarItem(
            icon: Icon(Icons.favorite_border), label: '관심목록'),
        BottomNavigationBarItem(
            icon: Icon(Icons.person_outline), label: '마이페이지'),
      ],
      onTap: (index) {
        if (onTap != null) {
          // ✅ StatefulShellRoute 사용 시
          onTap!(index);
        } else {
          // ↩️ (백업) 기존 goNamed 방식
          context.goNamed(_routeNames[index]);
        }
      },
    );
  }
}
