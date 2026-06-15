import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/error_mapper.dart';
import '../../../core/utils/validators.dart';
import '../../../providers/repository_providers.dart';
import '../../../shared/widgets/widgets.dart';

/// 6-digit SMS code entry. On success, ensures the `users` row exists and
/// lets the router redirect to onboarding or home based on profile state.
class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({super.key, required this.phone});

  final String phone;

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  bool _isLoading = false;
  bool _isResending = false;
  String? _error;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final authRepo = ref.read(authRepositoryProvider);
      await authRepo.verifyOtp(phone: widget.phone, token: _codeController.text.trim());
      await authRepo.ensureUserRow();
      // Router redirect handles navigation from here.
    } catch (e) {
      setState(() => _error = ErrorMapper.map(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resend() async {
    setState(() {
      _isResending = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).sendOtp(widget.phone);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A new code is on its way.')),
      );
    } catch (e) {
      setState(() => _error = ErrorMapper.map(e));
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.pop()),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Enter your code', style: AppTextStyles.displayMedium),
                const SizedBox(height: 8),
                Text(
                  'We sent a 6-digit code to ${widget.phone}.',
                  style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 32),
                TextFormField(
                  controller: _codeController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.displayMedium.copyWith(letterSpacing: 8),
                  decoration: const InputDecoration(
                    counterText: '',
                    hintText: '000000',
                  ),
                  validator: Validators.otp,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  ErrorBanner(message: _error!),
                ],
                const SizedBox(height: 24),
                PearmoButton(label: 'Verify', isLoading: _isLoading, onPressed: _verify),
                const SizedBox(height: 12),
                PearmoButton(
                  label: 'Resend code',
                  variant: PearmoButtonVariant.text,
                  isLoading: _isResending,
                  onPressed: _resend,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
