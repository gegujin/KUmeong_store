import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:math' as math;
import 'package:kumeong_store/models/latlng.dart' as model;

const Color kuInfo = Color(0xFF147AD6);

class DeliveryRiderArgs {
  final String orderId;
  final String customerName;
  final String pickupName;
  final String dropoffName;
  final int price;
  final String? productTitle;
  final String? imageUrl;
  final String? contactPhone;
  final String moveTypeText; // 도보/자전거/오토바이 등
  final model.LatLng pickupCoord;
  final model.LatLng dropoffCoord;
  final List<model.LatLng>? route;

  DeliveryRiderArgs({
    required this.orderId,
    required this.customerName,
    required this.pickupName,
    required this.dropoffName,
    required this.price,
    required this.moveTypeText,
    required this.pickupCoord,
    required this.dropoffCoord,
    this.productTitle,
    this.imageUrl,
    this.contactPhone,
    this.route,
  });
}

enum RiderStage { newOrder, onPickup, delivering, delivered }

class DeliveryRiderScreen extends StatefulWidget {
  const DeliveryRiderScreen({super.key, required this.args});
  final DeliveryRiderArgs args;

  @override
  State<DeliveryRiderScreen> createState() => _DeliveryRiderScreenState();
}

class _DeliveryRiderScreenState extends State<DeliveryRiderScreen> {
  NaverMapController? _mapCtrl;
  RiderStage _stage = RiderStage.newOrder;
  DateTime _stageStartedAt = DateTime.now();

  // 라이더 전용 컨트롤 상태
  bool _cashReceived = false; // 현장 결제 체크
  final _pickupCodeCtrl = TextEditingController(); // 수거 인증 코드(선택)
  final _dropoffCodeCtrl = TextEditingController(); // 인도 인증 코드(선택)
  bool _busy = false; // 서버 호출 중 로딩

  @override
  void dispose() {
    _pickupCodeCtrl.dispose();
    _dropoffCodeCtrl.dispose();
    _mapCtrl = null;
    super.dispose();
  }

