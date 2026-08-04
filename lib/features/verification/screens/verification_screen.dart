import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/enums.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_mapper.dart';
import '../../../data/repositories/verification_repository.dart';
import '../../../providers/auth_providers.dart';
import '../../../providers/profile_providers.dart';
import '../../../providers/repository_providers.dart';
import '../../../shared/widgets/widgets.dart';
import '../widgets/liveness_check_screen.dart';

/// Two independently-submittable verification tiers:
/// 1. Liveliness check + selfie — proves the user is a real person.
/// 2. NIC front/back, on top of tier 1 — proves the displayed age is real.
/// Both are uploaded to the private `nic-documents` bucket, then
/// `submit-verification` queues them for manual review.
class VerificationScreen extends ConsumerWidget {
  const VerificationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tierAsync = ref.watch(myVerificationTierProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Verification')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          tierAsync.when(
            data: (tier) => _TierBanner(tier: tier),
            loading: () => const LoadingIndicator(),
            error: (error, _) => ErrorBanner(message: ErrorMapper.map(error)),
          ),
          const SizedBox(height: 12),
          VerificationDisclaimer(tier: tierAsync.valueOrNull),
          const SizedBox(height: 24),
          _SelfieTierCard(currentTier: tierAsync.valueOrNull),
          const SizedBox(height: 24),
          _IdTierCard(currentTier: tierAsync.valueOrNull),
        ],
      ),
    );
  }
}

class _TierBanner extends StatelessWidget {
  const _TierBanner({required this.tier});

  final VerificationTier tier;

  @override
  Widget build(BuildContext context) {
    final (icon, color, message) = switch (tier) {
      VerificationTier.unverified => (Icons.shield_outlined, AppColors.textSecondary, 'Not verified yet.'),
      VerificationTier.selfieVerified =>
        (Icons.verified, AppColors.secondaryDark, "You're verified as a real person."),
      VerificationTier.idVerified =>
        (Icons.verified, AppColors.secondaryDark, 'Your age is verified.'),
      VerificationTier.paidVerified =>
        (Icons.workspace_premium, AppColors.secondaryDark, 'Verified Plus.'),
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(child: Text(message, style: AppTextStyles.bodyMedium)),
        ],
      ),
    );
  }
}

/// Tier 1 card — liveliness check, then selfie, then submit.
class _SelfieTierCard extends ConsumerStatefulWidget {
  const _SelfieTierCard({required this.currentTier});

  final VerificationTier? currentTier;

  @override
  ConsumerState<_SelfieTierCard> createState() => _SelfieTierCardState();
}

class _SelfieTierCardState extends ConsumerState<_SelfieTierCard> {
  File? _selfie;
  bool _isSubmitting = false;
  bool _loadingStatus = true;
  VerificationSubmissionStatus? _lastSubmission;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;
    final status = await ref
        .read(verificationRepositoryProvider)
        .getLatestSubmission(userId: userId, tier: 'selfie');
    if (mounted) {
      setState(() {
        _lastSubmission = status;
        _loadingStatus = false;
      });
    }
  }

  Future<void> _runLivenessCheck() async {
    final result = await Navigator.of(context).push<File>(
      MaterialPageRoute(builder: (_) => const LivenessCheckScreen()),
    );
    if (result != null) setState(() => _selfie = result);
  }

  Future<void> _submit() async {
    final selfie = _selfie;
    if (selfie == null) {
      setState(() => _error = 'Run the liveliness check first.');
      return;
    }
    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    final userId = ref.read(currentUserIdProvider);
    try {
      if (userId == null) throw Exception('Not signed in');
      final storage = ref.read(storageRepositoryProvider);
      final selfiePath = await storage.uploadSelfie(userId, selfie);
      await ref.read(verificationRepositoryProvider).submitSelfieVerification(
            selfiePath: selfiePath,
            livelinessPassed: true,
          );
      ref.invalidate(myVerificationTierProvider);
      await _loadStatus();
    } catch (e) {
      setState(() => _error = ErrorMapper.map(e));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final alreadyVerified = (widget.currentTier?.isAtLeastSelfieVerified ?? false);
    final isPending = _lastSubmission?.status == 'pending';
    final isRejected = _lastSubmission?.status == 'rejected';

    return PearmoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.face_retouching_natural, color: AppColors.secondaryDark),
              const SizedBox(width: 8),
              Expanded(
                child: Text('1. Verify you\'re real', style: AppTextStyles.title),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'A quick liveliness check (look straight, blink, turn your head) followed by a '
            "selfie. Reviewed manually, and shows matches you're a real person.",
            style: AppTextStyles.body,
          ),
          const SizedBox(height: 16),
          if (alreadyVerified)
            Text('Already verified.', style: AppTextStyles.bodyMedium)
          else if (_loadingStatus)
            const LoadingIndicator()
          else ...[
            if (isRejected) ...[
              ErrorBanner(
                message: _lastSubmission?.rejectionReason?.trim().isNotEmpty == true
                    ? 'Your last submission was rejected: ${_lastSubmission!.rejectionReason}'
                    : 'Your last submission was rejected. Please try again.',
              ),
              const SizedBox(height: 12),
            ],
            _DocumentPreview(
              file: _selfie,
              label: 'Run liveliness check',
              icon: Icons.camera_front_outlined,
              onTap: _isSubmitting ? null : _runLivenessCheck,
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              ErrorBanner(message: _error!),
            ],
            const SizedBox(height: 16),
            PearmoButton(
              label: isPending ? 'Submitted, awaiting review' : 'Submit for review',
              icon: Icons.shield_outlined,
              isLoading: _isSubmitting,
              onPressed: (_isSubmitting || isPending) ? null : _submit,
            ),
          ],
        ],
      ),
    );
  }
}

