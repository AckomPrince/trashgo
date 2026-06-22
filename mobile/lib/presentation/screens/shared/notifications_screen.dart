import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';

// Keep the existing provider
final _notifProvider = FutureProvider((ref) async => <Map>[]);

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  static final _mockNotifs = [
    {
      'icon': Icons.check_circle_outline,
      'iconBg': Color(0xFFE8F5E9),
      'iconFg': Color(0xFF2E7D32),
      'title': 'Pickup Completed',
      'body': 'Your waste has been collected. You earned 15 points!',
      'time': '2 min ago',
      'unread': true,
    },
    {
      'icon': Icons.notifications_outlined,
      'iconBg': Color(0xFFFFF3E0),
      'iconFg': Color(0xFFF57C00),
      'title': 'Rider En Route',
      'body': 'Kwame is on the way to your pickup location.',
      'time': '18 min ago',
      'unread': true,
    },
    {
      'icon': Icons.info_outline,
      'iconBg': Color(0xFFF3E5F5),
      'iconFg': Color(0xFF7B1FA2),
      'title': 'Price Confirmed',
      'body': 'Your waste size has been confirmed. Review the price to continue.',
      'time': '1 hr ago',
      'unread': false,
    },
    {
      'icon': Icons.stars_rounded,
      'iconBg': Color(0xFFE8F5E9),
      'iconFg': Color(0xFF2E7D32),
      'title': 'Points Bonus!',
      'body': 'You earned a 50-point bonus for your 5th pickup.',
      'time': 'Yesterday',
      'unread': false,
    },
    {
      'icon': Icons.cancel_outlined,
      'iconBg': Color(0xFFFFEBEE),
      'iconFg': Color(0xFFD32F2F),
      'title': 'Order Cancelled',
      'body': 'Your pickup request has been cancelled. No charges applied.',
      'time': '3 days ago',
      'unread': false,
    },
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: () {},
            child: const Text(
              'Mark all read',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: ListView.separated(
        itemCount: _mockNotifs.length,
        separatorBuilder: (_, __) =>
            const Divider(height: 1, color: Color(0xFFF0F0F0)),
        itemBuilder: (ctx, i) {
          final n = _mockNotifs[i];
          final unread = n['unread'] as bool;
          return Container(
            color: unread ? const Color(0xFFF3FAF4) : Colors.white,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left unread indicator
                Container(
                  width: 7,
                  height: 80,
                  color: unread ? AppColors.primary : Colors.transparent,
                ),
                // Icon badge
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 16, 0, 16),
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: n['iconBg'] as Color,
                      borderRadius: BorderRadius.circular(21),
                    ),
                    child: Icon(
                      n['icon'] as IconData,
                      color: n['iconFg'] as Color,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(0, 14, 16, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                n['title'] as String,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: unread
                                      ? FontWeight.w700
                                      : FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            Text(
                              n['time'] as String,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFFB5B5B5),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          n['body'] as String,
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: AppColors.textSecondary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
