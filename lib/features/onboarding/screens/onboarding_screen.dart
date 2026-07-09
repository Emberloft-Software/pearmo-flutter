import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/constants/enums.dart';
import '../../../core/constants/regions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/error_mapper.dart';
import '../../../core/utils/validators.dart';
import '../../../shared/widgets/widgets.dart';
import '../data/personality_questions.dart';
import '../models/onboarding_draft.dart';
import '../providers/onboarding_controller.dart';
import '../widgets/avatar_picker.dart';
import '../widgets/choice_widgets.dart';
import '../widgets/likert_scale.dart';
import '../widgets/onboarding_scaffold.dart';

/// The onboarding flow described in the handoff doc — identity/preferences,
/// the PEARMO personality questionnaire (2 questions per trait), partner
/// preferences, avatar selection, an optional voice intro, and region — all
/// saved in one insert via [OnboardingController.submit].
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pageController = PageController();
  int _step = 0;
  bool _isSubmitting = false;
  String? _error;

  static const int _totalSteps = 18;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goNext() {
    if (_step == _totalSteps - 1) {
      _submit();
      return;
    }
    setState(() => _step++);
    _pageController.nextPage(duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
  }

  void _goBack() {
    if (_step == 0) return;
    setState(() => _step--);
    _pageController.previousPage(duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
  }

  Future<void> _submit() async {
    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    try {
      final warning = await ref.read(onboardingControllerProvider.notifier).submit();
      if (warning != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(warning)));
      }
    } catch (e) {
      setState(() => _error = ErrorMapper.map(e));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(onboardingControllerProvider);
    final controller = ref.read(onboardingControllerProvider.notifier);

    final pages = <_StepDef>[
      _StepDef(
        title: "Let's get to know you",
        subtitle:
            "A few quick questions help ${AppConstants.appName} curate matches who actually fit "
            'how you think and live — no endless swiping.',
        canContinue: true,
        content: const _WelcomeStep(),
      ),
      _StepDef(
        title: 'When were you born?',
        subtitle: 'You must be 18 or older to use Pearmo.',
        canContinue: Validators.dateOfBirthAdult(draft.dateOfBirth) == null,
        content: _DateOfBirthStep(draft: draft, controller: controller),
      ),
      _StepDef(
        title: 'How do you describe your gender?',
        canContinue: draft.gender != null,
        content: SingleChoiceList<Gender>(
          options: Gender.values.map((g) => ChoiceOption(g, g.label)).toList(),
          selected: draft.gender,
          onChanged: controller.setGender,
        ),
      ),
      _StepDef(
        title: "Who are you hoping to meet?",
        subtitle: 'Select all that apply.',
        canContinue: draft.seeking.isNotEmpty,
        content: MultiChoiceChips<Gender>(
          options: Gender.values.map((g) => ChoiceOption(g, g.label)).toList(),
          selected: draft.seeking,
          onToggle: controller.toggleSeeking,
        ),
      ),
      _StepDef(
        title: 'What age range are you open to?',
        canContinue: draft.seekingAgeMin != null && draft.seekingAgeMax != null,
        content: _AgeRangeStep(draft: draft, controller: controller),
      ),
      _StepDef(
        title: "What are you looking for?",
        canContinue: draft.relationshipIntent != null,
        content: SingleChoiceList<RelationshipIntent>(
          options: RelationshipIntent.values.map((e) => ChoiceOption(e, e.label)).toList(),
          selected: draft.relationshipIntent,
          onChanged: controller.setRelationshipIntent,
        ),
      ),
      for (final trait in PersonalityTrait.values)
        _StepDef(
          title: trait.label,
          subtitle: 'Answer honestly — this is private and only used for matching.',
          canContinue: PersonalityQuestions.forTrait(trait)
              .every((q) => draft.personalityAnswers.containsKey(q.id)),
          content: _PersonalityTraitStep(trait: trait, draft: draft, controller: controller),
        ),
      _StepDef(
        title: 'What matters most to you in a partner?',
        subtitle: 'Pick up to ${AppConstants.maxPartnerValues}.',
        canContinue: draft.partnerValues.isNotEmpty,
        content: MultiChoiceChips<PartnerValue>(
          options: PartnerValue.values.map((e) => ChoiceOption(e, e.label)).toList(),
          selected: draft.partnerValues,
          maxSelections: AppConstants.maxPartnerValues,
          onToggle: (v) => controller.togglePartnerValue(v, max: AppConstants.maxPartnerValues),
        ),
      ),
      _StepDef(
        title: 'What do you listen to?',
        subtitle: 'Select all that apply.',
        canContinue: draft.musicGenres.isNotEmpty,
        content: MultiChoiceChips<MusicGenre>(
          options: MusicGenre.values.map((e) => ChoiceOption(e, e.label)).toList(),
          selected: draft.musicGenres,
          onToggle: controller.toggleMusicGenre,
        ),
      ),
      _StepDef(
        title: 'Tell us a bit about yourself',
        subtitle: 'This is what your matches will read first.',
        canContinue: draft.aboutText.trim().isNotEmpty,
        content: _AboutStep(draft: draft, controller: controller),
      ),
      _StepDef(
        title: 'Pick an avatar',
        subtitle: "This is how you'll appear to matches until you choose to share a photo.",
        canContinue: true,
        content: AvatarPicker(selectedId: draft.avatarId, onSelected: controller.setAvatarId),
      ),
      _StepDef(
        title: 'Add a voice intro',
        subtitle: 'Optional — let your personality come through before any photos.',
        canContinue: true,
        content: AudioIntroRecorder(onRecorded: controller.setAudioIntroLocalPath),
      ),
      _StepDef(
        title: 'Where are you based?',
        subtitle:
            "We only show matches your general area — never your exact location, for everyone's privacy and safety.",
        canContinue: draft.regionName != null,
        content: SingleChoiceList<String>(
          options: SriLankaRegions.provinces.map((r) => ChoiceOption(r, r)).toList(),
          selected: draft.regionName,
          onChanged: controller.setRegion,
        ),
      ),
    ];

    final current = pages[_step];

    return OnboardingScaffold(
      step: _step + 1,
      totalSteps: _totalSteps,
      title: current.title,
      subtitle: current.subtitle,
      canContinue: current.canContinue && !_isSubmitting,
      onBack: _step > 0 ? _goBack : null,
      onNext: _goNext,
      isLoading: _isSubmitting,
      nextLabel: _step == _totalSteps - 1 ? "I'm ready — find my matches" : 'Continue',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          current.content,
          if (_error != null) ...[
            const SizedBox(height: 16),
            ErrorBanner(message: _error!),
          ],
        ],
      ),
    );
  }
}

