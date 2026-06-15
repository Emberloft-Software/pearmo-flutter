import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/widgets.dart';

/// Shown briefly while the router figures out where to send the user
/// (login / onboarding / home) based on auth + profile state.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: AppColors.heroGradient),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.favorite, color: Colors.white, size: 48),
            ),
            const SizedBox(height: 24),
            Text(AppConstants.appName, style: AppTextStyles.displayMedium),
            const SizedBox(height: 24),
            const LoadingIndicator(),
          ],
        ),
      ),
    );
  }
}
