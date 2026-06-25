// Dart enums mirroring the Postgres check-constraint value lists documented
// in the backend handoff. Each enum exposes `dbValue` (the exact string
// stored in Supabase) and a `fromDb` factory for parsing rows back.

/// Gender identity options, used for both `gender` and entries inside
/// the `seeking` array on `profiles`.
enum Gender {
  man,
  woman,
  nonBinary,
  preferNotToSay,
  other;

  String get dbValue => switch (this) {
        Gender.man => 'man',
        Gender.woman => 'woman',
        Gender.nonBinary => 'non_binary',
        Gender.preferNotToSay => 'prefer_not_to_say',
        Gender.other => 'other',
      };

  String get label => switch (this) {
        Gender.man => 'Man',
        Gender.woman => 'Woman',
        Gender.nonBinary => 'Non-binary',
        Gender.preferNotToSay => 'Prefer not to say',
        Gender.other => 'Other',
      };

  static Gender fromDb(String value) =>
      Gender.values.firstWhere((e) => e.dbValue == value, orElse: () => Gender.other);
}

/// What kind of relationship the user is looking for.
enum RelationshipIntent {
  serious,
  openToSee,
  companionship;

  String get dbValue => switch (this) {
        RelationshipIntent.serious => 'serious',
        RelationshipIntent.openToSee => 'open_to_see',
        RelationshipIntent.companionship => 'companionship',
      };

  String get label => switch (this) {
        RelationshipIntent.serious => 'Looking for something serious',
        RelationshipIntent.openToSee => 'Open to see where it goes',
        RelationshipIntent.companionship => 'Looking for companionship',
      };

  static RelationshipIntent fromDb(String value) => RelationshipIntent.values
      .firstWhere((e) => e.dbValue == value, orElse: () => RelationshipIntent.openToSee);
}

/// Where the user currently is in life.
enum LifeStage {
  figuringOut,
  buildingPath,
  fairlySettled,
  established;

  String get dbValue => switch (this) {
        LifeStage.figuringOut => 'figuring_out',
        LifeStage.buildingPath => 'building_path',
        LifeStage.fairlySettled => 'fairly_settled',
        LifeStage.established => 'established',
      };

  String get label => switch (this) {
        LifeStage.figuringOut => 'Still figuring things out',
        LifeStage.buildingPath => 'Building my path',
        LifeStage.fairlySettled => 'Fairly settled',
        LifeStage.established => 'Established',
      };

  static LifeStage fromDb(String value) => LifeStage.values
      .firstWhere((e) => e.dbValue == value, orElse: () => LifeStage.buildingPath);
}

/// How a user recharges socially.
enum EnergyType {
  introvert,
  ambivert,
  extrovert;

  String get dbValue => switch (this) {
        EnergyType.introvert => 'introvert',
        EnergyType.ambivert => 'ambivert',
        EnergyType.extrovert => 'extrovert',
      };

  String get label => switch (this) {
        EnergyType.introvert => 'Introvert',
        EnergyType.ambivert => 'Ambivert',
        EnergyType.extrovert => 'Extrovert',
      };

  static EnergyType fromDb(String value) => EnergyType.values
      .firstWhere((e) => e.dbValue == value, orElse: () => EnergyType.ambivert);
}

/// How a user tends to handle conflict.
enum ConflictStyle {
  talkImmediately,
  timeThenTalk,
  letItPass,
  stillFiguring;

  String get dbValue => switch (this) {
        ConflictStyle.talkImmediately => 'talk_immediately',
        ConflictStyle.timeThenTalk => 'time_then_talk',
        ConflictStyle.letItPass => 'let_it_pass',
        ConflictStyle.stillFiguring => 'still_figuring',
      };

  String get label => switch (this) {
        ConflictStyle.talkImmediately => 'Talk it through immediately',
        ConflictStyle.timeThenTalk => 'Take time, then talk',
        ConflictStyle.letItPass => 'Let it pass',
        ConflictStyle.stillFiguring => 'Still figuring this out',
      };

  static ConflictStyle fromDb(String value) => ConflictStyle.values
      .firstWhere((e) => e.dbValue == value, orElse: () => ConflictStyle.stillFiguring);
}

/// General pace of life.
enum LifestylePace {
  slowIntentional,
  balanced,
  fastDriven;

  String get dbValue => switch (this) {
        LifestylePace.slowIntentional => 'slow_intentional',
        LifestylePace.balanced => 'balanced',
        LifestylePace.fastDriven => 'fast_driven',
      };

  String get label => switch (this) {
        LifestylePace.slowIntentional => 'Slow & intentional',
        LifestylePace.balanced => 'Balanced',
        LifestylePace.fastDriven => 'Fast & driven',
      };

  static LifestylePace fromDb(String value) => LifestylePace.values
      .firstWhere((e) => e.dbValue == value, orElse: () => LifestylePace.balanced);
}

/// Traits a user values most in a partner. Onboarding allows picking a
/// maximum of 2.
enum PartnerValue {
  emotionalDepth,
  humour,
  ambition,
  kindness,
  loyalty,
  intelligence,
  adventure,
  stability,
  independence,
  familyOriented;

