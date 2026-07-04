import 'dart:async';

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
  Timer? _cooldownTimer;
  int _cooldownSeconds = 0;

  static const _resendCooldown = 30;

  @override
  void dispose() {
    _codeController.dispose();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  /// Client-side cooldown so a fast double/triple tap can't fire off
  /// several SMS sends before the first request round-trips — Supabase's
  /// own rate limit is the real backstop, this is just UX.
  void _startCooldown() {
    _cooldownTimer?.cancel();
    setState(() => _cooldownSeconds = _resendCooldown);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _cooldownSeconds--;
        if (_cooldownSeconds <= 0) timer.cancel();
      });
    });
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
    if (_isResending || _cooldownSeconds > 0) return;
    setState(() {
      _isResending = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).sendOtp(widget.phone);
      if (!mounted) return;
      _startCooldown();
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
                  label: _cooldownSeconds > 0 ? 'Resend code (${_cooldownSeconds}s)' : 'Resend code',
                  variant: PearmoButtonVariant.text,
                  isLoading: _isResending,
                  onPressed: _cooldownSeconds > 0 ? null : _resend,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
