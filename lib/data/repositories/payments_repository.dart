import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';

/// Kicks off a PayHere checkout for the "Verified Plus" tier.
class PaymentsRepository {
  PaymentsRepository(this._client);

  final SupabaseClient _client;

  Future<String> createCheckoutUrl(String userId) async {
    final response = await _client.functions.invoke(
      SupabaseConfig.fnCreatePayhereOrder,
      body: {'user_id': userId},
    );
    final data = response.data;
    if (data is Map && data['checkout_url'] is String) {
      return data['checkout_url'] as String;
    }
    throw const FormatException('Missing checkout_url in response.');
  }
}
