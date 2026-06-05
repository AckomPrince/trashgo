import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/order_model.dart';
import '../data/services/api_service.dart';
import '../data/services/socket_service.dart';

// ── Active order state ─────────────────────────────────────────
class ActiveOrderState {
  final OrderModel? order;
  final bool isLoading;
  final String? error;

  const ActiveOrderState({this.order, this.isLoading = false, this.error});
  ActiveOrderState copyWith({OrderModel? order, bool? isLoading, String? error}) =>
      ActiveOrderState(order: order ?? this.order, isLoading: isLoading ?? this.isLoading, error: error);
}

class ActiveOrderNotifier extends StateNotifier<ActiveOrderState> {
  ActiveOrderNotifier() : super(const ActiveOrderState());

  Future<bool> createOrder({
    required String address,
    required double lat,
    required double lng,
    required String wasteType,
    String? description,
  }) async {
    state = const ActiveOrderState(isLoading: true);
    try {
      final res = await ApiService.instance.createOrder({
        'pickup_address': address,
        'pickup_lat': lat,
        'pickup_lng': lng,
        'waste_type': wasteType,
        if (description != null) 'waste_description': description,
      });
      if (res['success'] == true) {
        final order = OrderModel.fromJson(res['order']);
        state = ActiveOrderState(order: order);
        _listenToUpdates(order.id);
        return true;
      }
      state = ActiveOrderState(error: res['error']);
      return false;
    } catch (e) {
      state = ActiveOrderState(error: e.toString());
      return false;
    }
  }

  Future<void> loadOrder(String orderId) async {
    state = const ActiveOrderState(isLoading: true);
    try {
      final res = await ApiService.instance.getOrder(orderId);
      if (res['success'] == true) {
        state = ActiveOrderState(order: OrderModel.fromJson(res['order']));
        _listenToUpdates(orderId);
      }
    } catch (e) {
      state = ActiveOrderState(error: e.toString());
    }
  }

  void _listenToUpdates(String orderId) {
    SocketService.instance.on('order:update', (data) {
      if (data['order_id'] == orderId && state.order != null) {
        // Refresh from server for latest data
        refreshOrder();
      }
    });
  }

  Future<void> refreshOrder() async {
    if (state.order == null) return;
    try {
      final res = await ApiService.instance.getOrder(state.order!.id);
      if (res['success'] == true) {
        state = ActiveOrderState(order: OrderModel.fromJson(res['order']));
      }
    } catch (_) {}
  }

  Future<bool> approvePrice() async {
    if (state.order == null) return false;
    try {
      final res = await ApiService.instance.approvePrice(state.order!.id);
      if (res['success'] == true) {
        await refreshOrder();
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> cancelOrder({String? reason}) async {
    if (state.order == null) return false;
    try {
      final res = await ApiService.instance.cancelOrder(state.order!.id, reason: reason);
      if (res['success'] == true) {
        state = const ActiveOrderState();
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  void clearOrder() {
    SocketService.instance.off('order:update');
    state = const ActiveOrderState();
  }
}

// ── Order history ──────────────────────────────────────────────
final activeOrderProvider = StateNotifierProvider<ActiveOrderNotifier, ActiveOrderState>(
  (ref) => ActiveOrderNotifier(),
);

final orderHistoryProvider = FutureProvider.family<List<OrderModel>, String?>((ref, status) async {
  final res = await ApiService.instance.listOrders(status: status);
  final list = res['orders'] as List;
  return list.map((j) => OrderModel.fromJson(j)).toList();
});
