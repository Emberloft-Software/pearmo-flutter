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
import '../../../data/models/consent_record.dart';
import '../../../data/models/message.dart';
import '../../../providers/auth_providers.dart';
import '../../../providers/connections_providers.dart';
import '../../../providers/consent_providers.dart';
import '../../../providers/matches_providers.dart';
import '../../../providers/messages_providers.dart';
import '../../../providers/notification_providers.dart';
import '../../../providers/profile_providers.dart';
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
  bool _isConsentBusy = false;
  String? _error;

  // Typing indicator — pure Realtime Broadcast (see
  // MessagesRepository.typingChannel), nothing persisted to any table.
  late final SupabaseClient _supabaseClient;

  /// Captured in [initState] rather than read from `ref` in [dispose] —
  /// touching `ref` during disposal throws "Cannot use ref after the widget
  /// was disposed", which meant the "which chat is open" marker was never
  /// cleared on the way out, and message notifications for that connection
  /// stayed suppressed for the rest of the session.
  late final StateController<String?> _openChatController;

  RealtimeChannel? _typingChannel;
  Timer? _typingClearTimer;
  DateTime? _lastTypingSentAt;
  bool _otherIsTyping = false;

  @override
  void initState() {
    super.initState();
    _supabaseClient = ref.read(supabaseClientProvider);
    _openChatController = ref.read(currentlyOpenChatConnectionIdProvider.notifier);
    _controller.addListener(_onComposerChanged);

    // Lets the app-wide notification watcher (see HomeShell) suppress a
    // "new message" alert for the conversation already on screen. Deferred
    // for the same reason as the clear in `dispose()` below.
    Future(() {
      if (mounted) _openChatController.state = widget.connectionId;
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

    // Deferred with `Future(...)`, not run inline: `dispose()` executes
    // inside `BuildOwner.finalizeTree`, where Riverpod refuses any provider
    // write ("Tried to modify a provider while the widget tree was
    // building"). The controller is captured in `initState` and outlives
    // this widget (plain, non-autoDispose `StateProvider`), so it's safe to
    // touch after unmount — `mounted` guards the app-shutdown case where
    // the whole container is already gone.
    //
    // Getting this wrong doesn't just log noise: the marker stays set, and
    // `PushNotificationListener` then suppresses this connection's message
    // notifications for the rest of the session.
    final controller = _openChatController;
    final connectionId = widget.connectionId;
    Future(() {
      if (!controller.mounted) return;
      if (controller.state == connectionId) controller.state = null;
    });

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

  /// Mirrors `ConnectionDetailScreen._intentFor` exactly, so tapping the
  /// locked composer here and using the Shared Unlocks panel there produce
  /// identical confirmation copy for the same underlying state.
  ConsentIntent _intentForConsentState(ConsentState state) => switch (state) {
        ConsentState.granted => ConsentIntent.revoke,
        ConsentState.waitingOnThem => ConsentIntent.revoke,
        ConsentState.needsYourResponse => ConsentIntent.agree,
        _ => ConsentIntent.request,
      };

  /// The chat composer is always visible once the connection itself allows
  /// chatting (not `pending`/`ended`) — even without `chat_unlock` consent —
  /// so the option to ask for it is discoverable instead of the composer
  /// just disappearing. Tapping it while locked explains the state and
  /// offers the next action (request / agree / cancel) inline, reusing the
  /// exact same `ConsentDialog` + `set_consent` RPC path the Shared Unlocks
  /// panel uses.
  Future<void> _handleLockedComposerTap(String userId, ConnectionConsents? consents) async {
    if (_isConsentBusy || consents == null) return;

    final record = consents.recordFor(ConsentType.chatUnlock.dbValue);
    final isGranted =
        isConsentGranted(consents.active, widget.connectionId, ConsentType.chatUnlock.dbValue);
    final state = resolveConsentState(currentUserId: userId, isGranted: isGranted, record: record);
    final intent = _intentForConsentState(state);
    final granting = intent != ConsentIntent.revoke;

    final confirmed =
        await ConsentDialog.show(context, type: ConsentType.chatUnlock, intent: intent);
    if (!confirmed) return;

    setState(() {
      _isConsentBusy = true;
      _error = null;
    });
    try {
      await ref.read(consentRepositoryProvider).setConsent(
            connectionId: widget.connectionId,
            type: ConsentType.chatUnlock,
            consenting: granting,
          );
      // Same reasoning as `ConnectionDetailScreen._toggleConsent`: don't
      // wait on the realtime stream to reflect our own write.
      ref.invalidate(connectionConsentsProvider(widget.connectionId));
    } catch (e) {
      if (mounted) setState(() => _error = ErrorMapper.map(e));
    } finally {
      if (mounted) setState(() => _isConsentBusy = false);
    }
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

  /// Explains why the attachment button is locked and offers the
  /// verification flow. Kept tappable rather than hidden so the feature is
  /// discoverable and the reason is legible — a greyed-out button with no
  /// explanation is what makes gating feel arbitrary.
  Future<void> _showMediaLocked(VerifyUnlockReason reason) async {
    final wantsToVerify = await VerifyToUnlockDialog.show(context, reason: reason);
    if (wantsToVerify && mounted) context.push('/verification');
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

    // My own tier arrives live via `myVerificationTierProvider`, but the
    // *other* participant's comes from `public_profiles` — a view, and
    // Realtime can't subscribe to views (streams need a table with a
    // replica identity). Reading their `users` row directly isn't an option
    // either: RLS on `users` is own-row only.
    //
    // The database posts a `system` message on every tier change, and that
    // stream *is* live — so its arrival is the signal to re-read their
    // profile. Without this the media button stays locked on the other
    // person's device until they restart the app.
    final otherUserId =
        userId == null ? null : connectionAsync.valueOrNull?.otherUserId(userId);
    if (otherUserId != null) {
      ref.listen(messagesStreamProvider(widget.connectionId), (previous, next) {
        final messages = next.valueOrNull;
        if (messages == null || messages.isEmpty) return;
        if (!messages.last.isSystem) return;
        ref.invalidate(candidateProfileProvider(otherUserId));
      });
    }

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

          // "Open chat" / "Share photos & videos" in Shared Unlocks used to
          // be purely cosmetic — toggling them updated `consent_records`
          // but nothing here ever checked that state, so revoking either
          // one didn't actually re-lock anything. Both are now real,
          // mutual, revocable-at-any-time gates on top of the existing
          // requirements (status pipeline / verification tier) — fails
          // closed while consents are still loading, same as the tier
          // check below already did.
          final consents = ref.watch(connectionConsentsProvider(widget.connectionId)).valueOrNull;
          final chatUnlockGranted = consents != null &&
              isConsentGranted(
                  consents.active, widget.connectionId, ConsentType.chatUnlock.dbValue);
          final mediaShareGranted = consents != null &&
              isConsentGranted(
                  consents.active, widget.connectionId, ConsentType.mediaShare.dbValue);

          final canChat = connection.status.canChat && chatUnlockGranted;

          // Photo/video sharing requires BOTH participants at
          // selfie_verified or higher AND mutual `media_share` consent.
          //
          // Fails closed on purpose: if either tier can't be resolved —
          // the other person paused their profile so `public_profiles`
          // returns no row, or the lookup is still in flight — media stays
          // locked rather than defaulting open.
          //
          // This is UI gating only. The enforcement that matters is the
          // storage RLS policy on the `chat-media` bucket; see
          // docs/matching-and-verification-tiers.md.
          final myTier = ref.watch(myVerificationTierProvider).valueOrNull;
          final otherTier = ref
              .watch(candidateProfileProvider(connection.otherUserId(userId)))
              .valueOrNull
              ?.verificationTier;
          final iAmVerified = myTier?.isAtLeastSelfieVerified ?? false;
          final theyAreVerified = otherTier?.isAtLeastSelfieVerified ?? false;
          final canShareMedia = iAmVerified && theyAreVerified && mediaShareGranted;
          final mediaLockReason = iAmVerified
              ? VerifyUnlockReason.chatMediaOther
              : theyAreVerified
                  ? VerifyUnlockReason.chatMediaSelf
                  : VerifyUnlockReason.chatMediaBoth;

          return Column(
            children: [
              if (!connection.status.canChat)
                _NoticeBanner(
                  icon: Icons.extension_outlined,
                  message: connection.status == ConnectionStatus.ended
                      ? 'This connection has ended. Chat is read-only.'
                      : 'Waiting for the connection request to be accepted.',
                ),
              // No separate banner for a missing `chat_unlock` grant — the
              // locked composer below is now the entry point for that
              // (always visible, tap to request/agree), so a second,
              // redundant explanation up here would just be clutter.
              if (connection.status == ConnectionStatus.limitedChat)
                const _NoticeBanner(
                  icon: Icons.info_outline,
                  message:
                      'You\'re in limited chat. Each of you can send up to '
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
                        if (message.isSystem) return _SystemNotice(message: message);
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
              // Shown for the whole "not pending, not ended" range, even
              // without `chat_unlock` consent — the composer used to just
              // disappear when locked, which hid the one thing a user
              // actually needed to do next. Locked, it's dimmed and
              // non-interactive underneath (`AbsorbPointer`) with a
              // full-bar tap target on top explaining the state and
              // offering the next action, instead of a passive banner.
              if (connection.status.canChat)
                Container(
                  decoration: const BoxDecoration(
                    color: AppColors.surface,
                    border: Border(top: BorderSide(color: AppColors.divider)),
                  ),
                  child: SafeArea(
                    minimum: const EdgeInsets.all(12),
                    child: Stack(
                      children: [
                        AbsorbPointer(
                          absorbing: !canChat,
                          child: Opacity(
                            opacity: canChat ? 1 : 0.55,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                IconButton(
                                  onPressed: _isSending
                                      ? null
                                      : canShareMedia
                                          ? () => _pickAndSendMedia(userId)
                                          : () => _showMediaLocked(mediaLockReason),
                                  icon: Icon(
                                    canShareMedia
                                        ? Icons.add_photo_alternate_outlined
                                        : Icons.lock_outline,
                                    color:
                                        canShareMedia ? AppColors.primary : AppColors.textSecondary,
                                  ),
                                  tooltip: canShareMedia
                                      ? 'Share photo or video'
                                      : 'Photo sharing needs both of you verified',
                                ),
                                Expanded(
                                  child: TextField(
                                    controller: _controller,
                                    minLines: 1,
                                    maxLines: 4,
                                    enabled: canChat,
                                    decoration: InputDecoration(
                                      hintText: canChat
                                          ? 'Type a message...'
                                          : 'Chat is locked — tap to open it',
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                _isSending || _isConsentBusy
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
                                        color: canChat
                                            ? AppColors.primary
                                            : AppColors.surfaceMuted,
                                        shape: const CircleBorder(),
                                        child: InkWell(
                                          customBorder: const CircleBorder(),
                                          onTap: canChat ? () => _send(userId) : null,
                                          child: SizedBox(
                                            width: 48,
                                            height: 48,
                                            child: Icon(
                                              canChat ? Icons.send_rounded : Icons.lock_outline,
                                              color: canChat
                                                  ? Colors.white
                                                  : AppColors.textSecondary,
                                              size: 22,
                                            ),
                                          ),
                                        ),
                                      ),
                              ],
                            ),
                          ),
                        ),
                        if (!canChat)
                          Positioned.fill(
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: _isConsentBusy
                                    ? null
                                    : () => _handleLockedComposerTap(userId, consents),
                                child: const SizedBox.expand(),
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
  const _NoticeBanner({required this.icon, required this.message});

  final IconData icon;
  final String message;

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
        ],
      ),
    );
  }
}

/// Centred, non-attributed notice for `content_type = 'system'` rows.
///
/// Used when one participant's verification tier changes mid-connection.
/// The change is announced in-thread rather than only as a push because a
/// badge that silently upgrades mid-conversation changes who the other
/// person understands they're talking to, with no signal — the thread entry
/// is the durable, un-missable record. Push is optional on top of it.
class _SystemNotice extends StatelessWidget {
  const _SystemNotice({required this.message});

  final Message message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.shield_outlined, size: 13, color: AppColors.textSecondary),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              message.content,
              textAlign: TextAlign.center,
              style: AppTextStyles.caption.copyWith(fontStyle: FontStyle.italic),
            ),
          ),
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
