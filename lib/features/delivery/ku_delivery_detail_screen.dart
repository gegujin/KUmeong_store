import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/foundation.dart' show kIsWeb; // ✅ 웹/모바일 분기
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:kumeong_store/models/latlng.dart' as model;
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'package:kumeong_store/core/router/route_names.dart' as R;
import 'dart:math' as math; // ✅ ETA 계산용

// ✅ DeliveryStatus로 이동 시 Args 전달 (경로는 프로젝트에 맞게 조정)
// 맨 위 import 구역
import 'package:kumeong_store/features/delivery/delivery_rider_screen.dart';

const Color kuInfo = Color(0xFF147AD6);

class KuDeliveryDetailArgs {
  final String title;
  final String sellerName;
  final int minutesAgo;
  final String start;
  final String end;
  final int price;
  final String imageUrl;
  final String? sellerAvatarUrl;
  final model.LatLng startCoord;
  final model.LatLng endCoord;

  const KuDeliveryDetailArgs({
    required this.title,
    required this.sellerName,
    required this.minutesAgo,
    required this.start,
    required this.end,
    required this.price,
    required this.imageUrl,
    required this.startCoord,
    required this.endCoord,
    this.sellerAvatarUrl,
  });
}

class KuDeliveryDetailScreen extends StatefulWidget {
  static const String routeName = 'ku-delivery-detail';
  final KuDeliveryDetailArgs args;
  const KuDeliveryDetailScreen({super.key, required this.args});

  @override
  State<KuDeliveryDetailScreen> createState() => _KuDeliveryDetailScreenState();
}

class _KuDeliveryDetailScreenState extends State<KuDeliveryDetailScreen> {
  NaverMapController? _mapController;

