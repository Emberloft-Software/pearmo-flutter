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
  });

  /// Stable id stem — `avatar_id` in the DB is `'$key-m'` or `'$key-f'`.
  final String key;
  final String name;

  /// Short trait summary, e.g. "Clever · Quick-witted".
  final String tagline;

  /// One-sentence meaning shown when the character is selected.
  final String description;

  String idFor(bool male) => male ? '$key-m' : '$key-f';
  String assetFor(bool male) => 'assets/avatars/$key-${male ? 'm' : 'f'}.png';
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
  static const List<AvatarCharacter> characters = [
    AvatarCharacter(
      key: 'fox',
      name: 'Fox',
      tagline: 'Clever · Flirtatious · Quick-witted',
      description:
          'A little hard to read, and treats banter as a form of flirting.',
    ),
    AvatarCharacter(
      key: 'wolf',
      name: 'Wolf',
      tagline: 'Loyal · Intense · Protective',
      description:
          'Forms deep, ride-or-die bonds rather than wide social circles.',
    ),
    AvatarCharacter(
      key: 'owl',
      name: 'Owl',
      tagline: 'Introspective · Observant · Quietly wise',
      description: 'Listens more than they talk, and notices everything.',
    ),
    AvatarCharacter(
      key: 'otter',
      name: 'Otter',
      tagline: 'Playful · Social · Affectionate',
      description:
          'Flirts through jokes and warmth — closeness comes naturally.',
    ),
    AvatarCharacter(
      key: 'deer',
      name: 'Deer',
      tagline: 'Gentle · Cautious · Sensitive',
      description: 'Needs safety and slow pacing before opening up.',
    ),
    AvatarCharacter(
      key: 'bear',
      name: 'Bear',
      tagline: 'Warm · Steady · Protective-but-soft',
      description:
          'The big teddy bear — a reassuring presence over excitement.',
    ),
    AvatarCharacter(
      key: 'cat',
      name: 'Cat',
      tagline: 'Independent · Selective · A little aloof',
      description: 'Values autonomy and gives affection on their own terms.',
    ),
    AvatarCharacter(
      key: 'dog',
      name: 'Dog',
      tagline: 'Loyal · Eager · Emotionally open',
      description: 'Wears their heart on their sleeve — no emotional games.',
    ),
    AvatarCharacter(
      key: 'crow',
      name: 'Raven',
      tagline: 'Sharp-minded · Dark-humored · Mysterious',
      description: 'Intelligent and intriguing, but emotionally guarded.',
    ),
    AvatarCharacter(
      key: 'rabbit',
      name: 'Rabbit',
      tagline: 'Sweet · Excitable · Affectionate',
      description:
          'Needs reassurance early, then loves warmly once comfortable.',
    ),
    AvatarCharacter(
      key: 'hawk',
      name: 'Hawk',
      tagline: 'Driven · Focused · Ambitious',
      description: 'Leads with goals and direction rather than feelings.',
    ),
    AvatarCharacter(
      key: 'horse',
      name: 'Horse',
      tagline: 'Graceful · Free-spirited · Untamed',
      description: 'Needs independence inside a relationship, never control.',
    ),
    AvatarCharacter(
      key: 'panther',
      name: 'Panther',
      tagline: 'Confident · Sensual · Deliberate',
      description: 'Comfortable with their own intensity and magnetism.',
    ),
    AvatarCharacter(
      key: 'squirrel',
      name: 'Squirrel',
      tagline: 'Energetic · Spontaneous · Endearing chaos',
      description: 'Fun and full of surprises — a little unpredictable.',
    ),
    AvatarCharacter(
      key: 'swan',
      name: 'Swan',
      tagline: 'Elegant · Composed · Deeply feeling',
      description: 'Poised on the outside, deeply emotional underneath.',
    ),
    AvatarCharacter(
      key: 'tiger',
      name: 'Tiger',
      tagline: 'Bold · Dominant · Unshrinking',
      description:
          'Wants a partner who matches their energy, not soothes it.',
    ),
    AvatarCharacter(
      key: 'hedgehog',
      name: 'Hedgehog',
      tagline: 'Soft · Guarded · Worth the wait',
      description: 'Slow to trust, protective of their heart, sweet once in.',
    ),
    AvatarCharacter(
      key: 'dolphin',
      name: 'Dolphin',
      tagline: 'Playful · Perceptive · Social',
      description:
          'The fun friend who is also surprisingly emotionally tuned-in.',
    ),
    AvatarCharacter(
      key: 'lion',
      name: 'Lion',
      tagline: 'Confident · Protective · Leader energy',
      description: 'Naturally takes charge and looks after their pride.',
    ),
    AvatarCharacter(
      key: 'koala',
      name: 'Koala',
      tagline: 'Laid-back · Low-drama · Cuddly',
      description: 'Wants comfort and calm over excitement — undemanding.',
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
