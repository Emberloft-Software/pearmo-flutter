import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/connection_rating.dart';

/// Post-connection ratings (respectfulness, communication, ghosting, overall).
class RatingsRepository {
  RatingsRepository(this._client);

  final SupabaseClient _client;

  Future<void> submitRating(ConnectionRating rating) async {
    await _client.from('connection_ratings').insert(rating.toJson());
  }
}
