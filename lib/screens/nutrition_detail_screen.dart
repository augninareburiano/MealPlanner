import 'package:flutter/material.dart';

import '../models/nutrition_facts.dart';
import '../models/recipe.dart';
import '../services/auth_service.dart';
import '../services/nutrition_facts_service.dart';

/// The nutritional values of one food or meal, shown as a facts panel and
/// measured against the user's DOST-FNRI daily target.
class NutritionDetailScreen extends StatefulWidget {
  const NutritionDetailScreen({super.key, required this.recipe});

  final Recipe recipe;

  @override
  State<NutritionDetailScreen> createState() => _NutritionDetailScreenState();
}

class _NutritionDetailScreenState extends State<NutritionDetailScreen> {
  static const _maxServings = 12;

  final _service = NutritionFactsService();
  late Future<ResolvedNutrition> _future;

  /// How many servings the user is looking at. The panel rebuilds locally when
  /// this changes — no refetch.
  int _servings = 1;

  @override
  void initState() {
    super.initState();
    final userId = AuthService().currentUser?.uid ?? '';
    _future = _service.resolve(recipe: widget.recipe, userId: userId);
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.recipe.name)),
      body: FutureBuilder<ResolvedNutrition>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _Message(
              icon: Icons.error_outline,
              title: "Couldn't load nutrition facts.",
              body: '${snapshot.error}',
            );
          }

          final facts = snapshot.data!.factsFor(_servings.toDouble());
          if (!facts.hasData) return _NoNutritionData(facts: facts);

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              _Header(facts: facts),
              const SizedBox(height: 16),
              _ServingSelector(
                servings: _servings,
                recipeServings: facts.recipeServings,
                onChanged: (value) => setState(() => _servings = value),
                max: _maxServings,
              ),
              const SizedBox(height: 16),
              if (facts.energy != null) ...[
                _EnergyCard(energy: facts.energy!),
                const SizedBox(height: 12),
              ],
              _FactsSection(title: 'Macronutrients', rows: facts.macros),
              if (facts.details.isNotEmpty) ...[
                const SizedBox(height: 12),
                _FactsSection(title: 'Watch these', rows: facts.details),
              ],
              if (facts.micronutrients.isNotEmpty) ...[
                const SizedBox(height: 12),
                _FactsSection(
                  title: 'Vitamins & minerals',
                  rows: facts.micronutrients,
                ),
              ],
              const SizedBox(height: 16),
              _FooterNote(facts: facts),
            ],
          );
        },
      ),
    );
  }
}

/// Formats a nutrient amount: whole numbers once they're big enough that a
/// decimal place is noise.
String _formatAmount(double value) =>
    value >= 10 ? value.round().toString() : value.toStringAsFixed(1);

class _Header extends StatelessWidget {
  const _Header({required this.facts});

  final NutritionFacts facts;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (facts.imageUrl != null) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              facts.imageUrl!,
              height: 180,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
          const SizedBox(height: 12),
        ],
        Text(
          facts.foodName,
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

class _ServingSelector extends StatelessWidget {
  const _ServingSelector({
    required this.servings,
    required this.recipeServings,
    required this.onChanged,
    required this.max,
  });

  final int servings;
  final int? recipeServings;
  final ValueChanged<int> onChanged;
  final int max;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    servings == 1 ? '1 serving' : '$servings servings',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (recipeServings != null)
                    Text(
                      'This dish makes $recipeServings '
                      'serving${recipeServings == 1 ? '' : 's'}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Fewer servings',
              icon: const Icon(Icons.remove_circle_outline),
              onPressed: servings > 1 ? () => onChanged(servings - 1) : null,
            ),
            IconButton(
              tooltip: 'More servings',
              icon: const Icon(Icons.add_circle_outline),
              onPressed: servings < max ? () => onChanged(servings + 1) : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _EnergyCard extends StatelessWidget {
  const _EnergyCard({required this.energy});

  final NutritionFactRow energy;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final percent = energy.dailyPercent;

    return Card(
      color: scheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Energy',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: scheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              '${_formatAmount(energy.amount)} kcal',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: scheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            if (percent != null) ...[
              const SizedBox(height: 8),
              Text(
                '$percent% of your estimated daily energy need '
                '(${energy.dailyReference!.round()} kcal)',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onPrimaryContainer.withValues(alpha: 0.85),
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FactsSection extends StatelessWidget {
  const _FactsSection({required this.title, required this.rows});

  final String title;
  final List<NutritionFactRow> rows;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            for (final row in rows) _FactRowTile(row: row),
          ],
        ),
      ),
    );
  }
}

class _FactRowTile extends StatelessWidget {
  const _FactRowTile({required this.row});

  final NutritionFactRow row;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final share = row.dailyShare;
    final labelStyle = row.isSub
        ? theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)
        : theme.textTheme.bodyLarge;

    return Padding(
      padding: EdgeInsets.only(top: 12, left: row.isSub ? 16 : 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  row.isSub ? 'of which ${row.label.toLowerCase()}' : row.label,
                  style: labelStyle,
                ),
              ),
              Text(
                '${_formatAmount(row.amount)} ${row.unit}',
                style: labelStyle?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          if (share != null) ...[
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: share.clamp(0.0, 1.0),
                minHeight: 6,
                backgroundColor: scheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(
                  row.exceedsLimit ? scheme.error : scheme.primary,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _shareLabel(row),
              style: theme.textTheme.bodySmall?.copyWith(
                color:
                    row.exceedsLimit ? scheme.error : scheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String _shareLabel(NutritionFactRow row) {
    final percent = row.dailyPercent!;
    final reference = '${_formatAmount(row.dailyReference!)} ${row.unit}';
    switch (row.referenceKind) {
      case DailyReferenceKind.target:
        return '$percent% of your daily target ($reference)';
      case DailyReferenceKind.limit:
        return '$percent% of the daily limit ($reference)';
    }
  }
}

class _FooterNote extends StatelessWidget {
  const _FooterNote({required this.facts});

  final NutritionFacts facts;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!facts.personalised) ...[
          Text(
            'Tip: complete your profile (age, sex, height, weight, activity) '
            'to compare these values against your own daily target. Showing '
            'general DOST-FNRI defaults for now.',
            style: style,
          ),
          const SizedBox(height: 8),
        ],
        Text(
          'Daily targets and limits follow the DOST-FNRI Philippine Dietary '
          'Reference Intakes (PDRI) and the Nutritional Guidelines for '
          'Filipinos. Nutrition data from '
          '${facts.source == 'themealdb' ? 'TheMealDB' : 'Spoonacular'}; '
          'figures are estimates and are a guide, not medical advice.',
          style: style,
        ),
      ],
    );
  }
}

class _NoNutritionData extends StatelessWidget {
  const _NoNutritionData({required this.facts});

  final NutritionFacts facts;

  @override
  Widget build(BuildContext context) => _Message(
        icon: Icons.info_outline,
        title: 'No nutrition data for ${facts.foodName}.',
        body: 'This recipe came from TheMealDB, the backup source, which '
            'lists ingredients but not nutritional values. Try searching for '
            'the dish by a more common name.',
      );
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 12),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              body,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
