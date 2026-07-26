import 'package:flutter/material.dart';

import '../../core/constants/enums.dart';
import '../../core/theme/app_colors.dart';

/// One of the 20 Pearmo animal characters. Each has a male and female 3D
/// render bundled under `assets/avatars/` and a personality meaning shown
/// in the picker. Meanings are static app content — they live here, not in
/// the database (the unused `avatars` table stays untouched).
class AvatarCharacter {
  const AvatarCharacter({
    required this.key,
    required this.name,
    required this.tagline,
    required this.description,
    required this.extraversion,
    required this.agreeableness,
    required this.conscientiousness,
    required this.emotionalStability,
    required this.openness,
    required this.attachmentSecurity,
  });

  /// Stable id stem — `avatar_id` in the DB is `'$key-m'` or `'$key-f'`.
  final String key;
  final String name;

  /// Short trait summary, e.g. "Clever · Quick-witted".
  final String tagline;

  /// One-sentence meaning shown when the character is selected.
  final String description;

  /// This character's own personality "profile" (1-5 scale, same scale as
  /// `profiles.trait_*`), hand-derived from its tagline/description above —
  /// used by [AvatarCatalog.suggestCharacter] to find the closest match to
  /// the user's actual PEARMO answers. Not shown in the UI directly.
  final double extraversion;
  final double agreeableness;
  final double conscientiousness;
  final double emotionalStability;
  final double openness;
  final double attachmentSecurity;

  String idFor(bool male) => male ? '$key-m' : '$key-f';
  String assetFor(bool male) => 'assets/avatars/$key-${male ? 'm' : 'f'}.png';

  double traitValue(PersonalityTrait trait) => switch (trait) {
        PersonalityTrait.extraversion => extraversion,
        PersonalityTrait.agreeableness => agreeableness,
        PersonalityTrait.conscientiousness => conscientiousness,
        PersonalityTrait.emotionalStability => emotionalStability,
        PersonalityTrait.openness => openness,
        PersonalityTrait.attachmentSecurity => attachmentSecurity,
      };
}

/// Resolved view of a concrete `avatar_id` (character + gender variant).
class AvatarInfo {
  const AvatarInfo({required this.character, required this.isMale});

  final AvatarCharacter character;
  final bool isMale;

  String get id => character.idFor(isMale);
  String get assetPath => character.assetFor(isMale);
}

/// Pearmo's avatar set: 20 anthro-animal characters, each in a male and a
/// female variant (40 selectable ids like `fox-f`, `wolf-m`).
///
/// Legacy ids (`av_001`..`av_024`, from the launch set of generated
/// circle avatars) still resolve — they map deterministically onto the new
/// characters so existing profiles keep working with zero data migration.
class AvatarCatalog {
  AvatarCatalog._();

