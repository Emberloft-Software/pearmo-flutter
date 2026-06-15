import '../../../core/constants/enums.dart';
import '../../../shared/avatars/avatar_catalog.dart';

/// In-progress answers collected across the onboarding flow. Mutable by
/// design — [OnboardingController] clones it on every change so Riverpod
/// sees a new reference and rebuilds listeners.
class OnboardingDraft {
  DateTime? dateOfBirth;
  Gender? gender;
  Set<Gender> seeking;
  RelationshipIntent? relationshipIntent;
  LifeStage? lifeStage;
  EnergyType? energyType;
  ConflictStyle? conflictStyle;
  LifestylePace? lifestylePace;
  Set<PartnerValue> partnerValues;
  Set<MusicGenre> musicGenres;
  String aboutText;
  String avatarId;
  String countryCode;
  String? regionName;

  /// Local file path for a recorded audio intro, pending upload on submit.
  String? audioIntroLocalPath;

  OnboardingDraft({
    this.dateOfBirth,
    this.gender,
    Set<Gender>? seeking,
    this.relationshipIntent,
    this.lifeStage,
    this.energyType,
    this.conflictStyle,
    this.lifestylePace,
    Set<PartnerValue>? partnerValues,
    Set<MusicGenre>? musicGenres,
    this.aboutText = '',
    String? avatarId,
    this.countryCode = 'LK',
    this.regionName,
    this.audioIntroLocalPath,
  })  : seeking = seeking ?? {},
        partnerValues = partnerValues ?? {},
        musicGenres = musicGenres ?? {},
        avatarId = avatarId ?? AvatarCatalog.allIds.first;

  OnboardingDraft clone() => OnboardingDraft(
        dateOfBirth: dateOfBirth,
        gender: gender,
        seeking: Set.of(seeking),
        relationshipIntent: relationshipIntent,
        lifeStage: lifeStage,
        energyType: energyType,
        conflictStyle: conflictStyle,
        lifestylePace: lifestylePace,
        partnerValues: Set.of(partnerValues),
        musicGenres: Set.of(musicGenres),
        aboutText: aboutText,
        avatarId: avatarId,
        countryCode: countryCode,
        regionName: regionName,
        audioIntroLocalPath: audioIntroLocalPath,
      );
}
