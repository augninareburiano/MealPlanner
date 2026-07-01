import 'package:flutter/material.dart';

import '../services/auth_service.dart';

/// Placeholder home screen. For now it only needs a working Sign Out; meal
/// logging, recipe suggestions, and DOST-FNRI feedback come later.
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
                'Meal logging, recipe suggestions, and DOST-FNRI feedback '
                'are coming soon.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
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
