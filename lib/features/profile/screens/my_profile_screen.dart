import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/enums.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/error_mapper.dart';
import '../../../data/models/profile.dart';
import '../../../providers/profile_providers.dart';
import '../../../providers/repository_providers.dart';
import '../../../shared/widgets/widgets.dart';

/// The signed-in user's own profile — a read-only view of everything set
/// during onboarding plus their live verification tier. Editing lives in
/// Settings, Verification and Membership below.
// TODO(backend): the brainstorm's AI agent assistant (chat-based profile
// help, conversation coaching, etc.) has no edge function yet — would need
// its own entry point here once that's built.
class MyProfileScreen extends ConsumerWidget {
  const MyProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(myProfileProvider);
    final tierAsync = ref.watch(myVerificationTierProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Your Profile')),
      body: profileAsync.when(
        data: (profile) {
          if (profile == null) {
            return const EmptyState(
              icon: Icons.person_outline,
              title: 'No profile yet',
              message: 'Complete onboarding to set up your profile.',
            );
          }
          return _buildBody(context, ref, profile, tierAsync.valueOrNull);
        },
        loading: () => const LoadingIndicator(),
        error: (error, _) => Padding(
          padding: const EdgeInsets.all(20),
          child: ErrorBanner(message: ErrorMapper.map(error)),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, WidgetRef ref, Profile profile, VerificationTier? tier) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Center(
          child: SignedAvatarDisplay(
            avatarId: profile.avatarId,
            photoPath: profile.profilePhotoUrl,
            showPhoto: profile.isPhotoPublic,
            size: 120,
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: Text('${profile.age} · ${profile.gender.label}', style: AppTextStyles.headline),
        ),
        if (tier != null) ...[
          const SizedBox(height: 8),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: tier.label == 'Unverified'
                    ? AppColors.surfaceMuted
                    : AppColors.secondaryLight,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    tier.label == 'Unverified' ? Icons.shield_outlined : Icons.verified,
                    size: 16,
                    color: tier.label == 'Unverified'
                        ? AppColors.textSecondary
                        : AppColors.secondaryDark,
                  ),
                  const SizedBox(width: 6),
                  Text(tier.label, style: AppTextStyles.caption),
                ],
              ),
            ),
          ),
        ],
        if (profile.regionName != null) ...[
          const SizedBox(height: 4),
          Center(child: Text(profile.regionName!, style: AppTextStyles.caption)),
        ],
        const SizedBox(height: 24),
        if (profile.audioIntroUrl != null && profile.audioIntroUrl!.isNotEmpty) ...[
          AudioIntroPlayer(storagePath: profile.audioIntroUrl!),
          const SizedBox(height: 24),
        ],
        const SectionHeader(title: 'About'),
        Text(
          profile.aboutText.isEmpty ? 'Add something about yourself in settings.' : profile.aboutText,
          style: AppTextStyles.bodyLarge,
        ),
        const SizedBox(height: 24),
        const SectionHeader(title: 'Looking for'),
        AttributeChipList(labels: [
          profile.relationshipIntent.label,
          profile.lifeStage.label,
          profile.energyType.label,
          profile.conflictStyle.label,
          profile.lifestylePace.label,
        ]),
        if (profile.partnerValues.isNotEmpty) ...[
          const SizedBox(height: 24),
          const SectionHeader(title: 'Values most in a partner'),
          AttributeChipList(labels: profile.partnerValues.map((e) => e.label).toList()),
        ],
        if (profile.musicGenres.isNotEmpty) ...[
          const SizedBox(height: 24),
          const SectionHeader(title: 'Music taste'),
          AttributeChipList(labels: profile.musicGenres.map((e) => e.label).toList()),
        ],
        const SizedBox(height: 24),
        const SectionHeader(title: "Who you're open to meeting"),
        AttributeChipList(labels: profile.seeking.map((e) => e.label).toList()),
        const SizedBox(height: 32),
        PearmoButton(
          label: 'Settings',
          variant: PearmoButtonVariant.outline,
          icon: Icons.settings_outlined,
          onPressed: () => context.push('/settings'),
        ),
        const SizedBox(height: 12),
        PearmoButton(
          label: 'Verification',
          variant: PearmoButtonVariant.outline,
          icon: Icons.verified_user_outlined,
          onPressed: () => context.push('/verification'),
        ),
        const SizedBox(height: 12),
        PearmoButton(
          label: 'Membership',
          variant: PearmoButtonVariant.outline,
          icon: Icons.workspace_premium_outlined,
          onPressed: () => context.push('/payments'),
        ),
        const SizedBox(height: 12),
        PearmoButton(
          label: 'Sign out',
          variant: PearmoButtonVariant.outline,
          icon: Icons.logout,
          onPressed: () => ref.read(authRepositoryProvider).signOut(),
        ),
      ],
    );
  }
}
