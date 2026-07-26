import '../../core/constants/enums.dart';

/// The signed-in user's own row in `profiles`. Contains everything from
/// onboarding plus the settings fields the user can edit later.
class Profile {
  final String userId;

  /// From `display_name`. The column exists in the schema but no app flow
  /// writes it yet, so this is null for most users — callers must fall
  /// back (e.g. to the avatar character's name). Never fabricate a name.
  final String? displayName;

  final DateTime dateOfBirth;
  final Gender gender;
  final List<Gender> seeking;
  final RelationshipIntent relationshipIntent;
  final int seekingAgeMin;
  final int seekingAgeMax;

  /// PEARMO personality trait scores (1.0-5.0, averaged from the Likert
  /// questionnaire answers at onboarding) — used by `score_compatibility`,
  /// never shown to other users.
  final double traitExtraversion;
  final double traitAgreeableness;
  final double traitConscientiousness;
  final double traitEmotionalStability;
  final double traitOpenness;
  final double traitAttachmentSecurity;

  final List<PartnerValue> partnerValues;
  final List<MusicGenre> musicGenres;
  final String aboutText;
  final String avatarId;
  final String countryCode;
  final String? regionName;
  final bool onboardingComplete;
  final bool isPhotoPublic;
  final String? activeHoursStart;
  final String? activeHoursEnd;
  final bool hideFromContacts;
  final String? profilePhotoUrl;
  final String? audioIntroUrl;

  /// Whether the profile is currently visible to new matches. Users can
  /// pause this themselves (reversible — unlike account deletion) without
  /// losing any data.
  final bool isProfileActive;

  const Profile({
    required this.userId,
    this.displayName,
    required this.dateOfBirth,
    required this.gender,
    required this.seeking,
    required this.relationshipIntent,
    required this.seekingAgeMin,
    required this.seekingAgeMax,
    required this.traitExtraversion,
    required this.traitAgreeableness,
    required this.traitConscientiousness,
    required this.traitEmotionalStability,
    required this.traitOpenness,
    required this.traitAttachmentSecurity,
    required this.partnerValues,
    required this.musicGenres,
    required this.aboutText,
    required this.avatarId,
    required this.countryCode,
    this.regionName,
    this.onboardingComplete = false,
    this.isPhotoPublic = false,
    this.activeHoursStart,
    this.activeHoursEnd,
    this.hideFromContacts = false,
    this.profilePhotoUrl,
    this.audioIntroUrl,
    this.isProfileActive = true,
  });

