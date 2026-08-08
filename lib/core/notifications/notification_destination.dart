import '../../providers/home_tab_provider.dart';

/// Where tapping a notification should take the user.
class NotificationDestination {
  const NotificationDestination(this.route, {this.homeTab});

  /// Route to push. `/home` means "don't push anything" — the shell is
  /// already there — and is used together with [homeTab].
  final String route;

  /// Tab of `HomeShell` to select first, if any.
  final int? homeTab;
}

/// Maps the `data` map that `send-push` attaches to every notification
/// (`{type, connection_id}`) onto a destination in the app.
///
/// Returns null for anything unrecognised, so an unknown or future
/// notification type just opens the app rather than throwing.
NotificationDestination? destinationFor(Map<String, dynamic> data) {
  final type = data['type'] as String?;
  final connectionId = data['connection_id'] as String?;
  if (type == null) return null;

  // Every connection-scoped destination needs the id; fall back to the
  // Connections tab if the payload somehow arrived without one.
  const hub = NotificationDestination('/home', homeTab: HomeTab.connections);

  switch (type) {
    case 'message':
      return connectionId == null
          ? hub
          : NotificationDestination('/connection/$connectionId/chat');

    case 'game_invite':
      return connectionId == null
          ? hub
          : NotificationDestination('/connection/$connectionId/games');

    // Accept/Decline live on the hub screen, not the connection detail
    // screen, so a new request has to land there.
    case 'connection_request':
      return hub;

    // These all concern one existing connection, and the thing the user
    // wants next (break the ice, respond to a consent request, see what
    // changed) is on its detail screen — which is also where the Shared
    // Unlocks panel lives.
    case 'connection_accepted':
    case 'connection_ended':
    case 'consent_requested':
    case 'consent_granted':
    case 'consent_revoked':
    case 'consent_declined':
      return connectionId == null
          ? hub
          : NotificationDestination('/connection/$connectionId');

    default:
      return null;
  }
}
