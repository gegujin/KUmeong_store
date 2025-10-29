import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';

/// 거래 방법 선택 화면
class TradeConfirmScreen extends StatelessWidget {
  const TradeConfirmScreen({
    super.key,
    this.productId,
    this.roomId,
  });

  final String? productId;
  final String? roomId;

  @override
  Widget build(BuildContext context) {
    final kux = Theme.of(context).extension<KuColors>()!;
    final scheme = Theme.of(context).colorScheme;

    final resolvedRoomId =
        (roomId == null || roomId!.isEmpty) ? 'room-demo' : roomId!;

    void _goPayment({required bool isDelivery}) {
      final qp = <String, String>{
        'delivery': isDelivery ? 'true' : 'false',
        'roomId': resolvedRoomId,
        if (productId != null && productId!.isNotEmpty) 'productId': productId!,
      };
      context.pushNamed('paymentMethod', queryParameters: qp);
    }

    return Scaffold(
      backgroundColor: scheme.background,
      appBar: AppBar(
        backgroundColor: kux.green,
        title: const Text('거래 방법', style: TextStyle(color: Colors.white)),
        leading: const BackButton(color: Colors.white),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _TradeOptionCard(
              accentColor: kux.green,
              label: '대면 거래',
              icon: Icons.handshake_outlined,
              onTap: () => _goPayment(isDelivery: false),
            ),
            const SizedBox(height: 16),
            _TradeOptionCard(
              accentColor: kux.accent,
              label: 'KU대리',
              icon: Icons.local_shipping_outlined,
              onTap: () => _goPayment(isDelivery: true),
            ),
          ],
        ),
      ),
    );
  }
}

class _TradeOptionCard extends StatelessWidget {
  final Color accentColor;
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _TradeOptionCard({
    Key? key,
    required this.accentColor,
    required this.label,
    required this.icon,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final bgColor = accentColor.withOpacity(0.1);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        height: 80,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: accentColor, width: 2),
        ),
        child: Row(
          children: [
            const SizedBox(width: 16),
            Icon(icon, size: 32, color: accentColor),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: accentColor),
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 20),
            const SizedBox(width: 16),
          ],
        ),
      ),
    );
  }
}
