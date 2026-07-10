import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/config/app_config.dart';

class ApiService {
  static ApiService? _instance;
  late final Dio _dio;
  final _storage = const FlutterSecureStorage();

  ApiService._() {
    _dio = Dio(BaseOptions(
      baseUrl: AppConfig.baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json'},
    ));

    _dio.interceptors.addAll([
      _AuthInterceptor(_storage),
      LogInterceptor(requestBody: true, responseBody: true),
    ]);
  }

  static ApiService get instance => _instance ??= ApiService._();

  // ── Auth ───────────────────────────────────────────────────
  Future<Map<String, dynamic>> registerCustomer(Map<String, dynamic> data) =>
      _post('/auth/register/customer', data);

  Future<Map<String, dynamic>> registerRider(Map<String, dynamic> data) =>
      _post('/auth/register/rider', data);

  Future<Map<String, dynamic>> login(Map<String, dynamic> data) =>
      _post('/auth/login', data);

  Future<Map<String, dynamic>> getMe() => _get('/auth/me');

  Future<Map<String, dynamic>> updateFcmToken(String token) =>
      _patch('/auth/fcm-token', {'fcm_token': token});

  // ── Orders ─────────────────────────────────────────────────
  Future<Map<String, dynamic>> createOrder(Map<String, dynamic> data) =>
      _post('/orders', data);

  Future<Map<String, dynamic>> getOrder(String orderId) =>
      _get('/orders/$orderId');

  Future<Map<String, dynamic>> listOrders({String? status, int page = 1}) =>
      _get('/orders', params: {'status': status, 'page': page});

  Future<Map<String, dynamic>> acceptOrder(String orderId) =>
      _post('/orders/$orderId/accept', {});

  Future<Map<String, dynamic>> updateOrderStatus(String orderId, String status, {String? wasteSize}) =>
      _patch('/orders/$orderId/status', {'status': status, if (wasteSize != null) 'waste_size': wasteSize});

  Future<Map<String, dynamic>> approvePrice(String orderId) =>
      _patch('/orders/$orderId/approve-price', {});

  Future<Map<String, dynamic>> startPickup(String orderId) =>
      _patch('/orders/$orderId/start', {});

  Future<Map<String, dynamic>> completeOrder(String orderId, {String? completionPhotoUrl}) =>
      _patch('/orders/$orderId/complete', {
        if (completionPhotoUrl != null) 'completion_photo_url': completionPhotoUrl,
      });

  Future<Map<String, dynamic>> cancelOrder(String orderId, {String? reason}) =>
      _patch('/orders/$orderId/cancel', {'reason': reason});

  Future<Map<String, dynamic>> rateOrder(String orderId, int rating, {String? review}) =>
      _post('/orders/$orderId/rate', {'rating': rating, 'review': review});

  // S3: decline an offered order · S2: rate the rider
  Future<Map<String, dynamic>> declineOrder(String orderId) =>
      _post('/orders/$orderId/decline', {});

  Future<Map<String, dynamic>> rateRider(String orderId, int rating, {String? review}) =>
      _post('/orders/$orderId/rate-rider', {'rating': rating, 'review': review});

  // ── Riders ─────────────────────────────────────────────────
  Future<Map<String, dynamic>> setAvailability(bool online) =>
      _patch('/riders/availability', {'online': online});

  Future<Map<String, dynamic>> updateLocation(double lat, double lng) =>
      _patch('/riders/location', {'lat': lat, 'lng': lng});

  Future<Map<String, dynamic>> getEarnings({String period = 'all'}) =>
      _get('/riders/earnings', params: {'period': period});

  Future<Map<String, dynamic>> getNearbyOrders({double? lat, double? lng}) =>
      _get('/riders/nearby-orders', params: {
        if (lat != null) 'lat': lat,
        if (lng != null) 'lng': lng,
      });

  // S1: wallet · S4: onboarding/docs · S6: incentives + SOS
  Future<Map<String, dynamic>> getRiderWallet() => _get('/riders/wallet');

  Future<Map<String, dynamic>> getOnboarding() => _get('/riders/onboarding');

  Future<Map<String, dynamic>> uploadDocument(String docType, String url, {String? ghanaCardNumber}) =>
      _patch('/riders/documents', {
        'doc_type': docType,
        'url': url,
        if (ghanaCardNumber != null) 'ghana_card_number': ghanaCardNumber,
      });

  Future<Map<String, dynamic>> getIncentives() => _get('/riders/incentives');

  Future<Map<String, dynamic>> sos({String? orderId, double? lat, double? lng, String? note}) =>
      _post('/riders/sos', {
        if (orderId != null) 'order_id': orderId,
        if (lat != null) 'lat': lat,
        if (lng != null) 'lng': lng,
        if (note != null) 'note': note,
      });

  // P: payouts to MoMo / bank
  Future<Map<String, dynamic>> getPayoutRecipients() => _get('/riders/payout-recipients');

  Future<Map<String, dynamic>> createPayoutRecipient(Map<String, dynamic> data) =>
      _post('/riders/payout-recipients', data);

  Future<Map<String, dynamic>> initiatePayout({required double amount, String? recipientId}) =>
      _post('/riders/payout', {
        'amount': amount,
        if (recipientId != null) 'recipient_id': recipientId,
      });

  Future<Map<String, dynamic>> getPayouts() => _get('/riders/payouts');

  // ── Rewards ────────────────────────────────────────────────
  Future<Map<String, dynamic>> getWallet() => _get('/rewards/wallet');

  Future<Map<String, dynamic>> getTransactions() => _get('/rewards/transactions');

  Future<Map<String, dynamic>> redeemPoints(Map<String, dynamic> data) =>
      _post('/rewards/redeem', data);

  Future<Map<String, dynamic>> getRedemptions() => _get('/rewards/redemptions');

  // ── Payments ───────────────────────────────────────────────
  Future<Map<String, dynamic>> initializePayment(String orderId) =>
      _post('/payments/initialize', {'order_id': orderId});

  // ── Internals ──────────────────────────────────────────────
  Future<Map<String, dynamic>> _get(String path, {Map<String, dynamic>? params}) async {
    final response = await _dio.get(path, queryParameters: params?..removeWhere((k, v) => v == null));
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> data) async {
    final response = await _dio.post(path, data: data);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> _patch(String path, Map<String, dynamic> data) async {
    final response = await _dio.patch(path, data: data);
    return response.data as Map<String, dynamic>;
  }
}

// ── Auth interceptor: attaches Bearer token ────────────────────
class _AuthInterceptor extends Interceptor {
  final FlutterSecureStorage _storage;
  _AuthInterceptor(this._storage);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final token = await _storage.read(key: AppConfig.tokenKey);
    if (token != null) options.headers['Authorization'] = 'Bearer $token';
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401) {
      // Attempt token refresh
      try {
        final refresh = await _storage.read(key: AppConfig.refreshKey);
        if (refresh == null) return handler.next(err);

        final dio = Dio(BaseOptions(baseUrl: AppConfig.baseUrl));
        final res = await dio.post('/auth/refresh', data: {'refresh_token': refresh});
        final newToken = res.data['token'];

        await _storage.write(key: AppConfig.tokenKey, value: newToken);
        err.requestOptions.headers['Authorization'] = 'Bearer $newToken';

        final retryRes = await Dio().fetch(err.requestOptions);
        return handler.resolve(retryRes);
      } catch (_) {
        await _storage.deleteAll();
      }
    }
    handler.next(err);
  }
}
