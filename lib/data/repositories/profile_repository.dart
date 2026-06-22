import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';
import '../models/profile.dart';

/// Reads/writes the signed-in user's own `profiles` row, plus the
/// `analyse-profile` sentiment pass run after onboarding.
class ProfileRepository {
  ProfileRepository(this._client);

  final SupabaseClient _client;

  Future<Profile?> getMyProfile(String userId) async {
    final row = await _client.from('profiles').select().eq('user_id', userId).maybeSingle();
    if (row == null) return null;
    return Profile.fromJson(row);
  }

  /// Upsert (not insert) so retrying onboarding after a later step fails
  /// (audio upload, sentiment analysis) doesn't hit a unique-constraint
  /// error on a `profiles` row already created by the earlier attempt.
  Future<void> saveOnboarding(Profile profile) async {
    await _client.from('profiles').upsert(profile.toInsertJson(), onConflict: 'user_id');
  }

  Future<void> runSentimentAnalysis() async {
    await _client.functions.invoke(SupabaseConfig.fnAnalyseProfile);
  }

  Future<void> updateSettings({
    required String userId,
    bool? isPhotoPublic,
    String? activeHoursStart,
    String? activeHoursEnd,
    bool? hideFromContacts,
    String? regionName,
    String? countryCode,
  }) async {
    final updates = <String, dynamic>{
      if (isPhotoPublic != null) 'is_photo_public': isPhotoPublic,
      if (activeHoursStart != null) 'active_hours_start': activeHoursStart,
      if (activeHoursEnd != null) 'active_hours_end': activeHoursEnd,
      if (hideFromContacts != null) 'hide_from_contacts': hideFromContacts,
      if (regionName != null) 'region_name': regionName,
      if (countryCode != null) 'country_code': countryCode,
    };
    if (updates.isEmpty) return;
    await _client.from('profiles').update(updates).eq('user_id', userId);
  }

  Future<void> updateProfilePhotoPath(String userId, String path) async {
    await _client.from('profiles').update({'profile_photo_url': path}).eq('user_id', userId);
  }

  Future<void> updateAudioIntroPath(String userId, String path) async {
    await _client.from('profiles').update({'audio_intro_url': path}).eq('user_id', userId);
  }
}
