import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';
import '../models/date_checkin.dart';

/// Date safety check-ins: create/acknowledge/cancel via the `date-checkin`
/// edge function, plus reading the user's own check-ins to show reminders.
class CheckinRepository {
  CheckinRepository(this._client);

  final SupabaseClient _client;

  Future<void> create({
    required String connectionId,
    required DateTime scheduledFor,
    required String emergencyContact,
  }) async {
    await _client.functions.invoke(
      SupabaseConfig.fnDateCheckin,
      body: {
        'action': 'create',
        'connection_id': connectionId,
        'scheduled_for': scheduledFor.toUtc().toIso8601String(),
        'emergency_contact': emergencyContact,
      },
    );
  }

  Future<void> acknowledge(String checkinId) async {
    await _client.functions.invoke(
      SupabaseConfig.fnDateCheckin,
      body: {'action': 'acknowledge', 'checkin_id': checkinId},
    );
  }

  Future<void> cancel(String checkinId) async {
    await _client.functions.invoke(
      SupabaseConfig.fnDateCheckin,
      body: {'action': 'cancel', 'checkin_id': checkinId},
    );
  }

  /// Upcoming/past check-ins created by the current user for a connection.
  Future<List<DateCheckin>> getCheckins(String connectionId) async {
    final rows = await _client
        .from('date_checkins')
        .select()
        .eq('connection_id', connectionId)
        .order('scheduled_for', ascending: false);
    return (rows as List).map((e) => DateCheckin.fromJson(e as Map<String, dynamic>)).toList();
  }
}
