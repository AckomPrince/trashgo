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
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
    _ctrl.forward();
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
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.primary,
    body: Center(
      child: FadeTransition(
        opacity: _fade,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 90, height: 90,
              decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(22),
              ),
              child: const Icon(Icons.delete_outline_rounded, size: 50, color: AppColors.primary),
            ),
            const SizedBox(height: 20),
            const Text('TrashGo', style: TextStyle(
              color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold, fontFamily: 'Poppins',
            )),
            const SizedBox(height: 8),
            const Text('Clean city. Smart pickup.', style: TextStyle(
              color: Colors.white70, fontSize: 16, fontFamily: 'Poppins',
            )),
            const SizedBox(height: 60),
            const CircularProgressIndicator(color: Colors.white54, strokeWidth: 2),
          ],
        ),
      ),
    ),
  );
}
