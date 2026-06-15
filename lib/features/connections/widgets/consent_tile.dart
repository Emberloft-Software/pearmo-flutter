import 'package:flutter/material.dart';

import '../../../core/constants/enums.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/pearmo_card.dart';

/// One row of the consent panel: shows whether [type] is currently unlocked
/// for both participants, and a button to request/revoke it.
class ConsentTile extends StatelessWidget {
  const ConsentTile({
    super.key,
    required this.type,
    required this.isGranted,
    required this.isLoading,
    required this.onTap,
  });

  final ConsentType type;
  final bool isGranted;
  final bool isLoading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PearmoCard(
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isGranted ? AppColors.secondaryLight : AppColors.surfaceMuted,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isGranted ? Icons.lock_open : Icons.lock_outline,
              color: isGranted ? AppColors.secondaryDark : AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(type.label, style: AppTextStyles.bodyMedium),
                const SizedBox(height: 2),
                Text(
                  isGranted ? 'Unlocked for you both' : type.description,
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (isLoading)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
            )
          else
            TextButton(
              onPressed: onTap,
              child: Text(isGranted ? 'Revoke' : 'Request'),
            ),
        ],
      ),
    );
  }
}