  int get age {
    final now = DateTime.now();
    var age = now.year - dateOfBirth.year;
    if (now.month < dateOfBirth.month ||
        (now.month == dateOfBirth.month && now.day < dateOfBirth.day)) {
      age--;
    }
    return age;
  }

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      userId: json['user_id'] as String,
      displayName: json['display_name'] as String?,
      dateOfBirth: DateTime.parse(json['date_of_birth'] as String),
      gender: Gender.fromDb(json['gender'] as String),
      seeking: ((json['seeking'] as List?) ?? const [])
          .map((e) => Gender.fromDb(e as String))
          .toList(),
      relationshipIntent: RelationshipIntent.fromDb(json['relationship_intent'] as String),
      seekingAgeMin: json['seeking_age_min'] as int? ?? 18,
      seekingAgeMax: json['seeking_age_max'] as int? ?? 99,
      traitExtraversion: (json['trait_extraversion'] as num?)?.toDouble() ?? 3.0,
      traitAgreeableness: (json['trait_agreeableness'] as num?)?.toDouble() ?? 3.0,
      traitConscientiousness: (json['trait_conscientiousness'] as num?)?.toDouble() ?? 3.0,
      traitEmotionalStability: (json['trait_emotional_stability'] as num?)?.toDouble() ?? 3.0,
      traitOpenness: (json['trait_openness'] as num?)?.toDouble() ?? 3.0,
      traitAttachmentSecurity: (json['trait_attachment_security'] as num?)?.toDouble() ?? 3.0,
      partnerValues: ((json['partner_values'] as List?) ?? const [])
          .map((e) => PartnerValue.fromDb(e as String))
          .toList(),
      musicGenres: ((json['music_genres'] as List?) ?? const [])
          .map((e) => MusicGenre.fromDb(e as String))
          .toList(),
      aboutText: json['about_text'] as String? ?? '',
      avatarId: json['avatar_id'] as String? ?? 'av_001',
      countryCode: json['country_code'] as String? ?? 'LK',
      regionName: json['region_name'] as String?,
      onboardingComplete: json['onboarding_complete'] as bool? ?? false,
      isPhotoPublic: json['is_photo_public'] as bool? ?? false,
      activeHoursStart: json['active_hours_start'] as String?,
      activeHoursEnd: json['active_hours_end'] as String?,
      hideFromContacts: json['hide_from_contacts'] as bool? ?? false,
      profilePhotoUrl: json['profile_photo_url'] as String?,
      audioIntroUrl: json['audio_intro_url'] as String?,
      isProfileActive: json['is_profile_active'] as bool? ?? true,
    );
  }

  /// Used for the initial onboarding insert.
  Map<String, dynamic> toInsertJson() => {
        'user_id': userId,
        // Explicitly reset, not omitted — a previously-deleted identity's
        // `display_name` was set to 'Deleted user' by `delete-account`, and
        // no onboarding step collects a real one yet (see the field doc
        // above), so a fresh/re-onboarding submission should clear it back
        // to null rather than silently inheriting that placeholder forever.
        'display_name': null,
        'date_of_birth':
            '${dateOfBirth.year.toString().padLeft(4, '0')}-${dateOfBirth.month.toString().padLeft(2, '0')}-${dateOfBirth.day.toString().padLeft(2, '0')}',
        'gender': gender.dbValue,
        'seeking': seeking.map((e) => e.dbValue).toList(),
        'relationship_intent': relationshipIntent.dbValue,
        'seeking_age_min': seekingAgeMin,
        'seeking_age_max': seekingAgeMax,
        'trait_extraversion': traitExtraversion,
        'trait_agreeableness': traitAgreeableness,
        'trait_conscientiousness': traitConscientiousness,
        'trait_emotional_stability': traitEmotionalStability,
        'trait_openness': traitOpenness,
        'trait_attachment_security': traitAttachmentSecurity,
        'partner_values': partnerValues.map((e) => e.dbValue).toList(),
        'music_genres': musicGenres.map((e) => e.dbValue).toList(),
        'about_text': aboutText,
        'avatar_id': avatarId,
        'country_code': countryCode,
        'region_name': regionName,
        'onboarding_complete': onboardingComplete,
        // Explicitly reset on every onboarding submission, not just left to
        // the column default — matters for a previously-deleted identity
        // re-onboarding, since `delete-account` sets both of these to hide
        // the old profile. Without resetting them here, a re-onboarded
        // profile would silently stay invisible until a manual Settings
        // change.
        'is_profile_active': true,
        'hide_from_contacts': false,
      };

  Profile copyWith({
    bool? isPhotoPublic,
    String? activeHoursStart,
    String? activeHoursEnd,
    bool? hideFromContacts,
    String? regionName,
    String? countryCode,
    String? profilePhotoUrl,
    String? audioIntroUrl,
  }) {
    return Profile(
      userId: userId,
      displayName: displayName,
      dateOfBirth: dateOfBirth,
      gender: gender,
      seeking: seeking,
      relationshipIntent: relationshipIntent,
      seekingAgeMin: seekingAgeMin,
      seekingAgeMax: seekingAgeMax,
      traitExtraversion: traitExtraversion,
      traitAgreeableness: traitAgreeableness,
      traitConscientiousness: traitConscientiousness,
      traitEmotionalStability: traitEmotionalStability,
      traitOpenness: traitOpenness,
      traitAttachmentSecurity: traitAttachmentSecurity,
      partnerValues: partnerValues,
      musicGenres: musicGenres,
      aboutText: aboutText,
      avatarId: avatarId,
      countryCode: countryCode ?? this.countryCode,
      regionName: regionName ?? this.regionName,
      onboardingComplete: onboardingComplete,
      isPhotoPublic: isPhotoPublic ?? this.isPhotoPublic,
      activeHoursStart: activeHoursStart ?? this.activeHoursStart,
      activeHoursEnd: activeHoursEnd ?? this.activeHoursEnd,
      hideFromContacts: hideFromContacts ?? this.hideFromContacts,
      profilePhotoUrl: profilePhotoUrl ?? this.profilePhotoUrl,
      audioIntroUrl: audioIntroUrl ?? this.audioIntroUrl,
    );
  }
}
