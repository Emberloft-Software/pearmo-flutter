import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

/// Color-coded connection-status pill (tinted background + dot + label).
class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.label, required this.color});

  final String label;
  final Color color;

  /// Canonical color for a `connection_status` db value.
  static Color colorFor(String dbValue) => switch (dbValue) {
        'pending' => AppColors.statusPending,
        'ice_breaking' => AppColors.statusIceBreaking,
        'limited_chat' => AppColors.statusLimitedChat,
        'open_chat' => AppColors.statusOpenChat,
        'media_unlocked' => AppColors.statusMediaUnlocked,
        'date_planned' => AppColors.statusDatePlanned,
        _ => AppColors.statusEnded,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          // The longest status label ("Accepted, break the ice!") doesn't fit
          // beside a 64px avatar on a narrow phone, so the label has to be
          // able to shrink rather than overflow the pill.
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
