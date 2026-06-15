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
        .order('sent_at')
        .map((rows) => rows.map((e) => Message.fromJson(e)).toList());
  }

  Future<void> sendMessage({
    required String connectionId,
    required String senderId,
    required String content,
    String contentType = 'text',
  }) async {
    await _client.from('messages').insert({
      'connection_id': connectionId,
      'sender_id': senderId,
      'content': content,
      'content_type': contentType,
    });
  }
}
