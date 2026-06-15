/// Row inserted into `connection_ratings` after a connection ends.
class ConnectionRating {
  final String connectionId;
  final String raterId;
  final String ratedId;
  final int respectfulness;
  final int communication;
  final int ghostingBehaviour;
  final int overall;

  const ConnectionRating({
    required this.connectionId,
    required this.raterId,
    required this.ratedId,
    required this.respectfulness,
    required this.communication,
    required this.ghostingBehaviour,
    required this.overall,
  });

  Map<String, dynamic> toJson() => {
        'connection_id': connectionId,
        'rater_id': raterId,
        'rated_id': ratedId,
        'respectfulness': respectfulness,
        'communication': communication,
        'ghosting_behaviour': ghostingBehaviour,
        'overall': overall,
      };
}
