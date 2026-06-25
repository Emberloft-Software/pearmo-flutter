import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/constants/enums.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/error_mapper.dart';
import '../../../data/models/message.dart';
import '../../../providers/auth_providers.dart';
import '../../../providers/connections_providers.dart';
import '../../../providers/messages_providers.dart';
import '../../../providers/repository_providers.dart';
import '../../../shared/widgets/widgets.dart';

/// Chat for an active connection. The backend enforces the
/// connection-status gating and the 5-message cap during `limited_chat` —
/// this screen just streams messages and surfaces those rules through
/// [ErrorMapper]. Message text is wrapped in [SelectionContainer.disabled]
/// so it can't be copied, per the women's-safety brainstorm requirements.
// TODO(backend): AI harassment filtering and screenshot detection/
// watermarking from the brainstorm doc need a moderation edge function and
// platform-level screenshot hooks respectively — neither exists yet, so
// `reports` (see ReportScreen) remains the primary safety mechanism.
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, required this.connectionId});

  final String connectionId;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  bool _isSending = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send(String userId) async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _isSending = true;
      _error = null;
    });
    try {
      await ref.read(messagesRepositoryProvider).sendMessage(
            connectionId: widget.connectionId,
            senderId: userId,
            content: text,
          );
      _controller.clear();
    } catch (e) {
      setState(() => _error = ErrorMapper.map(e));
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = ref.watch(currentUserIdProvider);
    final connectionAsync = ref.watch(connectionStreamProvider(widget.connectionId));
    final messagesAsync = ref.watch(messagesStreamProvider(widget.connectionId));

    return Scaffold(
      appBar: AppBar(title: const Text('Chat')),
      body: connectionAsync.when(
        data: (connection) {
          if (connection == null || userId == null) {
            return const EmptyState(icon: Icons.link_off, title: 'Connection not found');
          }

          final canChat = connection.status.canChat;

          return Column(
            children: [
              if (!canChat)
                _NoticeBanner(
                  icon: Icons.extension_outlined,
                  message: connection.status == ConnectionStatus.ended
                      ? 'This connection has ended. Chat is read-only.'
                      : "Chat unlocks once you've broken the ice together.",
                  action: connection.status == ConnectionStatus.accepted ||
                          connection.status == ConnectionStatus.iceBreaking
                      ? TextButton(
                          onPressed: () => context.push('/connection/${widget.connectionId}/games'),
                          child: const Text('Play a game'),
                        )
                      : null,
                ),
              if (connection.status == ConnectionStatus.limitedChat)
                const _NoticeBanner(
                  icon: Icons.info_outline,
                  message:
                      'You\'re in limited chat — each of you can send up to '
                      '${AppConstants.limitedChatMessageCap} messages until you both unlock open chat.',
                ),
              Expanded(
                child: messagesAsync.when(
                  data: (messages) {
                    if (messages.isEmpty) {
                      return const EmptyState(
                        icon: Icons.chat_bubble_outline,
                        title: 'No messages yet',
                        message: 'Say hello!',
                      );
                    }
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (_scrollController.hasClients) {
                        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
                      }
                    });
                    return ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final message = messages[index];
                        return _MessageBubble(message: message, isMine: message.isMine(userId));
                      },
                    );
                  },
                  loading: () => const LoadingIndicator(),
                  error: (error, _) => Padding(
                    padding: const EdgeInsets.all(20),
                    child: ErrorBanner(message: ErrorMapper.map(error)),
                  ),
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: ErrorBanner(message: _error!),
                ),
              if (canChat)
                SafeArea(
                  minimum: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          minLines: 1,
                          maxLines: 4,
                          decoration: const InputDecoration(hintText: 'Type a message...'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _isSending
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                              ),
                            )
                          : IconButton(
                              onPressed: () => _send(userId),
                              icon: const Icon(Icons.send, color: AppColors.primary),
                            ),
                    ],
                  ),
                ),
            ],
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

class _NoticeBanner extends StatelessWidget {
  const _NoticeBanner({required this.icon, required this.message, this.action});

  final IconData icon;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      color: AppColors.accentLavender.withValues(alpha: 0.15),
      child: Row(
        children: [
          Icon(icon, color: AppColors.accentLavender, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(message, style: AppTextStyles.caption)),
          ?action,
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.isMine});

  final Message message;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isMine ? AppColors.primaryLight : AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            SelectionContainer.disabled(
              child: Text(message.content, style: AppTextStyles.body),
            ),
            const SizedBox(height: 2),
            Text(DateFormat.Hm().format(message.sentAt), style: AppTextStyles.caption),
          ],
        ),
      ),
    );
  }
}
