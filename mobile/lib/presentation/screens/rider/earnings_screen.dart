import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../data/services/api_service.dart';
import '../../../core/theme/app_theme.dart';

final _earningsProvider = FutureProvider.family<Map, String>((ref, period) => ApiService.instance.getEarnings(period: period));

class EarningsScreen extends ConsumerStatefulWidget {
  const EarningsScreen({super.key});
  @override
  ConsumerState<EarningsScreen> createState() => _EarningsScreenState();
}

class _EarningsScreenState extends ConsumerState<EarningsScreen> {
  String _period = 'today';

  @override
  Widget build(BuildContext context) {
    final earnings = ref.watch(_earningsProvider(_period));
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('My Earnings'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.account_balance_wallet_outlined),
            tooltip: 'Wallet & Payouts',
            onPressed: () => context.push('/rider/wallet'),
          ),
        ],
      ),
      body: Column(children: [
        // ── Period segmented control
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(color: const Color(0xFFF1F3F1), borderRadius: BorderRadius.circular(12)),
          child: Row(children: ['today', 'week', 'month', 'all'].map((p) {
            final sel = _period == p;
            return Expanded(child: GestureDetector(
              onTap: () => setState(() => _period = p),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: sel ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                  boxShadow: sel ? const [BoxShadow(color: Color(0x15000000), blurRadius: 4, offset: Offset(0, 1))] : null,
                ),
                child: Text(
                  p == 'today' ? 'Today' : p[0].toUpperCase() + p.substring(1),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                    color: sel ? AppColors.primary : AppColors.textSecondary,
                  ),
                ),
              ),
            ));
          }).toList()),
        ),

        Expanded(child: earnings.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text(e.toString())),
          data: (data) {
            final s = data['summary'] ?? {};
            final recent = data['recent_earnings'] as List? ?? [];
            return ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), children: [
              // ── Summary card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [BoxShadow(color: Color(0x0F000000), blurRadius: 8, offset: Offset(0, 2))],
                ),
                child: Column(children: [
                  const Text('Net Earnings', style: TextStyle(fontSize: 12.5, color: AppColors.textMuted, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 6),
                  Text(
                    'GHS ${double.parse((s['total_net'] ?? 0).toString()).toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w800, color: AppColors.primary),
                  ),
                  Text('from ${s['total_jobs'] ?? 0} jobs', style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted)),
                  const SizedBox(height: 20),
                  Row(children: [
                    _StatChip(
                      label: 'Gross',
                      value: 'GHS ${double.parse((s['total_gross'] ?? 0).toString()).toStringAsFixed(2)}',
                      color: AppColors.infoBg,
                      textColor: AppColors.info,
                    ),
                    const SizedBox(width: 8),
                    _StatChip(
                      label: 'Commission',
                      value: 'GHS ${double.parse((s['total_commission'] ?? 0).toString()).toStringAsFixed(2)}',
                      color: AppColors.errorBg,
                      textColor: AppColors.error,
                    ),
                    const SizedBox(width: 8),
                    _StatChip(
                      label: 'Net',
                      value: 'GHS ${double.parse((s['total_net'] ?? 0).toString()).toStringAsFixed(2)}',
                      color: AppColors.primaryBg,
                      textColor: AppColors.primary,
                    ),
                  ]),
                ]),
              ),

              const SizedBox(height: 24),
              const Text('Recent Jobs', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: AppColors.textPrimary)),
              const SizedBox(height: 12),

              if (recent.isEmpty)
                const Center(child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('No earnings yet', style: TextStyle(color: AppColors.textSecondary)),
                ))
              else
                // ── Recent jobs card
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [BoxShadow(color: Color(0x0F000000), blurRadius: 8, offset: Offset(0, 2))],
                  ),
                  child: Column(children: recent.asMap().entries.map((entry) {
                    final e = entry.value;
                    final last = entry.key == recent.length - 1;
                    return Column(children: [
                      Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(color: AppColors.primaryBg, borderRadius: BorderRadius.circular(10)),
                            child: const Icon(Icons.delete_outline, color: AppColors.primary, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(e['pickup_address'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 2),
                            Text(
                              '${e['waste_type'] ?? ''} · ${DateFormat('dd MMM').format(DateTime.parse(e['created_at']))}',
                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                          ])),
                          Text(
                            '+GHS ${double.parse(e['net'].toString()).toStringAsFixed(2)}',
                            style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.primary, fontSize: 14),
                          ),
                        ]),
                      ),
                      if (!last) const Divider(height: 1, color: Color(0xFFF4F4F4)),
                    ]);
                  }).toList()),
                ),
            ]);
          },
        )),
      ]),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label, value;
  final Color color, textColor;
  const _StatChip({required this.label, required this.value, required this.color, required this.textColor});

  @override
  Widget build(BuildContext context) => Expanded(child: Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(14)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(value, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: textColor), maxLines: 1, overflow: TextOverflow.ellipsis),
      const SizedBox(height: 2),
      Text(label, style: TextStyle(fontSize: 11, color: textColor.withOpacity(0.75))),
    ]),
  ));
}
