import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/enums.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/error_mapper.dart';
import '../../../data/models/connection.dart';
import '../../../providers/auth_providers.dart';
import '../../../providers/connections_providers.dart';
import '../../../providers/matches_providers.dart';
import '../../../shared/widgets/widgets.dart';
import '../widgets/match_card.dart';

/// The home tab — today's curated matches. No swiping: each candidate is a
/// card the user can open, then either send a connection request or pass.
class MatchesScreen extends ConsumerWidget {
  const MatchesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cardsAsync = ref.watch(dailyMatchCardsProvider);
    final activeConnection = ref.watch(activeConnectionProvider).valueOrNull;
    final userId = ref.watch(currentUserIdProvider);
    final myTier = ref.watch(myAppUserProvider).valueOrNull?.verificationTier;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Today's Matches"),
      ),
      body: Column(
        children: [
          if (myTier == VerificationTier.unverified) const _UnverifiedPoolBanner(),
          if (activeConnection != null && userId != null) ...[
            _CurrentConnectionCard(connection: activeConnection, userId: userId),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 4),
              child: SectionHeader(title: "Today's Matches"),
            ),
          ],
          Expanded(
            child: RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () async {
                ref.invalidate(dailyMatchCardsProvider);
                await ref.read(dailyMatchCardsProvider.future);
              },
              child: cardsAsync.when(
                data: (cards) {
                  if (cards.isEmpty) {
                    return ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.7,
                          child: const _EmptyMatches(),
                        ),
                      ],
                    );
                  }

                  return ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(20),
                    itemCount: cards.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final card = cards[index];
                      return MatchCardWidget(
                        card: card,
                        onTap: () => context.push('/candidate/${card.match.candidateId}'),
                      );
                    },
                  );
                },
                loading: () => const LoadingIndicator(),
                error: (error, _) => ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: ErrorBanner(
                        message: ErrorMapper.map(error),
                        onRetry: () => ref.invalidate(dailyMatchCardsProvider),
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

/// Explains *why* an unverified user is seeing these particular people,
/// shown only to unverified users.
///
/// Copy is deliberately symmetric — "everyone here, including you" — rather
/// than warning the viewer about the people on their cards. A one-sided
/// warning would imply Pearmo has vouched for the viewer and not the
/// viewee, which is false: both are in exactly the same unchecked state.
///
/// The CTA is framed as an unlock the user wants ("show your face"), not as
/// a comparison against anyone else. Pressuring someone to submit identity
/// documents because of another user's status is the line this copy stays
/// on the right side of.
class _UnverifiedPoolBanner extends StatelessWidget {
  const _UnverifiedPoolBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.shield_outlined, size: 16, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              Text(
                "You're in the unverified pool",
                style: AppTextStyles.caption.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            "Everyone here — including you — has signed up but hasn't completed a selfie "
            "check yet. Pearmo hasn't confirmed anyone's photo, age, or identity.",
            style: AppTextStyles.caption,
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: () => context.push('/verification'),
              child: const Text('Verify to show your face'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Empty state that says when the next batch actually lands instead of a
/// blanket "check back tomorrow" — which was wrong whenever the batch was
/// generated at any hour other than midnight, and is a promise the app
/// couldn't keep at all before `refresh_my_matches` existed.
class _EmptyMatches extends ConsumerWidget {
  const _EmptyMatches();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expiry = ref.watch(nextBatchExpiryProvider).valueOrNull;

    String message;
    if (expiry == null) {
      // No unexpired batch — either brand new, or the pool genuinely had
      // nobody eligible. Honest about being early rather than implying a
      // schedule we can't promise in a small beta.
      message = "You're early — we'll show you people as they join. "
          'Adding a voice intro and verifying make you easier to match.';
    } else {
      final remaining = expiry.difference(DateTime.now());
      final hours = remaining.inHours;
      final label = hours >= 1
          ? '$hours hour${hours == 1 ? '' : 's'}'
          : '${remaining.inMinutes.clamp(1, 59)} minutes';
      message = "You've seen everyone in today's set. Your next matches arrive in about $label.";
    }

    return EmptyState(
      icon: Icons.favorite_border,
      title: 'No new matches right now',
      message: message,
    );
  }
}

/// Pinned above today's matches (with its own header, ahead of "Today's
/// Matches") whenever the user has an active connection — reuses the same
/// gradient `HeroProfileCard` treatment as the profile screens so it reads
/// as clearly more prominent than a plain match card, not just a small
/// reminder banner. Shown because the user generally can't get matched with
/// anyone new while it's ongoing (`getActiveConnection`'s "one at a time"
/// rule).
class _CurrentConnectionCard extends ConsumerWidget {
  const _CurrentConnectionCard({required this.connection, required this.userId});

  final Connection connection;
  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final otherUserId = connection.otherUserId(userId);
    final profileAsync = ref.watch(candidateProfileProvider(otherUserId));

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'Your Connection'),
          const SizedBox(height: 10),
          profileAsync.when(
            data: (profile) => Column(
              children: [
                GestureDetector(
                  onTap: () => context.push('/connection/${connection.id}'),
                  child: HeroProfileCard(
                    avatarId: profile.avatarId,
                    photoPath: profile.profilePhotoUrl,
                    showPhoto: profile.hasPublicPhoto,
                    title: '${profile.age} · ${profile.gender.label}',
                    subtitle: profile.regionName,
                  ),
                ),
                const SizedBox(height: 10),
                StatusPill(
                  label: connection.status.label,
                  color: StatusPill.colorFor(connection.status.dbValue),
                ),
              ],
            ),
            loading: () => const SizedBox(height: 190, child: LoadingIndicator()),
            error: (_, _) => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}
