import 'package:flutter/material.dart';

import '../connections/screens/connection_hub_screen.dart';
import '../matches/screens/matches_screen.dart';
import '../profile/screens/my_profile_screen.dart';

/// Bottom-nav shell for the three main tabs: today's matches, the
/// connection hub, and the user's own profile.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const _screens = [
    MatchesScreen(),
    ConnectionHubScreen(),
    MyProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (index) => setState(() => _index = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.favorite_outline), label: 'Matches'),
          BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline), label: 'Connection'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Profile'),
        ],
      ),
    );
  }
}
