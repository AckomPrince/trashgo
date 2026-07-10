import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../data/services/api_service.dart';
import '../../../core/theme/app_theme.dart';

// S1 wallet + P payouts. Riders see their balance, saved MoMo/bank methods,
// withdraw to a recipient, and review payout history.
final _walletProvider = FutureProvider.autoDispose<Map>((ref) => ApiService.instance.getRiderWallet());
final _payoutsProvider = FutureProvider.autoDispose<Map>((ref) => ApiService.instance.getPayouts());
final _recipientsProvider = FutureProvider.autoDispose<Map>((ref) => ApiService.instance.getPayoutRecipients());

double _num(dynamic v) => double.tryParse((v ?? 0).toString()) ?? 0;

class RiderWalletScreen extends ConsumerWidget {
  const RiderWalletScreen({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(_walletProvider);
    ref.invalidate(_payoutsProvider);
    ref.invalidate(_recipientsProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wallet = ref.watch(_walletProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Wallet & Payouts'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: () => _refresh(ref),
        child: wallet.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(children: [Padding(padding: const EdgeInsets.all(24), child: Text('Failed to load wallet: $e'))]),
          data: (w) {
            final bal = _num(w['wallet']?['balance']);
            final earned = _num(w['wallet']?['total_earned']);
            final withdrawn = _num(w['wallet']?['total_withdrawn']);
            return ListView(padding: const EdgeInsets.all(16), children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Available balance', style: TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 6),
                  Text('GHS ${bal.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 16),
                  Row(children: [
                    Expanded(child: _mini('Earned', 'GHS ${earned.toStringAsFixed(2)}')),
                    Expanded(child: _mini('Withdrawn', 'GHS ${withdrawn.toStringAsFixed(2)}')),
                  ]),
                ]),
              ),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(child: ElevatedButton.icon(
                  onPressed: bal > 0 ? () => _withdrawDialog(context, ref, bal) : null,
                  icon: const Icon(Icons.account_balance_wallet_outlined, size: 18),
                  label: const Text('Withdraw'),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
                )),
                const SizedBox(width: 12),
                Expanded(child: OutlinedButton.icon(
                  onPressed: () => _addRecipientDialog(context, ref),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add method'),
                  style: OutlinedButton.styleFrom(foregroundColor: AppColors.primary, padding: const EdgeInsets.symmetric(vertical: 14)),
                )),
              ]),
              const SizedBox(height: 24),
              const Text('Payout methods', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              const SizedBox(height: 10),
              _recipientsList(ref),
              const SizedBox(height: 24),
              const Text('Payout history', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              const SizedBox(height: 10),
              _payoutsList(ref),
            ]);
          },
        ),
      ),
    );
  }

  Widget _mini(String label, String value) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 11)),
      ]);

  Widget _recipientsList(WidgetRef ref) {
    final recs = ref.watch(_recipientsProvider);
    return recs.when(
      loading: () => const Padding(padding: EdgeInsets.all(12), child: LinearProgressIndicator()),
      error: (e, _) => Text('$e'),
      data: (d) {
        final list = (d['recipients'] as List?) ?? [];
        if (list.isEmpty) return const Text('No payout methods yet. Add one to withdraw.', style: TextStyle(color: AppColors.textSecondary));
        return Column(children: list.map((r) => Card(
          child: ListTile(
            leading: const Icon(Icons.phone_android, color: AppColors.primary),
            title: Text('${r['provider'] ?? r['type']} · ${r['account_number']}'),
            subtitle: Text(r['account_name'] ?? ''),
            trailing: (r['is_default'] == true) ? const Chip(label: Text('Default')) : null,
          ),
        )).toList());
      },
    );
  }

  Widget _payoutsList(WidgetRef ref) {
    final pos = ref.watch(_payoutsProvider);
    return pos.when(
      loading: () => const Padding(padding: EdgeInsets.all(12), child: LinearProgressIndicator()),
      error: (e, _) => Text('$e'),
      data: (d) {
        final list = (d['payouts'] as List?) ?? [];
        if (list.isEmpty) return const Text('No payouts yet.', style: TextStyle(color: AppColors.textSecondary));
        return Column(children: list.map((p) {
          final status = (p['status'] ?? '').toString();
          return Card(child: ListTile(
            title: Text('GHS ${_num(p['amount']).toStringAsFixed(2)}'),
            subtitle: Text(p['created_at'] != null ? DateFormat('dd MMM, HH:mm').format(DateTime.parse(p['created_at'])) : ''),
            trailing: Text(status.toUpperCase(), style: TextStyle(
              fontWeight: FontWeight.w700,
              color: status == 'paid' ? AppColors.primary : (status == 'failed' || status == 'reversed' ? AppColors.error : AppColors.info),
            )),
          ));
        }).toList());
      },
    );
  }

  Future<void> _withdrawDialog(BuildContext context, WidgetRef ref, double balance) async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Withdraw to MoMo/Bank'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('Available: GHS ${balance.toStringAsFixed(2)}', style: const TextStyle(color: AppColors.textSecondary)),
        const SizedBox(height: 12),
        TextField(controller: ctrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Amount (GHS)')),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Withdraw')),
      ],
    ));
    if (ok != true) return;
    final amount = double.tryParse(ctrl.text.trim());
    if (amount == null || amount <= 0) return;
    try {
      await ApiService.instance.initiatePayout(amount: amount);
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payout requested')));
      await _refresh(ref);
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Payout failed: $e')));
    }
  }

  Future<void> _addRecipientDialog(BuildContext context, WidgetRef ref) async {
    final numberCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    String provider = 'MTN';
    final ok = await showDialog<bool>(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setInner) => AlertDialog(
      title: const Text('Add MoMo method'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        DropdownButton<String>(
          value: provider,
          isExpanded: true,
          items: const ['MTN', 'Vodafone', 'AirtelTigo']
              .map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
          onChanged: (v) => setInner(() => provider = v ?? 'MTN'),
        ),
        TextField(controller: numberCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'MoMo number')),
        TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Account name')),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
      ],
    )));
    if (ok != true) return;
    try {
      await ApiService.instance.createPayoutRecipient({
        'type': 'mobile_money',
        'provider': provider,
        'account_number': numberCtrl.text.trim(),
        'account_name': nameCtrl.text.trim(),
        'is_default': true,
      });
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Method saved')));
      await _refresh(ref);
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }
}
