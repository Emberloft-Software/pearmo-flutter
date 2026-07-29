import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
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

    return Scaffold(
      appBar: AppBar(
        title: const Text("Today's Matches"),
      ),
      body: Column(
        children: [
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
                          child: const EmptyState(
                            icon: Icons.favorite_border,
                            title: 'No new matches today',
                            message:
                                "${AppConstants.appName} curates a fresh set of matches each day. "
                                'Check back tomorrow!',
                          ),
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
