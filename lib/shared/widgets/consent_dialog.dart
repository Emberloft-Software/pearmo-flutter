import 'package:flutter/material.dart';

import '../../core/constants/enums.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import 'pearmo_button.dart';

/// Confirmation dialog shown before requesting or revoking a consent-gated
/// unlock (chat, media, calls, location, gift address). Copy deliberately
/// only promises what's actually true today — the change is visible to the
/// other participant live in the app (see `ConsentTile`'s per-state
/// copy) — not a push notification, since no event currently pushes on a
/// `consent_records` change (see CLAUDE.md "Push notifications").
class ConsentDialog extends StatelessWidget {
  const ConsentDialog({super.key, required this.type, required this.granting});

  final ConsentType type;
  final bool granting;

  static Future<bool> show(BuildContext context, {required ConsentType type, required bool granting}) {
    return showDialog<bool>(
      context: context,
      builder: (_) => ConsentDialog(type: type, granting: granting),
    ).then((value) => value ?? false);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(granting ? 'Unlock "${type.label}"?' : 'Revoke "${type.label}"?'),
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
                Expanded(
                  child: Text(
                    granting
                        ? "They'll see your request the next time they open this connection, and it unlocks the moment you both agree."
                        : "They'll see that you've turned this off the next time they open this connection.",
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
          label: 'Cancel',
          variant: PearmoButtonVariant.text,
          expand: false,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        PearmoButton(
          label: granting ? 'Send request' : 'Revoke',
          variant: granting ? PearmoButtonVariant.primary : PearmoButtonVariant.danger,
          expand: false,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    );
  }
}
