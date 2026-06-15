import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/widgets.dart';

/// Shared layout for every onboarding step: progress bar, title/subtitle,
/// scrollable content, and a Next button that's disabled until [canContinue].
class OnboardingScaffold extends StatelessWidget {
  const OnboardingScaffold({
    super.key,
    required this.step,
    required this.totalSteps,
    required this.title,
    this.subtitle,
    required this.child,
    required this.onNext,
    this.onBack,
    this.canContinue = true,
    this.nextLabel = 'Continue',
    this.isLoading = false,
  });

  final int step;
  final int totalSteps;
  final String title;
  final String? subtitle;
  final Widget child;
  final VoidCallback? onNext;
  final VoidCallback? onBack;
  final bool canContinue;
  final String nextLabel;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: onBack != null
            ? IconButton(icon: const Icon(Icons.arrow_back), onPressed: onBack)
            : null,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: step / totalSteps,
                  minHeight: 8,
                  backgroundColor: AppColors.surfaceMuted,
                  color: AppColors.primary,
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTextStyles.headline),
                    if (subtitle != null) ...[
                      const SizedBox(height: 8),
                      Text(subtitle!,
                          style: AppTextStyles.body.copyWith(color: AppColors.textSecondary)),
                    ],
                    const SizedBox(height: 24),
                    child,
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: PearmoButton(
                label: nextLabel,
                isLoading: isLoading,
                onPressed: canContinue ? onNext : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
