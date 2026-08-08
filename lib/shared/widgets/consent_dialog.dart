import 'package:flutter/material.dart';

import '../../core/constants/enums.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import 'pearmo_button.dart';

/// What the user is about to do, so the dialog can use accurate copy —
/// "send a request", "agree to theirs", and "turn it off again" are three
/// different actions that all used to share one granting/revoking bool.
enum ConsentIntent { request, agree, revoke }

/// Confirmation dialog shown before requesting, agreeing to, or revoking a
/// consent-gated unlock. Both participants are pushed a notification for
/// each of these (see `send-push`'s `consent_*` events), and the change is
/// also reflected live in the other person's Shared Unlocks panel.
class ConsentDialog extends StatelessWidget {
  const ConsentDialog({super.key, required this.type, required this.intent});

  final ConsentType type;
  final ConsentIntent intent;

  static Future<bool> show(
    BuildContext context, {
    required ConsentType type,
    required ConsentIntent intent,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (_) => ConsentDialog(type: type, intent: intent),
    ).then((value) => value ?? false);
  }

  bool get granting => intent != ConsentIntent.revoke;

  String get _title => switch (intent) {
        ConsentIntent.request => 'Request "${type.label}"?',
        ConsentIntent.agree => 'Agree to "${type.label}"?',
        ConsentIntent.revoke => 'Turn off "${type.label}"?',
      };

  String get _note => switch (intent) {
        ConsentIntent.request =>
          "They'll get a notification asking if they agree, and this unlocks the moment they do.",
        ConsentIntent.agree =>
          "This unlocks it for both of you right away, and they'll be notified. Either of you can turn it off again at any time.",
        ConsentIntent.revoke =>
          "This locks it again for both of you straight away, and they'll be notified. Re-opening it later needs a fresh request.",
      };

  String get _actionLabel => switch (intent) {
        ConsentIntent.request => 'Send request',
        ConsentIntent.agree => 'Agree',
        ConsentIntent.revoke => 'Turn off',
      };

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(type.description, style: AppTextStyles.body),
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
                const Icon(Icons.notifications_active_outlined, size: 20, color: AppColors.secondaryDark),
                const SizedBox(width: 8),
                Expanded(child: Text(_note, style: AppTextStyles.caption)),
              ],
            ),
          ),
        ],
      ),
      actions: [
        PearmoButton(
          label: 'Cancel',
          variant: PearmoButtonVariant.text,
          expand: false,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        PearmoButton(
          label: _actionLabel,
          variant: granting ? PearmoButtonVariant.primary : PearmoButtonVariant.danger,
          expand: false,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    );
  }
}
