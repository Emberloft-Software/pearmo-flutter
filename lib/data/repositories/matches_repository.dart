import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/daily_match.dart';
import '../models/public_profile.dart';

/// Today's curated match cards and candidate profile lookups.
class MatchesRepository {
  MatchesRepository(this._client);

  final SupabaseClient _client;

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