class _StepDef {
  const _StepDef({
    required this.title,
    this.subtitle,
    required this.canContinue,
    required this.content,
  });

  final String title;
  final String? subtitle;
  final bool canContinue;
  final Widget content;
}

class _WelcomeStep extends StatelessWidget {
  const _WelcomeStep();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.favorite, color: AppColors.primaryDark, size: 32),
          const SizedBox(height: 12),
          Text(
            "Your answers are private. They're used to find people who genuinely match your "
            'personality and intentions — not to be shown off in a public bio.',
            style: AppTextStyles.body,
          ),
        ],
      ),
    );
  }
}

class _DateOfBirthStep extends StatelessWidget {
  const _DateOfBirthStep({required this.draft, required this.controller});

  final OnboardingDraft draft;
  final OnboardingController controller;

  @override
  Widget build(BuildContext context) {
    final dob = draft.dateOfBirth;
    final error = Validators.dateOfBirthAdult(dob);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PearmoCard(
          onTap: () async {
            final now = DateTime.now();
            final picked = await showDatePicker(
              context: context,
              initialDate: dob ?? DateTime(now.year - 25, now.month, now.day),
              firstDate: DateTime(now.year - 100),
              lastDate: DateTime(now.year - 18, now.month, now.day),
            );
            if (picked != null) controller.setDateOfBirth(picked);
          },
          child: Row(
            children: [
              const Icon(Icons.cake_outlined, color: AppColors.primary),
              const SizedBox(width: 12),
              Text(
                dob == null
                    ? 'Select date of birth'
                    : '${dob.year}-${dob.month.toString().padLeft(2, '0')}-${dob.day.toString().padLeft(2, '0')}',
                style: AppTextStyles.bodyMedium,
              ),
            ],
          ),
        ),
        if (dob != null && error != null) ...[
          const SizedBox(height: 12),
          ErrorBanner(message: error),
        ],
      ],
    );
  }
}

