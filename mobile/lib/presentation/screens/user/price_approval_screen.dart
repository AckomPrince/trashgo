import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../providers/order_provider.dart';
import '../../../data/services/api_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../widgets/custom_button.dart';

class PriceApprovalScreen extends ConsumerStatefulWidget {
  final String orderId;
  const PriceApprovalScreen({super.key, required this.orderId});
  @override
  ConsumerState<PriceApprovalScreen> createState() => _PriceApprovalScreenState();
}

class _PriceApprovalScreenState extends ConsumerState<PriceApprovalScreen> {
  bool _approving = false;
  bool _paying    = false;

  Future<void> _approve() async {
    setState(() => _approving = true);
    final ok = await ref.read(activeOrderProvider.notifier).approvePrice();
    setState(() => _approving = false);
    if (!mounted) return;
    if (ok) _initPayment();
    else ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to approve price')));
  }

  Future<void> _initPayment() async {
    setState(() => _paying = true);
    try {
      final res = await ApiService.instance.initializePayment(widget.orderId);
      if (!mounted) return;
      if (res['success'] == true) {
        // Open Paystack authorization URL in browser
        final url = res['authorization_url'] as String;
        // In production: use url_launcher
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Open: $url'), duration: const Duration(seconds: 10)),
        );
        context.go('/tracking/${widget.orderId}');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error));
    } finally {
      setState(() => _paying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(activeOrderProvider);
    final order = state.order;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Approve Price'), backgroundColor: AppColors.primary),
      body: order == null
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(24),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Center(child: Icon(Icons.receipt_long_outlined, size: 64, color: AppColors.primary)),
                const SizedBox(height: 20),
                const Center(child: Text('Confirm Your Pickup Price', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
                const SizedBox(height: 32),

                _InfoRow(label: 'Waste Type',  value: order.wasteTypeLabel),
                _InfoRow(label: 'Waste Size',  value: (order.wasteSize ?? '—').toUpperCase()),
                _InfoRow(label: 'Address',     value: order.pickupAddress),
                const Divider(height: 32),
                _InfoRow(label: 'Service Fee', value: 'GHS ${order.finalPrice?.toStringAsFixed(2) ?? "—"}', bold: true),

                const Spacer(),

                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                  child: const Row(children: [
                    Icon(Icons.info_outline, color: Colors.orange, size: 20),
                    SizedBox(width: 10),
                    Expanded(child: Text('Payment will only be charged after the pickup is completed.', style: TextStyle(fontSize: 13, color: Colors.orange))),
                  ]),
                ),
                const SizedBox(height: 20),

                CustomButton(
                  text: 'Approve & Pay GHS ${order.finalPrice?.toStringAsFixed(2) ?? "—"}',
                  isLoading: _approving || _paying,
                  onPressed: _approve,
                ),
                const SizedBox(height: 12),
                CustomButton(
                  text: 'Cancel Order',
                  outlined: true,
                  onPressed: () async {
                    await ref.read(activeOrderProvider.notifier).cancelOrder(reason: 'Price declined');
                    if (mounted) context.go('/home');
                  },
                ),
              ]),
            ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label, value;
  final bool bold;
  const _InfoRow({required this.label, required this.value, this.bold = false});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: const TextStyle(color: AppColors.textSecondary)),
      Text(value, style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.w500, fontSize: bold ? 18 : 14, color: bold ? AppColors.primary : AppColors.textPrimary)),
    ]),
  );
}