  /// Set A — anthro-animal trait projection. Order defines picker order.
  /// Each entry's `extraversion`/`agreeableness`/`conscientiousness`/
  /// `emotionalStability`/`openness`/`attachmentSecurity` (1-5 scale) is a
  /// hand-derived reading of its own tagline/description above, used only
  /// by [suggestCharacter] — not shown to the user directly.
  static const List<AvatarCharacter> characters = [
    AvatarCharacter(
      key: 'fox',
      name: 'Fox',
      tagline: 'Clever · Flirtatious · Quick-witted',
      description:
          'A little hard to read, and treats banter as a form of flirting.',
      extraversion: 4.0,
      agreeableness: 2.5,
      conscientiousness: 3.0,
      emotionalStability: 3.5,
      openness: 4.5,
      attachmentSecurity: 2.5,
    ),
    AvatarCharacter(
      key: 'wolf',
      name: 'Wolf',
      tagline: 'Loyal · Intense · Protective',
      description:
          'Forms deep, ride-or-die bonds rather than wide social circles.',
      extraversion: 2.5,
      agreeableness: 4.0,
      conscientiousness: 4.0,
      emotionalStability: 3.5,
      openness: 3.0,
      attachmentSecurity: 4.5,
    ),
    AvatarCharacter(
      key: 'owl',
      name: 'Owl',
      tagline: 'Introspective · Observant · Quietly wise',
      description: 'Listens more than they talk, and notices everything.',
      extraversion: 1.5,
      agreeableness: 3.5,
      conscientiousness: 4.0,
      emotionalStability: 4.0,
      openness: 4.5,
      attachmentSecurity: 3.5,
    ),
    AvatarCharacter(
      key: 'otter',
      name: 'Otter',
      tagline: 'Playful · Social · Affectionate',
      description:
          'Flirts through jokes and warmth — closeness comes naturally.',
      extraversion: 4.5,
      agreeableness: 4.5,
      conscientiousness: 3.0,
      emotionalStability: 3.5,
      openness: 4.0,
      attachmentSecurity: 4.0,
    ),
    AvatarCharacter(
      key: 'deer',
      name: 'Deer',
      tagline: 'Gentle · Cautious · Sensitive',
      description: 'Needs safety and slow pacing before opening up.',
      extraversion: 2.0,
      agreeableness: 4.0,
      conscientiousness: 3.0,
      emotionalStability: 2.0,
      openness: 3.0,
      attachmentSecurity: 2.5,
    ),
    AvatarCharacter(
      key: 'bear',
      name: 'Bear',
      tagline: 'Warm · Steady · Protective-but-soft',
      description:
          'The big teddy bear — a reassuring presence over excitement.',
      extraversion: 2.5,
      agreeableness: 4.5,
      conscientiousness: 4.0,
      emotionalStability: 4.5,
      openness: 3.0,
      attachmentSecurity: 4.5,
    ),
    AvatarCharacter(
      key: 'cat',
      name: 'Cat',
      tagline: 'Independent · Selective · A little aloof',
      description: 'Values autonomy and gives affection on their own terms.',
      extraversion: 2.5,
      agreeableness: 2.5,
      conscientiousness: 3.5,
      emotionalStability: 4.0,
      openness: 3.0,
      attachmentSecurity: 2.0,
    ),
    AvatarCharacter(
      key: 'dog',
      name: 'Dog',
      tagline: 'Loyal · Eager · Emotionally open',
      description: 'Wears their heart on their sleeve — no emotional games.',
      extraversion: 4.5,
      agreeableness: 4.5,
      conscientiousness: 3.0,
      emotionalStability: 3.0,
      openness: 3.0,
      attachmentSecurity: 4.5,
    ),
    AvatarCharacter(
      key: 'crow',
      name: 'Raven',
      tagline: 'Sharp-minded · Dark-humored · Mysterious',
      description: 'Intelligent and intriguing, but emotionally guarded.',
      extraversion: 2.5,
      agreeableness: 3.0,
      conscientiousness: 3.5,
      emotionalStability: 3.5,
      openness: 4.5,
      attachmentSecurity: 2.0,
    ),
    AvatarCharacter(
      key: 'rabbit',
      name: 'Rabbit',
      tagline: 'Sweet · Excitable · Affectionate',
      description:
          'Needs reassurance early, then loves warmly once comfortable.',
      extraversion: 4.0,
      agreeableness: 4.5,
      conscientiousness: 2.5,
      emotionalStability: 2.5,
      openness: 3.0,
      attachmentSecurity: 3.0,
    ),
    AvatarCharacter(
      key: 'hawk',
      name: 'Hawk',
      tagline: 'Driven · Focused · Ambitious',
      description: 'Leads with goals and direction rather than feelings.',
      extraversion: 3.0,
      agreeableness: 2.5,
      conscientiousness: 4.5,
      emotionalStability: 4.0,
      openness: 3.5,
      attachmentSecurity: 2.5,
    ),
    AvatarCharacter(
      key: 'horse',
      name: 'Horse',
      tagline: 'Graceful · Free-spirited · Untamed',
      description: 'Needs independence inside a relationship, never control.',
      extraversion: 3.5,
      agreeableness: 3.0,
      conscientiousness: 2.5,
      emotionalStability: 3.5,
      openness: 4.5,
      attachmentSecurity: 2.0,
    ),
    AvatarCharacter(
      key: 'panther',
      name: 'Panther',
      tagline: 'Confident · Sensual · Deliberate',
      description: 'Comfortable with their own intensity and magnetism.',
      extraversion: 3.5,
      agreeableness: 3.0,
      conscientiousness: 4.0,
      emotionalStability: 4.0,
      openness: 3.5,
      attachmentSecurity: 3.5,
    ),
    AvatarCharacter(
      key: 'squirrel',
      name: 'Squirrel',
      tagline: 'Energetic · Spontaneous · Endearing chaos',
      description: 'Fun and full of surprises — a little unpredictable.',
      extraversion: 4.5,
      agreeableness: 3.5,
      conscientiousness: 1.5,
      emotionalStability: 2.5,
      openness: 4.0,
      attachmentSecurity: 3.0,
    ),
    AvatarCharacter(
      key: 'swan',
      name: 'Swan',
      tagline: 'Elegant · Composed · Deeply feeling',
      description: 'Poised on the outside, deeply emotional underneath.',
      extraversion: 3.0,
      agreeableness: 4.0,
      conscientiousness: 4.0,
      emotionalStability: 2.5,
      openness: 3.5,
      attachmentSecurity: 4.0,
    ),
    AvatarCharacter(
      key: 'tiger',
      name: 'Tiger',
      tagline: 'Bold · Dominant · Unshrinking',
      description:
          'Wants a partner who matches their energy, not soothes it.',
      extraversion: 4.5,
      agreeableness: 2.0,
      conscientiousness: 3.5,
      emotionalStability: 4.5,
      openness: 3.5,
      attachmentSecurity: 3.0,
    ),
    AvatarCharacter(
      key: 'hedgehog',
      name: 'Hedgehog',
      tagline: 'Soft · Guarded · Worth the wait',
      description: 'Slow to trust, protective of their heart, sweet once in.',
      extraversion: 1.5,
      agreeableness: 3.5,
      conscientiousness: 3.0,
      emotionalStability: 2.5,
      openness: 2.5,
      attachmentSecurity: 2.0,
    ),
    AvatarCharacter(
      key: 'dolphin',
      name: 'Dolphin',
      tagline: 'Playful · Perceptive · Social',
      description:
          'The fun friend who is also surprisingly emotionally tuned-in.',
      extraversion: 4.5,
      agreeableness: 4.0,
      conscientiousness: 3.0,
      emotionalStability: 4.0,
      openness: 4.0,
      attachmentSecurity: 3.5,
    ),
    AvatarCharacter(
      key: 'lion',
      name: 'Lion',
      tagline: 'Confident · Protective · Leader energy',
      description: 'Naturally takes charge and looks after their pride.',
      extraversion: 4.0,
      agreeableness: 3.5,
      conscientiousness: 4.0,
      emotionalStability: 4.5,
      openness: 3.0,
      attachmentSecurity: 4.0,
    ),
    AvatarCharacter(
      key: 'koala',
      name: 'Koala',
      tagline: 'Laid-back · Low-drama · Cuddly',
      description: 'Wants comfort and calm over excitement — undemanding.',
      extraversion: 2.0,
      agreeableness: 4.0,
      conscientiousness: 2.5,
      emotionalStability: 4.0,
      openness: 2.5,
      attachmentSecurity: 3.5,
    ),
  ];

