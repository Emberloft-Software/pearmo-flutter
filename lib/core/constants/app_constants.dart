/// App-wide constants that don't belong to a specific feature.
class AppConstants {
  AppConstants._();

  static const String appName = 'Pearmo';

  /// Number of selectable avatars at launch (`av_001` .. `av_024`). The
  /// handoff doc notes this set can grow later — `AvatarCatalog` reads
  /// from this single constant so adding more avatars is a one-line change.
  static const int avatarCount = 24;

  /// Max number of partner values a user can pick during onboarding.
  static const int maxPartnerValues = 2;

  /// Max length for the free-text "about" answer (onboarding question 10).
  static const int aboutMaxLength = 600;

  /// Max number of unanswered messages allowed during `limited_chat`.
  static const int limitedChatMessageCap = 5;

  /// Max audio intro duration in seconds.
  static const int audioIntroMaxSeconds = 60;

  /// How many daily match cards are generated per user per day.
  static const int dailyMatchCount = 5;
}
