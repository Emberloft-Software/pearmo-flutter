import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  /// Every OTP costs a real SMS, so the send button locks for a minute
  /// after each one. This is convenience, not security — the actual
  /// backstop is Supabase Auth's server-side SMS rate limit, since anyone
  /// can call the endpoint without going through this screen.
  static const _sendCooldown = Duration(seconds: 60);
  DateTime? _lastSentAt;
  Timer? _cooldownTicker;

  int get _cooldownRemaining {
    final last = _lastSentAt;
    if (last == null) return 0;
    final left = _sendCooldown - DateTime.now().difference(last);
    return left.isNegative ? 0 : left.inSeconds + 1;
  }

  void _startCooldown() {
    _lastSentAt = DateTime.now();
    _cooldownTicker?.cancel();
    _cooldownTicker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _cooldownRemaining == 0) {
        timer.cancel();
      }
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _cooldownTicker?.cancel();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    if (_cooldownRemaining > 0) return;
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    // Always send the normalised E.164 form, never the raw field text —
    // Supabase Auth keys accounts by the exact string, so this is what stops
    // one person from ending up with two identities.
    final phone = Validators.normalizeSriLankanMobile(_phoneController.text)!;
    try {
      await ref.read(authRepositoryProvider).sendOtp(phone);
      if (!mounted) return;
      // Only after a send actually succeeded — a failed attempt sent no SMS
      // and shouldn't cost the user a minute.
      _startCooldown();
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
      // Scrollable, not a fixed Column with Spacers. Focusing the phone field
      // opens the keyboard, which takes ~300px off this screen — more than
      // the Spacers can give back — so everything past the fold was simply
      // clipped, which is why parts of the copy went missing. The minHeight
      // keeps the content vertically centred whenever it does fit.
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: (constraints.maxHeight - 48).clamp(0.0, double.infinity),
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Two of the 3D characters on the stage gradient — the brand
                    // moment before any text.
                    Container(
                      width: 108,
                      height: 96,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: AppColors.heroGradient,
                          begin: Alignment.topRight,
                          end: Alignment.bottomLeft,
                        ),
                        borderRadius: BorderRadius.circular(28),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Stack(
                        children: [
                          Positioned(
                            left: -14,
                            bottom: -6,
                            width: 76,
                            child: Image.asset(
                              'assets/avatars/fox-f.png',
                              errorBuilder: (_, _, _) => const SizedBox.shrink(),
                            ),
                          ),
                          Positioned(
                            right: -14,
                            bottom: -6,
                            width: 76,
                            child: Image.asset(
                              'assets/avatars/wolf-m.png',
                              errorBuilder: (_, _, _) => const SizedBox.shrink(),
                            ),
                          ),
                        ],
                      ),
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
                      // Digits only: the country code is fixed and shown, so a
                      // typed `+` can only ever be a mistake.
                      //
                      // We ask for 10 digits (`0771234567`) because that's how
                      // Sri Lankans actually write their number — making them
                      // drop the leading 0 to suit the displayed +94 just
                      // invites mistyping. `normalizeSriLankanMobile` strips the
                      // 0 if present and accepts 9 digits too.
                      //
                      // The cap is 11, not 10, so an autofilled or pasted
                      // `94771234567` still normalises instead of being silently
                      // truncated into an invalid number. The counter is hidden,
                      // so the user only ever sees the "10 digits" ask.
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      maxLength: 11,
                      decoration: const InputDecoration(
                        labelText: 'Mobile number',
                        hintText: '0771234567',
                        helperText: 'Your 10-digit mobile number, no need to type +94',
                        counterText: '',
                        // Fixed-width, self-centering box rather than a padded
                        // Text with zero-size constraints — the latter let the
                        // prefix and the input text share horizontal space and
                        // overlap.
                        //
                        // Has to be `prefixIcon`, not `prefix`: Flutter only
                        // renders `prefix` once the field is focused or has
                        // text, and +94 needs to be visible before the user
                        // taps in, otherwise they'll type it themselves.
                        //
                        // 🇱🇰 falls back to the letters "LK" on some older
                        // Android builds, which still reads correctly here.
                        prefixIcon: SizedBox(
                          width: 78,
                          child: Center(
                            child: Text(
                              '🇱🇰 +94',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                        prefixIconConstraints: BoxConstraints(minWidth: 78, maxWidth: 78),
                      ),
                      validator: Validators.sriLankanMobile,
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      ErrorBanner(message: _error!),
                    ],
                    const SizedBox(height: 24),
                    PearmoButton(
                      label: _cooldownRemaining > 0
                          ? 'Send code in ${_cooldownRemaining}s'
                          : 'Send code',
                      isLoading: _isLoading,
                      onPressed: _cooldownRemaining > 0 ? null : _sendOtp,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'By continuing you agree to keep the first conversations on Pearmo\'s platform '
                      'and follow our community safety guidelines.',
                      style: AppTextStyles.caption,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
