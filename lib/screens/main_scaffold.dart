import 'package:flutter/material.dart';

import 'diary_screen.dart';
import 'home_screen.dart';

/// Hosts the app's main screens behind a shared bottom navigation bar.
///
/// Each tab is rebuilt when selected so its data reloads on every visit (e.g.
/// food logged on Home shows up when switching to Diary).
class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _index == 0 ? const HomeScreen() : const DiaryScreen(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.book_outlined),
            selectedIcon: Icon(Icons.book),
            label: 'Diary',
          ),
        ],
      ),
    );
  }
}
