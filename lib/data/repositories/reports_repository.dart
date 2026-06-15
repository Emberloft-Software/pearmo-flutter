import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/report.dart';

/// User and message reporting — the primary safety mechanism backed by the
/// current schema (see plan notes on screenshot detection / AI filtering).
class ReportsRepository {
  ReportsRepository(this._client);

  final SupabaseClient _client;

  Future<void> submitReport(Report report) async {
    await _client.from('reports').insert(report.toJson());
  }
}
