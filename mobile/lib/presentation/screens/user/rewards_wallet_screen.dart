import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../data/services/api_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../widgets/custom_button.dart';

final _walletProvider = FutureProvider((ref) => ApiService.instance.getWallet());
final _txProvider     = FutureProvider((ref) => ApiService.instance.getTransactions());

class RewardsWalletScreen extends ConsumerStatefulWidget {
  const RewardsWalletScreen({super.key});
  @override
  ConsumerState<RewardsWalletScreen> createState() => _RewardsWalletScreenState();
}

class _RewardsWalletScreenState extends ConsumerState<RewardsWalletScreen> {
  bool _showRedeem = false;
  final _pointsCtrl   = TextEditingController();
  final _accountCtrl  = TextEditingController();
  String _method = 'mobile_money';
  bool _redeeming = false;

  Future<void> _redeem() async {
    final pts = int.tryParse(_pointsCtrl.text);
    if (pts == null || pts < 500) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Minimum redemption is 500 points')));
      return;
    }
    setState(() => _redeeming = true);
    try {
      final res = await ApiService.instance.redeemPoints({'points': pts, 'payout_method': _method, 'payout_account': _accountCtrl.text});
      if (!mounted) return;
      if (res['success'] == true) {
        ref.invalidate(_walletProvider);
        ref.invalidate(_txProvider);
        setState(() => _showRedeem = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Redemption requested! GHS ${res['cash_value']} will be sent within 3 business days.'), backgroundColor: Colors.green));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['error'] ?? 'Failed'), backgroundColor: AppColors.error));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error));
    } finally {
      setState(() => _redeeming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final wallet = ref.watch(_walletProvider);
    final txs    = ref.watch(_txProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Rewards Wallet'), backgroundColor: AppColors.primary),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          // Balance card
          wallet.when(
            loading: () => const SizedBox(height: 120, child: Center(child: CircularProgressIndicator(color: Colors.white))),
            error: (e, _) => const SizedBox.shrink(),
            data: (data) {
              final w = data['wallet'] ?? {};
              final balance = w['balance'] ?? 0;
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [AppColors.primary, Color(0xFF1B5E20)]),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(children: [
                  const Icon(Icons.stars_rounded, color: Colors.amber, size: 40),
                  const SizedBox(height: 8),
                  Text('$balance', style: const TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.bold)),
                  const Text('Points Balance', style: TextStyle(color: Colors.white70)),
                  const SizedBox(height: 4),
                  Text('≈ GHS ${(balance / 100).toStringAsFixed(2)}', style: const TextStyle(color: Colors.white60, fontSize: 13)),
                  const SizedBox(height: 20),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                    _StatPill(label: 'Earned', value: '${w['total_earned'] ?? 0}'),
                    _StatPill(label: 'Redeemed', value: '${w['total_redeemed'] ?? 0}'),
                  ]),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: balance >= 500 ? () => setState(() => _showRedeem = !_showRedeem) : null,
                    icon: const Icon(Icons.redeem, size: 18),
                    label: const Text('Redeem Points'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: AppColors.primary),
                  ),
                  if (balance < 500) const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text('Need 500 points to redeem', style: TextStyle(color: Colors.white60, fontSize: 12)),
                  ),
                ]),
              );
            },
          ),

          // Redeem form
          if (_showRedeem) ...[
            const SizedBox(height: 20),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Redeem Points', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 14),
                  TextFormField(controller: _pointsCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Points to Redeem (min 500)', prefixIcon: Icon(Icons.stars_rounded, color: Colors.amber))),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _method,
                    decoration: const InputDecoration(labelText: 'Payout Method'),
                    items: const [
                      DropdownMenuItem(value: 'mobile_money', child: Text('MTN MoMo / Airtel')),
                      DropdownMenuItem(value: 'bank_transfer', child: Text('Bank Transfer')),
                    ],
                    onChanged: (v) => setState(() => _method = v!),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(controller: _accountCtrl, decoration: InputDecoration(labelText: _method == 'mobile_money' ? 'Mobile Number' : 'Account Number', prefixIcon: const Icon(Icons.account_balance_outlined))),
                  const SizedBox(height: 16),
                  CustomButton(text: 'Submit Redemption', isLoading: _redeeming, onPressed: _redeem),
                ]),
              ),
            ),
          ],

          const SizedBox(height: 24),
          // Transaction history
          const Align(alignment: Alignment.centerLeft, child: Text('Transaction History', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
          const SizedBox(height: 12),
          txs.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => const SizedBox.shrink(),
            data: (data) {
              final list = data['transactions'] as List? ?? [];
              if (list.isEmpty) return const Padding(padding: EdgeInsets.all(20), child: Center(child: Text('No transactions yet', style: TextStyle(color: AppColors.textSecondary))));
              return Column(children: list.map((t) => _TxTile(tx: t)).toList());
            },
          ),
        ]),
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final String label, value;
  const _StatPill({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Column(children: [
    Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
    Text(label, style: const TextStyle(color: Colors.white60, fontSize: 12)),
  ]);
}

class _TxTile extends StatelessWidget {
  final Map tx;
  const _TxTile({required this.tx});
  @override
  Widget build(BuildContext context) {
    final earned = tx['type'] == 'earned' || tx['type'] == 'bonus';
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: (earned ? Colors.green : Colors.red).withOpacity(0.1),
        child: Icon(earned ? Icons.add_circle_outline : Icons.remove_circle_outline, color: earned ? Colors.green : Colors.red),
      ),
      title: Text(tx['note'] ?? tx['type'], style: const TextStyle(fontSize: 14)),
      subtitle: Text(DateFormat('dd MMM, HH:mm').format(DateTime.parse(tx['created_at'])), style: const TextStyle(fontSize: 12)),
      trailing: Text('${earned ? '+' : ''}${tx['amount']} pts', style: TextStyle(color: earned ? Colors.green : Colors.red, fontWeight: FontWeight.bold)),
    );
  }
}
