import 'package:flutter/material.dart';

import '../models/recipe.dart';
import '../services/nutrition_facts_service.dart';
import 'nutrition_detail_screen.dart';

/// Starting points offered before the user has searched anything.
const _suggestions = [
  'Chicken adobo',
  'Sinigang',
  'Pancit',
  'Fried rice',
  'Lumpia',
  'Tinola',
];

/// Search entry point for the nutrition facts feature: look up any food or
/// meal and open its nutritional values.
class NutritionSearchScreen extends StatefulWidget {
  const NutritionSearchScreen({super.key, this.service});

  /// Injectable so tests can drive the screen without real network calls.
  /// Defaults to the real service.
  final NutritionFactsService? service;

  @override
  State<NutritionSearchScreen> createState() => _NutritionSearchScreenState();
}

class _NutritionSearchScreenState extends State<NutritionSearchScreen> {
  late final _service = widget.service ?? NutritionFactsService();
  final _controller = TextEditingController();

  List<Recipe> _results = const [];
  bool _loading = false;

  /// Null until the first search finishes, so the opening hint isn't mistaken
  /// for an empty result.
  String? _lastQuery;

  @override
  void dispose() {
    _controller.dispose();
    _service.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;

    FocusScope.of(context).unfocus();
    setState(() => _loading = true);

    final results = await _service.search(trimmed);
    if (!mounted) return;
    setState(() {
      _results = results;
      _lastQuery = trimmed;
      _loading = false;
    });
  }

  void _openSuggestion(String suggestion) {
    _controller.text = suggestion;
    _search(suggestion);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nutrition Facts')),
      body: Column(
        children: [
          if (!_service.hasNutritionSource) const _NoSourceBanner(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _controller,
              textInputAction: TextInputAction.search,
              onSubmitted: _search,
              decoration: InputDecoration(
                hintText: 'Search a food or meal',
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  tooltip: 'Search',
                  icon: const Icon(Icons.arrow_forward),
                  onPressed: () => _search(_controller.text),
                ),
              ),
            ),
          ),
          Expanded(child: _buildBody(context)),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_lastQuery == null) return _IntroHint(onTap: _openSuggestion);
    if (_results.isEmpty) return _NoResults(query: _lastQuery!);

    return ListView.separated(
      itemCount: _results.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) => _ResultTile(
        recipe: _results[index],
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => NutritionDetailScreen(recipe: _results[index]),
          ),
        ),
      ),
    );
  }
}

/// Shown when no Spoonacular key is configured: search still works through the
/// backup source, but it can only return names, so say that up front rather
/// than letting every result look like it has no nutrition.
class _NoSourceBanner extends StatelessWidget {
  const _NoSourceBanner();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      color: scheme.errorContainer,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Icon(Icons.warning_amber, color: scheme.onErrorContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Nutrition data source is not set up, so results will show '
              'names only. Add a Spoonacular API key to see nutritional '
              'values.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: scheme.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultTile extends StatelessWidget {
  const _ResultTile({required this.recipe, required this.onTap});

  final Recipe recipe;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: _Thumbnail(imageUrl: recipe.imageUrl),
      title: Text(recipe.name),
      subtitle: Text(_summary()),
      trailing: const Icon(Icons.chevron_right),
    );
  }

  /// A one-line macro summary, or a nudge to open the item when the search
  /// result didn't come with nutrition (TheMealDB backup results).
  String _summary() {
    if (recipe.calories == null) return 'Tap to look up nutrition facts';
    final parts = <String>['${recipe.calories!.round()} kcal'];
    void add(String label, double? grams) {
      if (grams != null) parts.add('$label ${grams.round()} g');
    }

    add('C', recipe.carbs);
    add('P', recipe.protein);
    add('F', recipe.fat);
    return '${parts.join('  ·  ')}  ·  per serving';
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      width: 56,
      height: 56,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: const Icon(Icons.restaurant),
    );
    if (imageUrl == null) return placeholder;

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        imageUrl!,
        width: 56,
        height: 56,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => placeholder,
      ),
    );
  }
}

class _IntroHint extends StatelessWidget {
  const _IntroHint({required this.onTap});

  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 24),
        Icon(
          Icons.search,
          size: 56,
          color: Theme.of(context).colorScheme.outline,
        ),
        const SizedBox(height: 16),
        Text(
          'Look up the nutritional values of any food or meal — energy, '
          'macronutrients, fibre, sodium and more, measured against your '
          'DOST-FNRI daily target.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 24),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final suggestion in _suggestions)
              ActionChip(
                label: Text(suggestion),
                onPressed: () => onTap(suggestion),
              ),
          ],
        ),
      ],
    );
  }
}

class _NoResults extends StatelessWidget {
  const _NoResults({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.no_food,
              size: 48,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 12),
            Text(
              'No matches for "$query".',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Try a simpler name, or check your internet connection — '
              'nutrition data is fetched online the first time.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
