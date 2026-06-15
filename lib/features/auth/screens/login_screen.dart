import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/error_mapper.dart';
import '../../../core/utils/validators.dart';
import '../../../providers/repository_providers.dart';
import '../../../shared/widgets/widgets.dart';

/// Phone-number entry screen. Sends an SMS OTP via Supabase phone auth and
/// hands off to [OtpScreen] for verification.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final phone = _phoneController.text.trim();
    try {
      await ref.read(authRepositoryProvider).sendOtp(phone);
      if (!mounted) return;
      context.push('/verify?phone=${Uri.encodeComponent(phone)}');
    } catch (e) {
      setState(() => _error = ErrorMapper.map(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Spacer(),
                Container(
                  width: 72,
                  height: 72,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(colors: AppColors.heroGradient),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.favorite, color: Colors.white, size: 36),
                ),
                const SizedBox(height: 24),
                Text('Welcome to ${AppConstants.appName}', style: AppTextStyles.displayMedium),
                const SizedBox(height: 8),
                Text(
                  'Curated matches, not endless swiping. Enter your phone number to get started.',
                  style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 32),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  autofillHints: const [AutofillHints.telephoneNumber],
                  decoration: const InputDecoration(
                    labelText: 'Phone number',
                    hintText: '+94771234567',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                  validator: Validators.phone,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  ErrorBanner(message: _error!),
                ],
                const SizedBox(height: 24),
                PearmoButton(
                  label: 'Send code',
                  isLoading: _isLoading,
                  onPressed: _sendOtp,
                ),
                const SizedBox(height: 16),
                Text(
                  'By continuing you agree to keep the first conversations on Pearmo\'s platform '
                  'and follow our community safety guidelines.',
                  style: AppTextStyles.caption,
                  textAlign: TextAlign.center,
                ),
                const Spacer(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
