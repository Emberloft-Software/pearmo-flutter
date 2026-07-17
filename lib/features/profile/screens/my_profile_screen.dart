import 'dart:math' as math;

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
///
/// The personality radar renders the private `trait_*` scores (1–5). It is
/// deliberately only shown here — traits are never exposed to other users
/// (see CLAUDE.md: excluded from `public_profiles`, used server-side by
/// `score_compatibility` only).
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
      padding: const EdgeInsets.all(16),
      children: [
        HeroProfileCard(
          avatarId: profile.avatarId,
          photoPath: profile.profilePhotoUrl,
          showPhoto: profile.isPhotoPublic,
          title: '${profile.age} · ${profile.gender.label}',
          subtitle: profile.regionName,
          tierLabel: tier?.label,
          isVerified: tier != null && tier.label != 'Unverified',
        ),
        const SizedBox(height: 12),
        if (profile.audioIntroUrl != null && profile.audioIntroUrl!.isNotEmpty) ...[
          AudioIntroPlayer(storagePath: profile.audioIntroUrl!),
          const SizedBox(height: 12),
        ],
        QuoteCard(
          label: 'In your own words',
          text: profile.aboutText,
          emptyPlaceholder: 'Add something about yourself in settings.',
        ),
        const SizedBox(height: 12),
        BentoCard(
          label: 'Personality',
          child: Column(
            children: [
              const SizedBox(height: 4),
              _TraitRadar(profile: profile),
              const SizedBox(height: 8),
              Text(
                'Only you can see this — matches never see your trait scores.',
                style: AppTextStyles.caption,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        BentoCard(
          label: 'Looking for',
          child: AttributeChipList(labels: [
            profile.relationshipIntent.label,
            'Ages ${profile.seekingAgeMin}–${profile.seekingAgeMax}',
            ...profile.seeking.map((e) => e.label),
          ]),
        ),
        if (profile.partnerValues.isNotEmpty) ...[
          const SizedBox(height: 12),
          BentoCard(
            label: 'Values most in a partner',
            child: AttributeChipList(labels: profile.partnerValues.map((e) => e.label).toList()),
          ),
        ],
        if (profile.musicGenres.isNotEmpty) ...[
          const SizedBox(height: 12),
          BentoCard(
            label: 'Music taste',
            child: AttributeChipList(labels: profile.musicGenres.map((e) => e.label).toList()),
          ),
        ],
        const SizedBox(height: 24),
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

/// Hexagonal radar of the six PEARMO traits (1–5 scale) with labeled rings
/// at every whole step so the axes are readable at a glance.
class _TraitRadar extends StatelessWidget {
  const _TraitRadar({required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context) {
    final traits = <(String, double)>[
      ('Openness', profile.traitOpenness),
      ('Conscient.', profile.traitConscientiousness),
      ('Extraversion', profile.traitExtraversion),
      ('Agreeable.', profile.traitAgreeableness),
      ('Stability', profile.traitEmotionalStability),
      ('Security', profile.traitAttachmentSecurity),
    ];

    return AspectRatio(
      aspectRatio: 1,
      child: CustomPaint(painter: _RadarPainter(traits)),
    );
  }
}

class _RadarPainter extends CustomPainter {
  _RadarPainter(this.traits);

  /// (label, score 1.0–5.0) per axis, clockwise from the top.
  final List<(String, double)> traits;

  static const double _min = 1;
  static const double _max = 5;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 * 0.62;
    final n = traits.length;

    Offset point(int axis, double fraction) {
      final angle = -math.pi / 2 + axis * 2 * math.pi / n;
      return center +
          Offset(math.cos(angle), math.sin(angle)) * radius * fraction;
    }

    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = AppColors.divider;

    // Grid rings at scores 2, 3, 4, 5.
    for (var score = 2; score <= 5; score++) {
      final fraction = (score - _min) / (_max - _min);
      final path = Path();
      for (var i = 0; i < n; i++) {
        final p = point(i, fraction);
        i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
      }
      path.close();
      canvas.drawPath(path, ringPaint);
    }

    // Axis lines.
    for (var i = 0; i < n; i++) {
      canvas.drawLine(center, point(i, 1), ringPaint);
    }

    // Scale tick numbers (1–5) along the vertical axis.
    for (var score = 1; score <= 5; score++) {
      final fraction = (score - _min) / (_max - _min);
      final pos = center - Offset(0, radius * fraction);
      _paintText(
        canvas,
        '$score',
        pos + const Offset(-8, 0),
        AppTextStyles.caption.copyWith(fontSize: 9),
        anchorRight: true,
      );
    }

    // Score polygon — single data color (violet).
    final scorePath = Path();
    final dots = <Offset>[];
    for (var i = 0; i < n; i++) {
      final value = traits[i].$2.clamp(_min, _max);
      final p = point(i, (value - _min) / (_max - _min));
      dots.add(p);
      i == 0 ? scorePath.moveTo(p.dx, p.dy) : scorePath.lineTo(p.dx, p.dy);
    }
    scorePath.close();
    canvas.drawPath(
      scorePath,
      Paint()..color = AppColors.primary.withValues(alpha: 0.16),
    );
    canvas.drawPath(
      scorePath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeJoin = StrokeJoin.round
        ..color = AppColors.primary,
    );
    for (final p in dots) {
      canvas.drawCircle(p, 5, Paint()..color = Colors.white);
      canvas.drawCircle(p, 3.5, Paint()..color = AppColors.primary);
    }

    // Axis labels + values just beyond each vertex.
    for (var i = 0; i < n; i++) {
      final labelPos = point(i, 1.28);
      _paintText(
        canvas,
        traits[i].$1,
        labelPos + const Offset(0, -7),
        AppTextStyles.caption.copyWith(
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
          fontSize: 11,
        ),
      );
      _paintText(
        canvas,
        traits[i].$2.toStringAsFixed(1),
        labelPos + const Offset(0, 7),
        AppTextStyles.caption.copyWith(fontSize: 10),
      );
    }
  }

  void _paintText(Canvas canvas, String text, Offset at, TextStyle style,
      {bool anchorRight = false}) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    final offset = anchorRight
        ? at - Offset(painter.width, painter.height / 2)
        : at - Offset(painter.width / 2, painter.height / 2);
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(_RadarPainter oldDelegate) => oldDelegate.traits != traits;
}
