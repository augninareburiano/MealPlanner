import 'package:flutter/material.dart';

import '../../widgets/glass.dart';

class _Note {
  _Note(this.icon, this.title, this.body);
  final IconData icon;
  final String title;
  final String body;
}

/// A simple notifications/reminders feed. Reminders are generated from the time
/// of day and dismissible.
class NotificationsSection extends StatefulWidget {
  const NotificationsSection({super.key});

  @override
  State<NotificationsSection> createState() => _NotificationsSectionState();
}

class _NotificationsSectionState extends State<NotificationsSection> {
  late final List<_Note> _notes = _build();

  List<_Note> _build() {
    final hour = DateTime.now().hour;
    return [
      if (hour < 10)
        _Note(Icons.free_breakfast, 'Breakfast time',
            "Log your breakfast to start tracking today's calories.")
      else if (hour < 15)
        _Note(Icons.lunch_dining, 'Lunch reminder',
            'Have you logged your lunch yet?')
      else
        _Note(Icons.dinner_dining, 'Dinner reminder',
            'Log your dinner to close out the day.'),
      _Note(Icons.water_drop, 'Stay hydrated',
          'Aim for 8 glasses of water today.'),
      _Note(Icons.monitor_weight, 'Weekly weigh-in',
          'Update your weight to track your progress.'),
      _Note(Icons.pie_chart, 'Your targets',
          'Complete your profile for personalized calorie and nutrient goals.'),
      _Note(Icons.local_fire_department, 'Welcome to FoodGApp',
          'Plan meals, track nutrition, and hit your goals. 🎉'),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_notes.isEmpty) {
      return Center(
        child: Text("You're all caught up!",
            style: theme.textTheme.bodyMedium),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (var i = 0; i < _notes.length; i++)
          Dismissible(
            key: ValueKey(_notes[i].title),
            onDismissed: (_) => setState(() => _notes.removeAt(i)),
            child: GlassCard(
              margin: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: theme.colorScheme.primaryContainer,
                    child: Icon(_notes[i].icon,
                        color: theme.colorScheme.onPrimaryContainer),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_notes[i].title,
                            style: theme.textTheme.titleSmall),
                        const SizedBox(height: 2),
                        Text(_notes[i].body,
                            style: theme.textTheme.bodySmall),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
