import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/error_mapper.dart';
import '../../../data/models/connection.dart';
import '../../../providers/auth_providers.dart';
import '../../../providers/connections_providers.dart';
import '../../../providers/matches_providers.dart';
import '../../../shared/avatars/avatar_catalog.dart';
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
          if (activeConnection != null && userId != null)
            _CurrentConnectionCard(connection: activeConnection, userId: userId),
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

/// Pinned above today's matches whenever the user has an active connection
/// — a quick reminder/shortcut, since they generally can't get matched with
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

    return profileAsync.when(
      data: (profile) {
        final character = AvatarCatalog.resolve(profile.avatarId).character;
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Material(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => context.push('/connection/${connection.id}'),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Row(
                  children: [
                    SignedAvatarDisplay(
                      avatarId: profile.avatarId,
                      photoPath: profile.profilePhotoUrl,
                      showPhoto: profile.hasPublicPhoto,
                      size: 48,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('CURRENT CONNECTION', style: AppTextStyles.label),
                          const SizedBox(height: 2),
                          Text('${profile.age} · The ${character.name}',
                              style: AppTextStyles.bodyMedium),
                          const SizedBox(height: 6),
                          StatusPill(
                            label: connection.status.label,
                            color: StatusPill.colorFor(connection.status.dbValue),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: AppColors.textSecondary),
                  ],
                ),
              ),
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}
