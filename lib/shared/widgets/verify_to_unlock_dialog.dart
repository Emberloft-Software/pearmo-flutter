import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import 'pearmo_button.dart';

/// Shown when an unverified user taps a feature that's gated behind tier-1
/// verification (currently: adding a profile picture). Keeps the feature
/// visible/tappable rather than hidden, with this dialog as the CTA into
/// the verification flow.
class VerifyToUnlockDialog extends StatelessWidget {
  const VerifyToUnlockDialog({super.key});

  /// Returns `true` if the user chose to go verify now.
  static Future<bool> show(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (_) => const VerifyToUnlockDialog(),
    ).then((value) => value ?? false);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Verify to add a picture'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Adding a real photo is only available once you've verified you're a real "
            'person — a quick liveliness check plus a selfie, reviewed manually.',
            style: AppTextStyles.body,
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.secondaryLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.shield_outlined, size: 20, color: AppColors.secondaryDark),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Your avatar is always shown until then.',
                    style: AppTextStyles.caption,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        PearmoButton(
          label: 'Not now',
          variant: PearmoButtonVariant.text,
          expand: false,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        PearmoButton(
          label: 'Verify now',
          expand: false,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    );
  }
}
