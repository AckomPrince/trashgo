import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/order_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/services/api_service.dart';
import '../../widgets/active_order_banner.dart';
import '../../widgets/custom_button.dart';
import '../user/order_history_screen.dart';
import '../user/rewards_wallet_screen.dart';
import '../shared/profile_screen.dart';

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
    // FIX: removed auto refreshUser call here. It was causing /auth/me to be
    // called on every home screen creation and contributed to rate-limiting.
    // Wallet data is fetched separately by the rewards provider.
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
        OrderHistoryScreen(asTab: true),
        RewardsWalletScreen(asTab: true),
        ProfileScreen(asTab: true),
      ]),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tab,
        onTap: (i) => setState(() => _tab = i),
        backgroundColor: Colors.white,
        elevation: 0,
        selectedLabelStyle: const TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w500,
        ),
        selectedItemColor: AppColors.primary,
        unselectedItemColor: Color(0xFFB0B0B0),
        iconSize: 24,
        type: BottomNavigationBarType.fixed,
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

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top bar
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Good morning',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          'Hi, ${user.fullName.split(' ').first} 👋',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Stack(
                    children: [
                      IconButton(
                        onPressed: () => context.push('/notifications'),
                        icon: Container(
                          width: 42,
                          height: 42,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFFF4F4F4),
                          ),
                          child: const Icon(
                            Icons.notifications_outlined,
                            color: AppColors.textPrimary,
                            size: 22,
                          ),
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ── Scrollable content
            Expanded(
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Rewards gradient card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.primary, AppColors.primaryDark],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          stops: [0, 1],
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
                          const SizedBox(height: 6),
                          Text(
                            '${wallet?.balance ?? 0} points',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 30,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Redeemable as cash every 3 months',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.78),
                              fontSize: 11.5,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerRight,
                            child: GestureDetector(
                              onTap: () => context.push('/wallet'),
                              child: const Text(
                                'View Wallet →',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Active pickup banner
                    _ActiveOrderSection(),

                    const SizedBox(height: 20),

                    // Request Pickup CTA
                    GestureDetector(
                      onTap: () => context.push('/request-pickup'),
                      child: Container(
                        width: double.infinity,
                        height: 64,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x4C2E7D32),
                              blurRadius: 20,
                              offset: Offset(0, 8),
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.local_shipping_outlined, color: Colors.white, size: 24),
                            SizedBox(width: 10),
                            Text(
                              'Request Pickup 🚛',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 28),

                    // Waste type selector
                    const Text(
                      'Waste Type',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const _WasteTypeSelector(),

                    const SizedBox(height: 28),

                    // Recent Orders
                    const _RecentOrders(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActiveOrderSection extends ConsumerWidget {
  const _ActiveOrderSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(orderHistoryProvider(null));

    return history.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (orders) {
        final active = orders
            .where((o) => o.status != 'completed' && o.status != 'cancelled')
            .firstOrNull;
        if (active == null) return const SizedBox.shrink();

        return ActiveOrderBanner(
          order: active,
          onTrack: () => context.push('/tracking/${active.id}'),
          onCancel: () => _confirmCancel(context, ref, active.id),
        );
      },
    );
  }

  void _confirmCancel(BuildContext context, WidgetRef ref, String orderId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel pickup?'),
        content: const Text('Are you sure you want to cancel this active pickup?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Keep'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await ApiService.instance.cancelOrder(orderId);
              ref.invalidate(orderHistoryProvider(null));
            },
            child: const Text('Cancel', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class _WasteTypeSelector extends StatefulWidget {
  const _WasteTypeSelector();

  @override
  State<_WasteTypeSelector> createState() => _WasteTypeSelectorState();
}

class _WasteTypeSelectorState extends State<_WasteTypeSelector> {
  int _sel = 0;

  static const _types = [
    {'label': 'General',    'icon': Icons.delete_outline,         'bg': Color(0xFFEEF1EE), 'fg': Color(0xFF4B635E)},
    {'label': 'Recyclable', 'icon': Icons.recycling,              'bg': Color(0xFFE8F5E9), 'fg': Color(0xFF2E7D32)},
    {'label': 'Organic',    'icon': Icons.eco_outlined,           'bg': Color(0xFFE0F2F1), 'fg': Color(0xFF00796B)},
    {'label': 'Hazardous',  'icon': Icons.warning_amber_outlined, 'bg': Color(0xFFFFEBEE), 'fg': Color(0xFFD32F2F)},
    {'label': 'Bulky',      'icon': Icons.weekend_outlined,       'bg': Color(0xFFFFF3E0), 'fg': Color(0xFFF57C00)},
  ];

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 96,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: _types.length,
      separatorBuilder: (_, __) => const SizedBox(width: 10),
      itemBuilder: (ctx, i) {
        final t = _types[i];
        final sel = _sel == i;
        return GestureDetector(
          onTap: () => setState(() => _sel = i),
          child: Container(
            width: 80,
            height: 86,
            decoration: BoxDecoration(
              color: sel ? AppColors.primaryBg : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: sel ? AppColors.primary : const Color(0xFFEFEFEF),
                width: sel ? 1.5 : 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  t['icon'] as IconData,
                  color: sel ? AppColors.primary : (t['fg'] as Color),
                  size: 26,
                ),
                const SizedBox(height: 6),
                Text(
                  t['label'] as String,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: sel ? AppColors.primary : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

class _RecentOrders extends ConsumerWidget {
  const _RecentOrders();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(orderHistoryProvider(null));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Recent Pickups',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
            ),
            TextButton(
              onPressed: () => context.push('/history'),
              child: const Text('See all'),
            ),
          ],
        ),
        history.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => const SizedBox.shrink(),
          data: (orders) => orders.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(
                    child: Text('No pickups yet', style: TextStyle(color: AppColors.textSecondary)),
                  ),
                )
              : Column(
                  children: orders.take(3).map((o) => _OrderTile(order: o)).toList(),
                ),
        ),
      ],
    );
  }
}

class _OrderTile extends StatelessWidget {
  final dynamic order;
  const _OrderTile({required this.order});

  @override
  Widget build(BuildContext context) {
    // Determine badge colors from waste type
    Color badgeBg = AppColors.wasteGeneralBg;
    Color badgeFg = AppColors.wasteGeneralFg;
    IconData icon = Icons.delete_outline;
    switch (order.wasteType) {
      case 'recyclable':
        badgeBg = AppColors.wasteRecyclableBg;
        badgeFg = AppColors.wasteRecyclableFg;
        icon = Icons.recycling;
        break;
      case 'organic':
        badgeBg = AppColors.wasteOrganicBg;
        badgeFg = AppColors.wasteOrganicFg;
        icon = Icons.eco_outlined;
        break;
      case 'hazardous':
        badgeBg = AppColors.wasteHazardousBg;
        badgeFg = AppColors.wasteHazardousFg;
        icon = Icons.warning_amber_outlined;
        break;
      case 'bulky':
        badgeBg = AppColors.wasteBulkyBg;
        badgeFg = AppColors.wasteBulkyFg;
        icon = Icons.weekend_outlined;
        break;
    }

    return GestureDetector(
      onTap: () => context.push('/tracking/${order.id}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [
            BoxShadow(color: Color(0x0F000000), blurRadius: 8, offset: Offset(0, 2)),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: badgeBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: badgeFg, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    order.wasteTypeLabel,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    order.pickupAddress,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            OrderStatusChip(status: order.status),
          ],
        ),
      ),
    );
  }
}
