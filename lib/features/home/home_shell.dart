import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/home_tab_provider.dart';
import '../connections/screens/connection_hub_screen.dart';
import '../matches/screens/matches_screen.dart';
import '../profile/screens/my_profile_screen.dart';
import 'push_notification_listener.dart';

/// Bottom-nav shell for the three main tabs: today's matches, the
/// connection hub, and the user's own profile.
///
/// The selected tab lives in [homeTabIndexProvider] rather than local state
/// so a notification tap can switch to it (see `destinationFor`).
class HomeShell extends ConsumerWidget {
  const HomeShell({super.key});

  static const _screens = [
    MatchesScreen(),
    ConnectionHubScreen(),
    MyProfileScreen(),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = ref.watch(homeTabIndexProvider);

    return PushNotificationListener(
      child: Scaffold(
        body: IndexedStack(index: index, children: _screens),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: index,
          onTap: (next) => ref.read(homeTabIndexProvider.notifier).state = next,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.favorite_outline),
              activeIcon: Icon(Icons.favorite),
              label: 'Matches',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.chat_bubble_outline),
              activeIcon: Icon(Icons.chat_bubble),
              label: 'Connection',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
