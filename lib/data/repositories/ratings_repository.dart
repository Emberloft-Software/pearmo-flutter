import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/connection_rating.dart';

/// Post-connection ratings (respectfulness, communication, ghosting, overall).
class RatingsRepository {
  RatingsRepository(this._client);

  final SupabaseClient _client;

  Future<void> submitRating(ConnectionRating rating) async {
    await _client.from('connection_ratings').insert(rating.toJson());
  }

  /// Whether the given rater has already rated this connection. RLS only
  /// lets a user select ratings where they're the rater, so this only ever
  /// checks the caller's own prior submission — used to stop someone from
  /// re-navigating to the rate screen and submitting a second time (there's
  /// no unique DB constraint backing this, so it's a UI-level guard only).
  Future<bool> hasRated({required String connectionId, required String raterId}) async {
    final row = await _client
        .from('connection_ratings')
        .select('id')
        .eq('connection_id', connectionId)
        .eq('rater_id', raterId)
        .maybeSingle();
    return row != null;
  }
}
