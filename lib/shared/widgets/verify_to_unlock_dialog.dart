import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import 'pearmo_button.dart';

/// Which gated feature the user just tapped — decides the dialog's copy and
/// whether a "Verify now" action makes any sense.
enum VerifyUnlockReason {
  /// Adding a public profile photo (Settings).
  profilePicture,

  /// Chat media, blocked because *the viewer* hasn't verified.
  chatMediaSelf,

  /// Chat media, blocked because *the other participant* hasn't verified.
  /// The viewer has nothing to do here — see the note in [_Copy].
  chatMediaOther,

  /// Chat media, blocked because neither participant has verified.
  chatMediaBoth,
}

class _Copy {
  const _Copy({required this.title, required this.body, required this.actionable});

  final String title;
  final String body;

  /// Whether to offer "Verify now". False when the block is on the *other*
  /// person: there is deliberately no "remind them to verify" action
  /// anywhere in this dialog. Nudging one user to submit a selfie or an ID
  /// because of who they happen to be talking to is the coercion line —
  /// the app tells the viewer what's true and stops there.
  final bool actionable;

  static _Copy of(VerifyUnlockReason reason) => switch (reason) {
        VerifyUnlockReason.profilePicture => const _Copy(
            title: 'Verify to add a picture',
            body: "Adding a real photo is only available once you've verified you're a real "
                'person — a quick liveliness check plus a selfie, reviewed manually.',
            actionable: true,
          ),
        VerifyUnlockReason.chatMediaSelf => const _Copy(
            title: 'Verify to share photos',
            body: 'Photos and videos can be shared once both of you have verified '
                "you're real people — a quick liveliness check plus a selfie, reviewed "
                "manually. They've done theirs; yours isn't complete yet.",
            actionable: true,
          ),
        VerifyUnlockReason.chatMediaOther => const _Copy(
            title: 'Photo sharing is locked',
            body: 'Photos and videos unlock once both of you have completed the selfie '
                "check. You've done yours — they haven't yet. Nothing for you to do here; "
                "it'll unlock on its own if they verify.",
            actionable: false,
          ),
        VerifyUnlockReason.chatMediaBoth => const _Copy(
            title: 'Verify to share photos',
            body: 'Photos and videos can be shared once both of you have verified '
                "you're real people — a quick liveliness check plus a selfie, reviewed "
                'manually. Neither of you has completed it yet.',
            actionable: true,
          ),
      };
}

/// Shown when a user taps a feature gated behind tier-1 (selfie)
/// verification. Keeps the feature visible and tappable rather than hidden,
/// with this dialog as the explanation and the CTA into the flow.
class VerifyToUnlockDialog extends StatelessWidget {
  const VerifyToUnlockDialog({super.key, this.reason = VerifyUnlockReason.profilePicture});

  final VerifyUnlockReason reason;

  /// Returns `true` if the user chose to go verify now.
  static Future<bool> show(
    BuildContext context, {
    VerifyUnlockReason reason = VerifyUnlockReason.profilePicture,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (_) => VerifyToUnlockDialog(reason: reason),
    ).then((value) => value ?? false);
  }

  @override
  Widget build(BuildContext context) {
    final copy = _Copy.of(reason);

    return AlertDialog(
      title: Text(copy.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(copy.body, style: AppTextStyles.body),
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
                    reason == VerifyUnlockReason.profilePicture
                        ? 'Your avatar is always shown until then.'
                        : 'Text messages work normally either way.',
                    style: AppTextStyles.caption,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        // "Not now" keeps equal visual weight with "Verify now" on purpose —
        // declining verification stays a real, un-penalised choice.
        PearmoButton(
          label: copy.actionable ? 'Not now' : 'Got it',
          variant: PearmoButtonVariant.text,
          expand: false,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        if (copy.actionable)
          PearmoButton(
            label: 'Verify now',
            expand: false,
            onPressed: () => Navigator.of(context).pop(true),
          ),
      ],
    );
  }
}