  String get dbValue => switch (this) {
        PartnerValue.emotionalDepth => 'emotional_depth',
        PartnerValue.humour => 'humour',
        PartnerValue.ambition => 'ambition',
        PartnerValue.kindness => 'kindness',
        PartnerValue.loyalty => 'loyalty',
        PartnerValue.intelligence => 'intelligence',
        PartnerValue.adventure => 'adventure',
        PartnerValue.stability => 'stability',
        PartnerValue.independence => 'independence',
        PartnerValue.familyOriented => 'family_oriented',
      };

  String get label => switch (this) {
        PartnerValue.emotionalDepth => 'Emotional depth',
        PartnerValue.humour => 'Humour',
        PartnerValue.ambition => 'Ambition',
        PartnerValue.kindness => 'Kindness',
        PartnerValue.loyalty => 'Loyalty',
        PartnerValue.intelligence => 'Intelligence',
        PartnerValue.adventure => 'Adventure',
        PartnerValue.stability => 'Stability',
        PartnerValue.independence => 'Independence',
        PartnerValue.familyOriented => 'Family-oriented',
      };

  static PartnerValue fromDb(String value) => PartnerValue.values
      .firstWhere((e) => e.dbValue == value, orElse: () => PartnerValue.kindness);
}

/// Music genre preferences shown in onboarding & profile.
enum MusicGenre {
  pop,
  rock,
  hipHop,
  indie,
  electronic,
  classical,
  jazz,
  rnb,
  country,
  metal,
  kpop,
  reggae;

  String get dbValue => switch (this) {
        MusicGenre.pop => 'pop',
        MusicGenre.rock => 'rock',
        MusicGenre.hipHop => 'hip_hop',
        MusicGenre.indie => 'indie',
        MusicGenre.electronic => 'electronic',
        MusicGenre.classical => 'classical',
        MusicGenre.jazz => 'jazz',
        MusicGenre.rnb => 'rnb',
        MusicGenre.country => 'country',
        MusicGenre.metal => 'metal',
        MusicGenre.kpop => 'kpop',
        MusicGenre.reggae => 'reggae',
      };

  String get label => switch (this) {
        MusicGenre.pop => 'Pop',
        MusicGenre.rock => 'Rock',
        MusicGenre.hipHop => 'Hip-Hop',
        MusicGenre.indie => 'Indie',
        MusicGenre.electronic => 'Electronic',
        MusicGenre.classical => 'Classical',
        MusicGenre.jazz => 'Jazz',
        MusicGenre.rnb => 'R&B',
        MusicGenre.country => 'Country',
        MusicGenre.metal => 'Metal',
        MusicGenre.kpop => 'K-Pop',
        MusicGenre.reggae => 'Reggae',
      };

  static MusicGenre fromDb(String value) => MusicGenre.values
      .firstWhere((e) => e.dbValue == value, orElse: () => MusicGenre.pop);
}

/// Lifecycle stage of a `connections` row.
enum ConnectionStatus {
  pending,
  accepted,
  iceBreaking,
  limitedChat,
  openChat,
  mediaUnlocked,
  datePlanned,
  ended;

  String get dbValue => switch (this) {
        ConnectionStatus.pending => 'pending',
        ConnectionStatus.accepted => 'accepted',
        ConnectionStatus.iceBreaking => 'ice_breaking',
        ConnectionStatus.limitedChat => 'limited_chat',
        ConnectionStatus.openChat => 'open_chat',
        ConnectionStatus.mediaUnlocked => 'media_unlocked',
        ConnectionStatus.datePlanned => 'date_planned',
        ConnectionStatus.ended => 'ended',
      };

  String get label => switch (this) {
        ConnectionStatus.pending => 'Waiting for response',
        ConnectionStatus.accepted => 'Accepted — break the ice!',
        ConnectionStatus.iceBreaking => 'Breaking the ice',
        ConnectionStatus.limitedChat => 'Limited chat',
        ConnectionStatus.openChat => 'Open chat',
        ConnectionStatus.mediaUnlocked => 'Media unlocked',
        ConnectionStatus.datePlanned => 'Date planned',
        ConnectionStatus.ended => 'Ended',
      };

  /// Whether messages can be sent at all while in this status.
  bool get canChat =>
      this == ConnectionStatus.limitedChat ||
      this == ConnectionStatus.openChat ||
      this == ConnectionStatus.mediaUnlocked ||
      this == ConnectionStatus.datePlanned;

  static ConnectionStatus fromDb(String value) => ConnectionStatus.values
      .firstWhere((e) => e.dbValue == value, orElse: () => ConnectionStatus.pending);
}

/// The 6 progressive-unlock consent categories.
enum ConsentType {
  chatUnlock,
  mediaShare,
  voiceCall,
  videoCall,
  locationShare,
  giftAddress;

  String get dbValue => switch (this) {
        ConsentType.chatUnlock => 'chat_unlock',
        ConsentType.mediaShare => 'media_share',
        ConsentType.voiceCall => 'voice_call',
        ConsentType.videoCall => 'video_call',
        ConsentType.locationShare => 'location_share',
        ConsentType.giftAddress => 'gift_address',
      };

