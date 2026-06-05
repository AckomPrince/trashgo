import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/order_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../widgets/custom_button.dart';

class UserHomeScreen extends ConsumerStatefulWidget {
  const UserHomeScreen({super.key});
  @override
  ConsumerState<UserHomeScreen> createState() => _UserHomeScreenState();
}

class _UserHomeScreenState extends ConsumerState<UserHomeScreen> {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(authProvider.notifier).refreshUser();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final user = auth.user!;
    final wallet = user.wallet;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: IndexedStack(index: _tab, children: const [
        _HomeTab(),
        OrderHistoryScreen(),
        RewardsWalletScreen(),
        ProfileScreen(),
      ]),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tab,
        onTap: (i) => setState(() => _tab = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.history_outlined), activeIcon: Icon(Icons.history), label: 'History'),
          BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet_outlined), activeIcon: Icon(Icons.account_balance_wallet), label: 'Rewards'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}

class _HomeTab extends ConsumerWidget {
  const _HomeTab();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user   = ref.watch(authProvider).user!;
    final wallet = user.wallet;

    return CustomScrollView(slivers: [
      SliverAppBar(
        expandedHeight: 160,
        floating: true, pinned: true,
        backgroundColor: AppColors.primary,
        flexibleSpace: FlexibleSpaceBar(
          background: Padding(
            padding: const EdgeInsets.fromLTRB(20, 60, 20, 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Hello, ${user.fullName.split(' ').first}! 👋', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              const Text('Ready to clean up?', style: TextStyle(color: Colors.white70, fontSize: 14)),
            ]),
          ),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.notifications_outlined, color: Colors.white), onPressed: () => context.push('/notifications')),
        ],
      ),

      SliverToBoxAdapter(child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          // Points card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [AppColors.primary, AppColors.primaryLight]),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Your Points', style: TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 4),
                Text('${wallet?.balance ?? 0}', style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('≈ GHS ${((wallet?.balance ?? 0) / 100).toStringAsFixed(2)}', style: const TextStyle(color: Colors.white70)),
              ])),
              Column(children: [
                const Icon(Icons.stars_rounded, color: Colors.white, size: 40),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () => context.push('/wallet'),
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white54), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6)),
                  child: const Text('Redeem', style: TextStyle(fontSize: 12)),
                ),
              ]),
            ]),
          ),

          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => context.push('/request-pickup'),
            icon: const Icon(Icons.add_location_alt_outlined),
            label: const Text('Request Pickup'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              minimumSize: const Size(double.infinity, 56),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),

          const SizedBox(height: 24),
          _WasteTypeGrid(),

          const SizedBox(height: 24),
          const _RecentOrders(),
        ]),
      )),
    ]);
  }
}

class _WasteTypeGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final types = [
      {'icon': Icons.delete_outline,    'label': 'General',     'color': Colors.grey},
      {'icon': Icons.recycling,          'label': 'Recyclable',  'color': Colors.green},
      {'icon': Icons.eco_outlined,       'label': 'Organic',     'color': Colors.lightGreen},
      {'icon': Icons.warning_amber_outlined,'label': 'Hazardous','color': Colors.red},
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Waste Types', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      const SizedBox(height: 12),
      GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, mainAxisSpacing: 8, crossAxisSpacing: 8, childAspectRatio: 0.85),
        itemCount: types.length,
        itemBuilder: (_, i) {
          final t = types[i];
          final c = t['color'] as Color;
          return Column(children: [
            Container(
              width: 54, height: 54,
              decoration: BoxDecoration(color: c.withOpacity(0.1), borderRadius: BorderRadius.circular(14)),
              child: Icon(t['icon'] as IconData, color: c, size: 26),
            ),
            const SizedBox(height: 6),
            Text(t['label'] as String, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary), textAlign: TextAlign.center),
          ]);
        },
      ),
    ]);
  }
}

class _RecentOrders extends ConsumerWidget {
  const _RecentOrders();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(orderHistoryProvider(null));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        const Text('Recent Pickups', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        TextButton(onPressed: () => context.push('/history'), child: const Text('See all')),
      ]),
      history.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => const SizedBox.shrink(),
        data: (orders) => orders.isEmpty
            ? const Padding(padding: EdgeInsets.all(20), child: Center(child: Text('No pickups yet', style: TextStyle(color: AppColors.textSecondary))))
            : Column(children: orders.take(3).map((o) => _OrderTile(order: o)).toList()),
      ),
    ]);
  }
}

class _OrderTile extends StatelessWidget {
  final dynamic order;
  const _OrderTile({required this.order});
  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 10),
    child: ListTile(
      leading: Container(
        width: 42, height: 42,
        decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
        child: const Icon(Icons.delete_outline, color: AppColors.primary, size: 22),
      ),
      title: Text(order.pickupAddress, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
      subtitle: Text(order.wasteTypeLabel, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      trailing: OrderStatusChip(status: order.status),
      onTap: () => context.push('/tracking/${order.id}'),
    ),
  );
}

// Import stubs (screens are defined separately)
import '../user/order_history_screen.dart';
import '../user/rewards_wallet_screen.dart';
import '../shared/profile_screen.dart';
