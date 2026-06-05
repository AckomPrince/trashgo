import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';
import '../data/models/user_model.dart';
import '../data/services/api_service.dart';
import '../data/services/socket_service.dart';
import '../core/config/app_config.dart';

// ── Auth state ─────────────────────────────────────────────────
class AuthState {
  final UserModel? user;
  final bool isLoading;
  final String? error;

  const AuthState({this.user, this.isLoading = false, this.error});
  bool get isAuthenticated => user != null;
  AuthState copyWith({UserModel? user, bool? isLoading, String? error}) =>
      AuthState(user: user ?? this.user, isLoading: isLoading ?? this.isLoading, error: error);
}

// ── Auth notifier ──────────────────────────────────────────────
class AuthNotifier extends StateNotifier<AuthState> {
  final _storage = const FlutterSecureStorage();

  AuthNotifier() : super(const AuthState()) {
    _loadCachedUser();
  }

  Future<void> _loadCachedUser() async {
    final cached = await _storage.read(key: AppConfig.userKey);
    if (cached != null) {
      try {
        state = AuthState(user: UserModel.fromJson(jsonDecode(cached)));
      } catch (_) {}
    }
  }

  Future<bool> loginCustomer({required String emailOrPhone, required String password, String? fcmToken}) async {
    state = const AuthState(isLoading: true);
    try {
      final isEmail = emailOrPhone.contains('@');
      final res = await ApiService.instance.login({
        if (isEmail) 'email': emailOrPhone else 'phone': emailOrPhone,
        'password': password,
        if (fcmToken != null) 'fcm_token': fcmToken,
      });
      return _handleAuthResponse(res);
    } catch (e) {
      state = AuthState(error: _extractError(e));
      return false;
    }
  }

  Future<bool> registerCustomer({required String fullName, required String email, required String phone, required String password}) async {
    state = const AuthState(isLoading: true);
    try {
      final res = await ApiService.instance.registerCustomer({
        'full_name': fullName, 'email': email, 'phone': phone, 'password': password,
      });
      return _handleAuthResponse(res);
    } catch (e) {
      state = AuthState(error: _extractError(e));
      return false;
    }
  }

  Future<bool> registerRider({required String fullName, required String email, required String phone, required String password, String? vehicleType, String? vehiclePlate}) async {
    state = const AuthState(isLoading: true);
    try {
      final res = await ApiService.instance.registerRider({
        'full_name': fullName, 'email': email, 'phone': phone, 'password': password,
        if (vehicleType != null) 'vehicle_type': vehicleType,
        if (vehiclePlate != null) 'vehicle_plate': vehiclePlate,
      });
      return _handleAuthResponse(res);
    } catch (e) {
      state = AuthState(error: _extractError(e));
      return false;
    }
  }

  Future<bool> _handleAuthResponse(Map<String, dynamic> res) async {
    if (res['success'] == true) {
      final token   = res['token'] as String;
      final refresh = res['refresh_token'] as String?;
      final user    = UserModel.fromJson(res['user']);

      await _storage.write(key: AppConfig.tokenKey, value: token);
      if (refresh != null) await _storage.write(key: AppConfig.refreshKey, value: refresh);
      await _storage.write(key: AppConfig.userKey, value: jsonEncode(user.toJson()));

      // Connect socket
      SocketService.instance.connect(token);

      state = AuthState(user: user);
      return true;
    }
    state = AuthState(error: res['error'] ?? 'Login failed');
    return false;
  }

  Future<void> logout() async {
    SocketService.instance.disconnect();
    await _storage.deleteAll();
    state = const AuthState();
  }

  Future<void> refreshUser() async {
    try {
      final res  = await ApiService.instance.getMe();
      final user = UserModel.fromJson(res['user']);
      await _storage.write(key: AppConfig.userKey, value: jsonEncode(user.toJson()));
      state = AuthState(user: user);
    } catch (_) {}
  }

  String _extractError(dynamic e) {
    if (e is Exception) return e.toString().replaceAll('Exception: ', '');
    return 'Something went wrong';
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(),
);
