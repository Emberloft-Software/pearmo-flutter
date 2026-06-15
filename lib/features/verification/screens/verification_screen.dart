import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/enums.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_mapper.dart';
import '../../../providers/auth_providers.dart';
import '../../../providers/profile_providers.dart';
import '../../../providers/repository_providers.dart';
import '../../../shared/widgets/widgets.dart';

/// ID + selfie verification. NIC photos and a live selfie are uploaded to
/// the private `nic-documents` bucket, then `submit-verification` queues
/// them for manual review.
// TODO(backend): no OCR/liveness check yet — `submit-verification` is
// manual-review only. An automated pre-check could call an OCR/liveness
// edge function here before queuing for review.
class VerificationScreen extends ConsumerStatefulWidget {
  const VerificationScreen({super.key});

  @override
  ConsumerState<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends ConsumerState<VerificationScreen> {
  final _picker = ImagePicker();
  File? _nicFront;
  File? _nicBack;
  File? _selfie;
  bool _isSubmitting = false;
  bool _submitted = false;
  String? _error;

  Future<void> _pick(ImageSource source, void Function(File) onPicked) async {
    final picked = await _picker.pickImage(source: source, imageQuality: 85);
    if (picked != null) {
      setState(() => onPicked(File(picked.path)));
    }
  }

  Future<void> _submit(String userId) async {
    if (_nicFront == null || _selfie == null) {
      setState(() => _error = 'Please add at least your NIC front and a selfie.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    try {
      final storage = ref.read(storageRepositoryProvider);
      final nicFrontPath = await storage.uploadNicFront(userId, _nicFront!);
      final nicBackPath =
          _nicBack != null ? await storage.uploadNicBack(userId, _nicBack!) : null;
      final selfiePath = await storage.uploadSelfie(userId, _selfie!);

      await ref.read(verificationRepositoryProvider).submitVerification(
            nicFrontPath: nicFrontPath,
            nicBackPath: nicBackPath,
            selfiePath: selfiePath,
          );
      ref.invalidate(myVerificationTierProvider);
      setState(() => _submitted = true);
    } catch (e) {
      setState(() => _error = ErrorMapper.map(e));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tierAsync = ref.watch(myVerificationTierProvider);
    final userId = ref.watch(currentUserIdProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Verification')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          tierAsync.when(
            data: (tier) => _TierBanner(tier: tier, justSubmitted: _submitted),
            loading: () => const LoadingIndicator(),
            error: (error, _) => ErrorBanner(message: ErrorMapper.map(error)),
          ),
          const SizedBox(height: 24),
          Text(
            'Verifying your identity unlocks higher visibility for your profile and shows '
            "matches you're a real person. Your documents are reviewed manually and kept private.",
            style: AppTextStyles.body,
          ),
          const SizedBox(height: 24),
          const SectionHeader(title: 'National ID — front'),
          _DocumentPicker(
            file: _nicFront,
            label: 'Add NIC front photo',
            onTap: () => _pick(ImageSource.gallery, (f) => _nicFront = f),
          ),
          const SizedBox(height: 20),
          const SectionHeader(title: 'National ID — back (optional)'),
          _DocumentPicker(
            file: _nicBack,
            label: 'Add NIC back photo',
            onTap: () => _pick(ImageSource.gallery, (f) => _nicBack = f),
          ),
          const SizedBox(height: 20),
          const SectionHeader(title: 'Selfie'),
          _DocumentPicker(
            file: _selfie,
            label: 'Take a selfie',
            onTap: () => _pick(ImageSource.camera, (f) => _selfie = f),
          ),
          if (_error != null) ...[
            const SizedBox(height: 20),
            ErrorBanner(message: _error!),
          ],
          const SizedBox(height: 28),
          PearmoButton(
            label: _submitted ? 'Submitted for review' : 'Submit for review',
            icon: Icons.shield_outlined,
            isLoading: _isSubmitting,
            onPressed: (_isSubmitting || _submitted || userId == null)
                ? null
                : () => _submit(userId),
          ),
        ],
      ),
    );
  }
}

class _TierBanner extends StatelessWidget {
  const _TierBanner({required this.tier, required this.justSubmitted});

  final VerificationTier tier;
  final bool justSubmitted;

  @override
  Widget build(BuildContext context) {
    final (icon, color, message) = switch (tier) {
      VerificationTier.unverified => justSubmitted
          ? (Icons.hourglass_top, AppColors.accentLavender, 'Submitted — pending manual review.')
          : (Icons.shield_outlined, AppColors.textSecondary, 'Not verified yet.'),
      VerificationTier.idVerified => (Icons.verified, AppColors.secondaryDark, 'ID verified.'),
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

class _DocumentPicker extends StatelessWidget {
  const _DocumentPicker({required this.file, required this.label, required this.onTap});

  final File? file;
  final String label;
  final VoidCallback onTap;

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
                  const Icon(Icons.add_a_photo_outlined, color: AppColors.textSecondary),
                  const SizedBox(height: 8),
                  Text(label, style: AppTextStyles.caption),
                ],
              ),
      ),
    );
  }
}
