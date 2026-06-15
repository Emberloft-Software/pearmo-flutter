import 'package:flutter/material.dart';

import '../../core/constants/enums.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import 'pearmo_button.dart';

/// Confirmation dialog shown before requesting or revoking a consent-gated
/// unlock (chat, media, calls, location, gift address). Surfacing this as
/// its own dialog keeps the "send an alert to both parties" promise visible
/// and consistent everywhere it's used.
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
                        ? 'The other person will get a notification asking if they\'re okay with this too. It only unlocks once you both agree.'
                        : 'The other person will be notified that you\'ve turned this off.',
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
