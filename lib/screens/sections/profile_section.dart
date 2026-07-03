import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../widgets/animations.dart';
import '../../widgets/glass.dart';
import '../daily_targets_screen.dart';
import '../profile_edit_screen.dart';

/// The Profile tab: account header plus the profile sub-sections from the app
/// map, on frosted-glass cards. "Goals" opens the working daily-targets editor;
/// "Logout" signs out. The remaining items are placeholders owned by the
/// profile feature.
class ProfileSection extends StatelessWidget {
  const ProfileSection({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = AuthService();
    final email = auth.currentUser?.email ?? '';
    final initial = email.isNotEmpty ? email[0].toUpperCase() : '?';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        FadeSlideIn(
          child: GlassCard(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: theme.colorScheme.primary,
                  child: Text(
                    initial,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: theme.colorScheme.onPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('My Account', style: theme.textTheme.titleMedium),
                      const SizedBox(height: 2),
                      Text(
                        email.isEmpty ? 'Signed in' : email,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        FadeSlideIn(
          delay: const Duration(milliseconds: 120),
          child: GlassCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                _tile(
                  context,
                  icon: Icons.person,
                  title: 'Personal Information',
                  subtitle: 'Name, age, gender, height, weight',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const ProfileEditScreen(),
                    ),
                  ),
                ),
                _tile(
                  context,
                  icon: Icons.flag,
                  title: 'Goals',
                  subtitle: 'Calorie & nutrient targets',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const DailyTargetsScreen(),
                    ),
                  ),
                ),
                _tile(
                  context,
                  icon: Icons.restaurant,
                  title: 'Dietary Preferences',
                  subtitle: 'Vegetarian, halal, and more',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const ProfileEditScreen(),
                    ),
                  ),
                ),
                _tile(
                  context,
                  icon: Icons.warning_amber,
                  title: 'Allergies',
                  subtitle: 'Foods to avoid',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const ProfileEditScreen(),
                    ),
                  ),
                ),
                _tile(
                  context,
                  icon: Icons.settings,
                  title: 'Settings',
                  subtitle: 'Notifications, units, account',
                  comingSoon: true,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        FadeSlideIn(
          delay: const Duration(milliseconds: 220),
          child: FilledButton.tonalIcon(
            onPressed: auth.signOut,
            icon: const Icon(Icons.logout),
            label: const Text('Logout'),
          ),
        ),
      ],
    );
  }

  Widget _tile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
    bool comingSoon = false,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: comingSoon
          ? const Chip(
              label: Text('Soon'),
              visualDensity: VisualDensity.compact,
            )
          : const Icon(Icons.chevron_right),
      onTap: onTap ??
          () => ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('$title is coming soon.'),
                  duration: const Duration(seconds: 1),
                ),
              ),
    );
  }
}
