import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/daily_match.dart';
import '../models/public_profile.dart';

/// Today's curated match cards and candidate profile lookups.
class MatchesRepository {
  MatchesRepository(this._client);

  final SupabaseClient _client;

  /// Asks Postgres to generate today's batch for the signed-in user.
  ///
  /// Nothing else in the app ever writes `daily_matches` — before this
  /// existed, `generate_daily_matches()` had no caller at all (no client
  /// RPC, no cron job), so a new user's match list was simply empty
  /// forever. See docs/matching-and-verification-tiers.md.
  ///
  /// Safe to call on every app open: the underlying function no-ops while
  /// the user still has an unexpired batch, so this is one cheap round trip
  /// on all but the first call of each 24h window.
  ///
  /// Calls the `refresh_my_matches()` wrapper rather than
  /// `generate_daily_matches(uuid)` directly — the raw function takes an
  /// arbitrary user id, so exposing it to `authenticated` would let any
  /// user burn another user's daily generation. The wrapper derives the
  /// target from `auth.uid()` and is the only one granted to clients.
  Future<void> refreshMyMatches() async {
    await _client.rpc('refresh_my_matches');
  }

  /// When the user's current batch expires, regardless of whether they've
  /// already actioned every card — [getTodaysMatches] can't answer this
  /// because it filters actioned rows out.
  ///
  /// Used for honest "next matches in Xh" copy instead of a hardcoded
  /// "check back tomorrow", which was wrong as often as it was right.
  Future<DateTime?> getCurrentBatchExpiry(String userId) async {
    final rows = await _client
        .from('daily_matches')
        .select('expires_at')
        .eq('user_id', userId)
        .gt('expires_at', DateTime.now().toIso8601String())
        .order('expires_at', ascending: false)
        .limit(1);
    final list = rows as List;
    if (list.isEmpty) return null;
    return DateTime.parse((list.first as Map<String, dynamic>)['expires_at'] as String);
  }

  /// The up-to-5 candidates generated for today that haven't been acted on
  /// yet, ordered by match score.
  Future<List<DailyMatch>> getTodaysMatches(String userId) async {
    final rows = await _client
        .from('daily_matches')
        .select('id, candidate_id, user_id, score, expires_at, user_action')
        .eq('user_id', userId)
        .gt('expires_at', DateTime.now().toIso8601String())
        .isFilter('user_action', null)
        .order('score', ascending: false);
    return (rows as List).map((e) => DailyMatch.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<PublicProfile> getCandidateProfile(String candidateId) async {
    final row = await _client
        .from('public_profiles')
        .select()
        .eq('user_id', candidateId)
        .single();
    return PublicProfile.fromJson(row);
  }

  Future<void> markMatchAction({
    required String userId,
    required String candidateId,
    required String action,
  }) async {
    await _client
        .from('daily_matches')
        .update({'user_action': action})
        .eq('user_id', userId)
        .eq('candidate_id', candidateId);
  }
}
