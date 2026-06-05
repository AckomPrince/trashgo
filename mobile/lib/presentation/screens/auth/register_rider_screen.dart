import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../providers/auth_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../widgets/custom_button.dart';

class RegisterRiderScreen extends ConsumerStatefulWidget {
  const RegisterRiderScreen({super.key});
  @override
  ConsumerState<RegisterRiderScreen> createState() => _RegisterRiderScreenState();
}

class _RegisterRiderScreenState extends ConsumerState<RegisterRiderScreen> {
  final _form = GlobalKey<FormState>();
  final _nameCtrl    = TextEditingController();
  final _emailCtrl   = TextEditingController();
  final _phoneCtrl   = TextEditingController();
  final _passCtrl    = TextEditingController();
  final _vehicleCtrl = TextEditingController();
  final _plateCtrl   = TextEditingController();
  bool _obscure = true;

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    final ok = await ref.read(authProvider.notifier).registerRider(
      fullName:    _nameCtrl.text.trim(),
      email:       _emailCtrl.text.trim(),
      phone:       _phoneCtrl.text.trim(),
      password:    _passCtrl.text,
      vehicleType: _vehicleCtrl.text.trim(),
      vehiclePlate:_plateCtrl.text.trim(),
    );
    if (!mounted) return;
    if (ok) {
      showDialog(context: context, builder: (_) => AlertDialog(
        title: const Text('Registration Submitted'),
        content: const Text('Your rider account is pending admin approval. You will be notified once approved.'),
        actions: [TextButton(onPressed: () { Navigator.pop(context); context.go('/auth/login/rider'); }, child: const Text('OK'))],
      ));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ref.read(authProvider).error ?? 'Failed'), backgroundColor: AppColors.error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Register as Rider'), backgroundColor: Colors.transparent, foregroundColor: AppColors.primary, elevation: 0),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(key: _form, child: Column(children: [
          TextFormField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Full Name', prefixIcon: Icon(Icons.person_outline)), validator: (v) => v!.isEmpty ? 'Required' : null),
          const SizedBox(height: 14),
          TextFormField(controller: _emailCtrl, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email_outlined)), validator: (v) => !v!.contains('@') ? 'Invalid email' : null),
          const SizedBox(height: 14),
          TextFormField(controller: _phoneCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone', prefixIcon: Icon(Icons.phone_outlined)), validator: (v) => v!.length < 10 ? 'Invalid' : null),
          const SizedBox(height: 14),
          TextFormField(controller: _passCtrl, obscureText: _obscure, decoration: InputDecoration(labelText: 'Password', prefixIcon: const Icon(Icons.lock_outline), suffixIcon: IconButton(icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined), onPressed: () => setState(() => _obscure = !_obscure))), validator: (v) => v!.length < 6 ? 'Min 6 chars' : null),
          const SizedBox(height: 14),
          TextFormField(controller: _vehicleCtrl, decoration: const InputDecoration(labelText: 'Vehicle Type (e.g. Truck, Tricycle)', prefixIcon: Icon(Icons.local_shipping_outlined))),
          const SizedBox(height: 14),
          TextFormField(controller: _plateCtrl, decoration: const InputDecoration(labelText: 'Vehicle Plate Number', prefixIcon: Icon(Icons.confirmation_number_outlined))),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: AppColors.primaryLight.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: const Row(children: [
              Icon(Icons.info_outline, color: AppColors.primary, size: 20),
              SizedBox(width: 10),
              Expanded(child: Text('Your account needs admin approval before you can accept orders.', style: TextStyle(fontSize: 13, color: AppColors.textSecondary))),
            ]),
          ),
          const SizedBox(height: 24),
          CustomButton(text: 'Submit Application', isLoading: auth.isLoading, onPressed: _submit),
          TextButton(onPressed: () => context.go('/auth/login/rider'), child: const Text('Already registered? Login')),
        ])),
      ),
    );
  }
}
