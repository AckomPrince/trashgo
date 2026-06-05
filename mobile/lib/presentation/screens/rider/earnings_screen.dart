import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
      appBar: AppBar(title: const Text('My Earnings'), backgroundColor: AppColors.primary),
      body: Column(children: [
        // Period tabs
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(children: [
            for (final p in ['today', 'week', 'month', 'all'])
              Padding(padding: const EdgeInsets.only(right: 8), child: ChoiceChip(
                label: Text(p.toUpperCase()),
                selected: _period == p,
                onSelected: (_) => setState(() => _period = p),
                selectedColor: AppColors.primary.withOpacity(0.2),
              )),
          ]),
        ),

        Expanded(child: earnings.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text(e.toString())),
          data: (data) {
            final s = data['summary'] ?? {};
            final recent = data['recent_earnings'] as List? ?? [];
            return ListView(padding: const EdgeInsets.all(16), children: [
              // Summary cards
              Row(children: [
                Expanded(child: _EarnCard(label: 'Total Jobs', value: '${s['total_jobs'] ?? 0}', icon: Icons.work_outline, color: Colors.blue)),
                const SizedBox(width: 12),
                Expanded(child: _EarnCard(label: 'Net Earnings', value: 'GHS ${double.parse((s['total_net'] ?? 0).toString()).toStringAsFixed(2)}', icon: Icons.attach_money, color: Colors.green)),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _EarnCard(label: 'Gross', value: 'GHS ${double.parse((s['total_gross'] ?? 0).toString()).toStringAsFixed(2)}', icon: Icons.monetization_on_outlined, color: AppColors.primary)),
                const SizedBox(width: 12),
                Expanded(child: _EarnCard(label: 'Commission', value: 'GHS ${double.parse((s['total_commission'] ?? 0).toString()).toStringAsFixed(2)}', icon: Icons.percent, color: Colors.orange)),
              ]),

              const SizedBox(height: 24),
              const Text('Recent Jobs', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),
              if (recent.isEmpty)
                const Center(child: Padding(padding: EdgeInsets.all(20), child: Text('No earnings yet', style: TextStyle(color: AppColors.textSecondary)))),
              ...recent.map((e) => ListTile(
                leading: const CircleAvatar(backgroundColor: Color(0xFFE8F5E9), child: Icon(Icons.delete_outline, color: AppColors.primary, size: 20)),
                title: Text(e['pickup_address'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
                subtitle: Text(e['waste_type'] ?? '', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text('GHS ${double.parse(e['net'].toString()).toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 14)),
                  Text(DateFormat('dd MMM').format(DateTime.parse(e['created_at'])), style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                ]),
              )).toList(),
            ]);
          },
        )),
      ]),
    );
  }
}

class _EarnCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _EarnCard({required this.label, required this.value, required this.icon, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)]),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, color: color, size: 24),
      const SizedBox(height: 8),
      Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
      Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
    ]),
  );
}
