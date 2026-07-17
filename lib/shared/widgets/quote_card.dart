import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

/// Editorial pull-quote card for a user's `about_text` — italic serif over
/// a large, low-opacity quotation mark watermark centered in the card
/// (pink = love moments, its only job here).
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
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.divider),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Watermark quotation mark, centered behind the text.
          Positioned.fill(
            child: Center(
              child: Text(
                '“',
                style: AppTextStyles.quote.copyWith(
                  fontSize: 130,
                  height: 0.4,
                  color: AppColors.pink.withValues(alpha: 0.10),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label.toUpperCase(), style: AppTextStyles.label),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: Text(
                    hasText ? text : emptyPlaceholder,
                    textAlign: TextAlign.center,
                    style: hasText
                        ? AppTextStyles.quote
                        : AppTextStyles.body.copyWith(color: AppColors.textSecondary),
                  ),
                ),
                const SizedBox(height: 4),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
