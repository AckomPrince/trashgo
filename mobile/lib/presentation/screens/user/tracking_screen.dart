import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:go_router/go_router.dart';
import '../../../providers/order_provider.dart';
import '../../../data/services/socket_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../widgets/custom_button.dart';

class TrackingScreen extends ConsumerStatefulWidget {
  final String orderId;
  const TrackingScreen({super.key, required this.orderId});
  @override
  ConsumerState<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends ConsumerState<TrackingScreen> {
  GoogleMapController? _mapCtrl;
  LatLng? _riderPos;
  Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    ref.read(activeOrderProvider.notifier).loadOrder(widget.orderId);
    _setupSocketListeners();
  }

  void _setupSocketListeners() {
    SocketService.instance.on('rider:location_update', (data) {
      if (!mounted) return;
      final lat = double.tryParse(data['lat'].toString());
      final lng = double.tryParse(data['lng'].toString());
      if (lat == null || lng == null) return;
      setState(() {
        _riderPos = LatLng(lat, lng);
        _updateMarkers();
      });
      _mapCtrl?.animateCamera(CameraUpdate.newLatLng(LatLng(lat, lng)));
    });

    SocketService.instance.on('order:update', (data) {
      if (data['order_id'] == widget.orderId) {
        ref.read(activeOrderProvider.notifier).refreshOrder();
        if (data['status'] == 'size_confirmed') {
          if (mounted) context.push('/price-approval/${widget.orderId}');
        }
      }
    });

    // Start tracking rider
    final order = ref.read(activeOrderProvider).order;
    if (order?.riderId != null) {
      SocketService.instance.trackRider(order!.riderId!);
    }
  }

  void _updateMarkers() {
    final order = ref.read(activeOrderProvider).order;
    if (order == null) return;
    final ms = <Marker>{
      Marker(
        markerId: const MarkerId('pickup'),
        position: LatLng(order.pickupLat, order.pickupLng),
        infoWindow: const InfoWindow(title: 'Pickup Location'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      ),
    };
    if (_riderPos != null) {
      ms.add(Marker(
        markerId: const MarkerId('rider'),
        position: _riderPos!,
        infoWindow: const InfoWindow(title: 'Your Rider'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
      ));
    }
    setState(() => _markers = ms);
  }

  @override
  void dispose() {
    SocketService.instance.off('rider:location_update');
    SocketService.instance.off('order:update');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(activeOrderProvider);
    final order = state.order;

    return Scaffold(
      appBar: AppBar(title: const Text('Track Pickup'), backgroundColor: AppColors.primary),
      body: order == null
          ? const Center(child: CircularProgressIndicator())
          : Column(children: [
              // Map
              Expanded(
                flex: 3,
                child: GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: LatLng(order.pickupLat, order.pickupLng),
                    zoom: 14,
                  ),
                  markers: _markers.isEmpty ? {
                    Marker(
                      markerId: const MarkerId('pickup'),
                      position: LatLng(order.pickupLat, order.pickupLng),
                      infoWindow: const InfoWindow(title: 'Pickup Location'),
                    )
                  } : _markers,
                  onMapCreated: (c) {
                    _mapCtrl = c;
                    _updateMarkers();
                  },
                ),
              ),

              // Status panel
              Expanded(
                flex: 2,
                child: Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(20),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    _StatusTimeline(status: order.status),
                    const SizedBox(height: 16),

                    if (order.riderName != null) ...[
                      Row(children: [
                        const CircleAvatar(radius: 20, backgroundColor: AppColors.primaryLight, child: Icon(Icons.person, color: Colors.white)),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(order.riderName!, style: const TextStyle(fontWeight: FontWeight.w600)),
                          Text(order.vehicleType ?? 'Collector', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                        ])),
                        IconButton(icon: const Icon(Icons.phone_outlined, color: AppColors.primary), onPressed: () {}),
                      ]),
                      const Divider(height: 20),
                    ],

                    Text(order.pickupAddress, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis),

                    if (order.status == 'size_confirmed') ...[
                      const SizedBox(height: 12),
                      CustomButton(
                        text: 'Review & Approve Price — GHS ${order.finalPrice?.toStringAsFixed(2)}',
                        onPressed: () => context.push('/price-approval/${order.id}'),
                      ),
                    ],

                    if (order.isCompleted) ...[
                      const SizedBox(height: 12),
                      Center(child: Chip(
                        backgroundColor: Colors.green.withOpacity(0.1),
                        label: Text('✅ Pickup completed! +${order.pointsAwarded} points', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w600)),
                      )),
                    ],
                  ]),
                ),
              ),
            ]),
    );
  }
}

class _StatusTimeline extends StatelessWidget {
  final String status;
  const _StatusTimeline({required this.status});

  static const steps = ['requested', 'accepted', 'rider_en_route', 'rider_arrived', 'in_progress', 'completed'];

  @override
  Widget build(BuildContext context) {
    final current = steps.indexOf(status);
    return Row(children: steps.asMap().entries.map((e) {
      final done  = e.key <= current;
      final active= e.key == current;
      return Expanded(child: Row(children: [
        CircleAvatar(
          radius: 8,
          backgroundColor: done ? AppColors.primary : AppColors.divider,
          child: active ? const SizedBox(width: 6, height: 6, child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.white)) : null,
        ),
        if (e.key < steps.length - 1)
          Expanded(child: Container(height: 2, color: done ? AppColors.primary : AppColors.divider)),
      ]));
    }).toList());
  }
}
