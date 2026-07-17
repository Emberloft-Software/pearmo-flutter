import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/enums.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/error_mapper.dart';
import '../../../data/models/profile.dart';
import '../../../providers/auth_providers.dart';
import '../../../providers/connections_providers.dart';
import '../../../providers/matches_providers.dart';
import '../../../providers/profile_providers.dart';
import '../../../providers/repository_providers.dart';
import '../../../shared/avatars/avatar_catalog.dart';
import '../../../shared/widgets/widgets.dart';

/// The signed-in user's own profile: pinned hero card, then tabbed bento
/// sections (About / Personality / Music) and a compact account-action
/// grid. Editing lives in Settings, Verification and Membership.
///
/// The personality radar renders the private `trait_*` scores (1–5). It is
/// deliberately only shown here — traits are never exposed to other users
/// (see CLAUDE.md: excluded from `public_profiles`, used server-side by
/// `score_compatibility` only).
// TODO(backend): the brainstorm's AI agent assistant (chat-based profile
// help, conversation coaching, etc.) has no edge function yet — would need
// its own entry point here once that's built.
class MyProfileScreen extends ConsumerStatefulWidget {
  const MyProfileScreen({super.key});

  @override
  ConsumerState<MyProfileScreen> createState() => _MyProfileScreenState();
}

class _MyProfileScreenState extends ConsumerState<MyProfileScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(myProfileProvider);
    final tierAsync = ref.watch(myVerificationTierProvider);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: profileAsync.maybeWhen(
          data: (profile) => profile == null
              ? const Text('Profile')
              : _HeaderTitle(profile: profile, tier: tierAsync.valueOrNull),
          orElse: () => const Text('Profile'),
        ),
      ),
      body: profileAsync.when(
        data: (profile) {
          if (profile == null) {
            return const EmptyState(
              icon: Icons.person_outline,
              title: 'No profile yet',
              message: 'Complete onboarding to set up your profile.',
            );
          }
          return _buildBody(context, profile, tierAsync.valueOrNull);
        },
        loading: () => const LoadingIndicator(),
        error: (error, _) => Padding(
          padding: const EdgeInsets.all(20),
          child: ErrorBanner(message: ErrorMapper.map(error)),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, Profile profile, VerificationTier? tier) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        HeroProfileCard(
          avatarId: profile.avatarId,
          photoPath: profile.profilePhotoUrl,
          showPhoto: profile.isPhotoPublic,
          displayName: profile.displayName ??
              'The ${AvatarCatalog.resolve(profile.avatarId).character.name}',
          kicker: 'Profile · ${_pronouns(profile.gender)}',
          title: '${profile.age} · ${profile.gender.label}',
          subtitle: profile.regionName,
          tierLabel: tier?.label,
          isVerified: tier != null && tier.label != 'Unverified',
          audioPath: profile.audioIntroUrl,
        ),
        const SizedBox(height: 12),
        _SegmentedTabs(
          index: _tab,
          onChanged: (i) => setState(() => _tab = i),
          items: const [
            (Icons.person_outline, 'About'),
            (Icons.track_changes, 'Personality'),
            (Icons.music_note_outlined, 'Music'),
          ],
        ),
        const SizedBox(height: 12),
        ..._tabChildren(profile),
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Text('ACCOUNT', style: AppTextStyles.label),
        ),
        const SizedBox(height: 10),
        _AccountGrid(
          onSettings: () => context.push('/settings'),
          onVerification: () => context.push('/verification'),
          onMembership: () => context.push('/payments'),
          onSignOut: () => ref.read(authRepositoryProvider).signOut(),
        ),
      ],
    );
  }

  static String _pronouns(Gender gender) => switch (gender) {
        Gender.woman => 'She/Her',
        Gender.man => 'He/Him',
        _ => 'They/Them',
      };

  List<Widget> _tabChildren(Profile profile) => switch (_tab) {
        0 => [
            QuoteCard(
              label: 'In your own words',
              text: profile.aboutText,
              emptyPlaceholder: 'Add something about yourself in settings.',
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
                child: AttributeChipList(
                    labels: profile.partnerValues.map((e) => e.label).toList()),
              ),
            ],
          ],
        1 => [
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
            _TraitRow(
              icon: Icons.auto_awesome_outlined,
              name: 'Openness',
              description: 'Curious, creative, open to new ideas',
              score: profile.traitOpenness,
            ),
            _TraitRow(
              icon: Icons.track_changes,
              name: 'Conscientiousness',
              description: 'Organized, reliable, goal-driven',
              score: profile.traitConscientiousness,
            ),
            _TraitRow(
              icon: Icons.bolt_outlined,
              name: 'Extraversion',
              description: 'Where you draw your social energy',
              score: profile.traitExtraversion,
            ),
            _TraitRow(
              icon: Icons.favorite_outline,
              name: 'Agreeableness',
              description: 'Warm, empathetic, cooperative',
              score: profile.traitAgreeableness,
            ),
            _TraitRow(
              icon: Icons.spa_outlined,
              name: 'Emotional stability',
              description: 'Calm and steady under stress',
              score: profile.traitEmotionalStability,
            ),
            _TraitRow(
              icon: Icons.shield_outlined,
              name: 'Attachment security',
              description: 'Comfort with closeness and trust',
              score: profile.traitAttachmentSecurity,
            ),
          ],
        _ => [
            BentoCard(
              label: 'Music taste',
              child: profile.musicGenres.isEmpty
                  ? Text(
                      'No genres picked yet.',
                      style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
                    )
                  : GenreTileGrid(genres: profile.musicGenres),
            ),
            ..._connectionTasteMatch(profile),
          ],
      };

  /// "You & your connection both play X on repeat" — shown under Music when
  /// there is an active connection whose genres overlap yours. All data is
  /// already loaded by existing providers; the match % chip appears only if
  /// that person's daily-match row still exists (never fabricated).
  List<Widget> _connectionTasteMatch(Profile profile) {
    final connection = ref.watch(activeConnectionProvider).valueOrNull;
    final userId = ref.watch(currentUserIdProvider);
    if (connection == null || userId == null) return const [];

    final otherUserId = connection.otherUserId(userId);
    final theirProfile = ref.watch(candidateProfileProvider(otherUserId)).valueOrNull;
    if (theirProfile == null) return const [];

    final shared =
        theirProfile.musicGenres.where(profile.musicGenres.contains).toList();
    if (shared.isEmpty) return const [];

    final score = ref
        .watch(dailyMatchCardsProvider)
        .valueOrNull
        ?.where((c) => c.match.candidateId == otherUserId)
        .firstOrNull
        ?.match
        .score;

    return [
      const SizedBox(height: 12),
      TasteMatchCard(
        myAvatarId: profile.avatarId,
        theirAvatarId: theirProfile.avatarId,
        sharedGenres: shared,
        matchPercent: score == null ? null : (score * 100).round().clamp(0, 100),
      ),
    ];
  }
}

