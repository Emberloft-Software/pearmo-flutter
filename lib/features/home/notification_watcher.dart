import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/notifications/notification_service.dart';
import '../../providers/auth_providers.dart';
import '../../providers/connections_providers.dart';
import '../../providers/games_providers.dart';
import '../../providers/messages_providers.dart';
import '../../providers/notification_providers.dart';

/// Invisible app-wide listener that fires local notifications for new chat
/// messages, incoming connection requests, and new game invites — mounted
/// once above the bottom-nav shell so it keeps running across tab switches.
///
/// In-app/local only (see `NotificationService`), not server push: each
/// `ref.listen` below reacts to the same Realtime-backed providers the
/// relevant screens already use, so this only fires while the app process
/// is alive (foreground or backgrounded), never when fully killed.
class NotificationWatcher extends ConsumerStatefulWidget {
  const NotificationWatcher({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<NotificationWatcher> createState() => _NotificationWatcherState();
}

class _NotificationWatcherState extends ConsumerState<NotificationWatcher> {
  String? _lastSeenMessageId;
  Set<String> _seenSessionIds = {};
  Set<String> _seenRequestIds = {};

  @override
  Widget build(BuildContext context) {
    final userId = ref.watch(currentUserIdProvider);
    final activeConnection = ref.watch(activeConnectionProvider).valueOrNull;

    if (activeConnection != null && userId != null) {
      // `ref.listen` re-subscribes automatically whenever the family
      // argument (connection id) changes, and `previous == null` on the
      // very first callback for that new subscription — that's the signal
      // to just record a baseline instead of notifying for existing
      // history, no manual "did the connection change" bookkeeping needed.
      ref.listen(messagesStreamProvider(activeConnection.id), (previous, next) {
        final messages = next.valueOrNull;
        if (messages == null || messages.isEmpty) return;
        final latest = messages.last;
        if (previous == null) {
          _lastSeenMessageId = latest.id;
          return;
        }
        if (latest.id == _lastSeenMessageId) return;
        _lastSeenMessageId = latest.id;
        if (latest.senderId == userId) return;
        if (ref.read(currentlyOpenChatConnectionIdProvider) == activeConnection.id) return;

        final body = latest.isImage
            ? 'Sent a photo'
            : latest.isVideo
                ? 'Sent a video'
                : latest.content;
        NotificationService.instance.show(title: 'New message', body: body);
      });

      ref.listen(gameSessionsStreamProvider(activeConnection.id), (previous, next) {
        final sessions = next.valueOrNull;
        if (sessions == null) return;
        if (previous == null) {
          _seenSessionIds = sessions.map((s) => s.id).toSet();
          return;
        }
        for (final session in sessions) {
          if (_seenSessionIds.contains(session.id)) continue;
          _seenSessionIds.add(session.id);
          // No `created_by` column on ice_breaker_sessions (see CLAUDE.md),
          // so there's no way to tell who started it — the creator will
          // also see this fire once for their own action, a minor accepted
          // redundancy rather than guessed-at schema tracking.
          NotificationService.instance.show(
            title: 'Game invite',
            body: 'Your connection wants to play ${session.gameType.label}!',
          );
        }
      });
    }

    ref.listen(incomingRequestsStreamProvider, (previous, next) {
      final requests = next.valueOrNull;
      if (requests == null) return;
      if (previous == null) {
        _seenRequestIds = requests.map((r) => r.id).toSet();
        return;
      }
      for (final request in requests) {
        if (_seenRequestIds.contains(request.id)) continue;
        _seenRequestIds.add(request.id);
        NotificationService.instance.show(
          title: 'New connection request',
          body: 'Someone wants to connect with you!',
        );
      }
    });

    return widget.child;
  }
}
