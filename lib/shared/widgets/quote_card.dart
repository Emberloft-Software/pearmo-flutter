import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

/// Editorial pull-quote card for a user's `about_text` — italic serif with
/// a pink quotation mark (pink = love moments, its only job here).
class QuoteCard extends StatelessWidget {
  const QuoteCard({
    super.key,
    required this.label,
    required this.text,
    required this.emptyPlaceholder,
  });

  final String label;
  final String text;
  final String emptyPlaceholder;

  @override
  Widget build(BuildContext context) {
    final hasText = text.trim().isNotEmpty;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: AppTextStyles.label),
          Text(
            '“',
            style: AppTextStyles.quote.copyWith(
              fontSize: 52,
              height: 0.9,
              color: AppColors.pink,
            ),
          ),
          Text(
            hasText ? text : emptyPlaceholder,
            style: hasText
                ? AppTextStyles.quote
                : AppTextStyles.body.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
