// lib/features/chat/product_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';                // ✅ 추가
import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:go_router/go_router.dart';
import 'package:kumeong_store/models/post.dart';
import 'package:kumeong_store/core/theme.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:kumeong_store/core/router/route_names.dart' as R;
import 'package:kumeong_store/features/chat/data/chats_api.dart';         // ✅ ChatsApi 사용
import 'package:kumeong_store/features/chat/state/chat_rooms_provider.dart'; // ✅ 목록 갱신용 추가

// 서버 요청
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const String baseUrl = 'http://localhost:3000/api/v1';

class ProductDetailScreen extends ConsumerStatefulWidget {               // ✅ 변경
  const ProductDetailScreen({
    super.key,
    required this.productId,
    this.initialProduct,
  });

  final String productId;
  final Product? initialProduct;

  @override
  ConsumerState<ProductDetailScreen> createState() => _ProductDetailScreenState(); // ✅ 변경
}

class _ProductDetailScreenState extends ConsumerState<ProductDetailScreen> {      // ✅ 변경
  late final PageController _thumbController;
  int _thumbIndex = 0;

  bool _isUnknownText(String? s) {
    if (s == null) return true;
    final t = s.trim();
    return t.isEmpty || t == '알 수 없음';
  }

  Product? _product;
  bool _loading = false;
  String? _error;

  bool _creating = false; // 채팅방 생성 중
  bool _liked = true; // 찜 토글 상태
  bool _liking = false; // 찜 토글 요청 중

