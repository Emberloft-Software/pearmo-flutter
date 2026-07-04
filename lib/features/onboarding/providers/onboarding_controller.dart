import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/enums.dart';
import '../../../data/models/profile.dart';
import '../../../providers/auth_providers.dart';
import '../../../providers/profile_providers.dart';
import '../../../providers/repository_providers.dart';
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

  void setLifeStage(LifeStage value) => state = state.clone()..lifeStage = value;

  void setEnergyType(EnergyType value) => state = state.clone()..energyType = value;

  void setConflictStyle(ConflictStyle value) => state = state.clone()..conflictStyle = value;

  void setLifestylePace(LifestylePace value) => state = state.clone()..lifestylePace = value;

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
        draft.lifeStage == null ||
        draft.energyType == null ||
        draft.conflictStyle == null ||
        draft.lifestylePace == null ||
        draft.partnerValues.isEmpty ||
        draft.musicGenres.isEmpty ||
        draft.aboutText.trim().isEmpty) {
      throw StateError('Please answer every question before continuing');
    }

    final profile = Profile(
      userId: userId,
      dateOfBirth: draft.dateOfBirth!,
      gender: draft.gender!,
      seeking: draft.seeking.toList(),
      relationshipIntent: draft.relationshipIntent!,
      lifeStage: draft.lifeStage!,
      energyType: draft.energyType!,
      conflictStyle: draft.conflictStyle!,
      lifestylePace: draft.lifestylePace!,
      partnerValues: draft.partnerValues.toList(),
      musicGenres: draft.musicGenres.toList(),
      aboutText: draft.aboutText.trim(),
      avatarId: draft.avatarId,
      countryCode: draft.countryCode,
      regionName: draft.regionName,
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

    // Refresh so the router moves the user from /onboarding to /home.
    ref.invalidate(myProfileProvider);
    return warning;
  }
}
