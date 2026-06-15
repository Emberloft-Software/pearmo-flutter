/// Row from `daily_matches` — one of today's curated candidates for the
/// signed-in user.
class DailyMatch {
  final String id;
  final String userId;
  final String candidateId;
  final double score;
  final DateTime expiresAt;
  final String? userAction;

  const DailyMatch({
    required this.id,
    required this.userId,
    required this.candidateId,
    required this.score,
    required this.expiresAt,
    this.userAction,
  });

  factory DailyMatch.fromJson(Map<String, dynamic> json) {
    return DailyMatch(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      candidateId: json['candidate_id'] as String,
      score: (json['score'] as num).toDouble(),
      expiresAt: DateTime.parse(json['expires_at'] as String),
      userAction: json['user_action'] as String?,
    );
  }
}
