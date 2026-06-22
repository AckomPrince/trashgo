import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final Color? color;
  final bool outlined;

  const CustomButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.color,
    this.outlined = false,
  });

  @override
  Widget build(BuildContext context) {
    if (outlined) {
      return SizedBox(
        width: double.infinity,
        height: 52,
        child: OutlinedButton(
          onPressed: isLoading ? null : onPressed,
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: color ?? AppColors.primary, width: 1.5),
            foregroundColor: color ?? AppColors.primary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: isLoading
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: color ?? AppColors.primary,
                  ),
                )
              : Text(text, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
        ),
      );
    }

    final buttonColor = color ?? AppColors.primary;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: onPressed != null && !isLoading
            ? [
                BoxShadow(
                  color: buttonColor.withOpacity(0.28),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ]
            : [],
      ),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: buttonColor,
            foregroundColor: Colors.white,
            elevation: 0,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: isLoading ? null : onPressed,
          child: isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                )
              : Text(
                  text,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
        ),
      ),
    );
  }
}

/// Status pill widget used across screens.
class OrderStatusChip extends StatelessWidget {
  final String status;
  const OrderStatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg, String label) = switch (status) {
      'requested'     => (AppColors.warningBg, AppColors.warning,   'Finding Rider'),
      'accepted'      => (AppColors.infoBg,    AppColors.info,      'Accepted'),
      'rider_en_route'=> (AppColors.infoBg,    AppColors.info,      'En Route'),
      'rider_arrived' => (AppColors.tealBg,    AppColors.teal,      'Arrived'),
      'size_confirmed'=> (AppColors.warningBg, AppColors.warning,   'Confirm Price'),
      'price_approved'=> (AppColors.tealBg,    AppColors.teal,      'Pay Now'),
      'in_progress'   => (AppColors.primaryBg, AppColors.primary,   'In Progress'),
      'completed'     => (AppColors.primaryBg, AppColors.primary,   'Completed'),
      'cancelled'     => (AppColors.errorBg,   AppColors.error,     'Cancelled'),
      _               => (AppColors.dividerLight, AppColors.textMuted, status),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(color: fg, fontSize: 11.5, fontWeight: FontWeight.w600),
      ),
    );
  }
}
