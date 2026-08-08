import 'package:flutter/material.dart';

import '../../../core/constants/enums.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../data/models/consent_record.dart';
import '../../../shared/widgets/pearmo_card.dart';

/// One row of the consent panel: shows the live [ConsentState] for [type]
/// and a button to request/agree/revoke it.
class ConsentTile extends StatelessWidget {
  const ConsentTile({
    super.key,
    required this.type,
    required this.state,
    required this.isLoading,
    required this.onTap,
  });

  final ConsentType type;
  final ConsentState state;
  final bool isLoading;
  final VoidCallback onTap;

  bool get _isUnlocked => state == ConsentState.granted;

  String get _caption => switch (state) {
        ConsentState.none => type.description,
        ConsentState.waitingOnThem => "Requested — waiting for them to agree.",
        ConsentState.needsYourResponse => "They'd like to turn this on — agree to unlock it.",
        ConsentState.granted => 'Unlocked for you both',
        ConsentState.revokedByMe => 'You turned this off.',
        ConsentState.revokedByThem => 'They turned this off.',
      };

  String get _buttonLabel => switch (state) {
        ConsentState.none => 'Request',
        ConsentState.waitingOnThem => 'Cancel',
        ConsentState.needsYourResponse => 'Agree',
        ConsentState.granted => 'Revoke',
        ConsentState.revokedByMe => 'Request',
        ConsentState.revokedByThem => 'Request',
      };

  @override
  Widget build(BuildContext context) {
    final captionColor = state == ConsentState.needsYourResponse
        ? AppColors.secondaryDark
        : state == ConsentState.revokedByThem
            ? AppColors.textSecondary
            : null;

    return PearmoCard(
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _isUnlocked ? AppColors.secondaryLight : AppColors.surfaceMuted,
              shape: BoxShape.circle,
            ),
            child: Icon(
              _isUnlocked ? Icons.lock_open : Icons.lock_outline,
              color: _isUnlocked ? AppColors.secondaryDark : AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(type.label, style: AppTextStyles.bodyMedium),
                    if (state == ConsentState.needsYourResponse) ...[
                      const SizedBox(width: 6),
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: AppColors.magenta,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  _caption,
                  style: captionColor == null
                      ? AppTextStyles.caption
                      : AppTextStyles.caption.copyWith(color: captionColor),
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
              child: Text(_buttonLabel),
            ),
        ],
      ),
    );
  }
}
