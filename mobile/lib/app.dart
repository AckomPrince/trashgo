import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'core/theme/app_theme.dart';
import 'providers/auth_provider.dart';
import 'presentation/screens/splash/splash_screen.dart';
import 'presentation/screens/auth/role_select_screen.dart';
import 'presentation/screens/auth/login_screen.dart';
import 'presentation/screens/auth/register_user_screen.dart';
import 'presentation/screens/auth/register_rider_screen.dart';
import 'presentation/screens/user/user_home_screen.dart';
import 'presentation/screens/user/request_pickup_screen.dart';
import 'presentation/screens/user/tracking_screen.dart';
import 'presentation/screens/user/price_approval_screen.dart';
import 'presentation/screens/user/order_history_screen.dart';
import 'presentation/screens/user/rewards_wallet_screen.dart';
import 'presentation/screens/rider/rider_home_screen.dart';
import 'presentation/screens/rider/active_pickup_screen.dart';
import 'presentation/screens/rider/earnings_screen.dart';
import 'presentation/screens/rider/rider_wallet_screen.dart';
import 'presentation/screens/shared/notifications_screen.dart';
import 'presentation/screens/shared/profile_screen.dart';

class TrashGoApp extends ConsumerStatefulWidget {
  const TrashGoApp({super.key});

  @override
  ConsumerState<TrashGoApp> createState() => _TrashGoAppState();
}

class _TrashGoAppState extends ConsumerState<TrashGoApp> {
  late final GoRouter _router;
  late final ValueNotifier<bool> _authRefresh;
  StreamSubscription? _authSub;

  @override
  void initState() {
    super.initState();

    // FIX: Create one router instance and keep it alive across auth state changes.
    // A ValueNotifier is used as GoRouter's refreshListenable so redirects run
    // whenever auth changes without rebuilding/replacing the entire router.
    _authRefresh = ValueNotifier(false);
    _authSub = ref.read(authProvider.notifier).stream.listen((_) {
      _authRefresh.value = !_authRefresh.value;
    });

    _router = GoRouter(
      initialLocation: '/splash',
      refreshListenable: _authRefresh,
      redirect: (ctx, state) {
        final auth = ref.read(authProvider);
        final loggedIn = auth.isAuthenticated;
        final onAuth = state.matchedLocation.startsWith('/auth') ||
                       state.matchedLocation == '/splash';

        if (!loggedIn && !onAuth) return '/auth/role-select';
        if (loggedIn && onAuth) {
          return auth.user!.isRider ? '/rider/home' : '/home';
        }
        return null;
      },
      routes: [
        GoRoute(path: '/splash',           builder: (_, __) => const SplashScreen()),
        GoRoute(path: '/auth/role-select', builder: (_, __) => const RoleSelectScreen()),
        GoRoute(path: '/auth/login/:role', builder: (_, s) => LoginScreen(role: s.pathParameters['role']!)),
        GoRoute(path: '/auth/register/customer', builder: (_, __) => const RegisterUserScreen()),
        GoRoute(path: '/auth/register/rider',    builder: (_, __) => const RegisterRiderScreen()),

        // Customer routes
        GoRoute(path: '/home',             builder: (_, __) => const UserHomeScreen()),
        GoRoute(path: '/request-pickup',   builder: (_, __) => const RequestPickupScreen()),
        GoRoute(path: '/tracking/:id',     builder: (_, s)  => TrackingScreen(orderId: s.pathParameters['id']!)),
        GoRoute(path: '/price-approval/:id', builder: (_, s) => PriceApprovalScreen(orderId: s.pathParameters['id']!)),
        GoRoute(path: '/history',          builder: (_, __) => const OrderHistoryScreen()),
        GoRoute(path: '/wallet',           builder: (_, __) => const RewardsWalletScreen()),

        // Rider routes
        GoRoute(path: '/rider/home',       builder: (_, __) => const RiderHomeScreen()),
        GoRoute(path: '/rider/active/:id', builder: (_, s)  => ActivePickupScreen(orderId: s.pathParameters['id']!)),
        GoRoute(path: '/rider/earnings',   builder: (_, __) => const EarningsScreen()),
        GoRoute(path: '/rider/wallet',     builder: (_, __) => const RiderWalletScreen()),

        // Shared
        GoRoute(path: '/notifications',    builder: (_, __) => const NotificationsScreen()),
        GoRoute(path: '/profile',          builder: (_, __) => const ProfileScreen()),
      ],
    );
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _authRefresh.dispose();
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'TrashGo',
      theme: AppTheme.light,
      routerConfig: _router,
      debugShowCheckedModeBanner: false,
    );
  }
}
