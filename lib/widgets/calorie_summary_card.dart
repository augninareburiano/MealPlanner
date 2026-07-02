import 'package:flutter/material.dart';

/// Home dashboard header showing the day's calorie budget as
/// `Goal − Food + Exercise = Remaining`, with a progress bar for food eaten.
///
/// Exercise has no data source yet, so it defaults to zero until exercise
/// logging is added.
class CalorieSummaryCard extends StatelessWidget {
  const CalorieSummaryCard({
    super.key,
    required this.target,
    required this.foodCalories,
    this.exerciseCalories = 0,
  });

  final int target;
  final double foodCalories;
  final double exerciseCalories;

  int get remaining => (target - foodCalories + exerciseCalories).round();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = target <= 0 ? 0.0 : (foodCalories / target).clamp(0.0, 1.0);

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text("Today's Calories", style: theme.textTheme.titleMedium),
            const SizedBox(height: 16),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _Metric(label: 'Goal', value: target.toDouble()),
                  const _Operator('−'),
                  _Metric(label: 'Food', value: foodCalories),
                  const _Operator('+'),
                  _Metric(label: 'Exercise', value: exerciseCalories),
                  const _Operator('='),
                  _Metric(
                    label: 'Remaining',
                    value: remaining.toDouble(),
                    emphasize: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(value: progress, minHeight: 8),
            ),
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  final String label;
  final double value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final valueStyle = emphasize
        ? theme.textTheme.titleLarge?.copyWith(color: theme.colorScheme.primary)
        : theme.textTheme.titleMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        children: [
          Text('${value.round()}', style: valueStyle),
          const SizedBox(height: 4),
          Text(label, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _Operator extends StatelessWidget {
  const _Operator(this.symbol);

  final String symbol;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Text(symbol, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}
