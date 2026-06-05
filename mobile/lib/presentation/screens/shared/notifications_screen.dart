import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../data/services/api_service.dart';
import '../../../core/theme/app_theme.dart';

final _notifProvider = FutureProvider((ref) async {
  // Fetch from backend (would need a GET /notifications endpoint)
  return <Map>[];
});

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(title: const Text('Notifications'), backgroundColor: AppColors.primary),
    body: const Center(child: Text('Notifications will appear here', style: TextStyle(color: AppColors.textSecondary))),
  );
}
