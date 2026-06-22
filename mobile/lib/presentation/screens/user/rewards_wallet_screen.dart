import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../data/services/api_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../widgets/custom_button.dart';

final _walletProvider = FutureProvider((ref) => ApiService.instance.getWallet());
final _txProvider     = FutureProvider((ref) => ApiService.instance.getTransactions());

class RewardsWalletScreen extends ConsumerStatefulWidget {
  final bool asTab;
  const RewardsWalletScreen({super.key, this.asTab = false});
  @override
  ConsumerState<RewardsWalletScreen> createState() => _RewardsWalletScreenState();
}

class _RewardsWalletScreenState extends ConsumerState<RewardsWalletScreen> {
  bool _showRedeem = false;
  final _pointsCtrl  = TextEditingController();
  final _accountCtrl = TextEditingController();
  String _method = 'mobile_money';
  bool _redeeming = false;

  Future<void> _redeem() async {
    final pts = int.tryParse(_pointsCtrl.text);
    if (pts == null || pts < 500) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Minimum redemption is 500 points')),
      );
      return;
    }
    setState(() => _redeeming = true);
    try {
      final res = await ApiService.instance.redeemPoints({
        'points': pts,
        'payout_method': _method,
        'payout_account': _accountCtrl.text,
      });
      if (!mounted) return;
      if (res['success'] == true) {
        ref.invalidate(_walletProvider);
        ref.invalidate(_txProvider);
        setState(() => _showRedeem = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'Redemption requested! GHS ${res['cash_value']} will be sent within 3 business days.'),
          backgroundColor: Colors.green,
        ));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(res['error'] ?? 'Failed'),
          backgroundColor: AppColors.error,
        ));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error),
      );
    } finally {
      setState(() => _redeeming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final wallet = ref.watch(_walletProvider);
    final txs    = ref.watch(_txProvider);

    final body = SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Column(children: [
        // Balance card
        wallet.when(
          loading: () => const SizedBox(
            height: 120,
            child: Center(child: CircularProgressIndicator(color: Colors.white)),
          ),
          error: (e, _) => const SizedBox.shrink(),
          data: (data) {
            final w = data['wallet'] ?? {};
            final balance = w['balance'] ?? 0;
            return Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x4C1B5E20),
                    blurRadius: 26,
                    offset: Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'TrashGo Rewards',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.85),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$balance points',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Redeemable as cash every 3 months',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.75),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(children: [
                    Expanded(
                      child: _StatCard(
                        label: 'Earned',
                        value: '${w['total_earned'] ?? 0}',
                        color: AppColors.primaryBg,
                        textColor: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        label: 'Redeemed',
                        value: '${w['total_redeemed'] ?? 0}',
                        color: const Color(0xFFFFEBEE),
                        textColor: AppColors.error,
                      ),
                    ),
                  ]),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: balance >= 500
                          ? () => setState(() => _showRedeem = !_showRedeem)
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'Redeem Points',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  if (balance < 500)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Center(
                        child: Text(
                          'Need 500 points to redeem',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.65),
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),

        // Redeem form
        if (_showRedeem)
          Container(
            margin: const EdgeInsets.only(top: 20),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(color: Color(0x0F000000), blurRadius: 8, offset: Offset(0, 2)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Redeem Points',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
                const SizedBox(height: 14),
                _PaymentOption(
                  label: 'Mobile Money',
                  sub: 'MTN MoMo / Airtel',
                  selected: _method == 'mobile_money',
                  onTap: () => setState(() => _method = 'mobile_money'),
                ),
                const SizedBox(height: 10),
                _PaymentOption(
                  label: 'Bank Transfer',
                  sub: 'Direct to bank account',
                  selected: _method == 'bank_transfer',
                  onTap: () => setState(() => _method = 'bank_transfer'),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _pointsCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Points to Redeem (min 500)',
                    prefixIcon: Icon(Icons.stars_rounded, color: Colors.amber),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _accountCtrl,
                  decoration: InputDecoration(
                    labelText: _method == 'mobile_money' ? 'Mobile Number' : 'Account Number',
                    prefixIcon: const Icon(Icons.account_balance_outlined),
                  ),
                ),
                const SizedBox(height: 16),
                CustomButton(
                  text: 'Confirm Redemption',
                  isLoading: _redeeming,
                  onPressed: _redeem,
                ),
              ],
            ),
          ),

        const SizedBox(height: 24),

        // Transaction history heading
        const Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Redemption History',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: 12),
        txs.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => const SizedBox.shrink(),
          data: (data) {
            final list = data['transactions'] as List? ?? [];
            if (list.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(20),
                child: Center(
                  child: Text(
                    'No transactions yet',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              );
            }
            return Column(children: list.map((t) => _TxTile(tx: t)).toList());
          },
        ),
      ]),
    );

    if (widget.asTab) return body;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Rewards Wallet'),
        backgroundColor: AppColors.primary,
      ),
      body: body,
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label, value;
  final Color color, textColor;
  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
    required this.textColor,
  });
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: TextStyle(
                color: textColor,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: textColor.withOpacity(0.75),
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
}

class _PaymentOption extends StatelessWidget {
  final String label, sub;
  final bool selected;
  final VoidCallback onTap;
  const _PaymentOption({
    required this.label,
    required this.sub,
    required this.selected,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected ? AppColors.primaryBg : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.divider,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(children: [
            Radio<bool>(
              value: true,
              groupValue: selected,
              onChanged: (_) => onTap(),
              activeColor: AppColors.primary,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  Text(
                    sub,
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ]),
        ),
      );
}

class _TxTile extends StatelessWidget {
  final Map tx;
  const _TxTile({required this.tx});
  @override
  Widget build(BuildContext context) {
    final earned = tx['type'] == 'earned' || tx['type'] == 'bonus';
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
      leading: CircleAvatar(
        radius: 22,
        backgroundColor: earned ? AppColors.primaryBg : AppColors.errorBg,
        child: Icon(
          earned ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
          color: earned ? AppColors.primary : AppColors.error,
          size: 18,
        ),
      ),
      title: Text(
        tx['note'] ?? tx['type'],
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        DateFormat('dd MMM, HH:mm').format(DateTime.parse(tx['created_at'])),
        style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
      ),
      trailing: Text(
        '${earned ? '+' : ''}${tx['amount']} pts',
        style: TextStyle(
          color: earned ? AppColors.primary : AppColors.error,
          fontWeight: FontWeight.w800,
          fontSize: 14,
        ),
      ),
    );
  }
}