  String get _priceText {
    final p = widget.args.price.toString();
    final buf = StringBuffer();
    for (int i = 0; i < p.length; i++) {
      final idx = widget.args.price.toString().length - i;
      buf.write(p[i]);
      if (idx > 1 && idx % 3 == 1) buf.write(',');
    }
    return buf.toString();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: kuInfo,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        title: const Text('배달 상세페이지', style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.home_outlined, color: Colors.white),
            onPressed: () => context.goNamed(R.RouteNames.home), // ✅ 홈 탭으로
          ),
          IconButton(
            icon: const Icon(Icons.share_outlined, color: Colors.white),
            onPressed: () {/* TODO: 공유 */},
          ),
          PopupMenuButton<String>(
            itemBuilder: (ctx) => const [
              PopupMenuItem(value: 'report', child: Text('신고하기')),
              PopupMenuItem(value: 'block', child: Text('차단하기')),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          // 이미지(한눈에 보이게)
          Card(
            color: Colors.white,
            margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            child: SizedBox(
              height: 300,
              child: Center(
                child: Image.network(
                  widget.args.imageUrl,
                  fit: BoxFit.contain,
                  loadingBuilder: (_, child, prog) => prog == null
                      ? child
                      : const Center(
                          child: CircularProgressIndicator(color: kuInfo)),
                  errorBuilder: (_, __, ___) => const Center(
                      child: Icon(Icons.broken_image,
                          size: 48, color: Colors.grey)),
                ),
              ),
            ),
          ),
          const Divider(height: 24),

          // 정보
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundImage: (widget.args.sellerAvatarUrl == null ||
                              widget.args.sellerAvatarUrl!.isEmpty)
                          ? null
                          : NetworkImage(widget.args.sellerAvatarUrl!),
                      child: (widget.args.sellerAvatarUrl == null ||
                              widget.args.sellerAvatarUrl!.isEmpty)
                          ? const Icon(Icons.person_outline)
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.args.sellerName,
                              style: t.titleMedium?.copyWith(color: kuInfo)),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Text(widget.args.title, style: t.bodyMedium),
                              const SizedBox(width: 8),
                              const Text('·'),
                              const SizedBox(width: 8),
                              Text('${widget.args.minutesAgo}분 전',
                                  style: t.bodyMedium),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Text('출발: ${widget.args.start}',
                                  style: t.bodySmall
                                      ?.copyWith(color: Colors.grey[700])),
                              const SizedBox(width: 12),
                              Text('도착: ${widget.args.end}',
                                  style: t.bodySmall
                                      ?.copyWith(color: Colors.grey[700])),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text('가격: $_priceText원',
                    style: t.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700, color: kuInfo)),
              ],
            ),
          ),

          // ── 위치 카드(2번 스샷 스타일) ─────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: _LocationCard(
              title: '위치',
              endName: widget.args.end,
              onOpenMap: _openNaverRoute,
              // 아래 좌표는 플레이스홀더 텍스트에만 사용. (지도를 임시 비활성화)
              start: widget.args.startCoord,
              end: widget.args.endCoord,
              buildMap: (context) {
                // ▼▼▼ 실지도 표시를 원하면 이 블록을 주석 해제하세요 ▼▼▼
                /*
                return NaverMap(
                  options: NaverMapViewOptions(
                    initialCameraPosition: NCameraPosition(
                      target: NLatLng(widget.args.endCoord.lat, widget.args.endCoord.lng),
                      zoom: 15,
                    ),
                    locationButtonEnable: true,
                  ),
                  onMapReady: (controller) async {
                    _mapController = controller;

                    final startMarker = NMarker(
                      id: 'start',
                      position: NLatLng(widget.args.startCoord.lat, widget.args.startCoord.lng),
                      caption: const NOverlayCaption(text: '출발'),
                    );
                    final endMarker = NMarker(
                      id: 'end',
                      position: NLatLng(widget.args.endCoord.lat, widget.args.endCoord.lng),
                      caption: const NOverlayCaption(text: '도착'),
                    );
                    await controller.addOverlayAll({startMarker, endMarker});

                    final routeLine = NPolylineOverlay(
                      id: 'route',
                      coords: [
                        NLatLng(widget.args.startCoord.lat, widget.args.startCoord.lng),
                        NLatLng(widget.args.endCoord.lat, widget.args.endCoord.lng),
                      ],
                      width: 6,
                      color: kuInfo,
                    );
                    await controller.addOverlay(routeLine);
                  },
                );
                */
                // ▲▲▲ 현재는 플레이스홀더 표시 ▲▲▲
                return _MapPlaceholder();
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: SizedBox(
            height: 52,
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: kuInfo),
              // ✅ 여기만 교체됨: 확인 모달 → 네 누르면 DeliveryStatus로 이동
              onPressed: () async {
                final ok = await _confirmProceed(context);
                if (ok != true) return;

                // 간단 ETA 추정
                final meters = _distanceMeters(
                    widget.args.startCoord, widget.args.endCoord);
                final etaMinutes = _estimateEtaMinutes(meters);

                context.pushNamed(
                  R.RouteNames.deliveryRider, // ✅ 라이더 화면 라우트 이름으로 교체
                  extra: DeliveryRiderArgs(
                    orderId: DateTime.now().millisecondsSinceEpoch.toString(),
                    customerName: widget.args.sellerName, // 고객/의뢰자 명으로 쓸 값
                    pickupName: widget.args.start,
                    dropoffName: widget.args.end,
                    price: widget.args.price,
                    moveTypeText: '도보', // 필요 시 실제 이동수단으로 변경
                    pickupCoord: widget.args.startCoord,
                    dropoffCoord: widget.args.endCoord,
                    productTitle: widget.args.title,
                    imageUrl: widget.args.imageUrl,
                    contactPhone: null, // 있으면 채워넣기
                    route: [widget.args.startCoord, widget.args.endCoord],
                  ),
                );
              },

              child: const Text('KU대리 진행하기',
                  style: TextStyle(color: Colors.white)),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openNaverRoute() async {
    model.LatLng? my;
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (await Geolocator.isLocationServiceEnabled() &&
          (perm == LocationPermission.always ||
              perm == LocationPermission.whileInUse)) {
        final pos = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high);
        my = model.LatLng(lat: pos.latitude, lng: pos.longitude);
      }
    } catch (_) {}

    final s = my ?? widget.args.startCoord;
    final d = widget.args.endCoord;

    final scheme = Uri.parse(
      'nmap://route/walk'
      '?slat=${s.lat}&slng=${s.lng}&sname=${Uri.encodeComponent(my != null ? "현재 위치" : widget.args.start)}'
      '&dlat=${d.lat}&dlng=${d.lng}&dname=${Uri.encodeComponent(widget.args.end)}'
      '&appname=com.yourcompany.yourapp',
    );

    if (await canLaunchUrl(scheme)) {
      await launchUrl(scheme);
    } else {
      final web = Uri.parse(
        'https://map.naver.com/v5/directions?navigation=path'
        '&start=${s.lng},${s.lat},${Uri.encodeComponent(my != null ? "현재 위치" : widget.args.start)}'
        '&destination=${d.lng},${d.lat},${Uri.encodeComponent(widget.args.end)}',
      );
      await launchUrl(web, mode: LaunchMode.externalApplication);
    }
  }
}

