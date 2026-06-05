import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:go_router/go_router.dart';
import '../../../providers/order_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../widgets/custom_button.dart';

class RequestPickupScreen extends ConsumerStatefulWidget {
  const RequestPickupScreen({super.key});
  @override
  ConsumerState<RequestPickupScreen> createState() => _RequestPickupScreenState();
}

class _RequestPickupScreenState extends ConsumerState<RequestPickupScreen> {
  final _addressCtrl = TextEditingController();
  final _notesCtrl   = TextEditingController();
  String _wasteType  = 'general';
  double? _lat, _lng;
  bool _locating = false;

  static const _wasteTypes = [
    {'value': 'general',    'label': 'General',     'icon': Icons.delete_outline,       'desc': 'Household trash'},
    {'value': 'recyclable', 'label': 'Recyclable',  'icon': Icons.recycling,            'desc': 'Plastic, paper, metal'},
    {'value': 'organic',    'label': 'Organic',     'icon': Icons.eco_outlined,         'desc': 'Food, garden waste'},
    {'value': 'hazardous',  'label': 'Hazardous',   'icon': Icons.warning_amber_outlined,'desc': 'Chemicals, batteries'},
    {'value': 'bulky',      'label': 'Bulky',       'icon': Icons.weekend_outlined,     'desc': 'Furniture, appliances'},
  ];

  Future<void> _getLocation() async {
    setState(() => _locating = true);
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.deniedForever) throw Exception('Location denied');

      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      final placemarks = await placemarkFromCoordinates(pos.latitude, pos.longitude);
      final p = placemarks.first;
      final address = '${p.street}, ${p.locality}, ${p.country}';

      setState(() {
        _lat = pos.latitude;
        _lng = pos.longitude;
        _addressCtrl.text = address;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      setState(() => _locating = false);
    }
  }

  Future<void> _submit() async {
    if (_addressCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter or detect your address')));
      return;
    }
    if (_lat == null) {
      // Try to geocode the entered address
      try {
        final locs = await locationFromAddress(_addressCtrl.text);
        _lat = locs.first.latitude;
        _lng = locs.first.longitude;
      } catch (_) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not find location. Use GPS.')));
        return;
      }
    }

    final ok = await ref.read(activeOrderProvider.notifier).createOrder(
      address:   _addressCtrl.text,
      lat:       _lat!,
      lng:       _lng!,
      wasteType: _wasteType,
      description: _notesCtrl.text.isEmpty ? null : _notesCtrl.text,
    );

    if (!mounted) return;
    if (ok) {
      final order = ref.read(activeOrderProvider).order!;
      context.go('/tracking/${order.id}');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ref.read(activeOrderProvider).error ?? 'Failed to create order'),
        backgroundColor: AppColors.error,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final orderState = ref.watch(activeOrderProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Request Pickup'), backgroundColor: AppColors.primary),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // Address
          const Text('Pickup Location', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
          const SizedBox(height: 10),
          TextFormField(
            controller: _addressCtrl,
            maxLines: 2,
            decoration: InputDecoration(
              hintText: 'Enter your address',
              prefixIcon: const Icon(Icons.location_on_outlined, color: AppColors.primary),
              suffixIcon: _locating
                  ? const Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
                  : IconButton(icon: const Icon(Icons.my_location, color: AppColors.primary), onPressed: _getLocation, tooltip: 'Use my location'),
            ),
          ),

          const SizedBox(height: 24),
          const Text('Waste Type', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
          const SizedBox(height: 10),
          ...(_wasteTypes.map((t) {
            final selected = _wasteType == t['value'];
            return GestureDetector(
              onTap: () => setState(() => _wasteType = t['value'] as String),
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: selected ? AppColors.primary.withOpacity(0.08) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: selected ? AppColors.primary : AppColors.divider, width: selected ? 2 : 1),
                ),
                child: Row(children: [
                  Icon(t['icon'] as IconData, color: selected ? AppColors.primary : AppColors.textSecondary, size: 24),
                  const SizedBox(width: 14),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(t['label'] as String, style: TextStyle(fontWeight: FontWeight.w600, color: selected ? AppColors.primary : AppColors.textPrimary)),
                    Text(t['desc'] as String, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ])),
                  if (selected) const Icon(Icons.check_circle, color: AppColors.primary),
                ]),
              ),
            );
          })).toList(),

          const SizedBox(height: 16),
          TextFormField(
            controller: _notesCtrl,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Additional Notes (optional)', hintText: 'e.g. Gate code, floor number...'),
          ),

          const SizedBox(height: 32),
          // Price preview
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: AppColors.primaryLight.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: Row(children: const [
              Icon(Icons.info_outline, color: AppColors.primary, size: 20),
              SizedBox(width: 10),
              Expanded(child: Text('Final price is confirmed after the rider sees your waste size.', style: TextStyle(fontSize: 13, color: AppColors.textSecondary))),
            ]),
          ),

          const SizedBox(height: 20),
          CustomButton(
            text: 'Request Pickup',
            isLoading: orderState.isLoading,
            onPressed: _submit,
          ),
        ]),
      ),
    );
  }
}