/// Tier 2 card — NIC front/back, locked until tier 1 has passed.
class _IdTierCard extends ConsumerStatefulWidget {
  const _IdTierCard({required this.currentTier});

  final VerificationTier? currentTier;

  @override
  ConsumerState<_IdTierCard> createState() => _IdTierCardState();
}

class _IdTierCardState extends ConsumerState<_IdTierCard> {
  final _picker = ImagePicker();
  File? _nicFront;
  File? _nicBack;
  bool _isSubmitting = false;
  bool _loadingStatus = true;
  VerificationSubmissionStatus? _lastSubmission;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;
    final status = await ref
        .read(verificationRepositoryProvider)
        .getLatestSubmission(userId: userId, tier: 'id');
    if (mounted) {
      setState(() {
        _lastSubmission = status;
        _loadingStatus = false;
      });
    }
  }

  Future<void> _pick(void Function(File) onPicked) async {
    final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked != null) setState(() => onPicked(File(picked.path)));
  }

  Future<void> _submit() async {
    if (_nicFront == null) {
      setState(() => _error = 'Please add at least the NIC front photo.');
      return;
    }
    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    final userId = ref.read(currentUserIdProvider);
    try {
      if (userId == null) throw Exception('Not signed in');
      final storage = ref.read(storageRepositoryProvider);
      final nicFrontPath = await storage.uploadNicFront(userId, _nicFront!);
      final nicBackPath = _nicBack != null ? await storage.uploadNicBack(userId, _nicBack!) : null;
      await ref.read(verificationRepositoryProvider).submitIdVerification(
            nicFrontPath: nicFrontPath,
            nicBackPath: nicBackPath,
          );
      ref.invalidate(myVerificationTierProvider);
      await _loadStatus();
    } catch (e) {
      setState(() => _error = ErrorMapper.map(e));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final unlocked = widget.currentTier?.isAtLeastSelfieVerified ?? false;
    final alreadyVerified = widget.currentTier == VerificationTier.idVerified ||
        widget.currentTier == VerificationTier.paidVerified;
    final isPending = _lastSubmission?.status == 'pending';
    final isRejected = _lastSubmission?.status == 'rejected';

    return PearmoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                unlocked ? Icons.badge_outlined : Icons.lock_outline,
                color: unlocked ? AppColors.secondaryDark : AppColors.textSecondary,
              ),
              const SizedBox(width: 8),
              // Expanded, not bare: at 18px this title is wider than the
              // card's inner width on a 360dp phone, so it overflowed there
              // at the default text scale.
              Expanded(
                child: Text('2. Verify your age (optional)', style: AppTextStyles.title),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            unlocked
                ? 'Add your National ID so we can manually confirm the age on your profile '
                    'matches your document.'
                : 'Complete step 1 (verify you\'re real) first to unlock this step.',
            style: AppTextStyles.body,
          ),
          if (unlocked) ...[
            const SizedBox(height: 16),
            if (alreadyVerified)
              Text('Already verified.', style: AppTextStyles.bodyMedium)
            else if (_loadingStatus)
              const LoadingIndicator()
            else ...[
              if (isRejected) ...[
                ErrorBanner(
                  message: _lastSubmission?.rejectionReason?.trim().isNotEmpty == true
                      ? 'Your last submission was rejected: ${_lastSubmission!.rejectionReason}'
                      : 'Your last submission was rejected. Please try again.',
                ),
                const SizedBox(height: 12),
              ],
              Row(
                children: [
                  Expanded(
                    child: _DocumentPreview(
                      file: _nicFront,
                      label: 'NIC front',
                      icon: Icons.badge_outlined,
                      onTap: _isSubmitting ? null : () => _pick((f) => _nicFront = f),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _DocumentPreview(
                      file: _nicBack,
                      label: 'NIC back (optional)',
                      icon: Icons.badge_outlined,
                      onTap: _isSubmitting ? null : () => _pick((f) => _nicBack = f),
                    ),
                  ),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                ErrorBanner(message: _error!),
              ],
              const SizedBox(height: 16),
              PearmoButton(
                label: isPending ? 'Submitted, awaiting review' : 'Submit for review',
                icon: Icons.shield_outlined,
                isLoading: _isSubmitting,
                onPressed: (_isSubmitting || isPending) ? null : _submit,
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _DocumentPreview extends StatelessWidget {
  const _DocumentPreview({
    required this.file,
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final File? file;
  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      onTap: onTap,
      child: Container(
        height: 120,
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          border: Border.all(color: AppColors.divider),
        ),
        clipBehavior: Clip.antiAlias,
        child: file != null
            ? Image.file(file!, fit: BoxFit.cover, width: double.infinity)
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: AppColors.textSecondary),
                  const SizedBox(height: 8),
                  Text(label, style: AppTextStyles.caption),
                ],
              ),
      ),
    );
  }
}
