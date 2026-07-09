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
  Set<PartnerValue> partnerValues;
  Set<MusicGenre> musicGenres;
  String aboutText;
  String avatarId;
  String countryCode;
  String? regionName;
  int? seekingAgeMin;
  int? seekingAgeMax;

  /// Answers to the PEARMO personality questionnaire, keyed by
  /// [PersonalityQuestion.id] — 1-5 Likert value, pre-reverse-scoring.
  Map<String, int> personalityAnswers;

  /// Local file path for a recorded audio intro, pending upload on submit.
  String? audioIntroLocalPath;

  OnboardingDraft({
    this.dateOfBirth,
    this.gender,
    Set<Gender>? seeking,
    this.relationshipIntent,
    Set<PartnerValue>? partnerValues,
    Set<MusicGenre>? musicGenres,
    this.aboutText = '',
    String? avatarId,
    this.countryCode = 'LK',
    this.regionName,
    this.seekingAgeMin,
    this.seekingAgeMax,
    Map<String, int>? personalityAnswers,
    this.audioIntroLocalPath,
  })  : seeking = seeking ?? {},
        partnerValues = partnerValues ?? {},
        musicGenres = musicGenres ?? {},
        personalityAnswers = personalityAnswers ?? {},
        avatarId = avatarId ?? AvatarCatalog.allIds.first;

  OnboardingDraft clone() => OnboardingDraft(
        dateOfBirth: dateOfBirth,
        gender: gender,
        seeking: Set.of(seeking),
        relationshipIntent: relationshipIntent,
        partnerValues: Set.of(partnerValues),
        musicGenres: Set.of(musicGenres),
        aboutText: aboutText,
        avatarId: avatarId,
        countryCode: countryCode,
        regionName: regionName,
        seekingAgeMin: seekingAgeMin,
        seekingAgeMax: seekingAgeMax,
        personalityAnswers: Map.of(personalityAnswers),
        audioIntroLocalPath: audioIntroLocalPath,
      );
}
