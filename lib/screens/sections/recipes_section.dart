import 'package:flutter/material.dart';

import '../../models/recipe.dart';
import '../../models/saved_meal.dart';
import '../../services/auth_service.dart';
import '../../services/database_helper.dart';
import '../../services/recipe_repository.dart';
import '../../utils/date_format.dart';
import '../../utils/meal_types.dart';
import '../../widgets/add_food_dialog.dart';
import '../../widgets/glass.dart';

/// The Recipes tab: search recipes, browse by category, favourite them, and log
/// one straight to a meal. TheMealDB is keyless; Spoonacular adds nutrition
/// when a key is set.
class RecipesSection extends StatefulWidget {
  const RecipesSection({super.key});

  @override
  State<RecipesSection> createState() => _RecipesSectionState();
}

class _RecipesSectionState extends State<RecipesSection> {
  static const _categories = [
    'Chicken',
    'Beef',
    'Seafood',
    'Vegetarian',
    'Pasta',
    'Dessert',
    'Breakfast',
  ];

  final _repo = RecipeRepository();
  final _db = DatabaseHelper.instance;
  final _searchController = TextEditingController();
  late final String _userId;

  List<Recipe> _results = [];
  List<SavedMeal> _favorites = [];
  bool _loading = false;
  bool _searched = false;
  bool _showFavorites = false;
  String? _activeCategory;

  @override
  void initState() {
    super.initState();
    _userId = AuthService().currentUser?.uid ?? '';
    _loadFavorites();
  }

  @override
  void dispose() {
    _repo.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadFavorites() async {
    final favs = await _db.getSavedMeals(_userId);
    if (mounted) setState(() => _favorites = favs);
  }

  bool _isFav(String? apiMealId) =>
      apiMealId != null && _favorites.any((f) => f.apiMealId == apiMealId);

  Future<void> _toggleFav(Recipe recipe) async {
    await _db.ensureUserProfile(_userId);
    final existing = _favorites
        .where((f) => f.apiMealId == recipe.apiMealId)
        .toList();
    if (existing.isNotEmpty) {
      await _db.deleteSavedMeal(existing.first.id!);
    } else {
      await _db.insertSavedMeal(SavedMeal(
        userId: _userId,
        apiMealId: recipe.apiMealId,
        mealName: recipe.name,
        imageUrl: recipe.imageUrl,
      ));
    }
    _loadFavorites();
  }

  Future<void> _search() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _searched = true;
      _showFavorites = false;
      _activeCategory = null;
    });
    final results = await _repo.searchByName(query);
    if (!mounted) return;
    setState(() {
      _results = results;
      _loading = false;
    });
  }

  Future<void> _browseCategory(String category) async {
    setState(() {
      _loading = true;
      _searched = true;
      _showFavorites = false;
      _activeCategory = category;
    });
    final results = await _repo.browseCategory(category);
    if (!mounted) return;
    setState(() {
      _results = results;
      _loading = false;
    });
  }

  Future<void> _logRecipe(Recipe recipe) async {
    final mealType = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Add to which meal?'),
            ),
            for (final type in kMealTypes)
              ListTile(
                title: Text(mealTypeLabel(type)),
                onTap: () => Navigator.of(context).pop(type),
              ),
          ],
        ),
      ),
    );
    if (mealType == null || !mounted) return;
    await showAddFoodDialog(
      context,
      userId: _userId,
      mealDate: isoDate(DateTime.now()),
      mealType: mealType,
      name: recipe.name,
      calories: recipe.calories,
      protein: recipe.protein,
      carbs: recipe.carbs,
      fat: recipe.fat,
      apiMealId: recipe.apiMealId,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: GlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _search(),
                    decoration: const InputDecoration(
                      hintText: 'Search recipes (e.g. chicken)',
                      border: InputBorder.none,
                    ),
                  ),
                ),
                IconButton(icon: const Icon(Icons.search), onPressed: _search),
              ],
            ),
          ),
        ),
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: FilterChip(
                  avatar: const Icon(Icons.favorite, size: 18),
                  label: Text('Favorites (${_favorites.length})'),
                  selected: _showFavorites,
                  onSelected: (_) => setState(() => _showFavorites = true),
                ),
              ),
              for (final c in _categories)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: FilterChip(
                    label: Text(c),
                    selected: !_showFavorites && _activeCategory == c,
                    onSelected: (_) => _browseCategory(c),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _showFavorites
              ? _favoritesView(theme)
              : _loading
                  ? const Center(child: CircularProgressIndicator())
                  : !_searched
                      ? _hint(theme, 'Search or pick a category to start.')
                      : _results.isEmpty
                          ? _hint(theme, 'No recipes found.')
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                              itemCount: _results.length,
                              itemBuilder: (context, i) =>
                                  _recipeCard(_results[i]),
                            ),
        ),
      ],
    );
  }

  Widget _favoritesView(ThemeData theme) {
    if (_favorites.isEmpty) {
      return _hint(theme, 'No favourites yet. Tap the heart on a recipe.');
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      itemCount: _favorites.length,
      itemBuilder: (context, i) {
        final f = _favorites[i];
        return _recipeCard(Recipe(
          apiMealId: f.apiMealId ?? 'saved:${f.id}',
          name: f.mealName ?? 'Saved meal',
          source: 'saved',
          imageUrl: f.imageUrl,
        ));
      },
    );
  }

  Widget _hint(ThemeData theme, String text) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(text,
              textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
        ),
      );

  Widget _recipeCard(Recipe recipe) {
    final theme = Theme.of(context);
    final fav = _isFav(recipe.apiMealId);
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(10),
      onTap: () => _logRecipe(recipe),
      child: Row(
        children: [
          _thumb(recipe.imageUrl, theme),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(recipe.name,
                    style: theme.textTheme.titleSmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(
                  recipe.hasNutrition
                      ? '${recipe.calories!.round()} kcal · P ${recipe.protein!.round()}g'
                      : 'Tap to add to a meal',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(fav ? Icons.favorite : Icons.favorite_border,
                color: fav ? Colors.redAccent : null),
            onPressed: () => _toggleFav(recipe),
          ),
          const Icon(Icons.add_circle_outline),
        ],
      ),
    );
  }

  Widget _thumb(String? url, ThemeData theme) {
    Widget fallback() => Container(
          width: 64,
          height: 64,
          color: theme.colorScheme.primaryContainer,
          child: Icon(Icons.restaurant,
              color: theme.colorScheme.onPrimaryContainer),
        );
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: url == null
          ? fallback()
          : Image.network(
              url,
              width: 64,
              height: 64,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, progress) =>
                  progress == null ? child : fallback(),
              errorBuilder: (_, __, ___) => fallback(),
            ),
    );
  }
}
