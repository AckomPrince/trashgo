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
  ConsumerState<PriceApprovalScreen> createState() =>
      _PriceApprovalScreenState();
}

class _PriceApprovalScreenState extends ConsumerState<PriceApprovalScreen> {
  bool _approving = false;
  bool _paying = false;

  @override
  void initState() {
    super.initState();
    // FIX: load the order when this screen is opened directly; otherwise the
    // active order state may be empty and the approve/pay buttons never show.
    // Defer the mutation until after the first frame to avoid modifying a
    // provider during the widget tree build phase.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(activeOrderProvider.notifier).loadOrder(widget.orderId);
    });
  }

  Future<void> _approve() async {
    setState(() => _approving = true);
    final ok = await ref.read(activeOrderProvider.notifier).approvePrice();
    setState(() => _approving = false);
    if (!mounted) return;
    if (ok) {
      _initPayment();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to approve price')),
      );
    }
  }

  Future<void> _initPayment() async {
    setState(() => _paying = true);
    try {
      final res =
          await ApiService.instance.initializePayment(widget.orderId);
      if (!mounted) return;
      if (res['success'] == true) {
        // Open Paystack authorization URL in browser
        final url = res['authorization_url'] as String;
        // In production: use url_launcher
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Open: $url'),
            duration: const Duration(seconds: 10),
          ),
        );
        context.go('/tracking/${widget.orderId}');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      setState(() => _paying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(activeOrderProvider);
    final order = state.order;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Approve Price'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: order == null
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          // Success badge
                          Container(
                            width: 96,
                            height: 96,
                            decoration: const BoxDecoration(
                              color: AppColors.primaryBg,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check_circle_outline_rounded,
                              color: AppColors.primary,
                              size: 52,
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Waste Size Confirmed',
                            style: TextStyle(
                              fontSize: 21,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Your rider has assessed the waste. Review the price below.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13.5,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 28),

                          // Price card
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x12000000),
                                  blurRadius: 18,
                                  offset: Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                const Text(
                                  'TOTAL PRICE',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textMuted,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'GHS ${order.finalPrice?.toStringAsFixed(2) ?? "—"}',
                                  style: const TextStyle(
                                    fontSize: 38,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.primary,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                // Breakdown rows
                                _PriceRow(
                                  label: 'Waste Type',
                                  value: order.wasteTypeLabel,
                                ),
                                const Divider(
                                    height: 20, color: Color(0xFFF2F2F2)),
                                _PriceRow(
                                  label: 'Size',
                                  value:
                                      (order.wasteSize ?? '—').toUpperCase(),
                                ),
                                const Divider(
                                    height: 20, color: Color(0xFFF2F2F2)),
                                _PriceRow(
                                  label: 'Rider',
                                  value: order.riderName ?? 'Assigned',
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),

                          // Info box
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.warningBg,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.info_outline,
                                    color: AppColors.warning, size: 18),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Payment is charged only after the pickup is completed.',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: AppColors.warning,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),

                  // Sticky bottom
                  Padding(
                    padding:
                        const EdgeInsets.fromLTRB(24, 0, 24, 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CustomButton(
                          text:
                              'Approve & Pay  GHS ${order.finalPrice?.toStringAsFixed(2) ?? "—"}',
                          isLoading: _approving || _paying,
                          onPressed: _approve,
                        ),
                        const SizedBox(height: 10),
                        GestureDetector(
                          onTap: () async {
                            await ref
                                .read(activeOrderProvider.notifier)
                                .cancelOrder(reason: 'Price declined');
                            if (mounted) context.go('/home');
                          },
                          child: const Text(
                            'Cancel Order',
                            style: TextStyle(
                              color: AppColors.error,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _PriceRow extends StatelessWidget {
  final String label, value;
  const _PriceRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      );
}
