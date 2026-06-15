import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Rounded surface used for cards/sections throughout the app.
class PearmoCard extends StatelessWidget {
  const PearmoCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.onTap,
    this.color,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: child,
    );

    if (onTap == null) return card;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        child: card,
      ),
    );
  }
}
