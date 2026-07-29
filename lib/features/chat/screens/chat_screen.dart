import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video_player/video_player.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/constants/enums.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/error_mapper.dart';
import '../../../data/models/message.dart';
import '../../../providers/auth_providers.dart';
import '../../../providers/connections_providers.dart';
import '../../../providers/messages_providers.dart';
import '../../../providers/notification_providers.dart';
import '../../../providers/repository_providers.dart';
import '../../../shared/widgets/widgets.dart';

enum _MediaChoice { photo, video }

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

  // Typing indicator — pure Realtime Broadcast (see
  // MessagesRepository.typingChannel), nothing persisted to any table.
  late final SupabaseClient _supabaseClient;
  RealtimeChannel? _typingChannel;
  Timer? _typingClearTimer;
  DateTime? _lastTypingSentAt;
  bool _otherIsTyping = false;

  @override
  void initState() {
    super.initState();
    _supabaseClient = ref.read(supabaseClientProvider);
    _controller.addListener(_onComposerChanged);

    // Lets the app-wide notification watcher (see HomeShell) suppress a
    // "new message" alert for the conversation already on screen.
    Future.microtask(() {
      if (mounted) {
        ref.read(currentlyOpenChatConnectionIdProvider.notifier).state = widget.connectionId;
      }
    });

    final myUserId = ref.read(currentUserIdProvider);
    _typingChannel = ref.read(messagesRepositoryProvider).typingChannel(widget.connectionId)
      ..onBroadcast(
        event: 'typing',
        callback: (payload) {
          final fromUserId = payload['user_id'] as String?;
          if (fromUserId == null || fromUserId == myUserId) return;
          _typingClearTimer?.cancel();
          setState(() => _otherIsTyping = true);
          _typingClearTimer = Timer(const Duration(seconds: 3), () {
            if (mounted) setState(() => _otherIsTyping = false);
          });
        },
      ).subscribe();
  }

  @override
  void dispose() {
    _controller.removeListener(_onComposerChanged);
    _controller.dispose();
    _scrollController.dispose();
    _typingClearTimer?.cancel();
    final channel = _typingChannel;
    if (channel != null) _supabaseClient.removeChannel(channel);
    // Only clear if we're still the one "on top" — avoids a stale clear if
    // another ChatScreen instance already took over.
    if (ref.read(currentlyOpenChatConnectionIdProvider) == widget.connectionId) {
      ref.read(currentlyOpenChatConnectionIdProvider.notifier).state = null;
    }
    super.dispose();
  }

  /// Broadcasts a "typing" event, throttled to at most once every 2s so
  /// every keystroke doesn't open a new round trip.
  void _onComposerChanged() {
    if (_controller.text.isEmpty) return;
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;
    final now = DateTime.now();
    if (_lastTypingSentAt != null && now.difference(_lastTypingSentAt!) < const Duration(seconds: 2)) {
      return;
    }
    _lastTypingSentAt = now;
    _typingChannel?.sendBroadcastMessage(event: 'typing', payload: {'user_id': userId});
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

  Future<void> _pickAndSendMedia(String userId) async {
    final choice = await showModalBottomSheet<_MediaChoice>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_outlined),
              title: const Text('Photo'),
              onTap: () => Navigator.of(context).pop(_MediaChoice.photo),
            ),
            ListTile(
              leading: const Icon(Icons.videocam_outlined),
              title: const Text('Video'),
              onTap: () => Navigator.of(context).pop(_MediaChoice.video),
            ),
          ],
        ),
      ),
    );
    if (choice == null) return;

    final picker = ImagePicker();
    final picked = choice == _MediaChoice.photo
        ? await picker.pickImage(source: ImageSource.gallery, imageQuality: 85)
        : await picker.pickVideo(source: ImageSource.gallery);
    if (picked == null || !mounted) return;

    setState(() {
      _isSending = true;
      _error = null;
    });
    try {
      final ext = picked.path.split('.').last;
      // Unique per message (timestamp + sender), unlike the deterministic
      // per-user paths elsewhere — so this never needs an UPDATE storage
      // policy the way profile-photo/NIC uploads did (see CLAUDE.md).
      final messageId = '${DateTime.now().microsecondsSinceEpoch}_$userId';
      final path = await ref.read(storageRepositoryProvider).uploadChatMedia(
            connectionId: widget.connectionId,
            messageId: messageId,
            file: File(picked.path),
            ext: ext,
          );
      await ref.read(messagesRepositoryProvider).sendMessage(
            connectionId: widget.connectionId,
            senderId: userId,
            content: choice == _MediaChoice.photo ? '📷 Photo' : '🎬 Video',
            contentType: choice == _MediaChoice.photo ? 'image' : 'video',
            mediaUrl: path,
          );
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
      appBar: AppBar(
        title: const Text('Chat'),
        actions: [
          connectionAsync.maybeWhen(
            data: (connection) => connection != null && connection.status != ConnectionStatus.ended
                ? IconButton(
                    onPressed: () => context.push('/connection/${widget.connectionId}/games'),
                    icon: const Icon(Icons.extension_outlined),
                    tooltip: 'Ice-breaker games',
                  )
                : const SizedBox.shrink(),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
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
              if (_otherIsTyping)
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Align(alignment: Alignment.centerLeft, child: _TypingIndicator()),
                ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: ErrorBanner(message: _error!),
                ),
              if (canChat)
                Container(
                  decoration: const BoxDecoration(
                    color: AppColors.surface,
                    border: Border(top: BorderSide(color: AppColors.divider)),
                  ),
                  child: SafeArea(
                    minimum: const EdgeInsets.all(12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        IconButton(
                          onPressed: _isSending ? null : () => _pickAndSendMedia(userId),
                          icon: const Icon(Icons.add_photo_alternate_outlined, color: AppColors.primary),
                          tooltip: 'Share photo or video',
                        ),
                        Expanded(
                          child: TextField(
                            controller: _controller,
                            minLines: 1,
                            maxLines: 4,
                            decoration: const InputDecoration(hintText: 'Type a message...'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        _isSending
                            ? Container(
                                width: 48,
                                height: 48,
                                padding: const EdgeInsets.all(14),
                                decoration: const BoxDecoration(
                                  color: AppColors.primaryLight,
                                  shape: BoxShape.circle,
                                ),
                                child: const CircularProgressIndicator(
                                    strokeWidth: 2, color: AppColors.primary),
                              )
                            : Material(
                                color: AppColors.primary,
                                shape: const CircleBorder(),
                                child: InkWell(
                                  customBorder: const CircleBorder(),
                                  onTap: () => _send(userId),
                                  child: const SizedBox(
                                    width: 48,
                                    height: 48,
                                    child: Icon(Icons.send_rounded,
                                        color: Colors.white, size: 22),
                                  ),
                                ),
                              ),
                      ],
                    ),
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

/// "Other person is typing" bubble — three dots pulsing in sequence, driven
/// by one repeating [AnimationController] rather than per-dot timers.
class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(3, (i) {
              // Stagger each dot's pulse by a third of the cycle.
              final t = (_controller.value + i / 3) % 1.0;
              final opacity = 0.3 + 0.7 * (0.5 - (t - 0.5).abs()) * 2;
              return Padding(
                padding: EdgeInsets.only(left: i == 0 ? 0 : 4),
                child: Opacity(
                  opacity: opacity.clamp(0.3, 1.0),
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: AppColors.textSecondary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              );
            }),
          );
        },
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
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primaryDark, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.caption.copyWith(color: AppColors.textPrimary),
            ),
          ),
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
    // Asymmetric radii point the "tail" corner toward the sender.
    final radius = BorderRadius.only(
      topLeft: const Radius.circular(20),
      topRight: const Radius.circular(20),
      bottomLeft: Radius.circular(isMine ? 20 : 6),
      bottomRight: Radius.circular(isMine ? 6 : 20),
    );
    final hasMedia = (message.isImage || message.isVideo) && message.mediaUrl != null;

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        padding: hasMedia
            ? const EdgeInsets.all(6)
            : const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isMine ? AppColors.primary : AppColors.surface,
          borderRadius: radius,
          border: isMine ? null : Border.all(color: AppColors.divider),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasMedia)
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: message.isImage
                    ? _ImageBubbleContent(path: message.mediaUrl!)
                    : _VideoBubbleContent(path: message.mediaUrl!),
              )
            else
              SelectionContainer.disabled(
                child: Text(
                  message.content,
                  style: AppTextStyles.body
                      .copyWith(color: isMine ? Colors.white : AppColors.textPrimary),
                ),
              ),
            Padding(
              padding: EdgeInsets.only(top: hasMedia ? 4 : 2, left: hasMedia ? 4 : 0),
              child: Text(
                DateFormat.Hm().format(message.sentAt),
                style: AppTextStyles.caption.copyWith(
                  fontSize: 10.5,
                  color: isMine ? Colors.white70 : AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Signed-URL image thumbnail — tap to view full-screen (zoomable).
class _ImageBubbleContent extends ConsumerWidget {
  const _ImageBubbleContent({required this.path});

  final String path;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final urlAsync = ref.watch(signedChatMediaUrlProvider(path));
    return urlAsync.when(
      data: (url) => GestureDetector(
        onTap: () => showDialog(
          context: context,
          builder: (_) => Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.all(12),
            child: InteractiveViewer(child: Image.network(url)),
          ),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 220, maxWidth: 220),
          child: Image.network(url, fit: BoxFit.cover),
        ),
      ),
      loading: () =>
          const SizedBox(width: 160, height: 160, child: Center(child: LoadingIndicator())),
      error: (_, _) => const SizedBox(
        width: 160,
        height: 100,
        child: Center(child: Icon(Icons.broken_image_outlined)),
      ),
    );
  }
}

/// Inline video bubble — tap to toggle play/pause. Loads the
/// [VideoPlayerController] once the signed URL resolves.
class _VideoBubbleContent extends ConsumerStatefulWidget {
  const _VideoBubbleContent({required this.path});

  final String path;

  @override
  ConsumerState<_VideoBubbleContent> createState() => _VideoBubbleContentState();
}

class _VideoBubbleContentState extends ConsumerState<_VideoBubbleContent> {
  VideoPlayerController? _controller;
  String? _loadedUrl;

  void _initIfNeeded(String url) {
    if (_loadedUrl == url) return;
    _loadedUrl = url;
    final controller = VideoPlayerController.networkUrl(Uri.parse(url));
    controller.initialize().then((_) {
      if (!mounted) {
        controller.dispose();
        return;
      }
      setState(() => _controller = controller);
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final urlAsync = ref.watch(signedChatMediaUrlProvider(widget.path));
    return urlAsync.when(
      data: (url) {
        _initIfNeeded(url);
        final controller = _controller;
        if (controller == null || !controller.value.isInitialized) {
          return const SizedBox(
              width: 220, height: 220, child: Center(child: LoadingIndicator()));
        }
        return GestureDetector(
          onTap: () => setState(
            () => controller.value.isPlaying ? controller.pause() : controller.play(),
          ),
          child: SizedBox(
            width: 220,
            child: AspectRatio(
              aspectRatio: controller.value.aspectRatio,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  VideoPlayer(controller),
                  if (!controller.value.isPlaying)
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.35),
                        shape: BoxShape.circle,
                      ),
                      padding: const EdgeInsets.all(10),
                      child: const Icon(Icons.play_arrow, color: Colors.white, size: 28),
                    ),
                ],
              ),
            ),
          ),
        );
      },
      loading: () =>
          const SizedBox(width: 220, height: 220, child: Center(child: LoadingIndicator())),
      error: (_, _) => const SizedBox(
        width: 220,
        height: 100,
        child: Center(child: Icon(Icons.error_outline)),
      ),
    );
  }
}
