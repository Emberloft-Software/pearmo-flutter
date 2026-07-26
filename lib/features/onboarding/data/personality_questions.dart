import '../../../core/constants/enums.dart';

/// One Likert statement from the PEARMO questionnaire (see project handoff
/// PDF). `isReverse` statements are scored `6 - answer` before averaging,
/// per the document's scoring instructions.
class PersonalityQuestion {
  const PersonalityQuestion({
    required this.id,
    required this.trait,
    required this.text,
    this.isReverse = false,
  });

  /// Stable id used as the key in `OnboardingDraft.personalityAnswers` —
  /// independent of list order/trait so answers survive reordering.
  final String id;
  final PersonalityTrait trait;
  final String text;
  final bool isReverse;
}

/// 2 questions per trait (12 total) — a shortened form of the source
/// document's 30-question instrument (5 per trait). Trait scores are still
/// just an average of however many items were asked, so this doesn't change
/// the scoring math, only its precision. One direct + one reverse-scored
/// item per trait, preserved from the original set to keep some protection
/// against straight-line answering.
class PersonalityQuestions {
  PersonalityQuestions._();

  static const List<PersonalityQuestion> all = [
    PersonalityQuestion(
      id: 'extraversion_1',
      trait: PersonalityTrait.extraversion,
      text: 'I enjoy meeting new people.',
    ),
    PersonalityQuestion(
      id: 'extraversion_2',
      trait: PersonalityTrait.extraversion,
      text: 'I prefer staying home rather than socializing.',
      isReverse: true,
    ),
    PersonalityQuestion(
      id: 'agreeableness_1',
      trait: PersonalityTrait.agreeableness,
      text: "I try to understand other people's feelings.",
    ),
    PersonalityQuestion(
      id: 'agreeableness_2',
      trait: PersonalityTrait.agreeableness,
      text: 'I often argue with people.',
      isReverse: true,
    ),
    PersonalityQuestion(
      id: 'conscientiousness_1',
      trait: PersonalityTrait.conscientiousness,
      text: 'I usually plan ahead.',
    ),
    PersonalityQuestion(
      id: 'conscientiousness_2',
      trait: PersonalityTrait.conscientiousness,
      text: 'I often leave things unfinished.',
      isReverse: true,
    ),
    PersonalityQuestion(
      id: 'emotional_stability_1',
      trait: PersonalityTrait.emotionalStability,
      text: 'I remain calm under pressure.',
    ),
    PersonalityQuestion(
      id: 'emotional_stability_2',
      trait: PersonalityTrait.emotionalStability,
      text: 'I worry about many things.',
      isReverse: true,
    ),
    PersonalityQuestion(
      id: 'openness_1',
      trait: PersonalityTrait.openness,
      text: 'I enjoy trying new foods or places.',
    ),
    PersonalityQuestion(
      id: 'openness_2',
      trait: PersonalityTrait.openness,
      text: 'I prefer routines over new experiences.',
      isReverse: true,
    ),
    PersonalityQuestion(
      id: 'attachment_security_1',
      trait: PersonalityTrait.attachmentSecurity,
      text: 'I feel comfortable trusting my partner.',
    ),
    PersonalityQuestion(
      id: 'attachment_security_2',
      trait: PersonalityTrait.attachmentSecurity,
      text: 'I fear being abandoned.',
      isReverse: true,
    ),
  ];

  static List<PersonalityQuestion> forTrait(PersonalityTrait trait) =>
      all.where((q) => q.trait == trait).toList();

  /// Averages each trait's answers (reverse-scored items as `6 - answer`
  /// first), per the PEARMO scoring doc. Missing answers default to the
  /// neutral midpoint (3) rather than throwing — used both at final submit
  /// (where every question is already guaranteed answered) and by the
  /// avatar-suggestion step, which only needs a best-effort estimate.
  static Map<PersonalityTrait, double> computeTraitScores(Map<String, int> answers) {
    final scores = <PersonalityTrait, double>{};
    for (final trait in PersonalityTrait.values) {
      final values = forTrait(trait).map((q) {
        final raw = answers[q.id] ?? 3;
        return q.isReverse ? 6 - raw : raw;
      });
      scores[trait] = values.reduce((a, b) => a + b) / values.length;
    }
    return scores;
  }
}
