import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';

/// 결제 방법 선택 화면
/// [isDelivery]가 true면 '안심 결제' 옵션을 노출
class PaymentMethodScreen extends StatelessWidget {
  const PaymentMethodScreen({
    super.key,
    required this.isDelivery,
    required this.roomId, // 채팅방으로 네비게이션할 때 사용
    this.productId, // 안심결제(백엔드 검증)에 필요(선택적)
    this.partnerName,
    this.productTitle,
    this.price,
    this.imageUrl,
    this.categoryTop,
    this.categorySub,
    this.availablePoints,
  });

  final bool isDelivery; // ✅ KU대리(배달) 여부
  final String roomId;
  final String? productId;

  // 선택: UI/안심결제에 넘길 정보 (없어도 ID로 재조회 가능)
  final String? partnerName;
  final String? productTitle;
  final int? price;
  final String? imageUrl;
  final String? categoryTop;
  final String? categorySub;
  final int? availablePoints;

  /// ✅ 직접 결제 선택
  /// - 배달 흐름(isDelivery=true): 배달 패널만 보이게 (isKuDelivery=true, securePaid=false)
  /// - 대면 흐름(isDelivery=false): 버튼 영구 숨김 위해 (isKuDelivery=false, securePaid=true)
  void _goDirectPay(BuildContext context) {
    final bool kuDelivery = isDelivery;

    context.goNamed(
      'chatRoom',
      pathParameters: {'roomId': roomId},
      extra: {
        'isKuDelivery': kuDelivery, // 배달이면 true → 채팅방에서 배달 패널
        'securePaid':
            kuDelivery ? false : true, // 배달 직결: 패널만(확정 버튼 X) / 대면: 버튼 숨김 처리
        if (partnerName != null) 'partnerName': partnerName,
      },
    );
  }

  /// 안심 결제 선택 → 안심결제 화면으로 이동
  void _goSecurePay(BuildContext context) {
    if (productId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('안심결제에는 productId가 필요합니다.')),
      );
      return;
    }

    context.pushNamed(
      'securePay',
      pathParameters: {'roomId': roomId, 'productId': productId!},
      // extra에는 UI 최적화용 데이터만 전달 — 신뢰 원천은 서버
      extra: {
        'roomId': roomId,
        'productId': productId,
        if (productTitle != null) 'productTitle': productTitle,
        if (price != null) 'price': price,
        if (partnerName != null) 'partnerName': partnerName,
        if (imageUrl != null) 'imageUrl': imageUrl,
        if (categoryTop != null) 'categoryTop': categoryTop,
        if (categorySub != null) 'categorySub': categorySub,
        'availablePoints': availablePoints ?? 0,
        'availableMoney': 0,
        'defaultAddress': '서울특별시 성동구 왕십리로 00, 101동 1001호',
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final kux = Theme.of(context).extension<KuColors>()!;
    final options = <_Option>[
      _Option(
        label: '직접 결제',
        icon: Icons.attach_money,
        color: kux.green,
        onTap: () => _goDirectPay(context),
      ),
      if (isDelivery)
        _Option(
          label: '안심 결제',
          icon: Icons.shield_outlined,
          color: kux.darkGreen,
          onTap: () => _goSecurePay(context),
        ),
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: kux.green,
        title: Text(
          isDelivery ? '결제 방법 (배달)' : '결제 방법 (대면)',
          style: const TextStyle(color: Colors.white),
        ),
        automaticallyImplyLeading: false,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: options
              .map((o) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: _PaymentOptionCard(
                      label: o.label,
                      icon: o.icon,
                      accentColor: o.color,
                      onTap: o.onTap,
                    ),
                  ))
              .toList(),
        ),
      ),
    );
  }
}

class _Option {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _Option({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });
}

class _PaymentOptionCard extends StatelessWidget {
  const _PaymentOptionCard({
    super.key,
    required this.label,
    required this.icon,
    required this.accentColor,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color accentColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        height: 80,
        decoration: BoxDecoration(
          color: accentColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(20),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            const Positioned(
              right: 16,
              child:
                  Icon(Icons.arrow_forward_ios, size: 20, color: Colors.white),
            ),
            Positioned(
              left: 16,
              child: Icon(icon, size: 32, color: Colors.white),
            ),
            Text(
              label,
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}