  int get _elapsedMinutes {
    final diff = DateTime.now().difference(_stageStartedAt);
    return diff.inMinutes;
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.args;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: kuInfo,
        title: Text('배달기사 · 주문 #${a.orderId}',
            style: const TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.call, color: Colors.white),
            onPressed: a.contactPhone == null || a.contactPhone!.isEmpty
                ? null
                : () => _call(a.contactPhone!),
            tooltip: '고객에게 전화',
          ),
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline, color: Colors.white),
            onPressed: () {
              // TODO: 채팅 화면으로 이동
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('채팅은 준비 중입니다.')),
              );
            },
            tooltip: '채팅',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _headerCard(a),
          const SizedBox(height: 12),
          _stageCard(a),
          const SizedBox(height: 12),
          _riderQuickActions(a),
          const SizedBox(height: 12),
          _mapCard(a),
          const SizedBox(height: 12),
          _metaCard(a),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: _actionBar(a),
        ),
      ),
    );
  }

  // ───────── UI 블록들 ─────────

  Widget _headerCard(DeliveryRiderArgs a) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kuInfo),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 96,
              height: 96,
              child: (a.imageUrl == null || a.imageUrl!.isEmpty)
                  ? Container(color: kuInfo.withOpacity(0.25))
                  : Image.network(a.imageUrl!, fit: BoxFit.cover),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: DefaultTextStyle(
              style: const TextStyle(color: Colors.black87),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(a.productTitle ?? '요청 상품',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Text('고객: ',
                          style: TextStyle(
                              color: kuInfo, fontWeight: FontWeight.w600)),
                      Text(a.customerName),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Text('수익: ',
                          style: TextStyle(
                              color: kuInfo, fontWeight: FontWeight.w600)),
                      Text(_formatPrice(a.price)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stageCard(DeliveryRiderArgs a) {
    String stageText;
    switch (_stage) {
      case RiderStage.newOrder:
        stageText = '신규 배달 요청';
        break;
      case RiderStage.onPickup:
        stageText = '픽업 중';
        break;
      case RiderStage.delivering:
        stageText = '배달 중';
        break;
      case RiderStage.delivered:
        stageText = '배달 완료';
        break;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kuInfo),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(stageText,
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w800, color: kuInfo)),
          const SizedBox(height: 6),
          Text('경과 시간: 약 $_elapsedMinutes분'),
          const SizedBox(height: 8),
          _riderTimeline(),
        ],
      ),
    );
  }

  Widget _riderQuickActions(DeliveryRiderArgs a) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _chipAction(Icons.qr_code_scanner, '수거 인증', onTap: () async {
          await _openPickupVerifySheet(a);
        }),
        _chipAction(Icons.assignment_turned_in, '인도 인증', onTap: () async {
          await _openDropoffVerifySheet(a);
        }),
        _chipAction(Icons.attach_money, _cashReceived ? '현장 결제(완)' : '현장 결제',
            selected: _cashReceived, onTap: () {
          setState(() => _cashReceived = !_cashReceived);
        }),
        _chipAction(Icons.report, '문제 신고', onTap: () async {
          // TODO: 신고 화면 이동 or 신고 API
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('신고 기능은 준비 중입니다.')),
          );
        }),
        _chipAction(Icons.refresh, '경로 재계산', onTap: () async {
          // TODO: 서버/SDK 경로 재계산 연동
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('경로 재계산…(샘플)')),
          );
        }),
      ],
    );
  }

  Widget _chipAction(IconData icon, String label,
      {VoidCallback? onTap, bool selected = false}) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? kuInfo.withOpacity(0.12) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? kuInfo : Colors.grey.shade300),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 18, color: selected ? kuInfo : Colors.black87),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                color: selected ? kuInfo : Colors.black87,
                fontWeight: FontWeight.w600,
              )),
        ]),
      ),
    );
  }

  Widget _mapCard(DeliveryRiderArgs a) {
    final distanceM = _distanceMeters(a.pickupCoord, a.dropoffCoord);
    final distanceText = _formatDistance(distanceM);

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
          Row(
            children: [
              const Text('위치',
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: Color(0xFF121319))),
              const Spacer(),
              TextButton.icon(
                onPressed: () => _openInNaverMap(
                  start: a.pickupCoord,
                  end: a.dropoffCoord,
                  startName: a.pickupName,
                  endName: a.dropoffName,
                ),
                icon: const Icon(Icons.map_outlined, size: 18),
                label: const Text('네이버 지도로 보기'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            height: 180,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: kuInfo.withOpacity(0.5)),
            ),
            clipBehavior: Clip.antiAlias,
            child: _buildMapOrPlaceholder(a),
          ),
          const SizedBox(height: 10),
          Text(
            '픽업: ${a.pickupName}',
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black87),
          ),
          const SizedBox(height: 4),
          Text(
            '도착: ${a.dropoffName} · ${a.moveTypeText} ${distanceText}',
            style: TextStyle(color: Colors.grey[700]),
          ),
        ],
      ),
    );
  }

  Widget _metaCard(DeliveryRiderArgs a) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kuInfo),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _rowLine('주문번호', '#${a.orderId}'),
          const SizedBox(height: 6),
          _rowLine('이동수단', a.moveTypeText),
          const SizedBox(height: 6),
          _rowLine('수익', _formatPrice(a.price)),
          const SizedBox(height: 6),
          _rowLine('연락처',
              a.contactPhone?.isNotEmpty == true ? a.contactPhone! : '미제공'),
        ],
      ),
    );
  }

  // ───────── 하단 액션바(라이더 플로우) ─────────

  Widget _actionBar(DeliveryRiderArgs a) {
    if (_busy) {
      return FilledButton.icon(
        onPressed: () {},
        icon: const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
        ),
        label: const Text('처리 중…'),
        style: FilledButton.styleFrom(
          backgroundColor: kuInfo,
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
      );
    }

    switch (_stage) {
      case RiderStage.newOrder:
        return Row(
          children: [
            Expanded(
              child: _ctaOutlined(
                label: '거절',
                icon: Icons.close_rounded,
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ctaFilled(
                label: '수락',
                icon: Icons.check_circle_rounded,
                onPressed: () async {
                  final ok = await _confirmSheet(
                    title: '주문 수락',
                    primary: '수락',
                    summary: [
                      ('상품', a.productTitle ?? '요청 상품'),
                      ('픽업', a.pickupName),
                      ('도착', a.dropoffName),
                      ('수익', _formatPrice(a.price)),
                    ],
                  );
                  if (ok == true) {
                    await _withBusy(() async {
                      // TODO: 서버 상태 변경 - accepted/onPickup
                      _moveToStage(RiderStage.onPickup);
                    });
                  }
                },
              ),
            ),
          ],
        );

      case RiderStage.onPickup:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: _ctaOutlined(
                    label: '픽업지 길찾기',
                    icon: Icons.navigation_rounded,
                    onPressed: () => _openInNaverMap(
                      start: a.pickupCoord,
                      end: a.pickupCoord,
                      startName: '내 위치',
                      endName: a.pickupName,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ctaFilled(
                    label: '상품 수거',
                    icon: Icons.inventory_2_rounded,
                    onPressed: () async {
                      final verified = await _openPickupVerifySheet(a);
                      if (verified != true) return;

                      final ok = await _confirmSheet(
                        title: '상품 수거 확인',
                        primary: '배달 시작',
                        summary: [
                          ('픽업', a.pickupName),
                          ('주문', '#${a.orderId}'),
                        ],
                      );
                      if (ok == true) {
                        await _withBusy(() async {
                          // TODO: 서버 상태 변경 - delivering
                          _moveToStage(RiderStage.delivering);
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
          ],
        );

      case RiderStage.delivering:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: _ctaOutlined(
                    label: '도착지 길찾기',
                    icon: Icons.directions_rounded,
                    onPressed: () => _openInNaverMap(
                      start: a.pickupCoord,
                      end: a.dropoffCoord,
                      startName: a.pickupName,
                      endName: a.dropoffName,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ctaFilled(
                    label: '배달 완료',
                    icon: Icons.flag_rounded,
                    onPressed: () async {
                      final verified = await _openDropoffVerifySheet(a);
                      if (verified != true) return;

                      final ok = await _confirmSheet(
                        title: '배달 완료 처리',
                        primary: '완료',
                        summary: [
                          ('도착', a.dropoffName),
                          ('고객', a.customerName),
                          ('정산 예정', _formatPrice(a.price)),
                          if (_cashReceived) ('현장 결제', '수령'),
                        ],
                      );
                      if (ok == true) {
                        await _withBusy(() async {
                          // TODO: 서버 상태 변경 - delivered (+결제/코드/사진 증빙 전송)
                          _moveToStage(RiderStage.delivered);
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
          ],
        );

      case RiderStage.delivered:
        return _ctaTonal(
          label: '닫기',
          icon: Icons.check_rounded,
          onPressed: () => Navigator.of(context).maybePop(),
        );
    }
  }

  // ───────── 타임라인/유틸 ─────────

  Widget _riderTimeline() {
    final steps = [
      ('신규', RiderStage.newOrder),
      ('픽업 중', RiderStage.onPickup),
      ('배달 중', RiderStage.delivering),
      ('완료', RiderStage.delivered),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(steps.length * 2 - 1, (i) {
          if (i.isEven) {
            final step = steps[i ~/ 2];
            final done = _stage.index >= step.$2.index;
            return Column(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: done ? kuInfo : Colors.grey[300],
                  ),
                  child: done
                      ? const Icon(Icons.check, size: 16, color: Colors.white)
                      : null,
                ),
                const SizedBox(height: 4),
                Text(
                  step.$1,
                  style: TextStyle(
                      fontSize: 12, color: done ? kuInfo : Colors.grey[600]),
                ),
              ],
            );
          } else {
            final next = steps[i ~/ 2 + 1].$2;
            final done = _stage.index >= next.index;
            return Container(
              width: 44,
              height: 2,
              color: done ? kuInfo : Colors.grey[300],
            );
          }
        }),
      ),
    );
  }

  Widget _buildMapOrPlaceholder(DeliveryRiderArgs a) {
    if (kIsWeb) {
      return const Center(
        child: Text(
          '웹 미리보기: 지도는 모바일에서 표시됩니다.',
          style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w600),
        ),
      );
    }

    return NaverMap(
      onMapReady: (controller) async {
        _mapCtrl = controller;

        final pickup = NMarker(
          id: 'pickup',
          position: NLatLng(a.pickupCoord.lat, a.pickupCoord.lng),
          caption: const NOverlayCaption(text: '픽업'),
        );
        final dropoff = NMarker(
          id: 'dropoff',
          position: NLatLng(a.dropoffCoord.lat, a.dropoffCoord.lng),
          caption: const NOverlayCaption(text: '도착'),
        );
        await controller.addOverlayAll({pickup, dropoff});

        final points = (a.route != null && a.route!.isNotEmpty)
            ? a.route!
            : <model.LatLng>[a.pickupCoord, a.dropoffCoord];

        final poly = NPolylineOverlay(
          id: 'rider_route',
          coords:
              points.map((p) => NLatLng(p.lat, p.lng)).toList(growable: false),
          width: 6,
          color: kuInfo,
        );
        await controller.addOverlay(poly);

        final bounds = NLatLngBounds(
          southWest: NLatLng(
            _min(a.pickupCoord.lat, a.dropoffCoord.lat),
            _min(a.pickupCoord.lng, a.dropoffCoord.lng),
          ),
          northEast: NLatLng(
            _max(a.pickupCoord.lat, a.dropoffCoord.lat),
            _max(a.pickupCoord.lng, a.dropoffCoord.lng),
          ),
        );
        await controller.updateCamera(NCameraUpdate.fitBounds(bounds));
      },
      options: const NaverMapViewOptions(
        logoClickEnable: false,
        scaleBarEnable: false,
      ),
    );
  }

  void _moveToStage(RiderStage next) {
    setState(() {
      _stage = next;
      _stageStartedAt = DateTime.now();
    });
    // TODO: 서버에 상태 변경 API 호출 (필요 시)
    // ex) PATCH /api/v1/delivery/orders/{id}/status { status: 'onPickup'|'delivering'|'delivered' }
  }

  Future<void> _call(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('전화를 걸 수 없습니다.')));
    }
  }

  Future<bool?> _confirmSheet({
    required String title,
    required String primary,
    List<(String, String)> summary = const [],
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: false,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16 + 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const SizedBox(height: 12),
              Text(title,
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: kuInfo)),
              if (summary.isNotEmpty) const SizedBox(height: 12),
              if (summary.isNotEmpty)
                Column(
                  children: summary
                      .map((e) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            child: _rowLine(e.$1, e.$2),
                          ))
                      .toList(),
                ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: const Text('취소'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: kuInfo,
                      ),
                      onPressed: () => Navigator.of(ctx).pop(true),
                      child: Text(primary,
                          style: const TextStyle(color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // 인증 시트: 수거
  Future<bool?> _openPickupVerifySheet(DeliveryRiderArgs a) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.black12,
                    borderRadius: BorderRadius.circular(99))),
            const SizedBox(height: 12),
            const Text('수거 인증',
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w800, color: kuInfo)),
            const SizedBox(height: 12),
            TextField(
              controller: _pickupCodeCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '픽업 인증 코드(선택)',
                hintText: '예: 4자리 숫자',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('취소'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: kuInfo),
                  onPressed: () {
                    // TODO: 코드 서버 검증 필요 시 호출
                    Navigator.of(ctx).pop(true);
                  },
                  child: const Text('인증 완료',
                      style: TextStyle(color: Colors.white)),
                ),
              ),
            ]),
          ]),
        );
      },
    );
  }

  // 인증 시트: 인도
  Future<bool?> _openDropoffVerifySheet(DeliveryRiderArgs a) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.black12,
                    borderRadius: BorderRadius.circular(99))),
            const SizedBox(height: 12),
            const Text('인도 인증',
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w800, color: kuInfo)),
            const SizedBox(height: 12),
            TextField(
              controller: _dropoffCodeCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '수령 코드(선택)',
                hintText: '예: 6자리',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            CheckboxListTile(
              value: _cashReceived,
              onChanged: (v) => setState(() => _cashReceived = v ?? false),
              title: const Text('현장 결제 수령 완료'),
              controlAffinity: ListTileControlAffinity.leading,
            ),
            const SizedBox(height: 8),
            // TODO: 사진 인증/서명 캔버스/QR 스캔 추가 지점
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('취소'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: kuInfo),
                  onPressed: () {
                    // TODO: 코드/사진/서명 서버 검증 필요 시 호출
                    Navigator.of(ctx).pop(true);
                  },
                  child: const Text('인증 완료',
                      style: TextStyle(color: Colors.white)),
                ),
              ),
            ]),
          ]),
        );
      },
    );
  }

  // 바쁜 상태 묶기
  Future<void> _withBusy(Future<void> Function() task) async {
    setState(() => _busy = true);
    try {
      await task();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ───────── 포맷/수학 유틸 ─────────

  String _formatPrice(int price) {
    final s = price.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      final idx = s.length - i;
      buf.write(s[i]);
      final next = idx - 1;
      if (next > 0 && next % 3 == 0) buf.write(',');
    }
    return '${buf.toString()}원';
  }

  double _distanceMeters(model.LatLng a, model.LatLng b) {
    const R = 6371000.0;
    double _deg2rad(double d) => d * (math.pi / 180.0);
    final dLat = _deg2rad(b.lat - a.lat);
    final dLon = _deg2rad(b.lng - a.lng);
    final la1 = _deg2rad(a.lat);
    final la2 = _deg2rad(b.lat);

    final h = (math.sin(dLat / 2) * math.sin(dLat / 2)) +
        math.cos(la1) *
            math.cos(la2) *
            (math.sin(dLon / 2) * math.sin(dLon / 2));

    final c = 2 * math.atan2(math.sqrt(h), math.sqrt(1 - h));
    return R * c;
  }

  String _formatDistance(double meters) {
    if (meters < 1000) return '${meters.round()}m';
    final km = meters / 1000.0;
    return '${km.toStringAsFixed(km >= 10 ? 0 : 1)}km';
  }

  double _min(double a, double b) => a < b ? a : b;
  double _max(double a, double b) => a > b ? a : b;

  Future<void> _openInNaverMap({
    required model.LatLng start,
    required model.LatLng end,
    required String startName,
    required String endName,
  }) async {
    final scheme = Uri.parse(
      'nmap://route/walk'
      '?slat=${start.lat}&slng=${start.lng}'
      '&sname=${Uri.encodeComponent(startName)}'
      '&dlat=${end.lat}&dlng=${end.lng}'
      '&dname=${Uri.encodeComponent(endName)}'
      '&appname=com.kumeong.store',
    );
    final web = Uri.parse(
      'https://map.naver.com/v5/directions'
      '?navigation=path'
      '&start=${start.lng},${start.lat},${Uri.encodeComponent(startName)}'
      '&destination=${end.lng},${end.lat},${Uri.encodeComponent(endName)}',
    );

    if (await canLaunchUrl(scheme)) {
      await launchUrl(scheme);
      return;
    }
    if (await canLaunchUrl(web)) {
      await launchUrl(web, mode: LaunchMode.externalApplication);
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('네이버 지도를 열 수 없습니다.')),
    );
  }

  // ───────── 버튼 위젯(일관된 스타일) ─────────

  Widget _ctaFilled({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor: kuInfo,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onPressed: onPressed,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(color: Colors.white)),
        ],
      ),
    );
  }

  Widget _ctaOutlined({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14),
        side: BorderSide(color: kuInfo.withOpacity(0.6)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onPressed: onPressed,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: kuInfo),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(color: kuInfo)),
        ],
      ),
    );
  }

  Widget _ctaTonal({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return FilledButton.tonal(
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onPressed: onPressed,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }
}

Widget _rowLine(String label, String value) {
  return RichText(
    text: TextSpan(
      style: const TextStyle(fontSize: 15),
      children: [
        TextSpan(
          text: '$label: ',
          style: const TextStyle(color: kuInfo, fontWeight: FontWeight.w600),
        ),
        TextSpan(
          text: value,
          style: const TextStyle(color: Colors.black87),
        ),
      ],
    ),
  );
}
