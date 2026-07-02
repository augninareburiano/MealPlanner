import 'package:flutter/material.dart';

import '../models/meal_log.dart';
import '../utils/meal_types.dart';

/// A card for one meal category (Breakfast, Lunch, …): its logged items, the
/// calorie total for the category, and — when editable — Add Food / Generate
/// Food Plan actions.
///
/// Leaving [onAddFood]/[onGeneratePlan]/[onDeleteItem] null makes the card
/// read-only, which is how the Diary reuses it.
class MealSectionCard extends StatelessWidget {
  const MealSectionCard({
    super.key,
    required this.mealType,
    required this.items,
    this.onAddFood,
    this.onGeneratePlan,
    this.onDeleteItem,
  });

  final String mealType;
  final List<MealLog> items;
  final VoidCallback? onAddFood;
  final VoidCallback? onGeneratePlan;
  final void Function(MealLog log)? onDeleteItem;

  double get _totalCalories =>
      items.fold(0, (sum, log) => sum + (log.calories ?? 0));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final editable = onAddFood != null || onGeneratePlan != null;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  mealTypeLabel(mealType),
                  style: theme.textTheme.titleMedium,
                ),
                const Spacer(),
                Text(
                  '${_totalCalories.round()} kcal',
                  style: theme.textTheme.titleMedium,
                ),
              ],
            ),
            if (items.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text('No food logged.', style: theme.textTheme.bodySmall),
              )
            else
              ...items.map(
                (log) => _FoodTile(
                  log: log,
                  onDelete:
                      onDeleteItem == null ? null : () => onDeleteItem!(log),
                ),
              ),
            if (editable) ...[
              const Divider(),
              Row(
                children: [
                  if (onAddFood != null)
                    TextButton.icon(
                      onPressed: onAddFood,
                      icon: const Icon(Icons.add),
                      label: const Text('Add Food'),
                    ),
                  if (onGeneratePlan != null)
                    TextButton.icon(
                      onPressed: onGeneratePlan,
                      icon: const Icon(Icons.auto_awesome),
                      label: const Text('Generate Food Plan'),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FoodTile extends StatelessWidget {
  const _FoodTile({required this.log, this.onDelete});

  final MealLog log;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final serving = log.servingSize;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(log.foodName),
                if (serving != null && serving.isNotEmpty)
                  Text(serving, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          Text('${(log.calories ?? 0).round()} kcal'),
          if (onDelete != null)
            IconButton(
              tooltip: 'Remove',
              icon: const Icon(Icons.close, size: 18),
              onPressed: onDelete,
            ),
        ],
      ),
    );
  }
}