class _AgeRangeStep extends StatefulWidget {
  const _AgeRangeStep({required this.draft, required this.controller});

  final OnboardingDraft draft;
  final OnboardingController controller;

  @override
  State<_AgeRangeStep> createState() => _AgeRangeStepState();
}

class _AgeRangeStepState extends State<_AgeRangeStep> {
  static const _minAge = 18;
  static const _maxAge = 70;

  late RangeValues _range;

  @override
  void initState() {
    super.initState();
    final min = widget.draft.seekingAgeMin;
    final max = widget.draft.seekingAgeMax;
    if (min != null && max != null) {
      _range = RangeValues(min.toDouble(), max.toDouble());
    } else {
      // Sensible starting point based on the user's own age, if known.
      final ownAge = widget.draft.dateOfBirth == null
          ? 25
          : DateTime.now().year - widget.draft.dateOfBirth!.year;
      final defaultMin = (ownAge - 8).clamp(_minAge, _maxAge);
      final defaultMax = (ownAge + 10).clamp(_minAge, _maxAge);
      _range = RangeValues(defaultMin.toDouble(), defaultMax.toDouble());
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.controller.setSeekingAgeRange(defaultMin, defaultMax);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${_range.start.round()} – ${_range.end.round()}',
          style: AppTextStyles.headline,
        ),
        RangeSlider(
          values: _range,
          min: _minAge.toDouble(),
          max: _maxAge.toDouble(),
          divisions: _maxAge - _minAge,
          labels: RangeLabels('${_range.start.round()}', '${_range.end.round()}'),
          onChanged: (value) {
            setState(() => _range = value);
            widget.controller.setSeekingAgeRange(value.start.round(), value.end.round());
          },
        ),
      ],
    );
  }
}

class _PersonalityTraitStep extends StatelessWidget {
  const _PersonalityTraitStep({
    required this.trait,
    required this.draft,
    required this.controller,
  });

  final PersonalityTrait trait;
  final OnboardingDraft draft;
  final OnboardingController controller;

  @override
  Widget build(BuildContext context) {
    final questions = PersonalityQuestions.forTrait(trait);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final question in questions) ...[
          LikertQuestion(
            text: question.text,
            value: draft.personalityAnswers[question.id],
            onChanged: (value) => controller.answerPersonalityQuestion(question.id, value),
          ),
          const SizedBox(height: 16),
        ],
      ],
    );
  }
}

class _AboutStep extends StatefulWidget {
  const _AboutStep({required this.draft, required this.controller});

  final OnboardingDraft draft;
  final OnboardingController controller;

  @override
  State<_AboutStep> createState() => _AboutStepState();
}

class _AboutStepState extends State<_AboutStep> {
  late final TextEditingController _textController;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.draft.aboutText);
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _textController,
      maxLines: 6,
      maxLength: AppConstants.aboutMaxLength,
      decoration: const InputDecoration(
        hintText: 'I love deep conversations about...',
        alignLabelWithHint: true,
      ),
      onChanged: widget.controller.setAboutText,
    );
  }
}
