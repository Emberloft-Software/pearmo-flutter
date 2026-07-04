import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/screens/blocked_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/otp_screen.dart';
import '../../features/auth/screens/splash_screen.dart';
import '../../features/chat/screens/chat_screen.dart';
import '../../features/connections/screens/connection_detail_screen.dart';
import '../../features/home/home_shell.dart';
import '../../features/icebreakers/screens/game_screen.dart';
import '../../features/icebreakers/screens/game_selection_screen.dart';
import '../../features/matches/screens/candidate_detail_screen.dart';
import '../../features/payments/screens/payments_screen.dart';
import '../../features/ratings/screens/rating_screen.dart';
import '../../features/safety/screens/report_screen.dart';
import '../../features/settings/screens/settings_screen.dart';
import '../../features/verification/screens/verification_screen.dart';
import '../../features/onboarding/screens/onboarding_screen.dart';
import '../../providers/auth_providers.dart';
import '../../providers/profile_providers.dart';
import '../../providers/repository_providers.dart';

/// Bridges Riverpod state into go_router's `refreshListenable` so the
/// router re-evaluates `redirect` whenever auth or profile state changes.
class _RouterRefreshNotifier extends ChangeNotifier {
  _RouterRefreshNotifier(Ref ref) {
    ref.listen(authStateChangesProvider, (_, _) => notifyListeners());
    ref.listen(myAppUserProvider, (_, _) => notifyListeners());
    ref.listen(myProfileProvider, (_, _) => notifyListeners());
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = _RouterRefreshNotifier(ref);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      final location = state.matchedLocation;
      final isLoggedIn = ref.read(authRepositoryProvider).isLoggedIn;

      const authRoutes = ['/login', '/verify'];
      final onAuthRoute = authRoutes.any((r) => location.startsWith(r));

      if (!isLoggedIn) {
        return onAuthRoute ? null : '/login';
      }

      // Banned/deactivated accounts can still hold a valid Supabase Auth
      // session — block them here before anything else, since nothing else
      // in this repo enforces `users.is_banned`/`is_active`.
      final appUserAsync = ref.read(myAppUserProvider);
      if (appUserAsync.isLoading) {
        return null;
      }
      final appUser = appUserAsync.valueOrNull;
      if (appUser != null && appUser.isBlocked) {
        return location == '/blocked' ? null : '/blocked';
      }

      // Logged in — figure out if onboarding is complete.
      final profileAsync = ref.read(myProfileProvider);
      if (profileAsync.isLoading) {
        // Wait for the profile fetch to resolve before deciding — the
        // refresh notifier will re-run this once it completes.
        return null;
      }

      final onboardingComplete = profileAsync.valueOrNull?.onboardingComplete ?? false;

      if (!onboardingComplete) {
        return location == '/onboarding' ? null : '/onboarding';
      }

      // Fully onboarded — keep them out of auth/onboarding/splash screens.
      if (onAuthRoute || location == '/onboarding' || location == '/splash') {
        return '/home';
      }

      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (context, state) => const SplashScreen()),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/verify',
        builder: (context, state) {
          final phone = state.uri.queryParameters['phone'] ?? '';
          return OtpScreen(phone: phone);
        },
      ),
      GoRoute(
        path: '/blocked',
        builder: (context, state) => BlockedScreen(
          banReason: ref.read(myAppUserProvider).valueOrNull?.banReason,
        ),
      ),
      GoRoute(path: '/onboarding', builder: (context, state) => const OnboardingScreen()),
      GoRoute(path: '/home', builder: (context, state) => const HomeShell()),
      GoRoute(
        path: '/candidate/:id',
        builder: (context, state) =>
            CandidateDetailScreen(candidateId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/connection/:id',
        builder: (context, state) =>
            ConnectionDetailScreen(connectionId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/connection/:id/games',
        builder: (context, state) =>
            GameSelectionScreen(connectionId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/connection/:id/chat',
        builder: (context, state) =>
            ChatScreen(connectionId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/game/:sessionId',
        builder: (context, state) =>
            GameScreen(sessionId: state.pathParameters['sessionId']!),
      ),
      GoRoute(path: '/verification', builder: (context, state) => const VerificationScreen()),
      GoRoute(path: '/settings', builder: (context, state) => const SettingsScreen()),
      GoRoute(path: '/payments', builder: (context, state) => const PaymentsScreen()),
      GoRoute(
        path: '/report',
        builder: (context, state) => ReportScreen(
          reportedId: state.uri.queryParameters['reportedId']!,
          connectionId: state.uri.queryParameters['connectionId'],
        ),
      ),
      GoRoute(
        path: '/connection/:id/rate',
        builder: (context, state) => RatingScreen(
          connectionId: state.pathParameters['id']!,
          ratedId: state.uri.queryParameters['ratedId']!,
        ),
      ),
    ],
  );
});
