import '../../core/constants/enums.dart';

/// Row from the read-only `public_profiles` view — what one user is allowed
/// to see of a candidate/match. Already filters out banned/inactive users
/// and excludes private info such as exact date of birth.
class PublicProfile {
  final String userId;
  final int age;
  final Gender gender;
  final RelationshipIntent relationshipIntent;
  final LifeStage lifeStage;
  final EnergyType energyType;
  final LifestylePace lifestylePace;
  final List<PartnerValue> partnerValues;
  final List<MusicGenre> musicGenres;
  final String aboutText;
  final String avatarId;
  final String? audioIntroUrl;
  final String? profilePhotoUrl;
  final String? regionName;
  final String countryCode;
  final VerificationTier verificationTier;
  final double? trustScore;

  const PublicProfile({
    required this.userId,
    required this.age,
    required this.gender,
    required this.relationshipIntent,
    required this.lifeStage,
    required this.energyType,
    required this.lifestylePace,
    required this.partnerValues,
    required this.musicGenres,
    required this.aboutText,
    required this.avatarId,
    this.audioIntroUrl,
    this.profilePhotoUrl,
    this.regionName,
    required this.countryCode,
    this.verificationTier = VerificationTier.unverified,
    this.trustScore,
  });

  /// A photo should only ever be shown when the candidate has opted in
  /// AND the backend view actually returned a URL (it returns null when
  /// `is_photo_public` is false). Always fall back to the avatar.
  bool get hasPublicPhoto => profilePhotoUrl != null && profilePhotoUrl!.isNotEmpty;

  factory PublicProfile.fromJson(Map<String, dynamic> json) {
    return PublicProfile(
      userId: json['user_id'] as String,
      age: json['age'] as int? ?? 0,
      gender: Gender.fromDb(json['gender'] as String? ?? 'other'),
      relationshipIntent:
          RelationshipIntent.fromDb(json['relationship_intent'] as String? ?? 'open_to_see'),
      lifeStage: LifeStage.fromDb(json['life_stage'] as String? ?? 'building_path'),
      energyType: EnergyType.fromDb(json['energy_type'] as String? ?? 'ambivert'),
      lifestylePace: LifestylePace.fromDb(json['lifestyle_pace'] as String? ?? 'balanced'),
      partnerValues: ((json['partner_values'] as List?) ?? const [])
          .map((e) => PartnerValue.fromDb(e as String))
          .toList(),
      musicGenres: ((json['music_genres'] as List?) ?? const [])
          .map((e) => MusicGenre.fromDb(e as String))
          .toList(),
      aboutText: json['about_text'] as String? ?? '',
      avatarId: json['avatar_id'] as String? ?? 'av_001',
      audioIntroUrl: json['audio_intro_url'] as String?,
      profilePhotoUrl: json['profile_photo_url'] as String?,
      regionName: json['region_name'] as String?,
      countryCode: json['country_code'] as String? ?? 'LK',
      verificationTier: VerificationTier.fromDb(json['verification_tier'] as String? ?? 'unverified'),
      trustScore: (json['trust_score'] as num?)?.toDouble(),
    );
  }
}
