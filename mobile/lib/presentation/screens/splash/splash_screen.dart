import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});
  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;

  // Two pulse ring controllers, offset by half a cycle
  late AnimationController _pulse1;
  late AnimationController _pulse2;

  @override
  void initState() {
    super.initState();

    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
    _ctrl.forward();

    _pulse1 = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
      lowerBound: 0,
      upperBound: 1,
    )..repeat();

    _pulse2 = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
      lowerBound: 0,
      upperBound: 1,
    )..repeat();

    // Start the second ring half a cycle ahead so the two rings are offset
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) _pulse2.forward(from: 0.5);
    });

    _navigate();
  }

  Future<void> _navigate() async {
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    final auth = ref.read(authProvider);
    if (auth.isAuthenticated) {
      context.go(auth.user!.isRider ? '/rider/home' : '/home');
    } else {
      context.go('/auth/role-select');
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _pulse1.dispose();
    _pulse2.dispose();
    super.dispose();
  }

  Widget _buildRing(AnimationController pulse) {
    return AnimatedBuilder(
      animation: pulse,
      builder: (ctx, _) {
        final v = pulse.value;
        return Opacity(
          opacity: (1 - v) * 0.6,
          child: Container(
            width: 120 + v * 120,
            height: 120 + v * 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withOpacity(0.3 * (1 - v)),
                width: 1.5,
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.primary,
    body: Center(
      child: FadeTransition(
        opacity: _fade,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Pulse rings + logo badge stacked in a fixed-size box
            SizedBox(
              width: 260,
              height: 260,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Outer ring (pulse2 — offset by 0.5)
                  _buildRing(_pulse2),
                  // Inner ring (pulse1)
                  _buildRing(_pulse1),
                  // Logo badge
                  Container(
                    width: 120,
                    height: 120,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                    ),
                    child: const Icon(
                      Icons.delete_rounded,
                      size: 60,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Wordmark
            const Text(
              'TrashGo',
              style: TextStyle(
                color: Colors.white,
                fontSize: 36,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.72,
              ),
            ),
            const SizedBox(height: 10),
            // Tagline
            Text(
              'Waste pickup, on demand',
              style: TextStyle(
                color: Colors.white.withOpacity(0.66),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