/// Compact app-bar identity row: small avatar, name + age, region, and the
/// lime ID badge when verified — mirrors the v5 HTML phone header.
class _HeaderTitle extends StatelessWidget {
  const _HeaderTitle({required this.profile, required this.tier});

  final Profile profile;
  final VerificationTier? tier;

  @override
  Widget build(BuildContext context) {
    final character = AvatarCatalog.resolve(profile.avatarId).character;
    final name = profile.displayName?.split(' ').first ?? 'The ${character.name}';
    final isVerified = tier != null && tier!.label != 'Unverified';

    return Row(
      children: [
        AvatarDisplay(avatarId: profile.avatarId, size: 36),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$name, ${profile.age}',
                style: AppTextStyles.title.copyWith(fontSize: 17),
                overflow: TextOverflow.ellipsis,
              ),
              if (profile.regionName != null)
                Row(
                  children: [
                    const Icon(Icons.place_outlined,
                        size: 11, color: AppColors.textSecondary),
                    const SizedBox(width: 3),
                    Flexible(
                      child: Text(
                        profile.regionName!,
                        style: AppTextStyles.caption.copyWith(fontSize: 11),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
        if (isVerified)
          Container(
            margin: const EdgeInsets.only(left: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.secondary,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.verified_user, size: 12, color: AppColors.textPrimary),
                const SizedBox(width: 4),
                Text(
                  'ID',
                  style: AppTextStyles.caption.copyWith(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// One trait explained: icon, name, description, score and mini bar —
/// the v5 HTML trait-legend rows.
class _TraitRow extends StatelessWidget {
  const _TraitRow({
    required this.icon,
    required this.name,
    required this.description,
    required this.score,
  });

  final IconData icon;
  final String name;
  final String description;

  /// 1.0–5.0.
  final double score;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 17, color: AppColors.textPrimary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: AppTextStyles.bodyMedium),
                const SizedBox(height: 2),
                Text(description, style: AppTextStyles.caption),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                score.toStringAsFixed(1),
                style: AppTextStyles.statNumber.copyWith(fontSize: 17),
              ),
              const SizedBox(height: 6),
              Container(
                width: 56,
                height: 5,
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(3),
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: ((score - 1) / 4).clamp(0.0, 1.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Pill-style segmented control for switching profile sections.
class _SegmentedTabs extends StatelessWidget {
  const _SegmentedTabs({
    required this.index,
    required this.onChanged,
    required this.items,
  });

  final int index;
  final ValueChanged<int> onChanged;
  final List<(IconData, String)> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(i),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: i == index ? AppColors.surface : Colors.transparent,
                    borderRadius: BorderRadius.circular(999),
                    border: i == index ? Border.all(color: AppColors.divider) : null,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        items[i].$1,
                        size: 15,
                        color: i == index ? AppColors.primaryDark : AppColors.textSecondary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        items[i].$2,
                        style: AppTextStyles.caption.copyWith(
                          fontWeight: FontWeight.w700,
                          color: i == index ? AppColors.textPrimary : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 2×2 grid of compact account actions — replaces the old stack of four
/// full-width buttons. Sign out is styled as the destructive action.
class _AccountGrid extends StatelessWidget {
  const _AccountGrid({
    required this.onSettings,
    required this.onVerification,
    required this.onMembership,
    required this.onSignOut,
  });

  final VoidCallback onSettings;
  final VoidCallback onVerification;
  final VoidCallback onMembership;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 2.9,
      children: [
        _AccountTile(
          icon: Icons.settings_outlined,
          label: 'Settings',
          onTap: onSettings,
        ),
        _AccountTile(
          icon: Icons.verified_user_outlined,
          label: 'Verification',
          onTap: onVerification,
        ),
        _AccountTile(
          icon: Icons.workspace_premium_outlined,
          label: 'Membership',
          onTap: onMembership,
        ),
        _AccountTile(
          icon: Icons.logout,
          label: 'Sign out',
          isDestructive: true,
          onTap: onSignOut,
        ),
      ],
    );
  }
}

class _AccountTile extends StatelessWidget {
  const _AccountTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final iconColor = isDestructive ? AppColors.danger : AppColors.primaryDark;
    final iconBg = isDestructive
        ? AppColors.danger.withValues(alpha: 0.1)
        : AppColors.primaryLight;

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.divider),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 17, color: iconColor),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: isDestructive ? AppColors.danger : AppColors.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
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
