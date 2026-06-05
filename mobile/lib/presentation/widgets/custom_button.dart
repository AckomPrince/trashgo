import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final Color? color;
  final bool outlined;
  const CustomButton({super.key, required this.text, this.onPressed, this.isLoading = false, this.color, this.outlined = false});

  @override
  Widget build(BuildContext context) {
    if (outlined) {
      return OutlinedButton(
        onPressed: isLoading ? null : onPressed,
        child: isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : Text(text),
      );
    }
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: color ?? AppColors.primary,
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onPressed: isLoading ? null : onPressed,
      child: isLoading
          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
          : Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16)),
    );
  }
}

class OrderStatusChip extends StatelessWidget {
  final String status;
  const OrderStatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    Color bg; String label;
    switch (status) {
      case 'requested':          bg = Colors.orange;     label = 'Finding Rider'; break;
      case 'accepted':           bg = Colors.blue;       label = 'Accepted'; break;
      case 'rider_en_route':     bg = Colors.blueAccent; label = 'En Route'; break;
      case 'rider_arrived':      bg = Colors.purple;     label = 'Arrived'; break;
      case 'size_confirmed':     bg = Colors.deepOrange; label = 'Confirm Price'; break;
      case 'price_approved':     bg = Colors.teal;       label = 'Pay Now'; break;
      case 'in_progress':        bg = AppColors.primary; label = 'In Progress'; break;
      case 'completed':          bg = Colors.green;      label = 'Completed'; break;
      case 'cancelled':          bg = Colors.red;        label = 'Cancelled'; break;
      default:                   bg = Colors.grey;       label = status;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(color: bg, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}
