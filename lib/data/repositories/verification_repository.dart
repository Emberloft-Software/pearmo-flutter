import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';
import '../../core/constants/enums.dart';

/// Status of the most recent `verification_submissions` row for one tier.
class VerificationSubmissionStatus {
  const VerificationSubmissionStatus({required this.status, this.rejectionReason});

  final String status; // 'pending' | 'approved' | 'rejected'
  final String? rejectionReason;
}

/// NIC + selfie identity verification. Files are uploaded to storage first
/// (see [StorageRepository]), then this submits the paths for manual review.
class VerificationRepository {
  VerificationRepository(this._client);

  final SupabaseClient _client;

  /// Tier 1 — liveliness check + selfie. Confirms the user is a real person.
  Future<void> submitSelfieVerification({
    required String selfiePath,
    required bool livelinessPassed,
  }) async {
    await _client.functions.invoke(
      SupabaseConfig.fnSubmitVerification,
      body: {
        'tier': 'selfie',
        'selfie_path': selfiePath,
        'liveliness_passed': livelinessPassed,
      },
    );
  }

  /// Tier 2 — NIC submission on top of an existing selfie verification.
  /// Confirms the profile's displayed age matches the document.
  Future<void> submitIdVerification({
    required String nicFrontPath,
    String? nicBackPath,
  }) async {
    await _client.functions.invoke(
      SupabaseConfig.fnSubmitVerification,
      body: {
        'tier': 'id',
        'nic_front_path': nicFrontPath,
        if (nicBackPath != null) 'nic_back_path': nicBackPath,
      },
    );
  }

  /// The most recent submission for a given tier, if any — used to show
  /// "awaiting review" / rejection feedback instead of a bare form, since
  /// nothing else in the app reads `verification_submissions` today.
  Future<VerificationSubmissionStatus?> getLatestSubmission({
    required String userId,
    required String tier,
  }) async {
    final row = await _client
        .from('verification_submissions')
        .select('status, rejection_reason')
        .eq('user_id', userId)
        .eq('tier', tier)
        .order('submitted_at', ascending: false)
        .limit(1)
        .maybeSingle();
    if (row == null) return null;
    return VerificationSubmissionStatus(
      status: row['status'] as String? ?? 'pending',
      rejectionReason: row['rejection_reason'] as String?,
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
