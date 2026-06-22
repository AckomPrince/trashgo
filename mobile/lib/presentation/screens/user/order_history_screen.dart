import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../providers/order_provider.dart';
import '../../../data/models/order_model.dart';
import '../../../core/theme/app_theme.dart';
import '../../widgets/custom_button.dart';

class OrderHistoryScreen extends ConsumerStatefulWidget {
  final bool asTab;
  const OrderHistoryScreen({super.key, this.asTab = false});
  @override
  ConsumerState<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends ConsumerState<OrderHistoryScreen> {
  String? _filter;

  @override
  Widget build(BuildContext context) {
    final history = ref.watch(orderHistoryProvider(_filter));

    final body = Column(children: [
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
        child: Row(children: [
          for (final s in [null, 'completed', 'cancelled', 'in_progress'])
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => setState(() => _filter = s),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: _filter == s ? AppColors.primary : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _filter == s ? AppColors.primary : AppColors.divider,
                    ),
                  ),
                  child: Text(
                    s == null
                        ? 'All'
                        : s
                            .replaceAll('_', ' ')
                            .split(' ')
                            .map((w) => w[0].toUpperCase() + w.substring(1))
                            .join(' '),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _filter == s ? Colors.white : AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
        ]),
      ),
      Expanded(
        child: history.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text(e.toString())),
          data: (orders) => orders.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.delete_outline, size: 60, color: Color(0xFFCDD3CD)),
                      SizedBox(height: 12),
                      Text(
                        'No orders here yet',
                        style: TextStyle(fontSize: 14, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                  itemCount: orders.length,
                  itemBuilder: (_, i) => _HistoryCard(order: orders[i]),
                ),
        ),
      ),
    ]);

    if (widget.asTab) return body;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('My Orders'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: body,
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final OrderModel order;
  const _HistoryCard({required this.order});

  Color _badgeBg(String wt) {
    switch (wt) {
      case 'recyclable':
        return const Color(0xFFE8F5E9);
      case 'organic':
        return const Color(0xFFE0F2F1);
      case 'hazardous':
        return const Color(0xFFFFEBEE);
      case 'bulky':
        return const Color(0xFFFFF3E0);
      default:
        return const Color(0xFFEEF1EE);
    }
  }

  Color _badgeFg(String wt) {
    switch (wt) {
      case 'recyclable':
        return const Color(0xFF2E7D32);
      case 'organic':
        return const Color(0xFF00796B);
      case 'hazardous':
        return const Color(0xFFD32F2F);
      case 'bulky':
        return const Color(0xFFF57C00);
      default:
        return const Color(0xFF4B635E);
    }
  }

  IconData _icon(String wt) {
    switch (wt) {
      case 'recyclable':
        return Icons.recycling;
      case 'organic':
        return Icons.eco_outlined;
      case 'hazardous':
        return Icons.warning_amber_outlined;
      case 'bulky':
        return Icons.weekend_outlined;
      default:
        return Icons.delete_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Color(0x0F000000), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: _badgeBg(order.wasteType),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(_icon(order.wasteType), color: _badgeFg(order.wasteType), size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.wasteTypeLabel,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      DateFormat('dd MMM yyyy').format(order.requestedAt),
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              OrderStatusChip(status: order.status),
            ]),
            const SizedBox(height: 10),
            Text(
              order.pickupAddress,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            if (order.finalPrice != null || order.pointsAwarded > 0) ...[
              const SizedBox(height: 10),
              Row(children: [
                if (order.finalPrice != null)
                  Text(
                    'GHS ${order.finalPrice!.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                const Spacer(),
                if (order.pointsAwarded > 0)
                  Row(children: [
                    const Icon(Icons.stars_rounded, color: Colors.amber, size: 15),
                    const SizedBox(width: 3),
                    Text(
                      '+${order.pointsAwarded} pts',
                      style: const TextStyle(
                        color: Colors.amber,
                        fontWeight: FontWeight.w600,
                        fontSize: 12.5,
                      ),
                    ),
                  ]),
              ]),
            ],
          ],
        ),
      ),
    );
  }
}