  // ---------- 인증/요청 유틸 ----------
  Future<Map<String, String>> _authHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken');
    final h = <String, String>{'Content-Type': 'application/json; charset=utf-8'};
    if (token != null && token.isNotEmpty) h['Authorization'] = 'Bearer $token';
    return h;
  }

  Future<Product> _fetchProduct(String id) async {
    final uri = Uri.parse('$baseUrl/products/$id');
    final res = await http.get(uri, headers: await _authHeaders());
    if (res.statusCode != 200) {
      throw '상세 조회 실패 ${res.statusCode}: ${res.body}';
    }
    final data = jsonDecode(res.body);
    final map = data is Map && data['data'] != null ? data['data'] : data;
    return Product.fromJson(map as Map<String, dynamic>);
  }
  // -----------------------------------

  @override
  void initState() {
    super.initState();
    _thumbController = PageController();

    if (widget.initialProduct != null) {
      _product = widget.initialProduct;
      try {
        final dyn = widget.initialProduct as dynamic;
        if (dyn != null && dyn.isFavorited is bool) {
          _liked = dyn.isFavorited as bool;
        }
      } catch (_) {}
    }

    _loadIfNeeded();
  }

  @override
  void dispose() {
    _thumbController.dispose();
    super.dispose();
  }

  Future<void> _loadIfNeeded() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final fresh = await _fetchProduct(widget.productId);
      await _fillSellerNameIfMissing(fresh);
      _product = fresh;

      try {
        final dyn = fresh as dynamic;
        if (dyn.isFavorited is bool) _liked = (dyn.isFavorited as bool);
      } catch (_) {}

      setState(() {});
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ========================= 헬퍼들 =========================

  String _firstNonEmptyString(List<dynamic> candidates) {
    for (final c in candidates) {
      if (c == null) continue;
      if (c is String && c.trim().isNotEmpty) return c.trim();
      if (c is Map) {
        final n = c['name'] ?? c['nickname'] ?? c['displayName'];
        if (n is String && n.trim().isNotEmpty) return n.trim();
      }
    }
    return '';
  }

  String _textFrom(dynamic obj, List<String> keys) {
    if (obj is! Map) return '';
    for (final k in keys) {
      final v = obj[k];
      if (v is String && v.trim().isNotEmpty) return v.trim();
    }
    return '';
  }

  String _sellerName(Product p) {
    try {
      if (p.seller.name.trim().isNotEmpty) {
        final n = p.seller.name.trim();
        return _isUnknownText(n) ? '' : n;
      }
    } catch (_) {}
    try {
      final dyn = p as dynamic;
      final candidate = _firstNonEmptyString([
        dyn.seller,
        dyn.user,
        dyn.owner,
        dyn.author,
        dyn.createdBy,
        dyn.writer,
        dyn.account,
        dyn.profile,
        dyn.sellerName,
        dyn.userName,
        dyn.ownerName,
        dyn.authorName,
        dyn.nickname,
        dyn.nickName,
        dyn.displayName,
      ]);
      return _isUnknownText(candidate) ? '' : candidate;
    } catch (_) {}
    return '';
  }

  String _sellerLocation(Product p) {
    try {
      if (p.seller.locationName.trim().isNotEmpty) {
        return p.seller.locationName.trim();
      }
    } catch (_) {}

    try {
      final dyn = p as dynamic;

      final single = _firstNonEmptyString([
        dyn.locationName,
        dyn.regionName,
        dyn.addressText,
        dyn.placeName,
        dyn.tradeArea,
        dyn.tradeLocationName,
        dyn.meetingLocationName,
        dyn.meetPlaceName,
        dyn.areaName,
        dyn.guName,
        dyn.dongName,
      ]);
      if (single.isNotEmpty) return single;

      final objCandidates = [
        dyn.location,
        dyn.address,
        dyn.meetingPlace,
        dyn.meetingLocation,
        dyn.tradeLocation,
      ];

      for (final o in objCandidates) {
        if (o is Map) {
          final byName = _textFrom(o, ['name', 'label', 'alias']);
          if (byName.isNotEmpty) return byName;

          final partsRaw = [
            o['sido'] ?? o['province'],
            o['sigungu'] ?? o['city'] ?? o['district'],
            o['dong'] ?? o['town'] ?? o['neighborhood'],
            o['detail'] ?? o['roadAddress'] ?? o['street'],
          ];
          final parts =
              partsRaw.whereType<String>().map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
          if (parts.isNotEmpty) return parts.join(' ');
        }
      }
    } catch (_) {}

    return '';
  }

  double _sellerRating(Product p) {
    try {
      final r = p.seller.rating;
      final v = (r is num ? r.toDouble() : 0.0);
      return v.clamp(0.0, 5.0).toDouble();
    } catch (_) {}
    try {
      final dyn = p as dynamic;
      final r = dyn.rating ?? dyn.trustScore ?? dyn.reliability ?? 0.0;
      final v = (r is num ? r.toDouble() : 0.0);
      return v.clamp(0.0, 5.0).toDouble();
    } catch (_) {}
    return 0.0;
  }

  String? _sellerAvatar(Product p) {
    try {
      if (p.seller.avatarUrl.trim().isNotEmpty) {
        return p.seller.avatarUrl.trim();
      }
    } catch (_) {}

    try {
      final dyn = p as dynamic;

      final direct = _firstNonEmptyString([
        dyn.avatarUrl,
        dyn.profileImageUrl,
        dyn.userAvatar,
      ]);
      if (direct.isNotEmpty) return direct;

      for (final o in [dyn.seller, dyn.user, dyn.owner, dyn.author, dyn.profile, dyn.account]) {
        if (o is Map) {
          final a = _firstNonEmptyString([
            o['avatarUrl'],
            o['profileImageUrl'],
            o['imageUrl'],
          ]);
          if (a.isNotEmpty) return a;
        }
      }
    } catch (_) {}

    return null;
  }

  int _getPrice(Product p) {
    try {
      final dyn = p as dynamic;
      final v = dyn.priceWon ?? dyn.price ?? 0;
      return v is num ? v.toInt() : int.tryParse(v.toString()) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  String _formatPrice(int p) => '${NumberFormat.decimalPattern('ko_KR').format(p)}원';
  String _timeAgo(DateTime dt) => timeago.format(dt, locale: 'ko');

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    if (_product == null && _loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_product == null && _error != null) {
      return Scaffold(body: Center(child: Text('상품을 불러오지 못했습니다: $_error')));
    }
    if (_product == null) {
      return const Scaffold(body: Center(child: Text('상품 데이터가 없습니다.')));
    }

    final p = _product!;

    final String sellerName = (() {
      try {
        final n = p.seller.name;
        if (n is String && n.trim().isNotEmpty) return n.trim();
      } catch (_) {}
      return _sellerName(p);
    })();
    final String displaySellerName = _isUnknownText(sellerName) ? '' : sellerName;

    final String productAddress = (() {
      try {
        final dyn = p as dynamic;
        if (dyn.locationText is String && dyn.locationText.trim().isNotEmpty) {
          return dyn.locationText.trim();
        }
        if (dyn.addressText is String && dyn.addressText.trim().isNotEmpty) {
          return dyn.addressText.trim();
        }
      } catch (_) {}
      try {
        final s = p.seller.locationName;
        if (s is String && s.trim().isNotEmpty) return s.trim();
      } catch (_) {}
      return _sellerLocation(p);
    })();

    final List<String> images = (() {
      try {
        final imgs = p.imageUrls;
        if (imgs is List<String> && imgs.isNotEmpty) return imgs;
      } catch (_) {}
      return const <String>[];
    })();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: colors.primary,
        title: const Text('상품 상세페이지'),
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            context.go('/home');
          },
        ),
        actions: const [
          Icon(Icons.share_outlined, color: Colors.white),
          SizedBox(width: 8),
          Icon(Icons.more_vert, color: Colors.white),
          SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: [
          // 썸네일
          Card(
            color: Colors.white,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            child: SizedBox(
              height: 300,
              child: images.isEmpty
                  ? const Center(child: Icon(Icons.image_not_supported, size: 64))
                  : PageView.builder(
                      controller: _thumbController,
                      itemCount: images.length,
                      onPageChanged: (i) => setState(() => _thumbIndex = i),
                      itemBuilder: (_, i) => GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PhotoGalleryPage(
                              images: images,
                              initialIndex: _thumbIndex,
                            ),
                          ),
                        ),
                        child: Image.network(
                          images[i],
                          fit: BoxFit.contain,
                          loadingBuilder: (_, child, prog) => prog == null
                              ? child
                              : const Center(child: CircularProgressIndicator()),
                          errorBuilder: (_, __, ___) =>
                              const Center(child: Icon(Icons.broken_image, size: 48)),
                        ),
                      ),
                    ),
            ),
          ),

          if (images.isNotEmpty)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                images.length,
                (i) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _thumbIndex == i ? colors.primary : colors.onSurface.withAlpha(80),
                  ),
                ),
              ),
            ),

          Divider(height: 24, color: Colors.grey[200]),

          // 판매자 카드
          Card(
            color: Colors.white,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: _SellerCard(
                name: displaySellerName,
                location: productAddress,
                rating: _sellerRating(p),
                avatarUrl: _sellerAvatar(p),
                colors: colors,
              ),
            ),
          ),

          Divider(height: 24, color: Colors.grey[200]),

          // 제목·가격·등록시간
          Card(
            color: Colors.white,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.title,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: colors.primary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _formatPrice(_getPrice(p)),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    _timeAgo(p.createdAt),
                    style: TextStyle(color: colors.onSurface.withAlpha(150)),
                  ),
                ],
              ),
            ),
          ),

          Divider(height: 24, color: Colors.grey[200]),

          // 설명
          Card(
            color: Colors.white,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                p.description,
                style: TextStyle(fontSize: 16, color: colors.onSurface),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // 태그 칩 (임시)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _TagChips(tags: const ['운동용품']),
          ),

          const SizedBox(height: 16),
        ],
      ),

      // 하단 채팅하기 + 찜 버튼
      bottomNavigationBar: _buildBottomBar(colors),
    );
  }

  Widget _buildBottomBar(ColorScheme colors) {
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Row(
        children: [
          // ❤️ 찜 버튼
          IconButton(
            iconSize: 28,
            splashRadius: 24,
            onPressed: _toggleLike,
            icon: Icon(
              _liked ? Icons.favorite : Icons.favorite_border,
              color: _liked ? Colors.redAccent : Colors.grey,
            ),
          ),
          const SizedBox(width: 12),

          // 🟢 채팅하기 버튼 — ChatsApi 사용 + 목록 즉시 갱신
          Expanded(
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: colors.primary,
                foregroundColor: colors.onPrimary,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: _creating
                  ? null
                  : () async {
                      if (_product == null) return;
                      setState(() => _creating = true);
                      try {
                        final productId = widget.productId; // UUID 사용
                        final roomId = await chatsApi.ensureTrade(productId); // ✅ ChatsApi 호출

                        // ✅ 채팅목록 즉시 갱신
                        await ref.read(chatRoomsProvider.notifier).refresh();

                        if (!mounted) return;
                        context.pushNamed(
                          R.RouteNames.chatRoom,
                          pathParameters: {'roomId': roomId},
                          extra: {
                            'peerId': _product!.seller.id,
                            'peerName': _sellerName(_product!),
                            'isTrade': true,
                          },
                        );
                      } catch (e) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('채팅방 생성 실패: $e')),
                        );
                      } finally {
                        if (mounted) setState(() => _creating = false);
                      }
                    },
              child: _creating
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('채팅하기', style: TextStyle(fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }

  // ❤️ 찜 토글
  Future<void> _toggleLike() async {
    if (_liking) return;
    setState(() => _liking = true);

    final String id = widget.productId;
    if (id.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('상품 ID를 찾지 못했어요.')),
      );
      setState(() => _liking = false);
      return;
    }

    final prev = _liked;
    setState(() => _liked = !prev);

    try {
      final next = await _apiToggleFavorite(id);
      if (next == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('로그인이 필요하거나 요청이 실패했어요.')),
        );
      } else if (next != _liked) {
        if (!mounted) return;
        setState(() => _liked = next);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _liked = prev);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('실패: $e')),
      );
    } finally {
      if (mounted) setState(() => _liking = false);
    }
  }

  Future<bool?> _apiToggleFavorite(String productId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('accessToken');
    final headers = <String, String>{
      'Content-Type': 'application/json; charset=utf-8',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };

    final uri = Uri.parse('$baseUrl/favorites/$productId/toggle');
    final res = await http.post(uri, headers: headers);

    if (res.statusCode == 401) return null;
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw '즐겨찾기 토글 실패 ${res.statusCode}: ${res.body}';
    }

    final obj = jsonDecode(res.body);
    if (obj is Map) {
      if (obj['isFavorited'] is bool) return obj['isFavorited'] as bool;
      final data = obj['data'];
      if (data is Map && data['isFavorited'] is bool) {
        return data['isFavorited'] as bool;
      }
    }
    return null;
  }

  // --- 지도/위치 (옵션) ---
  Future<void> _onMapPressed() async {
    if (!mounted) return;
    final p = _product!;
    try {
      final pos = await _getCurrentLocation();
      if (!mounted) return;
      await _openNaverMap(
        pos.latitude,
        pos.longitude,
        p.location.lat,
        p.location.lng,
        p.seller.locationName,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<Position> _getCurrentLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      await Geolocator.openLocationSettings();
      throw '위치 서비스가 꺼져 있습니다.';
    }
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied) {
        throw '위치 권한이 거부되었습니다.';
      }
    }
    return Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
  }

  Future<void> _openNaverMap(
    double myLat,
    double myLng,
    double destLat,
    double destLng,
    String destName,
  ) async {
    const sName = '현재 위치';
    final scheme = Uri.parse(
      'nmap://route/walk'
      '?slat=$myLat&slng=$myLng'
      '&sname=${Uri.encodeComponent(sName)}'
      '&dlat=$destLat&dlng=$destLng'
      '&dname=${Uri.encodeComponent(destName)}'
      '&appname=com.yourcompany.yourapp',
    );
    if (await canLaunchUrl(scheme)) {
      await launchUrl(scheme);
      return;
    }
    final web = Uri.parse(
      'https://map.naver.com/v5/directions'
      '?navigation=path'
      '&start=$myLng,$myLat,${Uri.encodeComponent(sName)}'
      '&destination=$destLng,$destLat,${Uri.encodeComponent(destName)}',
    );
    if (await canLaunchUrl(web)) {
      await launchUrl(web, mode: LaunchMode.externalApplication);
      return;
    }
    throw '네이버 지도를 열 수 없습니다.';
  }

  // --- 판매자 이름 보정 ---
  Future<String?> _fetchUserNameById(String userId) async {
    if (userId.isEmpty) return null;
    final uri = Uri.parse('$baseUrl/users/$userId');
    final res = await http.get(uri, headers: await _authHeaders());
    if (res.statusCode != 200) return null;

    final obj = jsonDecode(res.body);
    final data = (obj is Map) ? (obj['data'] ?? obj) : null;
    if (data is Map) {
      final n = data['name'];
      if (n is String && n.trim().isNotEmpty) return n.trim();
    }
    return null;
  }

  Future<void> _fillSellerNameIfMissing(Product p) async {
    final currentName = p.seller.name.trim();
    final sellerId = p.seller.id.trim();
    if (!_isUnknownText(currentName)) return;
    if (sellerId.isEmpty) return;

    final fetched = await _fetchUserNameById(sellerId);
    if (fetched == null || fetched.isEmpty) return;

    if (!mounted) return;
    setState(() {
      _product = p.copyWith(seller: p.seller.copyWith(name: fetched));
    });
  }
}

