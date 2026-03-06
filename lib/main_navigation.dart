import 'package:flutter/material.dart';
import 'package:pikuru/theme/material.dart';
import 'package:pikuru/home_screen.dart';
import 'package:pikuru/screens/events_screen.dart';
import 'package:pikuru/screens/groups_screen.dart';
import 'package:pikuru/screens/account_screen.dart';
import 'package:pikuru/screens/courts_screen.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;

  // ← Called by HomeScreen welcome card buttons to switch tabs
  void _navigateToTab(int index) {
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    // Build screens here so HomeScreen gets the callback
    final screens = [
      HomeScreen(onNavigateToTab: _navigateToTab), // ← passes callback
      const CourtsScreen(),
      const EventsScreen(),
      const GroupsScreen(),
      const AccountScreen(),
    ];

    return Scaffold(
      body: screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.sports_tennis),
            label: 'Courts',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.event),
            label: 'Events',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.groups),
            label: 'Groups',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Account',
          ),
        ],
      ),
    );
  }
}