/// Maps a push notification's `data` payload to the route it should open
/// when tapped.
///
/// The `type`/`connection_id` keys are written by the `send-push` edge
/// function ([supabase/functions/send-push/index.ts]) — keep the two in
/// sync when adding an event there.
///
/// Returns `null` when there's nothing specific to open, in which case the
/// tap should just bring the app up wherever it was.
String? routeForPushData(Map<String, dynamic> data) {
  final type = data['type'] as String?;
  final connectionId = data['connection_id'] as String?;
  if (type == null) return null;

  return switch (type) {
    'message' when connectionId != null => '/connection/$connectionId/chat',
    'game_invite' when connectionId != null => '/connection/$connectionId/games',

    // A pending request is accepted/declined from the connections hub,
    // which is a tab inside HomeShell rather than its own route — the
    // connection detail screen has no accept/decline UI, so sending the
    // user there would be a dead end.
    'connection_request' => '/home',

    // Everything else (accept, end, and every consent event) is acted on
    // from the connection detail screen, which is also where the Shared
    // Unlocks panel lives.
    _ when connectionId != null => '/connection/$connectionId',
    _ => null,
  };
}
