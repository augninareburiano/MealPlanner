import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import 'feedback_screen.dart';
import 'nutrition_search_screen.dart';

/// Placeholder home screen. Meal logging comes later; the DOST-FNRI daily
/// nutrition feedback and the nutrition facts lookup are reachable from here.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    final email = authService.currentUser?.email ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('FoodGApp'),
        actions: [
          IconButton(
            tooltip: 'My profile',
            icon: const Icon(Icons.person_outline),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            ),
          ),
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: authService.signOut,
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.restaurant_menu, size: 64),
              const SizedBox(height: 16),
              Text(
                'Welcome to FoodGApp',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              if (email.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('Signed in as $email'),
              ],
              const SizedBox(height: 12),
              const Text(
                'Meal logging is coming soon.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const FeedbackScreen()),
                  ),
                  icon: const Icon(Icons.insights),
                  label: const Text("Today's nutrition feedback"),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const NutritionSearchScreen(),
                    ),
                  ),
                  icon: const Icon(Icons.local_dining),
                  label: const Text('Look up nutrition facts'),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: authService.signOut,
                icon: const Icon(Icons.logout),
                label: const Text('Sign out'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
