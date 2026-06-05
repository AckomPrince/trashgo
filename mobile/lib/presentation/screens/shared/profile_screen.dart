import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    if (user == null) return const SizedBox.shrink();
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Profile'), backgroundColor: AppColors.primary),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        Center(child: Column(children: [
          CircleAvatar(radius: 40, backgroundColor: AppColors.primaryLight, child: Text(user.fullName[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold))),
          const SizedBox(height: 12),
          Text(user.fullName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          Text(user.email, style: const TextStyle(color: AppColors.textSecondary)),
          Chip(label: Text(user.role.toUpperCase(), style: const TextStyle(fontSize: 11)), backgroundColor: AppColors.primary.withOpacity(0.1)),
        ])),
        const SizedBox(height: 32),
        _tile(Icons.phone_outlined, 'Phone', user.phone),
        _tile(Icons.email_outlined, 'Email', user.email),
        if (user.isRider && user.riderProfile != null) ...[
          _tile(Icons.local_shipping_outlined, 'Vehicle', user.riderProfile!.vehicleType ?? '—'),
          _tile(Icons.confirmation_number_outlined, 'Plate', user.riderProfile!.vehiclePlate ?? '—'),
          _tile(Icons.verified_outlined, 'Status', user.riderProfile!.status.toUpperCase()),
        ],
        const Divider(height: 32),
        ListTile(
          leading: const Icon(Icons.logout, color: Colors.red),
          title: const Text('Logout', style: TextStyle(color: Colors.red)),
          onTap: () async {
            await ref.read(authProvider.notifier).logout();
            if (context.mounted) context.go('/auth/role-select');
          },
        ),
      ]),
    );
  }

  static Widget _tile(IconData icon, String label, String value) => ListTile(
    leading: Icon(icon, color: AppColors.primary),
    title: Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
    subtitle: Text(value, style: const TextStyle(fontSize: 15, color: AppColors.textPrimary)),
  );
}
