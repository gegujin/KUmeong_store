// lib/features/mypage/heart_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:kumeong_store/utils/storage.dart'; // ✅ LoginPage와 동일 스토리지 사용
import 'package:kumeong_store/api_service.dart'; // toggleFavoriteById() 사용

import 'package:kumeong_store/core/router/route_names.dart' as R;
// 하단바가 전역이면 주석 처리 가능
import 'package:kumeong_store/core/widgets/app_bottom_nav.dart';

// ✅ baseUrl: 에뮬레이터 환경에 맞춰 필요시 10.0.2.2로 교체
// Android 에뮬레이터라면: 'http://10.0.2.2:3000/api/v1'
const String baseUrl = 'http://localhost:3000/api/v1';

class HeartPage extends StatefulWidget {
  const HeartPage({super.key});

  @override
  State<HeartPage> createState() => _HeartPageState();
}

class _HeartPageState extends State<HeartPage> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _items = [];

  // ✅ 로그인 화면으로 가는 안전한 헬퍼 (네임드 라우트 우선)
  void _goLogin() {
    if (!mounted) return;
    try {
      context.goNamed(R.RouteNames.login);
      return;
    } catch (_) {}
    context.go('/auth/login'); // 실제 등록된 경로로 교체 가능
  }

  // ✅ LoginPage 기준으로 통일: TokenStorage에서만 읽는다
  Future<String?> _getAccessToken() async {
    try {
      final t = await TokenStorage.getToken(); // String? 반환 가정
      if (t != null && t.trim().isNotEmpty) {
        // ignore: avoid_print
        print('[HeartPage] token loaded from TokenStorage (len=${t.length})');
        return t;
      }
    } catch (e) {
      // ignore: avoid_print
      print('[HeartPage] TokenStorage.getToken() error: $e');
    }
    // ignore: avoid_print
    print('[HeartPage] no token found (TokenStorage)');
    return null;
  }

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final token = await _getAccessToken();
      if (token == null) {
        // 토큰이 없으면 로그인 CTA를 화면에서 보여주기
        setState(() {
          _loading = false;
          _error = null;
        });
        return;
      }

      final res = await http.get(
        Uri.parse('$baseUrl/favorites?page=1&limit=50'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (res.statusCode != 200) {
        setState(() {
          _error = '관심목록 불러오기 실패 (${res.statusCode})';
          _loading = false;
        });
        return;
      }

      // 서버 응답 형태: { items: [...] } 또는 { ok:true, data:{ items:[...] } }
      final body = jsonDecode(res.body);
      final data = body is Map<String, dynamic> && body['data'] != null
          ? body['data'] as Map<String, dynamic>
          : (body as Map<String, dynamic>);

      final List list = (data['items'] as List? ?? []);
      _items = list.map<Map<String, dynamic>>((e) {
        final images = (e['images'] as List?)?.cast<String>() ?? const [];
        return {
          'id': e['id'] as String?,
          'title': e['title'] as String? ?? '',
          'priceWon': e['priceWon'] as int? ?? 0,
          'category': e['category'] as String? ?? '',
          'locationText': e['locationText'] as String? ?? '',
          'createdAt': e['createdAt'] as String? ?? '',
          'thumbnail': (e['thumbnail'] as String?) ??
              (e['thumbnailUrl'] as String?) ??
              (images.isNotEmpty ? images.first : null),
          'isFavorited': true, // 관심목록이므로 항상 true
        };
      }).toList();

      setState(() {
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = '에러: $e';
        _loading = false;
      });
    }
  }

  Future<void> _toggleFavorite(String productId) async {
    try {
      final token = await _getAccessToken();
      if (token == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('로그인이 필요합니다.')),
        );
        return; // 여기서는 강제 이동하지 않음
      }

      final res = await http.post(
        Uri.parse('$baseUrl/favorites/$productId/toggle'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (res.statusCode != 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('찜 토글 실패 (${res.statusCode})')),
        );
        return;
      }

      final m = jsonDecode(res.body) as Map<String, dynamic>;
      final next = m['isFavorited'] == true;

      // 관심목록 화면이므로 next=false면 목록에서 제거
      if (!next) {
        setState(() {
          _items.removeWhere((x) => x['id'] == productId);
        });
      } else {
        await _loadFavorites(); // (거의 없음) next=true면 재로딩
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('에러: $e')),
      );
    }
  }

  String _formatPrice(int won) {
    final s = won.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      final pos = s.length - i;
      buf.write(s[i]);
      if (pos > 1 && pos % 3 == 1) buf.write(',');
    }
    return '$buf원';
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
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : (_items.isEmpty
                  // ✅ 비었을 때: 토큰 없으면 로그인 CTA, 있으면 "없어요" 안내
                  ? FutureBuilder<String?>(
                      future: _getAccessToken(),
                      builder: (context, snap) {
                        final hasToken =
                            snap.connectionState == ConnectionState.done &&
                                (snap.data != null && snap.data!.isNotEmpty);

                        if (!hasToken) {
                          return Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text('로그인이 필요합니다.'),
                                const SizedBox(height: 12),
                                ElevatedButton.icon(
                                  onPressed: _goLogin,
                                  icon: const Icon(Icons.login),
                                  label: const Text('로그인하러 가기'),
                                ),
                              ],
                            ),
                          );
                        }
                        return const Center(child: Text('하트한 상품이 없어요.'));
                      },
                    )
                  : RefreshIndicator(
                      onRefresh: _loadFavorites,
                      child: ListView.separated(
                        itemCount: _items.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1, thickness: 0.5),
                        itemBuilder: (_, index) {
                          final p = _items[index];
                          final productId = p['id'] as String? ?? '';

                          return InkWell(
                            onTap: () {
                              if (productId.isEmpty) return;
                              context.pushNamed(
                                R.RouteNames
                                    .productDetail, // /home/product/:productId
                                pathParameters: {'productId': productId},
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 10),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // 썸네일
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: p['thumbnail'] != null
                                        ? Image.network(
                                            p['thumbnail'] as String,
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
                                            child: const Icon(
                                                Icons.image_not_supported),
                                          ),
                                  ),
                                  const SizedBox(width: 12),
                                  // 텍스트 영역
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // 제목 + 하트
                                        Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                p['title'] as String? ?? '',
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 15,
                                                ),
                                              ),
                                            ),
                                            IconButton(
                                              padding: EdgeInsets.zero,
                                              constraints:
                                                  const BoxConstraints(),
                                              icon: const Icon(
                                                Icons.favorite,
                                                color: Colors.red,
                                                size: 22,
                                              ),
                                              onPressed: () {
                                                if (productId.isNotEmpty) {
                                                  _toggleFavorite(productId);
                                                }
                                              },
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        // 위치/시간 (시간 포맷은 단순 표시)
                                        Text(
                                          [
                                            (p['locationText'] as String?)
                                                        ?.trim()
                                                        .isNotEmpty ==
                                                    true
                                                ? p['locationText'] as String
                                                : '위치 정보 없음',
                                            (p['createdAt'] as String?)
                                                    ?.substring(0, 10) ??
                                                '',
                                          ]
                                              .where((e) => e.isNotEmpty)
                                              .join(' | '),
                                          style: const TextStyle(
                                              color: Colors.grey),
                                        ),
                                        const SizedBox(height: 6),
                                        // 가격
                                        Text(
                                          '가격 ${_formatPrice(p['priceWon'] as int? ?? 0)}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
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
                    )),
      // bottomNavigationBar: const AppBottomNav(currentIndex: 2),
    );
  }
}
