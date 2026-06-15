import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/error_mapper.dart';
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

    return Scaffold(
      appBar: AppBar(
        title: const Text("Today's Matches"),
      ),
      body: RefreshIndicator(
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
    );
  }
}