// ======================= Sub Widgets =======================
// (아래 SubWidget 들은 변경 없음 — 그대로 사용)
class _SellerCard extends StatelessWidget { /* ... 그대로 ... */ 
  const _SellerCard({
    required this.name,
    required this.location,
    required this.rating,
    required this.avatarUrl,
    required this.colors,
  });
  final String name; final String location; final double rating; final String? avatarUrl; final ColorScheme colors;
  @override
  Widget build(BuildContext context) { /* 원문 그대로 */ 
    final double safeRating = rating.clamp(0.0, 5.0).toDouble();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        CircleAvatar(
          radius: 28,
          backgroundImage:
              (avatarUrl != null && avatarUrl!.isNotEmpty) ? NetworkImage(avatarUrl!) : null,
          child: (avatarUrl == null || avatarUrl!.isEmpty)
              ? (name.isNotEmpty
                  ? Text(
                      name[0].toUpperCase(),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                    )
                  : null)
              : null,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (name.isNotEmpty)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: colors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green.shade300),
                      ),
                      child: const Text(
                        '판매자',
                        style: TextStyle(
                          color: Colors.green,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              if (name.isNotEmpty) const SizedBox(height: 4),
              if (location.isNotEmpty)
                Text(
                  location,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: colors.onSurface.withOpacity(0.7)),
                ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            RatingBarIndicator(
              rating: safeRating,
              itemCount: 5,
              itemSize: 20.0,
              unratedColor: Colors.grey.shade300,
              itemBuilder: (context, index) => const Icon(Icons.star, color: Colors.orange),
              direction: Axis.horizontal,
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '신뢰 지수',
                  style: TextStyle(
                    fontSize: 12,
                    color: colors.onSurface.withOpacity(0.6),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${safeRating.toStringAsFixed(1)}/5',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

class _TagChips extends StatelessWidget { /* ... 그대로 ... */ 
  const _TagChips({required this.tags});
  final List<String> tags;
  @override
  Widget build(BuildContext context) { /* 원문 그대로 */ 
    final cs = Theme.of(context).colorScheme;
    final kux = Theme.of(context).extension<KuColors>()!;
    if (tags.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: tags.map((t) {
        return Chip(
          label: Text(
            t,
            style: TextStyle(color: cs.onSurface, fontWeight: FontWeight.w600),
          ),
          backgroundColor: Colors.white,
          shape: StadiumBorder(side: BorderSide(color: kux.accentSoft)),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          padding: const EdgeInsets.symmetric(horizontal: 10),
        );
      }).toList(),
    );
  }
}

class PhotoGalleryPage extends StatefulWidget { /* ... 그대로 ... */ 
  const PhotoGalleryPage({
    super.key,
    required this.images,
    this.initialIndex = 0,
  });
  final List<String> images;
  final int initialIndex;
  @override
  State<PhotoGalleryPage> createState() => _PhotoGalleryPageState();
}

class _PhotoGalleryPageState extends State<PhotoGalleryPage> { /* ... 그대로 ... */ 
  late final PageController _controller;
  late int _current;
  @override
  void initState() {
    super.initState();
    _current = widget.initialIndex;
    _controller = PageController(initialPage: _current);
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kuBlack,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(
          '${_current + 1} / ${widget.images.length}',
          style: const TextStyle(color: Colors.white),
        ),
      ),
      body: PageView.builder(
        controller: _controller,
        itemCount: widget.images.length,
        onPageChanged: (i) => setState(() => _current = i),
        itemBuilder: (_, i) => InteractiveViewer(
          panEnabled: true,
          minScale: 1.0,
          maxScale: 4.0,
          child: Image.network(
            widget.images[i],
            fit: BoxFit.contain,
            loadingBuilder: (_, child, prog) =>
                prog == null ? child : const Center(child: CircularProgressIndicator()),
            errorBuilder: (_, __, ___) =>
                const Center(child: Icon(Icons.broken_image, color: Colors.white, size: 64)),
          ),
        ),
      ),
    );
  }
}
