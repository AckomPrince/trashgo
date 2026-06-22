import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:go_router/go_router.dart';
import '../../../providers/order_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/services/api_service.dart';
import '../../widgets/active_order_banner.dart';
import '../../widgets/custom_button.dart';

class RequestPickupScreen extends ConsumerStatefulWidget {
  const RequestPickupScreen({super.key});
  @override
  ConsumerState<RequestPickupScreen> createState() =>
      _RequestPickupScreenState();
}

class _RequestPickupScreenState extends ConsumerState<RequestPickupScreen> {
  final _addressCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String _wasteType = 'general';
  double? _lat, _lng;
  bool _locating = false;

  static const _wasteTypes = [
    {
      'value': 'general',
      'label': 'General',
      'icon': Icons.delete_outline,
      'desc': 'Household trash'
    },
    {
      'value': 'recyclable',
      'label': 'Recyclable',
      'icon': Icons.recycling,
      'desc': 'Plastic, paper, metal'
    },
    {
      'value': 'organic',
      'label': 'Organic',
      'icon': Icons.eco_outlined,
      'desc': 'Food, garden waste'
    },
    {
      'value': 'hazardous',
      'label': 'Hazardous',
      'icon': Icons.warning_amber_outlined,
      'desc': 'Chemicals, batteries'
    },
    {
      'value': 'bulky',
      'label': 'Bulky',
      'icon': Icons.weekend_outlined,
      'desc': 'Furniture, appliances'
    },
  ];

  Future<void> _getLocation() async {
    setState(() => _locating = true);
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied)
        perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.deniedForever)
        throw Exception('Location denied');

      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      final placemarks =
          await placemarkFromCoordinates(pos.latitude, pos.longitude);
      final p = placemarks.first;
      final address = '${p.street}, ${p.locality}, ${p.country}';

      setState(() {
        _lat = pos.latitude;
        _lng = pos.longitude;
        _addressCtrl.text = address;
      });
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      setState(() => _locating = false);
    }
  }

  Future<void> _submit() async {
    if (_addressCtrl.text.isEmpty) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Please enter or detect your address')));
      return;
    }
    if (_lat == null) {
      try {
        final locs = await locationFromAddress(_addressCtrl.text);
        _lat = locs.first.latitude;
        _lng = locs.first.longitude;
      } catch (_) {
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Could not find location. Use GPS.')));
        return;
      }
    }

    final ok = await ref.read(activeOrderProvider.notifier).createOrder(
          address: _addressCtrl.text,
          lat: _lat!,
          lng: _lng!,
          wasteType: _wasteType,
          description: _notesCtrl.text.isEmpty ? null : _notesCtrl.text,
        );

    if (!mounted) return;
    if (ok) {
      final order = ref.read(activeOrderProvider).order!;
      context.go('/tracking/${order.id}');
    } else {
      final error = ref.read(activeOrderProvider).error ?? 'Failed to create order';
      if (error.toLowerCase().contains('active order')) {
        _showActiveOrderConflict(error);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(error),
          backgroundColor: AppColors.error,
        ));
      }
    }
  }

  void _showActiveOrderConflict(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Active pickup in progress'),
        content: Text(
          '$message\n\nCancel or complete your current pickup before requesting a new one.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              context.push('/history');
            },
            child: const Text('View Orders'),
          ),
        ],
      ),
    );
  }

  void _confirmCancel(BuildContext context, String orderId) {
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
              if (mounted) {
                ref.invalidate(orderHistoryProvider(null));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Pickup cancelled')),
                );
              }
            },
            child: const Text('Cancel', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final orderState = ref.watch(activeOrderProvider);
    final historyAsync = ref.watch(orderHistoryProvider(null));
    final activeOrder = historyAsync.value
        ?.where((o) => o.status != 'completed' && o.status != 'cancelled')
        .firstOrNull;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Request Pickup'),
        backgroundColor: AppColors.primary,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Scrollbar(
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (activeOrder != null) ...[
                        ActiveOrderBanner(
                          order: activeOrder,
                          onTrack: () =>
                              context.push('/tracking/${activeOrder.id}'),
                          onCancel: () =>
                              _confirmCancel(context, activeOrder.id),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Cancel the active pickup above before requesting a new one.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // ── Pickup Location section
                      const Text(
                        'Pickup Location',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _addressCtrl,
                        maxLines: 2,
                        decoration: InputDecoration(
                          hintText: 'Enter your address',
                          prefixIcon: const Icon(Icons.location_on_outlined,
                              color: AppColors.primary),
                          suffixIcon: _locating
                              ? const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  ),
                                )
                              : IconButton(
                                  icon: const Icon(Icons.my_location,
                                      color: AppColors.primary),
                                  onPressed: _getLocation,
                                  tooltip: 'Use my location',
                                ),
                        ),
                      ),

                      // Static map preview placeholder
                      const SizedBox(height: 10),
                      Container(
                        height: 140,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEEF2EE),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.divider),
                        ),
                        child: Stack(
                          children: [
                            const Center(
                              child: Icon(
                                Icons.map_outlined,
                                size: 48,
                                color: Color(0xFFB5C4B5),
                              ),
                            ),
                            Positioned(
                              top: 0,
                              right: 0,
                              bottom: 0,
                              left: 0,
                              child: Center(
                                child: Container(
                                  width: 32,
                                  height: 32,
                                  decoration: const BoxDecoration(
                                    color: AppColors.primary,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.location_on,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // ── Waste Type section
                      const SizedBox(height: 24),
                      const Text(
                        'Waste Type',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        childAspectRatio: 2.4,
                        children: _wasteTypes.map((t) {
                          final selected = _wasteType == t['value'];
                          return GestureDetector(
                            onTap: () => setState(
                                () => _wasteType = t['value'] as String),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: selected
                                    ? AppColors.primaryBg
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: selected
                                      ? AppColors.primary
                                      : AppColors.divider,
                                  width: selected ? 1.5 : 1,
                                ),
                                boxShadow: selected
                                    ? []
                                    : [
                                        const BoxShadow(
                                          color: Color(0x0A000000),
                                          blurRadius: 4,
                                          offset: Offset(0, 1),
                                        )
                                      ],
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(10),
                                      boxShadow: const [
                                        BoxShadow(
                                          color: Color(0x12000000),
                                          blurRadius: 4,
                                          offset: Offset(0, 1),
                                        )
                                      ],
                                    ),
                                    child: Icon(
                                      t['icon'] as IconData,
                                      color: selected
                                          ? AppColors.primary
                                          : AppColors.textSecondary,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    t['label'] as String,
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w600,
                                      color: selected
                                          ? AppColors.primary
                                          : AppColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),

                      // ── Additional notes
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _notesCtrl,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Additional Notes (optional)',
                          hintText: 'e.g. Gate code, floor number...',
                        ),
                      ),

                      // ── Info box
                      const SizedBox(height: 32),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.primaryBg,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.info_outline,
                                color: AppColors.primary, size: 20),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Final price is confirmed after the rider sees your waste size.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: CustomButton(
                text: activeOrder != null ? 'View Active Pickup' : 'Confirm Pickup',
                isLoading: orderState.isLoading,
                onPressed: activeOrder != null
                    ? () => context.push('/tracking/${activeOrder.id}')
                    : _submit,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
