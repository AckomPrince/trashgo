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
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(color: AppColors.tealBg, borderRadius: BorderRadius.circular(20)),
            child: const Text('Arrived at location', style: TextStyle(color: AppColors.teal, fontWeight: FontWeight.w600, fontSize: 13)),
          ),
          const SizedBox(height: 16),
          const Text('Confirm the waste size', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const SizedBox(height: 12),
          Row(children: ['small', 'medium', 'large'].map((s) {
            final sel = _selectedSize == s;
            return Expanded(child: GestureDetector(
              onTap: () => setState(() => _selectedSize = s),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: sel ? AppColors.primaryBg : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: sel ? AppColors.primary : const Color(0xFFE8E8E8), width: sel ? 1.5 : 1),
                ),
                child: Column(children: [
                  Icon(Icons.delete_outline, color: sel ? AppColors.primary : AppColors.textSecondary, size: 26),
                  const SizedBox(height: 6),
                  Text(s[0].toUpperCase() + s.substring(1), style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: sel ? AppColors.primary : AppColors.textPrimary)),
                  const SizedBox(height: 2),
                  Text(s == 'small' ? '~GHS 8-12' : s == 'medium' ? '~GHS 14-20' : '~GHS 22-35', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                ]),
              ),
            ));
          }).toList()),
          const SizedBox(height: 14),
          CustomButton(
            text: 'Confirm Size & Send Price',
            isLoading: _updating,
            onPressed: _selectedSize == null ? null : () => _updateStatus('size_confirmed', wasteSize: _selectedSize),
          ),
          const SizedBox(height: 10),
          Center(child: GestureDetector(
            onTap: () {},
            child: const Text('Report an issue', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w600, fontSize: 13)),
          )),
        ]);
      case 'size_confirmed':
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: AppColors.warningBg, borderRadius: BorderRadius.circular(12)),
          child: const Text('Waiting for customer to approve price...', style: TextStyle(color: AppColors.warning), textAlign: TextAlign.center),
        );
      case 'price_approved':
        return const Text('Waiting for customer payment...', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary));
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
      appBar: AppBar(
        title: const Text('Active Pickup'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.navigation_outlined, color: AppColors.primary),
            onPressed: _openNavigation,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _order == null
              ? const Center(child: Text('Order not found'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    // ── Progress stepper: 4-step segmented bar
                    Builder(builder: (_) {
                      final idx = _steps.indexWhere((s) => s['status'] == _order!.status);
                      final currentIdx = idx < 0 ? 0 : idx;
                      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: _steps.asMap().entries.map((e) {
                          final done = e.key <= currentIdx;
                          return Expanded(child: Container(
                            height: 5,
                            margin: EdgeInsets.only(right: e.key < _steps.length - 1 ? 4 : 0),
                            decoration: BoxDecoration(
                              color: done ? AppColors.primary : const Color(0xFFE2E2E2),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ));
                        }).toList()),
                        const SizedBox(height: 8),
                        Text(
                          'Step ${currentIdx + 1} of ${_steps.length} · ${_steps[currentIdx]['label']}',
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                        ),
                      ]);
                    }),
                    const SizedBox(height: 20),

                    // ── Customer info card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: const [BoxShadow(color: Color(0x0F000000), blurRadius: 8, offset: Offset(0, 2))],
                      ),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('Customer', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
                        const SizedBox(height: 10),
                        Row(children: [
                          const CircleAvatar(radius: 18, backgroundColor: AppColors.primaryBg, child: Icon(Icons.person_outline, color: AppColors.primary, size: 18)),
                          const SizedBox(width: 10),
                          Expanded(child: Text(_order!.customerName ?? 'Customer', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14))),
                        ]),
                        const SizedBox(height: 8),
                        Row(children: [
                          const Icon(Icons.location_on_outlined, color: AppColors.primary, size: 16),
                          const SizedBox(width: 6),
                          Expanded(child: Text(_order!.pickupAddress, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary))),
                        ]),
                        const SizedBox(height: 6),
                        Row(children: [
                          const Icon(Icons.delete_outline, color: AppColors.primary, size: 16),
                          const SizedBox(width: 6),
                          Text(_order!.wasteTypeLabel, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                        ]),
                        if (_order!.finalPrice != null) ...[
                          const SizedBox(height: 6),
                          Row(children: [
                            const Icon(Icons.attach_money, color: Colors.green, size: 16),
                            const SizedBox(width: 6),
                            Text('GHS ${_order!.finalPrice!.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.green, fontSize: 14)),
                          ]),
                        ],
                      ]),
                    ),

                    const SizedBox(height: 40),
                    _buildActionButton(),
                    const SizedBox(height: 20),
                  ]),
                ),
    );
  }
}
