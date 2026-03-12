import 'package:flutter/material.dart';
import 'package:pikuru/theme/material.dart';
import 'package:pikuru/home_screen.dart';
import 'package:pikuru/screens/events_screen.dart';
import 'package:pikuru/screens/groups_screen.dart';
import 'package:pikuru/screens/account_screen.dart';
import 'package:pikuru/screens/courts_screen.dart';
import 'package:pikuru/screens/event_history_screen.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;
  int _eventHistoryInitialTab = 0;

  // Index 5 is EventHistoryScreen — hidden from the bottom bar.
  // Bottom nav only covers 0–4.
  static const int _kEventHistory = 5;

  void _navigateToTab(int index) =>
      setState(() => _currentIndex = index);

  void _openEventHistory({int initialTab = 0}) => setState(() {
    _eventHistoryInitialTab = initialTab;
    _currentIndex = _kEventHistory;
  });

  @override
  Widget build(BuildContext context) {
    final screens = <Widget>[
      HomeScreen(onNavigateToTab: _navigateToTab),         // 0 – Home
      const CourtsScreen(),                                // 1 – Courts
      const EventsScreen(),                               // 2 – Events
      const GroupsScreen(),                               // 3 – Groups
      AccountScreen(                                      // 4 – Account
        onNavigateToTab: _navigateToTab,
        onOpenEventHistory: _openEventHistory,
      ),
      EventHistoryScreen(                                 // 5 – hidden
        key: ValueKey(_eventHistoryInitialTab),
        initialTab: _eventHistoryInitialTab,
        onBack: () => _navigateToTab(4),
      ),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        // Clamp so the bar never shows index 5 as selected.
        currentIndex: _currentIndex.clamp(0, 4),
        selectedItemColor: AppColors.primary,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined), label: 'Home'),
          BottomNavigationBarItem(
              icon: Icon(Icons.sports_tennis), label: 'Courts'),
          BottomNavigationBarItem(
              icon: Icon(Icons.event), label: 'Events'),
          BottomNavigationBarItem(
              icon: Icon(Icons.groups), label: 'Groups'),
          BottomNavigationBarItem(
              icon: Icon(Icons.person), label: 'Account'),
        ],
      ),
    );
  }
}