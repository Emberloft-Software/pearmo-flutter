import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/enums.dart';
import '../../../core/utils/error_mapper.dart';
import '../../../providers/auth_providers.dart';
import '../../../providers/connections_providers.dart';
import '../../../providers/games_providers.dart';
import '../../../shared/widgets/widgets.dart';
import '../widgets/draw_together_game.dart';
import '../widgets/prompts_game.dart';
import '../widgets/would_you_rather_game.dart';

/// Hosts whichever ice-breaker game a session is for, streaming live state
/// so both participants see each other's moves in real time.
class GameScreen extends ConsumerWidget {
  const GameScreen({super.key, required this.sessionId});

  final String sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionAsync = ref.watch(gameSessionStreamProvider(sessionId));
    final userId = ref.watch(currentUserIdProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Ice-breaker')),
      body: sessionAsync.when(
        data: (session) {
          if (session == null || userId == null) {
            return const EmptyState(icon: Icons.extension_off, title: 'Game not found');
          }
          final connectionAsync = ref.watch(connectionStreamProvider(session.connectionId));
          return connectionAsync.when(
            data: (connection) {
              if (connection == null) {
                return const EmptyState(icon: Icons.link_off, title: 'Connection not found');
              }
              final otherUserId = connection.otherUserId(userId);
              return switch (session.gameType) {
                GameType.wouldYouRather => WouldYouRatherGame(
                    session: session,
                    currentUserId: userId,
                    otherUserId: otherUserId,
                  ),
                GameType.prompts => PromptsGame(
                    session: session,
                    currentUserId: userId,
                    otherUserId: otherUserId,
                  ),
                GameType.drawTogether => DrawTogetherGame(
                    session: session,
                    currentUserId: userId,
                    otherUserId: otherUserId,
                  ),
                GameType.trivia => const EmptyState(
                    icon: Icons.quiz_outlined,
                    title: 'Coming soon',
                    message: 'Trivia is on its way!',
                  ),
              };
            },
            loading: () => const LoadingIndicator(),
            error: (error, _) => Padding(
              padding: const EdgeInsets.all(20),
              child: ErrorBanner(message: ErrorMapper.map(error)),
            ),
          );
        },
        loading: () => const LoadingIndicator(),
        error: (error, _) => Padding(
          padding: const EdgeInsets.all(20),
          child: ErrorBanner(message: ErrorMapper.map(error)),
        ),
      ),
    );
  }
}
