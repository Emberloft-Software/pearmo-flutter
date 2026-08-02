import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/enums.dart';
import '../../../data/models/profile.dart';
import '../../../providers/auth_providers.dart';
import '../../../providers/profile_providers.dart';
import '../../../providers/repository_providers.dart';
import '../data/personality_questions.dart';
import '../models/onboarding_draft.dart';

final onboardingControllerProvider =
    NotifierProvider<OnboardingController, OnboardingDraft>(OnboardingController.new);

class OnboardingController extends Notifier<OnboardingDraft> {
  @override
  OnboardingDraft build() => OnboardingDraft();

  void setDateOfBirth(DateTime value) => state = state.clone()..dateOfBirth = value;

  void setGender(Gender value) => state = state.clone()..gender = value;

  void toggleSeeking(Gender value) {
    final draft = state.clone();
    if (draft.seeking.contains(value)) {
      draft.seeking.remove(value);
    } else {
      draft.seeking.add(value);
    }
    state = draft;
  }

  void setRelationshipIntent(RelationshipIntent value) =>
      state = state.clone()..relationshipIntent = value;

  void answerPersonalityQuestion(String questionId, int value) {
    final draft = state.clone();
    draft.personalityAnswers[questionId] = value;
    state = draft;
  }

  void setSeekingAgeRange(int min, int max) {
    final draft = state.clone();
    draft.seekingAgeMin = min;
    draft.seekingAgeMax = max;
    state = draft;
  }

  /// Enforces the max-2 limit on partner values.
  void togglePartnerValue(PartnerValue value, {required int max}) {
    final draft = state.clone();
    if (draft.partnerValues.contains(value)) {
      draft.partnerValues.remove(value);
    } else if (draft.partnerValues.length < max) {
      draft.partnerValues.add(value);
    }
    state = draft;
  }

  void toggleMusicGenre(MusicGenre value) {
    final draft = state.clone();
    if (draft.musicGenres.contains(value)) {
      draft.musicGenres.remove(value);
    } else {
      draft.musicGenres.add(value);
    }
    state = draft;
  }

  void setAboutText(String value) => state = state.clone()..aboutText = value;

  void setAvatarId(String value) => state = state.clone()..avatarId = value;

  void setRegion(String value) => state = state.clone()..regionName = value;

  void setAudioIntroLocalPath(String? path) => state = state.clone()..audioIntroLocalPath = path;

  /// Saves the profile, uploads the audio intro (if recorded), and triggers
  /// the sentiment-analysis edge function — per the handoff doc's
  /// onboarding sequence. Returns a non-null warning message if the audio
  /// upload / sentiment pass failed after the profile itself was saved
  /// (still returns normally in that case, since those are best-effort
  /// follow-ups, not required onboarding steps — retrying them shouldn't be
  /// the only way out of the onboarding screen).
  Future<String?> submit() async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) {
      throw StateError('No authenticated user');
    }
    final draft = state;

    if (draft.dateOfBirth == null ||
        draft.gender == null ||
        draft.seeking.isEmpty ||
        draft.relationshipIntent == null ||
        draft.seekingAgeMin == null ||
        draft.seekingAgeMax == null ||
        draft.partnerValues.isEmpty ||
        draft.musicGenres.isEmpty ||
        draft.aboutText.trim().isEmpty ||
        PersonalityQuestions.all.any((q) => !draft.personalityAnswers.containsKey(q.id))) {
      throw StateError('Please answer every question before continuing');
    }

    final traitScores = PersonalityQuestions.computeTraitScores(draft.personalityAnswers);

    final profile = Profile(
      userId: userId,
      dateOfBirth: draft.dateOfBirth!,
      gender: draft.gender!,
      seeking: draft.seeking.toList(),
      relationshipIntent: draft.relationshipIntent!,
      partnerValues: draft.partnerValues.toList(),
      musicGenres: draft.musicGenres.toList(),
      aboutText: draft.aboutText.trim(),
      avatarId: draft.avatarId,
      countryCode: draft.countryCode,
      regionName: draft.regionName,
      seekingAgeMin: draft.seekingAgeMin!,
      seekingAgeMax: draft.seekingAgeMax!,
      traitExtraversion: traitScores[PersonalityTrait.extraversion]!,
      traitAgreeableness: traitScores[PersonalityTrait.agreeableness]!,
      traitConscientiousness: traitScores[PersonalityTrait.conscientiousness]!,
      traitEmotionalStability: traitScores[PersonalityTrait.emotionalStability]!,
      traitOpenness: traitScores[PersonalityTrait.openness]!,
      traitAttachmentSecurity: traitScores[PersonalityTrait.attachmentSecurity]!,
      onboardingComplete: true,
    );

    // Guards against the `profiles.user_id` FK failing when the session was
    // restored without going through OtpScreen (which is the only other
    // place that creates the `users` row).
    await ref.read(authRepositoryProvider).ensureUserRow();

    final profileRepo = ref.read(profileRepositoryProvider);
    await profileRepo.saveOnboarding(profile);

    // The required profile fields are saved at this point, so onboarding is
    // already complete as far as the router is concerned. Audio upload and
    // the sentiment pass are best-effort — a failure here shouldn't trap the
    // user retrying `submit()` against the same failure indefinitely, since
    // there's no other UI path to add the audio intro later.
    String? warning;
    try {
      if (draft.audioIntroLocalPath != null) {
        final storageRepo = ref.read(storageRepositoryProvider);
        final ext = draft.audioIntroLocalPath!.split('.').last;
        final path = await storageRepo.uploadAudioIntro(
          userId,
          File(draft.audioIntroLocalPath!),
          ext: ext,
        );
        await profileRepo.updateAudioIntroPath(userId, path);
      }
      await profileRepo.runSentimentAnalysis();
    } catch (_) {
      warning = "Your profile was saved, but we couldn't finish uploading your voice intro "
          "or analyzing your profile. This won't stop you from using the app.";
    }

    // Generate the first batch here rather than letting the matches screen
    // do it on first open, so the very first thing a new user sees after 18
    // onboarding steps is populated cards, not "No new matches today —
    // check back tomorrow". Empty-first-session is the single biggest churn
    // moment in the flow.
    //
    // Must run after `saveOnboarding` commits `onboarding_complete = true`
    // (the candidate filters check it), and deliberately sits *outside* the
    // best-effort block above — a failed audio upload or sentiment pass
    // must not cost the user their first batch.
    try {
      await ref.read(matchesRepositoryProvider).refreshMyMatches();
    } catch (_) {
      // Non-fatal: the matches screen retries on every open. Not folded
      // into `warning` either — "we couldn't generate matches" is not
      // actionable for the user, and the retry is invisible and automatic.
    }

    // Refresh so the router moves the user from /onboarding to /home.
    ref.invalidate(myProfileProvider);
    return warning;
  }
}
