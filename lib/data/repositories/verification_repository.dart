import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';
import '../../core/constants/enums.dart';

/// NIC + selfie identity verification. Files are uploaded to storage first
/// (see [StorageRepository]), then this submits the paths for manual review.
class VerificationRepository {
  VerificationRepository(this._client);

  final SupabaseClient _client;

  Future<void> submitVerification({
    required String nicFrontPath,
    String? nicBackPath,
    required String selfiePath,
  }) async {
    await _client.functions.invoke(
      SupabaseConfig.fnSubmitVerification,
      body: {
        'nic_front_path': nicFrontPath,
        if (nicBackPath != null) 'nic_back_path': nicBackPath,
        'selfie_path': selfiePath,
      },
    );
  }

  Future<VerificationTier> getVerificationTier(String userId) async {
    final row =
        await _client.from('users').select('verification_tier').eq('id', userId).single();
    return VerificationTier.fromDb(row['verification_tier'] as String? ?? 'unverified');
  }

  Stream<VerificationTier> watchVerificationTier(String userId) {
    return _client
        .from('users')
        .stream(primaryKey: ['id'])
        .eq('id', userId)
        .map((rows) => rows.isEmpty
            ? VerificationTier.unverified
            : VerificationTier.fromDb(rows.first['verification_tier'] as String? ?? 'unverified'));
  }
}
