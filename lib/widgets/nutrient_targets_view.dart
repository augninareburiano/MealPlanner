import 'package:flutter/material.dart';

import '../models/nutrient_targets.dart';
import 'glass.dart';

/// Read-only presentation of a [NutrientTargets]: the calorie hero, the macro
/// breakdown, and the key RENI micronutrient goals — on frosted-glass cards.
///
/// Pure (no data loading) so it's easy to reuse from other screens and to test
/// on its own.
class NutrientTargetsView extends StatelessWidget {
  const NutrientTargetsView({super.key, required this.targets});

  final NutrientTargets targets;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: _CalorieHero(targets: targets),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
          child: Text('Macronutrients', style: theme.textTheme.titleMedium),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              _MacroCard(label: 'Protein', grams: targets.proteinG),
              _MacroCard(label: 'Carbs', grams: targets.carbsG),
              _MacroCard(label: 'Fat', grams: targets.fatG),
              _MacroCard(label: 'Fiber', grams: targets.fiberG),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text(
            'Key nutrients (DOST-FNRI RENI)',
            style: theme.textTheme.titleMedium,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: GlassCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                _MicroRow(name: 'Calcium', value: targets.calciumMg, unit: 'mg'),
                _MicroRow(name: 'Iron', value: targets.ironMg, unit: 'mg'),
                _MicroRow(
                  name: 'Vitamin C',
                  value: targets.vitaminCMg,
                  unit: 'mg',
                ),
                _MicroRow(
                  name: 'Vitamin A',
                  value: targets.vitaminARaeUg,
                  unit: 'µg RAE',
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CalorieHero extends StatelessWidget {
  const _CalorieHero({required this.targets});

  final NutrientTargets targets;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassCard(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Column(
        children: [
          Text('Daily Calorie Target', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            '${targets.calories}',
            style: theme.textTheme.displaySmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text('kcal / day', style: theme.textTheme.bodyMedium),
          const SizedBox(height: 12),
          Chip(
            avatar: Icon(
              targets.personalized ? Icons.check_circle : Icons.info_outline,
              size: 18,
            ),
            label: Text(
              targets.personalized
                  ? 'Personalized to your profile'
                  : 'Estimated — complete your profile',
            ),
          ),
        ],
      ),
    );
  }
}

class _MacroCard extends StatelessWidget {
  const _MacroCard({required this.label, required this.grams});

  final String label;
  final double grams;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: GlassCard(
        margin: const EdgeInsets.all(4),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        radius: 18,
        child: Column(
          children: [
            Text('${grams.round()}', style: theme.textTheme.titleLarge),
            Text('g', style: theme.textTheme.bodySmall),
            const SizedBox(height: 4),
            Text(
              label,
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _MicroRow extends StatelessWidget {
  const _MicroRow({required this.name, required this.value, required this.unit});

  final String name;
  final double value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      title: Text(name),
      trailing: Text(
        '${value.round()} $unit',
        style: Theme.of(context).textTheme.titleSmall,
      ),
    );
  }
}
