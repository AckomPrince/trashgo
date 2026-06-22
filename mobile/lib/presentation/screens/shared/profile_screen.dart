import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';

class ProfileScreen extends ConsumerWidget {
  final bool asTab;
  const ProfileScreen({super.key, this.asTab = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    if (user == null) return const SizedBox.shrink();

    final body = ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      children: [
        // Hero section
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(20, 32, 20, 28),
          child: Column(children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: AppColors.primary,
              child: Text(
                user.fullName.isNotEmpty
                    ? user.fullName
                        .split(' ')
                        .map((n) => n[0])
                        .take(2)
                        .join('')
                    : '?',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              user.fullName,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              user.phone,
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () {},
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.primary, width: 1.5),
                foregroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                minimumSize: const Size(0, 0),
              ),
              child: const Text(
                'Edit Profile',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
          ]),
        ),

        const SizedBox(height: 12),

        // Settings group 1: Account
        _SettingsGroup(items: [
          _SettingsItem(
            icon: Icons.payment_outlined,
            label: 'Payment Methods',
            onTap: () {},
          ),
          _SettingsItem(
            icon: Icons.notifications_outlined,
            label: 'Notification Preferences',
            onTap: () {},
          ),
        ]),

        const SizedBox(height: 12),

        // Settings group 2: Support
        _SettingsGroup(items: [
          _SettingsItem(
            icon: Icons.help_outline_rounded,
            label: 'Help & Support',
            onTap: () {},
          ),
          _SettingsItem(
            icon: Icons.policy_outlined,
            label: 'Terms & Privacy',
            onTap: () {},
          ),
        ]),

        if (user.isRider && user.riderProfile != null) ...[
          const SizedBox(height: 12),
          _SettingsGroup(items: [
            _SettingsItem(
              icon: Icons.local_shipping_outlined,
              label: 'Vehicle: ${user.riderProfile!.vehicleType ?? '—'}',
              onTap: () {},
            ),
            _SettingsItem(
              icon: Icons.confirmation_number_outlined,
              label: 'Plate: ${user.riderProfile!.vehiclePlate ?? '—'}',
              onTap: () {},
            ),
            _SettingsItem(
              icon: Icons.verified_outlined,
              label: 'Status: ${user.riderProfile!.status.toUpperCase()}',
              onTap: () {},
            ),
          ]),
        ],

        const SizedBox(height: 24),

        // Logout button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton.icon(
              onPressed: () async {
                await ref.read(authProvider.notifier).logout();
                if (context.mounted) context.go('/auth/role-select');
              },
              icon: const Icon(Icons.logout_rounded, color: AppColors.error, size: 18),
              label: const Text(
                'Log Out',
                style: TextStyle(
                  color: AppColors.error,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFF2C9C9), width: 1.5),
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ),

        const SizedBox(height: 32),
      ],
    );

    if (asTab) return body;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: body,
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  final List<_SettingsItem> items;
  const _SettingsGroup({required this.items});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(color: Color(0x0F000000), blurRadius: 8, offset: Offset(0, 2)),
          ],
        ),
        child: Column(
          children: items.asMap().entries.map((e) {
            final last = e.key == items.length - 1;
            return Column(children: [
              e.value,
              if (!last)
                const Divider(height: 1, color: Color(0xFFF4F4F4), indent: 54),
            ]);
          }).toList(),
        ),
      );
}

class _SettingsItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _SettingsItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          width: 36,
          height: 36,
          decoration: const BoxDecoration(
            color: Color(0xFFF4F4F4),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: const Color(0xFF666666), size: 18),
        ),
        title: Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        trailing: const Icon(
          Icons.chevron_right_rounded,
          color: Color(0xFFC5C5C5),
          size: 20,
        ),
      );
}
