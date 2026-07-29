import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/message.dart';

/// Chat messages for a connection. The backend enforces both the
/// connection-status gating (no messages outside limited_chat/open_chat/
/// media_unlocked) and the 5-message cap during limited_chat — this
/// repository just sends/streams and lets `ErrorMapper` translate failures.
class MessagesRepository {
  MessagesRepository(this._client);

  final SupabaseClient _client;

  Stream<List<Message>> watchMessages(String connectionId) {
    return _client
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('connection_id', connectionId)
        // SupabaseStreamBuilder.order() defaults to ascending: false —
        // without this, messages arrive newest-first and render at the top
        // of a normal (non-reversed) ListView instead of the bottom.
        .order('sent_at', ascending: true)
        .map((rows) => rows.map((e) => Message.fromJson(e)).toList());
  }

  Future<void> sendMessage({
    required String connectionId,
    required String senderId,
    required String content,
    String contentType = 'text',
    String? mediaUrl,
  }) async {
    await _client.from('messages').insert({
      'connection_id': connectionId,
      'sender_id': senderId,
      'content': content,
      'content_type': contentType,
      if (mediaUrl != null) 'media_url': mediaUrl,
    });
  }

  /// Ephemeral per-connection channel for typing indicators — pure Realtime
  /// Broadcast, never persisted to any table (no RLS/migration involved).
  /// Caller owns the channel's lifecycle: call `.subscribe()` after wiring
  /// up listeners, and `SupabaseClient.removeChannel()` when done with it.
  RealtimeChannel typingChannel(String connectionId) =>
      _client.channel('typing:$connectionId');
}
