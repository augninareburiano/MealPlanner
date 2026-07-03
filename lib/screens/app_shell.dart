import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../widgets/glass.dart';
import 'sections/dashboard_section.dart';
import 'sections/grocery_section.dart';
import 'sections/meal_planner_section.dart';
import 'sections/notifications_section.dart';
import 'sections/nutrition_section.dart';
import 'sections/profile_section.dart';
import 'sections/recipes_section.dart';
import 'sections/weight_tracker_section.dart';

/// The main app shell shown after login.
///
/// Five primary destinations live in the bottom bar and keep their state in an
/// [IndexedStack]; the navigation drawer exposes the full app map — those five
/// plus the extra destinations (Grocery, Weight, Notifications), which open as
/// their own pages. Everything sits over a soft gradient with frosted-glass
/// chrome.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _tab = 0;

  static const _titles = [
    'Dashboard',
    'Meal Planner',
    'Recipes',
    'Nutrition',
    'Profile',
  ];

  void _selectTab(int index) {
    setState(() => _tab = index);
    Navigator.of(context).maybePop(); // close drawer if open
  }

  void _openPage(String title, Widget child) {
    Navigator.of(context).pop(); // close drawer
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GradientBackground(
          child: Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
              title: Text(title),
            ),
            body: child,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tabs = [
      DashboardSection(onOpenMealPlanner: () => setState(() => _tab = 1)),
      const MealPlannerSection(),
      const RecipesSection(),
      const NutritionSection(),
      const ProfileSection(),
    ];

    return GradientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          scrolledUnderElevation: 0,
          title: Text(_titles[_tab]),
          actions: [
            IconButton(
              tooltip: 'Notifications',
              icon: const Icon(Icons.notifications_outlined),
              onPressed: () =>
                  _openPage('Notifications', const NotificationsSection()),
            ),
          ],
        ),
        drawer: _buildDrawer(context),
        body: IndexedStack(index: _tab, children: tabs),
        bottomNavigationBar: GlassSurface(
          child: NavigationBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            selectedIndex: _tab,
            onDestinationSelected: (i) => setState(() => _tab = i),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard),
                label: 'Dashboard',
              ),
              NavigationDestination(
                icon: Icon(Icons.restaurant_menu_outlined),
                selectedIcon: Icon(Icons.restaurant_menu),
                label: 'Planner',
              ),
              NavigationDestination(
                icon: Icon(Icons.menu_book_outlined),
                selectedIcon: Icon(Icons.menu_book),
                label: 'Recipes',
              ),
              NavigationDestination(
                icon: Icon(Icons.pie_chart_outline),
                selectedIcon: Icon(Icons.pie_chart),
                label: 'Nutrition',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline),
                selectedIcon: Icon(Icons.person),
                label: 'Profile',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    final theme = Theme.of(context);
    final email = AuthService().currentUser?.email ?? 'Signed in';

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(color: theme.colorScheme.primary),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Icon(Icons.restaurant_menu,
                    size: 40, color: theme.colorScheme.onPrimary),
                const SizedBox(height: 8),
                Text(
                  'FoodGApp',
                  style: theme.textTheme.titleLarge
                      ?.copyWith(color: theme.colorScheme.onPrimary),
                ),
                Text(
                  email,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onPrimary),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          _drawerTab(Icons.dashboard_outlined, 'Dashboard', 0),
          _drawerTab(Icons.restaurant_menu_outlined, 'Meal Planner', 1),
          _drawerTab(Icons.menu_book_outlined, 'Recipes', 2),
          _drawerTab(Icons.pie_chart_outline, 'Nutrition', 3),
          _drawerTab(Icons.person_outline, 'Profile', 4),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.shopping_cart_outlined),
            title: const Text('Grocery List'),
            onTap: () => _openPage('Grocery List', const GrocerySection()),
          ),
          ListTile(
            leading: const Icon(Icons.monitor_weight_outlined),
            title: const Text('Weight Tracker'),
            onTap: () =>
                _openPage('Weight Tracker', const WeightTrackerSection()),
          ),
          ListTile(
            leading: const Icon(Icons.notifications_outlined),
            title: const Text('Notifications'),
            onTap: () =>
                _openPage('Notifications', const NotificationsSection()),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Logout'),
            onTap: AuthService().signOut,
          ),
        ],
      ),
    );
  }

  Widget _drawerTab(IconData icon, String label, int index) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      selected: _tab == index,
      onTap: () => _selectTab(index),
    );
  }
}
