import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:kumeong_store/features/home/home_screen.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:go_router/go_router.dart';
import 'package:kumeong_store/models/post.dart';
import 'package:kumeong_store/core/theme.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:kumeong_store/core/router/route_names.dart' as R;

class ProductDetailScreen extends StatefulWidget {
  const ProductDetailScreen({
    super.key,
    required this.productId,
    this.initialProduct,
  });

  final String productId;
  final Product? initialProduct;

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  late final PageController _thumbController;
  int _thumbIndex = 0;

  Product? _product;
  bool _loading = false;
  String? _error;

  bool _creating = false; // 채팅방 생성 중
  bool _liked = true; // 찜 토글 상태

  void _toggleLike() {
    setState(() => _liked = !_liked);
    // TODO: 서버 연동 시 API 호출
    // await wishApi.toggle(productId: widget.productId, liked: _liked);
  }

  @override
  void initState() {
    super.initState();
    _thumbController = PageController();
    _product = widget.initialProduct ?? demoProduct; // TODO: 연동 전 임시
    _loadIfNeeded(); // TODO: 백엔드 연동 포인트
  }

  Future<void> _loadIfNeeded() async {
    // TODO(연동): productId로 API 호출하여 상세 로딩
  }

  String _formatPrice(int p) =>
      '${NumberFormat.decimalPattern('ko_KR').format(p)}원';
  String _timeAgo(DateTime dt) => timeago.format(dt, locale: 'ko');

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    if (_loading && _product == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null && _product == null) {
      return Scaffold(body: Center(child: Text('상품을 불러오지 못했습니다: $_error')));
    }

    final p = _product!;
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
          // 썸네일 카드
          Card(
            color: Colors.white,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            child: SizedBox(
              height: 300,
              child: PageView.builder(
                controller: _thumbController,
                itemCount: p.imageUrls.length,
                onPageChanged: (i) => setState(() => _thumbIndex = i),
                itemBuilder: (_, i) => GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PhotoGalleryPage(
                        images: p.imageUrls,
                        initialIndex: _thumbIndex,
                      ),
                    ),
                  ),
                  child: Image.network(
                    p.imageUrls[i],
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

          // 페이지 인디케이터
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              p.imageUrls.length,
              (i) => Container(
                margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _thumbIndex == i
                      ? colors.primary
                      : colors.onSurface.withAlpha(80),
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
              child: _SellerCard(seller: p.seller, colors: colors),
            ),
          ),

          Divider(height: 24, color: Colors.grey[200]),

          // 제목·가격·등록시간 카드
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
                          _formatPrice(p.price),
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

          // 설명 카드
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

          // 태그 칩 (데모)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _TagChips(tags: const ['운동용품']),
          ),

          const SizedBox(height: 16),

          // 내 위치 → 거래 장소 보기
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.secondaryContainer,
                foregroundColor: colors.onSecondaryContainer,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              icon: const Icon(Icons.my_location),
              label: const Text('내 위치에서 거래 장소 보기'),
              onPressed: _onMapPressed,
            ),
          ),
        ],
      ),

      // 하단 채팅하기 + 찜 버튼
      bottomNavigationBar: _buildBottomBar(colors),
    );
  }

  // 하단 바 (찜 + 채팅하기)
  Widget _buildBottomBar(ColorScheme colors) {
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Row(
        children: [
          // ❤️ 찜 버튼 (토글)
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

          // 🟢 채팅하기 버튼 (기존 동작 유지)
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
              onPressed: _creating ? null : _onStartChatPressed,
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

  // ✅ 채팅방 생성 → 채팅방으로 이동
  Future<void> _onStartChatPressed() async {
    final p = _product!;
    try {
      setState(() => _creating = true);

      // TODO: 실제 API 연동
      final roomId = 'room-demo';

      if (!mounted) return;
      context.pushNamed(
        R.RouteNames.chatRoomOverlay,               // ✅ 오버레이 라우트로!
        pathParameters: {'roomId': roomId},
        extra: {
          'partnerName': p.seller.name,
          'isKuDelivery': false,
          'securePaid': false,
        },
      );
    } 
    catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('채팅방 생성 실패: $e')));
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

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
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
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
    return Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);
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
}

/// 판매자 카드
class _SellerCard extends StatelessWidget {
  const _SellerCard({required this.seller, required this.colors});
  final Seller seller;
  final ColorScheme colors;

  @override
  Widget build(BuildContext context) {
    // 0~5 범위로 클램프
    final double trust = seller.rating.clamp(0, 5).toDouble();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // 왼쪽: 프로필
        CircleAvatar(
          radius: 28,
          backgroundImage: NetworkImage(seller.avatarUrl),
        ),
        const SizedBox(width: 12),

        // 가운데: 이름/지역
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                seller.name,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: colors.primary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                seller.locationName,
                style: TextStyle(
                  color: colors.onSurface.withAlpha((0.7 * 255).round()),
                ),
              ),
            ],
          ),
        ),

        // 오른쪽: 별 + 신로 지수
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            // ⭐ 0.1 단위로 채워지는 인디케이터
            RatingBarIndicator(
              rating: trust,
              itemCount: 5,
              itemSize: 20.0,
              unratedColor: Colors.grey.shade300,
              itemBuilder: (context, index) => const Icon(
                Icons.star,
                color: Colors.orange,
              ),
              direction: Axis.horizontal,
            ),
            const SizedBox(height: 4),

            // 라벨
            Text(
              '신로 지수',
              style: TextStyle(
                fontSize: 12,
                color: colors.onSurface.withOpacity(0.6),
                fontWeight: FontWeight.w600,
              ),
            ),

            // 점수 텍스트 (0.1 단위)
            Text(
              '${trust.toStringAsFixed(1)}/5',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// 전체 화면 이미지 갤러리
class PhotoGalleryPage extends StatefulWidget {
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

class _TagChips extends StatelessWidget {
  const _TagChips({required this.tags});
  final List<String> tags;

  @override
  Widget build(BuildContext context) {
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

class _PhotoGalleryPageState extends State<PhotoGalleryPage> {
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
            loadingBuilder: (_, child, prog) => prog == null
                ? child
                : const Center(child: CircularProgressIndicator()),
            errorBuilder: (_, __, ___) => const Center(
                child: Icon(Icons.broken_image, color: Colors.white, size: 64)),
          ),
        ),
      ),
    );
  }
}