  /// All selectable ids: female variants then male, in character order.
  static List<String> get allIds => [
        for (final c in characters) c.idFor(false),
        for (final c in characters) c.idFor(true),
      ];

  /// Ids to show first in the picker for a given gender. Purely a display
  /// suggestion — any user may pick any avatar via "show all".
  static List<String> idsForGender(Gender? gender) => switch (gender) {
        Gender.man => [for (final c in characters) c.idFor(true)],
        Gender.woman => [for (final c in characters) c.idFor(false)],
        _ => allIds,
      };

  /// The character whose hand-derived trait profile is closest to the
  /// user's actual PEARMO answers (same `1 - |diff|/4` per-trait similarity
  /// used by `score_compatibility`, just comparing a person to a character
  /// instead of two people). Gender variant is chosen separately by the
  /// caller — this only picks which of the 20 characters fits best.
  static AvatarCharacter suggestCharacter(Map<PersonalityTrait, double> traitScores) {
    return characters.reduce(
      (best, c) => _matchScore(c, traitScores) > _matchScore(best, traitScores) ? c : best,
    );
  }

  static double _matchScore(AvatarCharacter c, Map<PersonalityTrait, double> traitScores) {
    var score = 0.0;
    for (final trait in PersonalityTrait.values) {
      final diff = (c.traitValue(trait) - (traitScores[trait] ?? 3.0)).abs();
      score += 1 - (diff / 4).clamp(0, 1);
    }
    return score;
  }

  /// Resolves any `avatar_id` — new (`fox-f`) or legacy (`av_007`) — to a
  /// character + variant. Unknown ids fall back to the first character so
  /// rendering never throws on bad data.
  static AvatarInfo resolve(String avatarId) {
    // Legacy generated-avatar ids: map deterministically onto the new set.
    final legacy = RegExp(r'^av_(\d+)$').firstMatch(avatarId);
    if (legacy != null) {
      final n = (int.tryParse(legacy.group(1)!) ?? 1) - 1;
      final character = characters[n % characters.length];
      // Alternate variants so the legacy set spreads across both.
      return AvatarInfo(character: character, isMale: (n ~/ characters.length).isEven == false);
    }

    final male = avatarId.endsWith('-m');
    final key = avatarId.replaceFirst(RegExp(r'-[mf]$'), '');
    final character = characters.firstWhere(
      (c) => c.key == key,
      orElse: () => characters.first,
    );
    return AvatarInfo(character: character, isMale: male);
  }

  /// Shared stage gradient every avatar sits on — one common treatment,
  /// no per-character color meaning (deep magenta → violet, from the v5
  /// design system).
  static const List<Color> stageGradient = [AppColors.magenta, AppColors.primary];
}
