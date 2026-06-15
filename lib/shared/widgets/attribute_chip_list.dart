import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

/// Read-only wrap of pill-shaped labels, used to display a profile's
/// chosen traits (relationship intent, life stage, partner values, etc.)
class AttributeChipList extends StatelessWidget {
  const AttributeChipList({super.key, required this.labels});

  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    if (labels.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: labels
          .map(
            (label) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surfaceMuted,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(label, style: AppTextStyles.bodyMedium),
            ),
          )
          .toList(),
    );
  }
}
