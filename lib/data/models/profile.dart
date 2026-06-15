import '../../core/constants/enums.dart';

/// The signed-in user's own row in `profiles`. Contains everything from
/// onboarding plus the settings fields the user can edit later.
class Profile {
  final String userId;
  final DateTime dateOfBirth;
  final Gender gender;
  final List<Gender> seeking;
  final RelationshipIntent relationshipIntent;
  final LifeStage lifeStage;
  final EnergyType energyType;
  final ConflictStyle conflictStyle;
  final LifestylePace lifestylePace;
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

  const Profile({
    required this.userId,
    required this.dateOfBirth,
    required this.gender,
    required this.seeking,
    required this.relationshipIntent,
    required this.lifeStage,
    required this.energyType,
    required this.conflictStyle,
    required this.lifestylePace,
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
      dateOfBirth: DateTime.parse(json['date_of_birth'] as String),
      gender: Gender.fromDb(json['gender'] as String),
      seeking: ((json['seeking'] as List?) ?? const [])
          .map((e) => Gender.fromDb(e as String))
          .toList(),
      relationshipIntent: RelationshipIntent.fromDb(json['relationship_intent'] as String),
      lifeStage: LifeStage.fromDb(json['life_stage'] as String),
      energyType: EnergyType.fromDb(json['energy_type'] as String),
      conflictStyle: ConflictStyle.fromDb(json['conflict_style'] as String),
      lifestylePace: LifestylePace.fromDb(json['lifestyle_pace'] as String),
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
    );
  }

  /// Used for the initial onboarding insert.
  Map<String, dynamic> toInsertJson() => {
        'user_id': userId,
        'date_of_birth':
            '${dateOfBirth.year.toString().padLeft(4, '0')}-${dateOfBirth.month.toString().padLeft(2, '0')}-${dateOfBirth.day.toString().padLeft(2, '0')}',
        'gender': gender.dbValue,
        'seeking': seeking.map((e) => e.dbValue).toList(),
        'relationship_intent': relationshipIntent.dbValue,
        'life_stage': lifeStage.dbValue,
        'energy_type': energyType.dbValue,
        'conflict_style': conflictStyle.dbValue,
        'lifestyle_pace': lifestylePace.dbValue,
        'partner_values': partnerValues.map((e) => e.dbValue).toList(),
        'music_genres': musicGenres.map((e) => e.dbValue).toList(),
        'about_text': aboutText,
        'avatar_id': avatarId,
        'country_code': countryCode,
        'region_name': regionName,
        'onboarding_complete': onboardingComplete,
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
      dateOfBirth: dateOfBirth,
      gender: gender,
      seeking: seeking,
      relationshipIntent: relationshipIntent,
      lifeStage: lifeStage,
      energyType: energyType,
      conflictStyle: conflictStyle,
      lifestylePace: lifestylePace,
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
