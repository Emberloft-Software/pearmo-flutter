import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/enums.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_mapper.dart';
import '../../../providers/auth_providers.dart';
import '../../../providers/profile_providers.dart';
import '../../../providers/repository_providers.dart';
import '../../../shared/widgets/widgets.dart';

const _benefits = [
  'Higher visibility in daily matches',
  'A "Verified Plus" badge on your profile',
  'Priority manual review for future verification needs',
];

/// Membership / "Verified Plus" upsell. Launches a PayHere hosted checkout
/// via `create-payhere-order` — once paid, `users.verification_tier`
/// updates server-side and `myVerificationTierProvider` picks it up live.
class PaymentsScreen extends ConsumerStatefulWidget {
  const PaymentsScreen({super.key});

  @override
  ConsumerState<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends ConsumerState<PaymentsScreen> {
  bool _isStartingCheckout = false;
  String? _error;

  Future<void> _upgrade(String userId) async {
    setState(() {
      _isStartingCheckout = true;
      _error = null;
    });
    try {
      final url = await ref.read(paymentsRepositoryProvider).createCheckoutUrl(userId);
      final launched = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      if (!launched) {
        setState(() => _error = 'Could not open the checkout page.');
      }
    } catch (e) {
      setState(() => _error =
          'Payments aren\'t available yet — please check back soon. (${ErrorMapper.map(e)})');
    } finally {
      if (mounted) setState(() => _isStartingCheckout = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tierAsync = ref.watch(myVerificationTierProvider);
    final userId = ref.watch(currentUserIdProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Membership')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          tierAsync.when(
            data: (tier) => _TierCard(tier: tier),
            loading: () => const LoadingIndicator(),
            error: (error, _) => ErrorBanner(message: ErrorMapper.map(error)),
          ),
          const SizedBox(height: 24),
          const SectionHeader(title: 'Verified Plus benefits'),
          ..._benefits.map((b) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_outline, color: AppColors.secondaryDark, size: 20),
                    const SizedBox(width: 10),
                    Expanded(child: Text(b, style: AppTextStyles.body)),
                  ],
                ),
              )),
          if (_error != null) ...[
            const SizedBox(height: 16),
            ErrorBanner(message: _error!),
          ],
          const SizedBox(height: 24),
          tierAsync.maybeWhen(
            data: (tier) => tier == VerificationTier.paidVerified
                ? const SizedBox.shrink()
                : PearmoButton(
                    label: 'Upgrade to Verified Plus',
                    icon: Icons.workspace_premium_outlined,
                    isLoading: _isStartingCheckout,
                    onPressed: (_isStartingCheckout || userId == null)
                        ? null
                        : () => _upgrade(userId),
                  ),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _TierCard extends StatelessWidget {
  const _TierCard({required this.tier});

  final VerificationTier tier;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      ),
      child: Row(
        children: [
          Icon(
            tier == VerificationTier.paidVerified ? Icons.workspace_premium : Icons.shield_outlined,
            color: tier == VerificationTier.paidVerified
                ? AppColors.secondaryDark
                : AppColors.textSecondary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Current plan', style: AppTextStyles.caption),
                Text(tier.label, style: AppTextStyles.title),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
