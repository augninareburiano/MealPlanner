import 'package:flutter/material.dart';

import '../models/meal_log.dart';
import '../utils/meal_types.dart';
import 'glass.dart';

/// A glass card for one meal category (Breakfast, Lunch, …): its logged items,
/// the calorie total, and — when editable — an Add Food action.
///
/// Leaving [onAddFood]/[onDeleteItem] null makes the card read-only (the Diary
/// uses it that way).
class MealSectionCard extends StatelessWidget {
  const MealSectionCard({
    super.key,
    required this.mealType,
    required this.items,
    this.onAddFood,
    this.onDeleteItem,
    this.onEditItem,
  });

  final String mealType;
  final List<MealLog> items;
  final VoidCallback? onAddFood;
  final void Function(MealLog log)? onDeleteItem;
  final void Function(MealLog log)? onEditItem;

  double get _totalCalories =>
      items.fold(0, (sum, log) => sum + (log.calories ?? 0));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GlassCard(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(mealTypeLabel(mealType), style: theme.textTheme.titleMedium),
              const Spacer(),
              Text('${_totalCalories.round()} kcal',
                  style: theme.textTheme.titleMedium),
            ],
          ),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child:
                  Text('No food logged.', style: theme.textTheme.bodySmall),
            )
          else
            ...items.map(
              (log) => _FoodTile(
                log: log,
                onDelete:
                    onDeleteItem == null ? null : () => onDeleteItem!(log),
                onTap: onEditItem == null ? null : () => onEditItem!(log),
              ),
            ),
          if (onAddFood != null) ...[
            const Divider(),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: onAddFood,
                icon: const Icon(Icons.add),
                label: const Text('Add Food'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FoodTile extends StatelessWidget {
  const _FoodTile({required this.log, this.onDelete, this.onTap});

  final MealLog log;
  final VoidCallback? onDelete;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final serving = log.servingSize;
    return InkWell(
      onTap: onTap,
      child: Padding(
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
      ),
    );
  }
}
