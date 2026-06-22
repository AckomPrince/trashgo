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

class _TrackingScreenState extends ConsumerState<TrackingScreen>
    with SingleTickerProviderStateMixin {
  GoogleMapController? _mapCtrl;
  LatLng? _riderPos;
  Set<Marker> _markers = {};

  // Pulse animation for the status dot
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(activeOrderProvider.notifier).loadOrder(widget.orderId);
    });
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
    _pulseCtrl.dispose();
    SocketService.instance.off('rider:location_update');
    SocketService.instance.off('order:update');
    super.dispose();
  }

  String _statusLabel(String status) => switch (status) {
        'requested'      => 'Finding your rider...',
        'accepted'       => 'Rider is on the way',
        'rider_en_route' => 'Rider is en route',
        'rider_arrived'  => 'Rider has arrived',
        'size_confirmed' => 'Awaiting your approval',
        'price_approved' => 'Payment confirmed',
        'in_progress'    => 'Pickup in progress',
        'completed'      => 'Pickup completed!',
        _                => 'Tracking order...',
      };

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(activeOrderProvider);
    final order = state.order;
    final topPad = MediaQuery.of(context).padding.top;

    if (order == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ── Full-bleed map
          Positioned.fill(
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: LatLng(order.pickupLat, order.pickupLng),
                zoom: 14,
              ),
              markers: _markers.isEmpty
                  ? {
                      Marker(
                        markerId: const MarkerId('pickup'),
                        position: LatLng(order.pickupLat, order.pickupLng),
                        infoWindow:
                            const InfoWindow(title: 'Pickup Location'),
                        icon: BitmapDescriptor.defaultMarkerWithHue(
                            BitmapDescriptor.hueGreen),
                      ),
                    }
                  : _markers,
              onMapCreated: (c) {
                _mapCtrl = c;
                _updateMarkers();
              },
              zoomControlsEnabled: false,
              myLocationButtonEnabled: false,
            ),
          ),

          // ── Floating top pill
          Positioned(
            top: topPad + 12,
            left: 16,
            right: 16,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: const [
                  BoxShadow(
                      color: Color(0x1A000000),
                      blurRadius: 12,
                      offset: Offset(0, 4)),
                ],
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: const Icon(Icons.arrow_back_ios_rounded,
                        size: 18, color: AppColors.textPrimary),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _statusLabel(order.status),
                      style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: AppColors.textPrimary),
                    ),
                  ),
                  // Pulsing green status dot
                  AnimatedBuilder(
                    animation: _pulseAnim,
                    builder: (_, __) => Opacity(
                      opacity: _pulseAnim.value,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Bottom sheet
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
                boxShadow: [
                  BoxShadow(
                      color: Color(0x1F000000),
                      blurRadius: 24,
                      offset: Offset(0, -8)),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Drag handle
                    Container(
                      margin: const EdgeInsets.only(top: 10, bottom: 4),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.divider,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),

                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Rider info row
                          if (order.riderName != null) ...[
                            Row(children: [
                              CircleAvatar(
                                radius: 24,
                                backgroundColor: AppColors.primary,
                                child: Text(
                                  order.riderName!
                                      .split(' ')
                                      .map((n) => n[0])
                                      .take(2)
                                      .join(''),
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(order.riderName!,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 15)),
                                    Text(order.vehicleType ?? 'Collector',
                                        style: const TextStyle(
                                            color: AppColors.textSecondary,
                                            fontSize: 12)),
                                  ],
                                ),
                              ),
                              // Phone button
                              Container(
                                width: 42,
                                height: 42,
                                decoration: const BoxDecoration(
                                    color: Color(0xFFF2F4F2),
                                    shape: BoxShape.circle),
                                child: const Icon(Icons.phone_outlined,
                                    color: AppColors.primary, size: 20),
                              ),
                              const SizedBox(width: 8),
                              // Chat button
                              Container(
                                width: 42,
                                height: 42,
                                decoration: const BoxDecoration(
                                    color: Color(0xFFF2F4F2),
                                    shape: BoxShape.circle),
                                child: const Icon(Icons.chat_bubble_outline,
                                    color: AppColors.primary, size: 20),
                              ),
                            ]),
                            const SizedBox(height: 16),
                            const Divider(color: AppColors.dividerLight),
                            const SizedBox(height: 14),
                          ],

                          // Progress dots
                          _StatusTimeline(status: order.status),
                          const SizedBox(height: 14),

                          // Address
                          Row(children: [
                            const Icon(Icons.location_on_outlined,
                                color: AppColors.textSecondary, size: 15),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                order.pickupAddress,
                                style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textSecondary),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ]),

                          // size_confirmed — approve price button
                          if (order.status == 'size_confirmed') ...[
                            const SizedBox(height: 14),
                            CustomButton(
                              text:
                                  'Review & Approve Price — GHS ${order.finalPrice?.toStringAsFixed(2)}',
                              onPressed: () =>
                                  context.push('/price-approval/${order.id}'),
                            ),
                          ],

                          // completed badge
                          if (order.isCompleted) ...[
                            const SizedBox(height: 14),
                            Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 10),
                                decoration: BoxDecoration(
                                    color: AppColors.primaryBg,
                                    borderRadius: BorderRadius.circular(12)),
                                child: Text(
                                  'Pickup completed! +${order.pointsAwarded} points',
                                  style: const TextStyle(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13),
                                ),
                              ),
                            ),
                          ],

                          const SizedBox(height: 16),

                          // Cancel link
                          if (!order.isCompleted)
                            Center(
                              child: GestureDetector(
                                onTap: () async {
                                  await ref
                                      .read(activeOrderProvider.notifier)
                                      .cancelOrder(reason: 'User cancelled');
                                  if (mounted) context.go('/home');
                                },
                                child: const Text(
                                  'Cancel Request',
                                  style: TextStyle(
                                    color: AppColors.error,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13.5,
                                  ),
                                ),
                              ),
                            ),

                          const SizedBox(height: 12),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusTimeline extends StatelessWidget {
  final String status;
  const _StatusTimeline({required this.status});

  static const _steps = [
    ('requested',      'Requested'),
    ('accepted',       'Accepted'),
    ('rider_en_route', 'En Route'),
    ('rider_arrived',  'Arrived'),
    ('size_confirmed', 'Size OK'),
  ];

  @override
  Widget build(BuildContext context) {
    final currentIdx = _steps.indexWhere((s) => s.$1 == status);
    final effectiveIdx = currentIdx == -1 ? _steps.length : currentIdx;

    return Column(children: [
      Row(
        children: _steps.asMap().entries.map((e) {
          final done   = e.key <= effectiveIdx;
          final active = e.key == effectiveIdx;
          return Expanded(
            child: Row(children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: done ? AppColors.primary : const Color(0xFFD8D8D8),
                  border: active
                      ? Border.all(color: AppColors.primary, width: 2)
                      : null,
                ),
                child: active
                    ? const Center(
                        child: SizedBox(
                          width: 6,
                          height: 6,
                          child: CircularProgressIndicator(
                              strokeWidth: 1.5, color: Colors.white),
                        ),
                      )
                    : null,
              ),
              if (e.key < _steps.length - 1)
                Expanded(
                  child: Container(
                    height: 2,
                    color: e.key < effectiveIdx
                        ? AppColors.primary
                        : const Color(0xFFD8D8D8),
                  ),
                ),
            ]),
          );
        }).toList(),
      ),
      const SizedBox(height: 6),
      Row(
        children: _steps.asMap().entries.map((e) {
          final done = e.key <= effectiveIdx;
          return Expanded(
            child: Text(
              e.value.$2,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: e.key == effectiveIdx
                    ? FontWeight.w700
                    : FontWeight.w500,
                color: done ? AppColors.primary : AppColors.textMuted,
              ),
            ),
          );
        }).toList(),
      ),
    ]);
  }
}
