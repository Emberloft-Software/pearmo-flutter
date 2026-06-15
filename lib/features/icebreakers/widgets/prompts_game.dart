import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_mapper.dart';
import '../../../data/models/ice_breaker_session.dart';
import '../../../providers/repository_providers.dart';
import '../../../shared/widgets/widgets.dart';
import '../data/icebreaker_content.dart';

/// "20 Questions": players take turns asking each other a question (from a
/// prompt bank or their own) and answering it — a turn-based Q&A history
/// stored as `state['qa']`.
class PromptsGame extends ConsumerStatefulWidget {
  const PromptsGame({
    super.key,
    required this.session,
    required this.currentUserId,
    required this.otherUserId,
  });

  final IceBreakerSession session;
  final String currentUserId;
  final String otherUserId;

  @override
  ConsumerState<PromptsGame> createState() => _PromptsGameState();
}

class _PromptsGameState extends ConsumerState<PromptsGame> {
  final _customQuestionController = TextEditingController();
  final _answerController = TextEditingController();
  bool _isUpdating = false;
  String? _error;

  @override
  void dispose() {
    _customQuestionController.dispose();
    _answerController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _qa => (widget.session.state['qa'] as List? ?? const [])
      .map((e) => Map<String, dynamic>.from(e as Map))
      .toList();

  Future<void> _askQuestion(String question) async {
    if (question.trim().isEmpty) return;
    final qa = _qa;
    qa.add({'askedBy': widget.currentUserId, 'question': question.trim(), 'answer': null});
    await _save(qa);
    _customQuestionController.clear();
  }

  Future<void> _submitAnswer() async {
    final answer = _answerController.text.trim();
    if (answer.isEmpty) return;
    final qa = _qa;
    if (qa.isEmpty) return;
    qa[qa.length - 1] = {...qa.last, 'answer': answer};
    await _save(qa);
    _answerController.clear();
  }

  Future<void> _save(List<Map<String, dynamic>> qa) async {
    setState(() {
      _isUpdating = true;
      _error = null;
    });
    try {
      await ref.read(gamesRepositoryProvider).updateState(widget.session.id, {'qa': qa});
    } catch (e) {
      setState(() => _error = ErrorMapper.map(e));
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final qa = _qa;
    final last = qa.isEmpty ? null : qa.last;

    final canAnswer =
        last != null && last['answer'] == null && last['askedBy'] != widget.currentUserId;
    final canAsk = qa.isEmpty || (last!['answer'] != null && last['askedBy'] != widget.currentUserId);

    final askedQuestions = qa.map((e) => e['question'] as String).toSet();
    final suggestions =
        IcebreakerContent.twentyQuestionsPrompts.where((q) => !askedQuestions.contains(q)).toList();

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (qa.isEmpty)
                Text(
                  'Take turns asking each other questions to break the ice. Pick a prompt below '
                  'or write your own.',
                  style: AppTextStyles.body,
                ),
              ...qa.map((item) {
                final isMine = item['askedBy'] == widget.currentUserId;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment:
                        isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                    children: [
                      _Bubble(
                        text: item['question'] as String,
                        isMine: isMine,
                        isQuestion: true,
                      ),
                      if (item['answer'] != null) ...[
                        const SizedBox(height: 6),
                        _Bubble(
                          text: item['answer'] as String,
                          isMine: !isMine,
                          isQuestion: false,
                        ),
                      ],
                    ],
                  ),
                );
              }),
              if (_error != null) ...[
                const SizedBox(height: 12),
                ErrorBanner(message: _error!),
              ],
            ],
          ),
        ),
        SafeArea(
          minimum: const EdgeInsets.all(16),
          child: canAnswer
              ? Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _answerController,
                        decoration: const InputDecoration(hintText: 'Type your answer...'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _isUpdating ? null : _submitAnswer,
                      icon: const Icon(Icons.send, color: AppColors.primary),
                    ),
                  ],
                )
              : canAsk
                  ? _AskQuestionPanel(
                      suggestions: suggestions,
                      controller: _customQuestionController,
                      isUpdating: _isUpdating,
                      onAsk: _askQuestion,
                    )
                  : Text(
                      'Waiting for the other person...',
                      style: AppTextStyles.caption,
                      textAlign: TextAlign.center,
                    ),
        ),
      ],
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.text, required this.isMine, required this.isQuestion});

  final String text;
  final bool isMine;
  final bool isQuestion;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 280),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isQuestion
              ? (isMine ? AppColors.primaryLight : AppColors.surfaceMuted)
              : AppColors.secondaryLight,
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        ),
        child: Text(text, style: AppTextStyles.body),
      ),
    );
  }
}

class _AskQuestionPanel extends StatelessWidget {
  const _AskQuestionPanel({
    required this.suggestions,
    required this.controller,
    required this.isUpdating,
    required this.onAsk,
  });

  final List<String> suggestions;
  final TextEditingController controller;
  final bool isUpdating;
  final ValueChanged<String> onAsk;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Your turn to ask', style: AppTextStyles.bodyMedium),
        const SizedBox(height: 8),
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: suggestions.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final question = suggestions[index];
              return ActionChip(
                label: Text(question, overflow: TextOverflow.ellipsis),
                onPressed: isUpdating ? null : () => onAsk(question),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                decoration: const InputDecoration(hintText: 'Or write your own question...'),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: isUpdating ? null : () => onAsk(controller.text),
              icon: const Icon(Icons.send, color: AppColors.primary),
            ),
          ],
        ),
      ],
    );
  }
}
