import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../providers/repository_providers.dart';
import '../../../shared/widgets/widgets.dart';

/// Shown instead of the app when the signed-in account is banned,
/// deactivated, or self-deleted (`users.is_banned`/`is_active`/`deleted_at`)
/// — the router redirects here so a still-valid Supabase Auth session can't
/// be used to reach any feature screen. Only action available is signing
/// out. Deletion normally signs the user out immediately after the
/// `delete-account` call succeeds (see `AuthRepository.deleteAccount()`),
/// so `isDeleted` here only matters if that second step didn't complete
/// (e.g. the app was killed mid-flow) and the session is still valid.
class BlockedScreen extends ConsumerStatefulWidget {
  const BlockedScreen({super.key, this.banReason, this.isDeleted = false});

  final String? banReason;
  final bool isDeleted;

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
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  widget.isDeleted ? Icons.delete_outline : Icons.block,
                  color: AppColors.danger,
                  size: 48,
                ),
                const SizedBox(height: 24),
                Text(
                  widget.isDeleted ? 'Account deleted' : 'Account suspended',
                  style: AppTextStyles.headline,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  widget.isDeleted
                      ? "Your account has been deleted. Sign out to finish — you're welcome to create "
                          'a new account any time.'
                      : (widget.banReason?.trim().isNotEmpty == true
                          ? widget.banReason!
                          : "Your account has been suspended or deactivated. If you think this is a "
                              'mistake, please contact support.'),
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
    );
  }
}
