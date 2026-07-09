import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';

/// A single 5-point Likert statement (Strongly Disagree..Strongly Agree),
/// matching the PEARMO questionnaire's scale.
class LikertQuestion extends StatelessWidget {
  const LikertQuestion({
    super.key,
    required this.text,
    required this.value,
    required this.onChanged,
  });

  final String text;
  final int? value;
  final ValueChanged<int> onChanged;

  static const _labels = ['Strongly disagree', 'Disagree', 'Neutral', 'Agree', 'Strongly agree'];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(text, style: AppTextStyles.bodyMedium),
          const SizedBox(height: 12),
          Row(
            children: List.generate(5, (index) {
              final score = index + 1;
              final isSelected = value == score;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: index < 4 ? 8 : 0),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                    onTap: () => onChanged(score),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primary : AppColors.surface,
                        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                        border: Border.all(
                          color: isSelected ? AppColors.primary : AppColors.divider,
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            '$score',
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: isSelected ? Colors.white : AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_labels.first, style: AppTextStyles.caption),
              Text(_labels.last, style: AppTextStyles.caption),
            ],
          ),
        ],
      ),
    );
  }
}
