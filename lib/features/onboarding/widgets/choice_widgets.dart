import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';

/// A single tappable option in a [SingleChoiceList].
class ChoiceOption<T> {
  const ChoiceOption(this.value, this.label, {this.description});

  final T value;
  final String label;
  final String? description;
}

/// Vertical list of mutually-exclusive options, used for single-answer
/// onboarding questions (gender, relationship intent, life stage, etc).
class SingleChoiceList<T> extends StatelessWidget {
  const SingleChoiceList({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  final List<ChoiceOption<T>> options;
  final T? selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: options.map((option) {
        final isSelected = option.value == selected;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            onTap: () => onChanged(option.value),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primaryLight : AppColors.surfaceMuted,
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                border: Border.all(
                  color: isSelected ? AppColors.primary : Colors.transparent,
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(option.label, style: AppTextStyles.bodyMedium),
                        if (option.description != null) ...[
                          const SizedBox(height: 4),
                          Text(option.description!, style: AppTextStyles.caption),
                        ],
                      ],
                    ),
                  ),
                  Icon(
                    isSelected ? Icons.check_circle : Icons.circle_outlined,
                    color: isSelected ? AppColors.primary : AppColors.textSecondary,
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

/// Wrapped choice chips for multi-select onboarding questions (seeking,
/// partner values, music genres). If [maxSelections] is set and reached,
/// unselected chips are visually disabled.
class MultiChoiceChips<T> extends StatelessWidget {
  const MultiChoiceChips({
    super.key,
    required this.options,
    required this.selected,
    required this.onToggle,
    this.maxSelections,
  });

  final List<ChoiceOption<T>> options;
  final Set<T> selected;
  final ValueChanged<T> onToggle;
  final int? maxSelections;

  @override
  Widget build(BuildContext context) {
    final reachedMax = maxSelections != null && selected.length >= maxSelections!;
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: options.map((option) {
        final isSelected = selected.contains(option.value);
        final disabled = !isSelected && reachedMax;
        return ChoiceChip(
          label: Text(option.label),
          selected: isSelected,
          onSelected: disabled ? null : (_) => onToggle(option.value),
          labelStyle: AppTextStyles.bodyMedium.copyWith(
            color: isSelected
                ? AppColors.primaryDark
                : disabled
                    ? AppColors.textSecondary.withValues(alpha: 0.5)
                    : AppColors.textPrimary,
          ),
        );
      }).toList(),
    );
  }
}
