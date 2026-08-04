import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../providers/repository_providers.dart';
import '../../../shared/widgets/widgets.dart';

/// Shown instead of the app when the signed-in account is banned or
/// deactivated (`users.is_banned`/`is_active`) — the router redirects here
/// so a still-valid Supabase Auth session can't be used to reach any
/// feature screen. Only action available is signing out.
///
/// Account deletion does NOT route here — `delete-account` deliberately
/// leaves `is_active` untouched so the same phone can sign back in and
/// re-onboard (the router's onboarding-incomplete redirect handles that
/// case instead). See CLAUDE.md "Account deletion".
class BlockedScreen extends ConsumerStatefulWidget {
  const BlockedScreen({super.key, this.banReason});

  final String? banReason;

  @override
  ConsumerState<BlockedScreen> createState() => _BlockedScreenState();
}

class _BlockedScreenState extends ConsumerState<BlockedScreen> {
  bool _isSigningOut = false;

  Future<void> _signOut() async {
    setState(() => _isSigningOut = true);
    await ref.read(authRepositoryProvider).signOut();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Scrollable: `banReason` is free text set by a moderator, so this
      // screen's height isn't bounded by anything the app controls.
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: (constraints.maxHeight - 48).clamp(0.0, double.infinity),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.block, color: AppColors.danger, size: 48),
                  const SizedBox(height: 24),
                  Text('Account suspended',
                      style: AppTextStyles.headline, textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  Text(
                    widget.banReason?.trim().isNotEmpty == true
                        ? widget.banReason!
                        : "Your account has been suspended or deactivated. If you think this is a mistake, please contact support.",
                    style: AppTextStyles.body,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  PearmoButton(
                    label: 'Sign out',
                    variant: PearmoButtonVariant.outline,
                    isLoading: _isSigningOut,
                    onPressed: _signOut,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