  String get label => switch (this) {
        ConsentType.chatUnlock => 'Open chat',
        ConsentType.mediaShare => 'Share photos & videos',
        ConsentType.voiceCall => 'Voice calls',
        ConsentType.videoCall => 'Video calls',
        ConsentType.locationShare => 'Share location',
        ConsentType.giftAddress => 'Gift delivery address',
      };

  String get description => switch (this) {
        ConsentType.chatUnlock => 'Unlocks the full chat between you both.',
        ConsentType.mediaShare => 'Allows sending photos and videos in chat.',
        ConsentType.voiceCall => 'Allows starting voice calls.',
        ConsentType.videoCall => 'Allows starting video calls.',
        ConsentType.locationShare => 'Shares a general location with each other.',
        ConsentType.giftAddress => 'Allows a gift to be delivered to you anonymously.',
      };

  static ConsentType fromDb(String value) => ConsentType.values
      .firstWhere((e) => e.dbValue == value, orElse: () => ConsentType.chatUnlock);
}

/// Reasons a user can be reported for.
enum ReportCategory {
  harassment,
  fakeProfile,
  inappropriateContent,
  unsolicitedImage,
  threateningBehaviour,
  other;

  String get dbValue => switch (this) {
        ReportCategory.harassment => 'harassment',
        ReportCategory.fakeProfile => 'fake_profile',
        ReportCategory.inappropriateContent => 'inappropriate_content',
        ReportCategory.unsolicitedImage => 'unsolicited_image',
        ReportCategory.threateningBehaviour => 'threatening_behaviour',
        ReportCategory.other => 'other',
      };

  String get label => switch (this) {
        ReportCategory.harassment => 'Harassment',
        ReportCategory.fakeProfile => 'Fake profile',
        ReportCategory.inappropriateContent => 'Inappropriate content',
        ReportCategory.unsolicitedImage => 'Unsolicited image',
        ReportCategory.threateningBehaviour => 'Threatening behaviour',
        ReportCategory.other => 'Other',
      };

  static ReportCategory fromDb(String value) => ReportCategory.values
      .firstWhere((e) => e.dbValue == value, orElse: () => ReportCategory.other);
}

/// Identity verification level, drives match visibility.
///
/// Tiered: `unverified` -> `selfieVerified` (liveliness check + selfie,
/// manually reviewed — confirms the user is a real person) ->
/// `idVerified` (also submitted a NIC, manually compared against the
/// profile's displayed age — confirms age) -> `paidVerified` (unrelated
/// payment tier, untouched by the verification flow).
enum VerificationTier {
  unverified,
  selfieVerified,
  idVerified,
  paidVerified;

  String get dbValue => switch (this) {
        VerificationTier.unverified => 'unverified',
        VerificationTier.selfieVerified => 'selfie_verified',
        VerificationTier.idVerified => 'id_verified',
        VerificationTier.paidVerified => 'paid_verified',
      };

  String get label => switch (this) {
        VerificationTier.unverified => 'Unverified',
        VerificationTier.selfieVerified => 'Selfie verified',
        VerificationTier.idVerified => 'Age verified',
        VerificationTier.paidVerified => 'Verified Plus',
      };

  /// Whether this tier has cleared the liveliness + selfie check — gates
  /// features like adding a public profile photo.
  bool get isAtLeastSelfieVerified => index >= VerificationTier.selfieVerified.index;

  static VerificationTier fromDb(String value) => VerificationTier.values
      .firstWhere((e) => e.dbValue == value, orElse: () => VerificationTier.unverified);
}

/// Ice-breaker game types. `prompts` is used to implement the "20
/// Questions" style turn-based Q&A game described in the brainstorm doc.
enum GameType {
  wouldYouRather,
  drawTogether,
  trivia,
  prompts;

  String get dbValue => switch (this) {
        GameType.wouldYouRather => 'would_you_rather',
        GameType.drawTogether => 'draw_together',
        GameType.trivia => 'trivia',
        GameType.prompts => 'prompts',
      };

  String get label => switch (this) {
        GameType.wouldYouRather => 'Would You Rather',
        GameType.drawTogether => 'Draw Together',
        GameType.trivia => 'Trivia',
        GameType.prompts => '20 Questions',
      };

  String get emoji => switch (this) {
        GameType.wouldYouRather => '🤔',
        GameType.drawTogether => '🎨',
        GameType.trivia => '🧠',
        GameType.prompts => '💬',
      };

  static GameType fromDb(String value) => GameType.values
      .firstWhere((e) => e.dbValue == value, orElse: () => GameType.prompts);
}

/// Why a connection ended.
enum EndReason {
  unilateral,
  mutual,
  reported,
  inactivity;

  String get dbValue => switch (this) {
        EndReason.unilateral => 'unilateral',
        EndReason.mutual => 'mutual',
        EndReason.reported => 'reported',
        EndReason.inactivity => 'inactivity',
      };

  static EndReason fromDb(String value) => EndReason.values
      .firstWhere((e) => e.dbValue == value, orElse: () => EndReason.unilateral);
}
