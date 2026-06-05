import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import '../../../data/services/api_service.dart';
import '../../../data/services/socket_service.dart';
import '../../../providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../widgets/custom_button.dart';

class RiderHomeScreen extends ConsumerStatefulWidget {
  const RiderHomeScreen({super.key});
  @override
  ConsumerState<RiderHomeScreen> createState() => _RiderHomeScreenState();
}

class _RiderHomeScreenState extends ConsumerState<RiderHomeScreen> {
  bool _isOnline   = false;
  bool _toggling   = false;
  List  _pending   = [];
  Map?  _activeOrder;
  int   _tab       = 0;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _setupSocketListeners();
  }

  Future<void> _loadProfile() async {
    try {
      final res = await ApiService.instance.getEarnings(period: 'today');
      // also get rider profile to check online status
      final profile = await ApiService.instance.getMe();
      if (!mounted) return;
      setState(() {
        _isOnline = profile['user']?['rider_profile']?['is_online'] ?? false;
      });
    } catch (_) {}
    _loadNearbyOrders();
  }

  Future<void> _loadNearbyOrders() async {
    try {
      final pos = await Geolocator.getCurrentPosition();
      final res = await ApiService.instance.getNearbyOrders(pos.latitude, pos.longitude);
      if (!mounted) return;
      setState(() => _pending = res['orders'] as List? ?? []);
    } catch (_) {}
  }

  void _setupSocketListeners() {
    SocketService.instance.on('new_order_request', (data) {
      if (!mounted) return;
      _showNewOrderDialog(data);
    });

    SocketService.instance.on('order:update', (data) {
      if (!mounted) return;
      setState(() {});
    });

    SocketService.instance.on('payment:success', (data) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('💰 Customer payment confirmed! Start the pickup.'), backgroundColor: Colors.green),
      );
    });
  }

  void _showNewOrderDialog(dynamic data) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('🗑️ New Pickup Request'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${data['distance_km']} km away'),
          const SizedBox(height: 4),
          Text('Type: ${data['waste_type']}'),
          const SizedBox(height: 4),
          Text(data['pickup_address'] ?? '', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Decline', style: TextStyle(color: Colors.red))),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _acceptOrder(data['order_id']);
            },
            child: const Text('Accept'),
          ),
        ],
      ),
    );
  }

  Future<void> _acceptOrder(String orderId) async {
    try {
      final res = await ApiService.instance.acceptOrder(orderId);
      if (!mounted) return;
      if (res['success'] == true) {
        context.push('/rider/active/$orderId');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error));
    }
  }

  Future<void> _toggleOnline() async {
    setState(() => _toggling = true);
    try {
      final newStatus = !_isOnline;
      await ApiService.instance.setAvailability(newStatus);
      SocketService.instance.setRiderAvailability(newStatus);
      setState(() => _isOnline = newStatus);
      if (newStatus) _loadNearbyOrders();
    } catch (_) {}
    setState(() => _toggling = false);
  }

  @override
  void dispose() {
    SocketService.instance.off('new_order_request');
    SocketService.instance.off('payment:success');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user!;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: IndexedStack(index: _tab, children: [
        _buildHomeTab(user),
        const EarningsScreen(),
        const ProfileScreen(),
      ]),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tab,
        onTap: (i) => setState(() => _tab = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.attach_money_outlined), activeIcon: Icon(Icons.attach_money), label: 'Earnings'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }

  Widget _buildHomeTab(user) => CustomScrollView(slivers: [
    SliverAppBar(
      pinned: true, backgroundColor: AppColors.primary,
      title: Text('Hi, ${user.fullName.split(' ').first}!', style: const TextStyle(color: Colors.white)),
      actions: [IconButton(icon: const Icon(Icons.notifications_outlined, color: Colors.white), onPressed: () => context.push('/notifications'))],
    ),
    SliverToBoxAdapter(child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Online toggle
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _isOnline ? AppColors.primary.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _isOnline ? AppColors.primary : Colors.grey),
          ),
          child: Row(children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_isOnline ? '🟢 You are ONLINE' : '⚫ You are OFFLINE',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: _isOnline ? AppColors.primary : Colors.grey)),
              Text(_isOnline ? 'You can receive orders' : 'Toggle to start accepting', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            ]),
            const Spacer(),
            _toggling
                ? const CircularProgressIndicator()
                : Switch(
                    value: _isOnline,
                    onChanged: (_) => _toggleOnline(),
                    activeColor: AppColors.primary,
                  ),
          ]),
        ),

        const SizedBox(height: 24),
        if (_isOnline && _pending.isNotEmpty) ...[
          const Text('Nearby Requests', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          ..._pending.map((o) => _NearbyOrderCard(order: o, onAccept: () => _acceptOrder(o['id']))),
        ] else if (_isOnline) ...[
          const Center(child: Padding(
            padding: EdgeInsets.all(40),
            child: Column(children: [
              Icon(Icons.search, size: 48, color: AppColors.textSecondary),
              SizedBox(height: 12),
              Text('Looking for nearby orders...', style: TextStyle(color: AppColors.textSecondary)),
            ]),
          )),
        ],
      ]),
    )),
  ]);
}

class _NearbyOrderCard extends StatelessWidget {
  final Map order;
  final VoidCallback onAccept;
  const _NearbyOrderCard({required this.order, required this.onAccept});

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 12),
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('${order['distance_km']} km away', style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.primary)),
          Chip(label: Text((order['waste_type'] as String).toUpperCase(), style: const TextStyle(fontSize: 11)), padding: EdgeInsets.zero),
        ]),
        const SizedBox(height: 6),
        Text(order['pickup_address'] ?? '', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(onPressed: onAccept, child: const Text('Accept Order')),
        ),
      ]),
    ),
  );
}

import '../rider/earnings_screen.dart';
import '../shared/profile_screen.dart';
