import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/error_mapper.dart';
import '../../../data/models/ice_breaker_session.dart';
import '../../../providers/repository_providers.dart';
import '../../../shared/widgets/widgets.dart';
import '../data/icebreaker_content.dart';

/// "Would You Rather": both players pick A or B for the current prompt.
/// Once both have answered, either player can advance to the next round.
class WouldYouRatherGame extends ConsumerStatefulWidget {
  const WouldYouRatherGame({
    super.key,
    required this.session,
    required this.currentUserId,
    required this.otherUserId,
  });

  final IceBreakerSession session;
  final String currentUserId;
  final String otherUserId;

  @override
  ConsumerState<WouldYouRatherGame> createState() => _WouldYouRatherGameState();
}

class _WouldYouRatherGameState extends ConsumerState<WouldYouRatherGame> {
  bool _isUpdating = false;
  String? _error;

  Future<void> _pick(String choice) async {
    final answers = Map<String, dynamic>.from(
      widget.session.state['answers'] as Map? ?? const {},
    );
    answers[widget.currentUserId] = choice;
    await _updateState({...widget.session.state, 'answers': answers});
  }

  Future<void> _nextRound() async {
    final round = (widget.session.state['round'] as int? ?? 0) + 1;
    await _updateState({'round': round, 'answers': <String, dynamic>{}});
  }

  Future<void> _updateState(Map<String, dynamic> newState) async {
    setState(() {
      _isUpdating = true;
      _error = null;
    });
    try {
      await ref.read(gamesRepositoryProvider).updateState(widget.session.id, newState);
    } catch (e) {
      setState(() => _error = ErrorMapper.map(e));
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final round = widget.session.state['round'] as int? ?? 0;
    final prompts = IcebreakerContent.wouldYouRatherPrompts;
    final prompt = prompts[round % prompts.length];
    final answers = Map<String, dynamic>.from(
      widget.session.state['answers'] as Map? ?? const {},
    );

    final myAnswer = answers[widget.currentUserId] as String?;
    final theirAnswer = answers[widget.otherUserId] as String?;
    final bothAnswered = myAnswer != null && theirAnswer != null;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('Round ${round + 1}', style: AppTextStyles.caption),
        const SizedBox(height: 8),
        Text('Would you rather...', style: AppTextStyles.headline),
        const SizedBox(height: 20),
        _OptionCard(
          label: prompt.$1,
          isSelected: myAnswer == 'a',
          onTap: myAnswer == null ? () => _pick('a') : null,
        ),
        const SizedBox(height: 12),
        Center(child: Text('OR', style: AppTextStyles.bodyMedium)),
        const SizedBox(height: 12),
        _OptionCard(
          label: prompt.$2,
          isSelected: myAnswer == 'b',
          onTap: myAnswer == null ? () => _pick('b') : null,
        ),
        const SizedBox(height: 24),
        if (myAnswer != null && !bothAnswered)
          Text(
            "You picked. Waiting for them to answer too...",
            style: AppTextStyles.caption,
            textAlign: TextAlign.center,
          ),
        if (bothAnswered) ...[
          PearmoCard(
            color: AppColors.secondaryLight,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('You both answered!', style: AppTextStyles.bodyMedium),
                const SizedBox(height: 8),
                Text(
                  myAnswer == theirAnswer
                      ? 'You picked the same thing 🎉'
                      : "You picked different things. That's interesting!",
                  style: AppTextStyles.body,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          PearmoButton(
            label: 'Next round',
            icon: Icons.arrow_forward,
            isLoading: _isUpdating,
            onPressed: _isUpdating ? null : _nextRound,
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: 16),
          ErrorBanner(message: _error!),
        ],
      ],
    );
  }
}

class _OptionCard extends StatelessWidget {
  const _OptionCard({required this.label, required this.isSelected, required this.onTap});

  final String label;
  final bool isSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return PearmoCard(
      onTap: onTap,
      color: isSelected ? AppColors.primaryLight : null,
      child: Text(label, style: AppTextStyles.bodyMedium, textAlign: TextAlign.center),
    );
  }
}
