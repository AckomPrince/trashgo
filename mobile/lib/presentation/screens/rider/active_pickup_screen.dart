import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../data/services/api_service.dart';
import '../../../data/services/socket_service.dart';
import '../../../data/models/order_model.dart';
import '../../../core/theme/app_theme.dart';
import '../../widgets/custom_button.dart';

class ActivePickupScreen extends ConsumerStatefulWidget {
  final String orderId;
  const ActivePickupScreen({super.key, required this.orderId});
  @override
  ConsumerState<ActivePickupScreen> createState() => _ActivePickupScreenState();
}

class _ActivePickupScreenState extends ConsumerState<ActivePickupScreen> {
  OrderModel? _order;
  bool _loading = true;
  String? _selectedSize;
  bool _updating = false;

  static const _steps = [
    {'status': 'accepted',       'label': 'Order Accepted',    'icon': Icons.check_circle_outline},
    {'status': 'rider_en_route', 'label': 'En Route',          'icon': Icons.directions_car_outlined},
    {'status': 'rider_arrived',  'label': 'Arrived',           'icon': Icons.location_on_outlined},
    {'status': 'size_confirmed', 'label': 'Size Confirmed',    'icon': Icons.straighten_outlined},
    {'status': 'in_progress',    'label': 'Picking Up',        'icon': Icons.local_shipping_outlined},
    {'status': 'completed',      'label': 'Completed',         'icon': Icons.done_all},
  ];

  @override
  void initState() {
    super.initState();
    _loadOrder();
    _startLocationUpdates();
  }

  Future<void> _loadOrder() async {
    try {
      final res = await ApiService.instance.getOrder(widget.orderId);
      if (!mounted) return;
      setState(() { _order = OrderModel.fromJson(res['order']); _loading = false; });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  void _startLocationUpdates() async {
    try {
      await Geolocator.requestPermission();
      Geolocator.getPositionStream(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 20),
      ).listen((pos) {
        ApiService.instance.updateLocation(pos.latitude, pos.longitude);
        SocketService.instance.updateRiderLocation(pos.latitude, pos.longitude);
      });
    } catch (_) {}
  }

  Future<void> _updateStatus(String status, {String? wasteSize}) async {
    setState(() => _updating = true);
    try {
      final res = await ApiService.instance.updateOrderStatus(widget.orderId, status, wasteSize: wasteSize);
      if (!mounted) return;
      if (res['success'] == true) await _loadOrder();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error));
    }
    setState(() => _updating = false);
  }

  Future<void> _complete() async {
    setState(() => _updating = true);
    try {
      final res = await ApiService.instance.completeOrder(widget.orderId);
      if (!mounted) return;
      if (res['success'] == true) {
        showDialog(context: context, barrierDismissible: false, builder: (_) => AlertDialog(
          title: const Text('✅ Pickup Complete!'),
          content: Text('Earnings: GHS ${res['rider_net_earning']}\nCustomer earned: ${res['points_awarded']} pts'),
          actions: [ElevatedButton(onPressed: () { Navigator.pop(context); context.go('/rider/home'); }, child: const Text('Done'))],
        ));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error));
    }
    setState(() => _updating = false);
  }

  void _openNavigation() async {
    if (_order == null) return;
    final url = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${_order!.pickupLat},${_order!.pickupLng}&travelmode=driving');
    if (await canLaunchUrl(url)) launchUrl(url, mode: LaunchMode.externalApplication);
  }

  Widget _buildActionButton() {
    if (_order == null) return const SizedBox.shrink();
    switch (_order!.status) {
      case 'accepted':
        return CustomButton(text: '🚗 Start En Route', isLoading: _updating, onPressed: () => _updateStatus('rider_en_route'));
      case 'rider_en_route':
        return CustomButton(text: '📍 Mark Arrived', isLoading: _updating, onPressed: () => _updateStatus('rider_arrived'));
      case 'rider_arrived':
        return Column(children: [
          const Text('Select Waste Size', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          Row(children: ['small', 'medium', 'large'].map((s) => Expanded(child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: GestureDetector(
              onTap: () => setState(() => _selectedSize = s),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _selectedSize == s ? AppColors.primary : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _selectedSize == s ? AppColors.primary : AppColors.divider),
                ),
                child: Text(s.toUpperCase(), textAlign: TextAlign.center,
                  style: TextStyle(color: _selectedSize == s ? Colors.white : AppColors.textPrimary, fontWeight: FontWeight.w600)),
              ),
            ),
          ))).toList()),
          const SizedBox(height: 14),
          CustomButton(
            text: '✅ Confirm Waste Size',
            isLoading: _updating,
            onPressed: _selectedSize == null ? null : () => _updateStatus('size_confirmed', wasteSize: _selectedSize),
          ),
        ]);
      case 'size_confirmed':
        return Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
          child: const Text('⏳ Waiting for customer to approve price...', style: TextStyle(color: Colors.orange), textAlign: TextAlign.center));
      case 'price_approved':
        return const Text('⏳ Waiting for customer payment...', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary));
      case 'in_progress':
        return CustomButton(text: '🏁 Complete Pickup', isLoading: _updating, onPressed: _complete, color: Colors.green);
      case 'completed':
        return const Center(child: Text('✅ Order Completed', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)));
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Active Pickup'), backgroundColor: AppColors.primary,
        actions: [IconButton(icon: const Icon(Icons.navigation_outlined), onPressed: _openNavigation)]),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _order == null ? const Center(child: Text('Order not found'))
          : Padding(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Progress stepper
                Card(child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(children: _steps.asMap().entries.map((e) {
                    final done    = _steps.indexWhere((s) => s['status'] == _order!.status) >= e.key;
                    final current = _order!.status == e.value['status'];
                    return Row(children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: done ? AppColors.primary : AppColors.divider,
                        child: Icon(e.value['icon'] as IconData, size: 16, color: Colors.white),
                      ),
                      const SizedBox(width: 12),
                      Text(e.value['label'] as String, style: TextStyle(fontWeight: current ? FontWeight.bold : FontWeight.normal, color: done ? AppColors.primary : AppColors.textSecondary)),
                      if (current) ...[const Spacer(), Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle))],
                      if (e.key < _steps.length - 1) const SizedBox(height: 30),
                    ]);
                  }).expand((w) => [w, const Padding(padding: EdgeInsets.only(left: 16), child: SizedBox(height: 1, width: double.infinity))]).toList(),
                  ),
                )),

                const SizedBox(height: 16),
                Card(child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Customer Info', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 10),
                    Row(children: [
                      const Icon(Icons.person_outline, size: 18, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Text(_order!.customerName ?? 'Customer'),
                    ]),
                    const SizedBox(height: 6),
                    Row(children: [
                      const Icon(Icons.location_on_outlined, size: 18, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_order!.pickupAddress, style: const TextStyle(fontSize: 13))),
                    ]),
                    const SizedBox(height: 6),
                    Row(children: [
                      const Icon(Icons.delete_outline, size: 18, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Text(_order!.wasteTypeLabel),
                    ]),
                    if (_order!.finalPrice != null) ...[
                      const SizedBox(height: 6),
                      Row(children: [
                        const Icon(Icons.attach_money, size: 18, color: Colors.green),
                        const SizedBox(width: 8),
                        Text('GHS ${_order!.finalPrice!.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                      ]),
                    ],
                  ]),
                )),

                const Spacer(),
                _buildActionButton(),
              ]),
            ),
    );
  }
}
