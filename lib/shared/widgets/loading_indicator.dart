import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Standard centered loading spinner for async screens.
class LoadingIndicator extends StatelessWidget {
  const LoadingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(color: AppColors.primary),
    );
  }
}
