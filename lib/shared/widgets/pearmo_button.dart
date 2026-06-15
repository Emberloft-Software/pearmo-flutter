import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

enum PearmoButtonVariant { primary, outline, text, danger }

/// Standard rounded-pill button used across the app, with a built-in
/// loading state so async actions never need bespoke spinners.
class PearmoButton extends StatelessWidget {
  const PearmoButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = PearmoButtonVariant.primary,
    this.isLoading = false,
    this.icon,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final PearmoButtonVariant variant;
  final bool isLoading;
  final IconData? icon;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final disabled = isLoading || onPressed == null;
    final child = isLoading
        ? SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: variant == PearmoButtonVariant.outline || variant == PearmoButtonVariant.text
                  ? AppColors.primary
                  : Colors.white,
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[Icon(icon, size: 20), const SizedBox(width: 8)],
              Text(label),
            ],
          );

    Widget button;
    switch (variant) {
      case PearmoButtonVariant.primary:
        button = ElevatedButton(onPressed: disabled ? null : onPressed, child: child);
      case PearmoButtonVariant.outline:
        button = OutlinedButton(onPressed: disabled ? null : onPressed, child: child);
      case PearmoButtonVariant.text:
        button = TextButton(onPressed: disabled ? null : onPressed, child: child);
      case PearmoButtonVariant.danger:
        button = ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
          onPressed: disabled ? null : onPressed,
          child: child,
        );
    }

    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}
