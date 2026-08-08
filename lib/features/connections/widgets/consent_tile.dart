import 'package:flutter/material.dart';

import '../../../core/constants/enums.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../data/models/consent_record.dart';
import '../../../shared/widgets/pearmo_card.dart';

/// One row of the consent panel: shows the live [ConsentState] for [type]
/// and a button (or, for an incoming request, an Agree/Decline pair) to
/// act on it.
class ConsentTile extends StatelessWidget {
  const ConsentTile({
    super.key,
    required this.type,
    required this.state,
    required this.isLoading,
    required this.onTap,
    this.onDecline,
  });

  final ConsentType type;
  final ConsentState state;
  final bool isLoading;

  /// Primary action: Request / Cancel / Agree / Revoke, depending on
  /// [state] — see [_buttonLabel].
  final VoidCallback onTap;

  /// Only used (and only shown) when [state] is [ConsentState.needsYourResponse]
  /// — an explicit "no" so the requester is told rather than left waiting
  /// indefinitely.
  final VoidCallback? onDecline;

  bool get _isUnlocked => state == ConsentState.granted;
  bool get _needsResponse => state == ConsentState.needsYourResponse;

  String get _caption => switch (state) {
        ConsentState.none => type.description,
        ConsentState.waitingOnThem => 'Requested. Waiting for them to agree.',
        ConsentState.needsYourResponse => "They'd like to turn this on.",
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
    final captionColor = _needsResponse
        ? AppColors.secondaryDark
        : state == ConsentState.revokedByThem
            ? AppColors.textSecondary
            : null;

    return PearmoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
                        // Flexible + ellipsis: "Share photos & videos" is
                        // wider than the space left once the action buttons
                        // are laid out on narrow screens.
                        Flexible(
                          child: Text(
                            type.label,
                            style: AppTextStyles.bodyMedium,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (_needsResponse) ...[
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
              // An incoming request needs two actions, which don't fit
              // beside the text on a narrow screen — they get their own
              // row below instead.
              else if (!_needsResponse)
                TextButton(
                  onPressed: onTap,
                  child: Text(_buttonLabel),
                ),
            ],
          ),
          if (_needsResponse && !isLoading)
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: onDecline,
                  child: const Text('Decline'),
                ),
                const SizedBox(width: 4),
                TextButton(
                  onPressed: onTap,
                  child: const Text('Agree'),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
