import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../data/services/api_service.dart';
import '../../../data/services/socket_service.dart';
import '../../../providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../rider/earnings_screen.dart';
import '../shared/profile_screen.dart';

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
      // FIX/MVP: fetch all unassigned requested orders without GPS filtering.
      // GPS-based matching will be added in a future update.
      final res = await ApiService.instance.getNearbyOrders();
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        title: Row(children: [
          const Icon(Icons.local_shipping_outlined, color: AppColors.primary, size: 22),
          const SizedBox(width: 10),
          const Text('New Pickup Request', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: AppColors.primaryBg, borderRadius: BorderRadius.circular(20)),
            child: Text(
            data['distance_km'] != null ? '${data['distance_km']} km away' : 'Open request',
            style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w600),
          ),
          ),
          const SizedBox(height: 10),
          Row(children: [
            const Icon(Icons.delete_outline, color: AppColors.textSecondary, size: 16),
            const SizedBox(width: 6),
            Text('${data['waste_type']}', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
          ]),
          const SizedBox(height: 6),
          Row(children: [
            const Icon(Icons.location_on_outlined, color: AppColors.textSecondary, size: 16),
            const SizedBox(width: 6),
            Expanded(child: Text(data['pickup_address'] ?? '', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary))),
          ]),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Decline', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _acceptOrder(data['order_id']);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              minimumSize: const Size(100, 44),
            ),
            child: const Text('Accept', style: TextStyle(fontWeight: FontWeight.w700)),
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

  Widget _buildHomeTab(user) => Scaffold(
    backgroundColor: AppColors.background,
    body: SafeArea(
      child: Column(children: [
        // ── Top bar
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Row(children: [
            // Avatar + name
            CircleAvatar(
              radius: 20,
              backgroundColor: AppColors.primary,
              child: Text(user.fullName[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(user.fullName.split(' ').first, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              Text(_isOnline ? 'Online · Accepting orders' : 'Offline', style: TextStyle(fontSize: 12, color: _isOnline ? AppColors.primary : AppColors.textMuted)),
            ])),
            // Online/offline toggle
            GestureDetector(
              onTap: _toggling ? null : _toggleOnline,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: 54,
                height: 30,
                decoration: BoxDecoration(
                  color: _isOnline ? AppColors.primary : const Color(0xFFCFCFCF),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Stack(children: [
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 250),
                    left: _isOnline ? 26 : 4,
                    top: 4,
                    child: Container(width: 22, height: 22, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
                  ),
                ]),
              ),
            ),
          ]),
        ),

        // ── Content
        Expanded(child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(children: [
            // Online state: dispatch list OR offline message
            if (_isOnline) ...[
              if (_pending.isNotEmpty) ...[
                const Align(alignment: Alignment.centerLeft, child: Text('Nearby Requests', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary))),
                const SizedBox(height: 12),
                ..._pending.map((o) => _NearbyOrderCard(
                      order: o,
                      onAccept: () => _acceptOrder(o['id']),
                      onDecline: () => setState(() => _pending.remove(o)),
                    )),
              ] else
                const _OnlineIdle(),
            ] else
              const _OfflineCard(),
          ]),
        )),
      ]),
    ),
  );
}

class _OnlineIdle extends StatelessWidget {
  const _OnlineIdle();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 60),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      SizedBox(
        width: 72,
        height: 72,
        child: DecoratedBox(
          decoration: BoxDecoration(color: AppColors.primaryBg, shape: BoxShape.circle),
          child: Icon(Icons.search_rounded, color: AppColors.primary, size: 36),
        ),
      ),
      SizedBox(height: 14),
      Text('Looking for nearby orders...', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: AppColors.textPrimary)),
      SizedBox(height: 6),
      Text('Stay online to receive new pickup requests', style: TextStyle(fontSize: 13, color: AppColors.textSecondary), textAlign: TextAlign.center),
    ]),
  );
}

class _OfflineCard extends StatelessWidget {
  const _OfflineCard();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 60),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      SizedBox(
        width: 72,
        height: 72,
        child: DecoratedBox(
          decoration: BoxDecoration(color: Color(0xFFF2F2F2), shape: BoxShape.circle),
          child: Icon(Icons.power_settings_new_rounded, color: Color(0xFF9E9E9E), size: 36),
        ),
      ),
      SizedBox(height: 14),
      Text("You're offline", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: AppColors.textPrimary)),
      SizedBox(height: 6),
      Text('Toggle the switch to go online and start accepting orders', style: TextStyle(fontSize: 13, color: AppColors.textSecondary), textAlign: TextAlign.center),
    ]),
  );
}

class _NearbyOrderCard extends StatelessWidget {
  final Map order;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  const _NearbyOrderCard({required this.order, required this.onAccept, required this.onDecline});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: const [BoxShadow(color: Color(0x0F000000), blurRadius: 8, offset: Offset(0, 2))],
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: AppColors.primaryBg, borderRadius: BorderRadius.circular(20)),
          child: Text(
            order['distance_km'] != null ? '${order['distance_km']} km away' : 'Open request',
            style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: Color(0xFFF4F4F4), borderRadius: BorderRadius.circular(20)),
          child: Text((order['waste_type'] ?? '').toUpperCase(), style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w600)),
        ),
      ]),
      const SizedBox(height: 10),
      Row(children: [
        const Icon(Icons.location_on_outlined, color: AppColors.textSecondary, size: 16),
        const SizedBox(width: 4),
        Expanded(child: Text(order['pickup_address'] ?? '', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis)),
      ]),
      const SizedBox(height: 14),
      Row(children: [
        Expanded(child: OutlinedButton(
          onPressed: onDecline,
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: AppColors.divider),
            foregroundColor: AppColors.textSecondary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            minimumSize: const Size(0, 44),
          ),
          child: const Text('Decline'),
        )),
        const SizedBox(width: 10),
        Expanded(child: ElevatedButton(
          onPressed: onAccept,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            minimumSize: const Size(0, 44),
          ),
          child: const Text('Accept', style: TextStyle(fontWeight: FontWeight.w700)),
        )),
      ]),
    ]),
  );
}
