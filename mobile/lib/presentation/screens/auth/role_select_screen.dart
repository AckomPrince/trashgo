import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';

class RoleSelectScreen extends StatelessWidget {
  const RoleSelectScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.delete_outline_rounded, size: 48, color: AppColors.primary),
            const SizedBox(height: 16),
            const Text('Welcome to\nTrashGo', style: TextStyle(
              fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.textPrimary, height: 1.2,
            )),
            const SizedBox(height: 8),
            const Text('How do you want to use the app?', style: TextStyle(
              fontSize: 16, color: AppColors.textSecondary,
            )),
            const SizedBox(height: 48),
            _RoleCard(
              icon: Icons.person_outline_rounded,
              title: 'I\'m a Customer',
              subtitle: 'Request waste pickup and earn rewards',
              color: AppColors.primary,
              onTap: () => context.go('/auth/login/customer'),
            ),
            const SizedBox(height: 16),
            _RoleCard(
              icon: Icons.local_shipping_outlined,
              title: 'I\'m a Rider',
              subtitle: 'Accept pickup jobs and earn income',
              color: AppColors.primaryLight,
              onTap: () => context.go('/auth/login/rider'),
            ),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('New here? ', style: TextStyle(color: AppColors.textSecondary)),
                TextButton(
                  onPressed: () => context.go('/auth/register/customer'),
                  child: const Text('Create account', style: TextStyle(color: AppColors.primary)),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class _RoleCard extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final Color color;
  final VoidCallback onTap;
  const _RoleCard({required this.icon, required this.title, required this.subtitle, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(16),
    child: Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
        boxShadow: [BoxShadow(color: color.withOpacity(0.08), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Row(children: [
        Container(
          width: 56, height: 56,
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(14)),
          child: Icon(icon, color: color, size: 28),
        ),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        ])),
        const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
      ]),
    ),
  );
}