/// ─────────────────────────────────────────────────────────────
/// 2번 스샷 스타일의 "위치" 카드 + 지도(현재는 플레이스홀더)
class _LocationCard extends StatelessWidget {
  const _LocationCard({
    required this.title,
    required this.endName,
    required this.onOpenMap,
    required this.start,
    required this.end,
    required this.buildMap,
  });

  final String title;
  final String endName;
  final VoidCallback onOpenMap;
  final model.LatLng start;
  final model.LatLng end;

  /// 나중에 지도를 다시 표시할 때 사용할 빌더(지금은 플레이스홀더 반환)
  final WidgetBuilder buildMap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE9EBF0)),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더 라인
          Row(
            children: [
              Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: Color(0xFF121319))),
              const Spacer(),
              TextButton.icon(
                onPressed: onOpenMap,
                icon: const Icon(Icons.map_outlined, size: 18),
                label: const Text('네이버 지도로 보기'),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // 지도 or 플레이스홀더
          Container(
            height: 160,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: kuInfo.withOpacity(0.5)),
            ),
            clipBehavior: Clip.antiAlias,
            child: buildMap(context),
          ),
          const SizedBox(height: 10),

          // 주소/거리 텍스트(간단 버전)
          Text(
            endName,
            style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Color(0xFF121319)),
          ),
          const SizedBox(height: 4),
          Text(
            '길찾기는 상단 버튼을 눌러 네이버 지도에서 확인하세요.',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }
}

/// 현재는 지도 대신 보여줄 플레이스홀더
class _MapPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        kIsWeb ? '웹 미리보기: 지도는 모바일에서 표시됩니다.' : '지도가 여기에 표시됩니다. (임시 비활성화)',
        style:
            const TextStyle(color: Colors.black54, fontWeight: FontWeight.w600),
        textAlign: TextAlign.center,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// ✅ 추가된 유틸리티 (확인 모달, 거리/ETA 계산)
Future<bool?> _confirmProceed(BuildContext context) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('배달 진행'),
      content: const Text('배달을 진행하시겠습니까?\n진행 시 배달 현황 화면으로 이동합니다.'),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('아니오')),
        FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('네')),
      ],
    ),
  );
}

int _estimateEtaMinutes(double meters) {
  // 도보 4.5km/h ≈ 75m/min, 최소 3분 ~ 최대 90분 클램프
  final mpm = 75.0;
  final eta = (meters / mpm).round();
  return eta.clamp(3, 90);
}

double _distanceMeters(model.LatLng a, model.LatLng b) {
  const R = 6371000.0; // 지구 반지름(m)
  double _deg2rad(double d) => d * (math.pi / 180.0);
  final dLat = _deg2rad(b.lat - a.lat);
  final dLon = _deg2rad(b.lng - a.lng);
  final la1 = _deg2rad(a.lat);
  final la2 = _deg2rad(b.lat);

  final h = (math.sin(dLat / 2) * math.sin(dLat / 2)) +
      math.cos(la1) * math.cos(la2) * (math.sin(dLon / 2) * math.sin(dLon / 2));

  final c = 2 * math.atan2(math.sqrt(h), math.sqrt(1 - h));
  return R * c;
}
