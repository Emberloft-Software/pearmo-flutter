import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/enums.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/error_mapper.dart';
import '../../../providers/games_providers.dart';
import '../../../providers/repository_providers.dart';
import '../../../shared/widgets/widgets.dart';

/// The games supported by the app today. `trivia` is a defined `GameType`
/// in the schema reserved for a future round-based quiz, but has no
/// implementation yet, so it isn't offered here.
const _availableGames = [GameType.wouldYouRather, GameType.prompts, GameType.drawTogether];

const _gameDescriptions = {
  GameType.wouldYouRather: 'Pick between two options and see how your answers compare.',
  GameType.prompts: 'Take turns asking and answering fun questions.',
  GameType.drawTogether: 'Doodle on a shared canvas together.',
};

/// Pick (or resume) an ice-breaker game for a connection. Playing a game
/// together is how a connection in `ice_breaking` moves things along
/// before chat unlocks.
class GameSelectionScreen extends ConsumerStatefulWidget {
  const GameSelectionScreen({super.key, required this.connectionId});

  final String connectionId;

  @override
  ConsumerState<GameSelectionScreen> createState() => _GameSelectionScreenState();
}

class _GameSelectionScreenState extends ConsumerState<GameSelectionScreen> {
  GameType? _starting;
  String? _error;

  Future<void> _start(GameType type) async {
    setState(() {
      _starting = type;
      _error = null;
    });
    try {
      final initialState = switch (type) {
        GameType.wouldYouRather => {'round': 0, 'answers': <String, dynamic>{}},
        GameType.prompts => {'qa': <Map<String, dynamic>>[]},
        GameType.drawTogether => {'strokes': <Map<String, dynamic>>[]},
        GameType.trivia => <String, dynamic>{},
      };
      final session = await ref.read(gamesRepositoryProvider).createSession(
            connectionId: widget.connectionId,
            gameType: type,
            initialState: initialState,
          );
      ref.invalidate(gameSessionsProvider(widget.connectionId));
      if (mounted) context.push('/game/${session.id}');
    } catch (e) {
      setState(() => _error = ErrorMapper.map(e));
    } finally {
      if (mounted) setState(() => _starting = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessionsAsync = ref.watch(gameSessionsProvider(widget.connectionId));

    return Scaffold(
      appBar: AppBar(title: const Text('Ice-breaker games')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Break the ice with a quick game — finishing one together helps build a connection '
            'before chat fully opens up.',
            style: AppTextStyles.body,
          ),
          const SizedBox(height: 20),
          if (_error != null) ...[
            ErrorBanner(message: _error!),
            const SizedBox(height: 16),
          ],
          sessionsAsync.when(
            data: (sessions) {
              return Column(
                children: _availableGames.map((type) {
                  final existing = sessions.where((s) => s.gameType == type).toList();
                  final hasSession = existing.isNotEmpty;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: PearmoCard(
                      onTap: _starting != null
                          ? null
                          : hasSession
                              ? () => context.push('/game/${existing.last.id}')
                              : () => _start(type),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: const BoxDecoration(
                              color: AppColors.primaryLight,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(type.emoji, style: const TextStyle(fontSize: 24)),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(type.label, style: AppTextStyles.title),
                                const SizedBox(height: 4),
                                Text(_gameDescriptions[type] ?? '', style: AppTextStyles.caption),
                              ],
                            ),
                          ),
                          if (_starting == type)
                            const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                            )
                          else
                            Icon(
                              hasSession ? Icons.play_arrow : Icons.add_circle_outline,
                              color: AppColors.primary,
                            ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              );
            },
            loading: () => const LoadingIndicator(),
            error: (error, _) => ErrorBanner(message: ErrorMapper.map(error)),
          ),
        ],
      ),
    );
  }
}
