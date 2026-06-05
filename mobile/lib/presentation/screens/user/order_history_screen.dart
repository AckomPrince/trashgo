import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../providers/order_provider.dart';
import '../../../data/models/order_model.dart';
import '../../../core/theme/app_theme.dart';
import '../../widgets/custom_button.dart';

class OrderHistoryScreen extends ConsumerStatefulWidget {
  const OrderHistoryScreen({super.key});
  @override
  ConsumerState<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends ConsumerState<OrderHistoryScreen> {
  String? _filter;

  @override
  Widget build(BuildContext context) {
    final history = ref.watch(orderHistoryProvider(_filter));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Pickup History'), backgroundColor: AppColors.primary),
      body: Column(children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(children: [null, 'completed', 'cancelled', 'in_progress'].map((s) => Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(s == null ? 'All' : s.replaceAll('_', ' ').toUpperCase()),
              selected: _filter == s,
              onSelected: (_) => setState(() => _filter = s),
              selectedColor: AppColors.primary.withOpacity(0.2),
              checkmarkColor: AppColors.primary,
            ),
          )).toList()),
        ),
        Expanded(child: history.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text(e.toString())),
          data: (orders) => orders.isEmpty
              ? const Center(child: Text('No pickups found', style: TextStyle(color: AppColors.textSecondary)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: orders.length,
                  itemBuilder: (_, i) => _HistoryCard(order: orders[i]),
                ),
        )),
      ]),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final OrderModel order;
  const _HistoryCard({required this.order});

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 12),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(DateFormat('dd MMM yyyy, HH:mm').format(order.requestedAt), style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          OrderStatusChip(status: order.status),
        ]),
        const SizedBox(height: 8),
        Text(order.pickupAddress, style: const TextStyle(fontWeight: FontWeight.w600), maxLines: 2, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 6),
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: Text(order.wasteTypeLabel, style: const TextStyle(fontSize: 11, color: AppColors.primary)),
          ),
          if (order.finalPrice != null) ...[
            const SizedBox(width: 8),
            Text('GHS ${order.finalPrice!.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
          if (order.pointsAwarded > 0) ...[
            const Spacer(),
            Row(children: [
              const Icon(Icons.stars_rounded, color: Colors.amber, size: 16),
              const SizedBox(width: 4),
              Text('+${order.pointsAwarded} pts', style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.w600, fontSize: 13)),
            ]),
          ],
        ]),
        if (order.isCompleted) ...[
          const Divider(height: 16),
          GestureDetector(
            onTap: () => context.push('/tracking/${order.id}'),
            child: const Text('View Details →', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w500)),
          ),
        ],
      ]),
    ),
  );
}
