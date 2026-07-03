import '../models/recipe.dart';
import 'api/api_exceptions.dart';
import 'api/spoonacular_service.dart';
import 'api/the_meal_db_service.dart';
import 'nutrition_cache_store.dart';

/// Single entry point the app uses for recipes and nutrition. It hides the two
/// data sources and the cache behind one API.
///
/// Policy:
///  * Spoonacular is primary; TheMealDB is the backup when Spoonacular is
///    unavailable, over quota, or returns nothing.
///  * Per-recipe nutrition is cached in `nutrition_cache`. [getNutrition]
///    checks the cache before the network, so repeat lookups don't call out
///    again (the caching that drives the response-rate goal).
///  * Failures and empty responses resolve to `[]` / `null` instead of
///    throwing, so the UI never crashes on a flaky network.
class RecipeRepository {
  RecipeRepository({
    SpoonacularService? spoonacular,
    TheMealDbService? theMealDb,
    NutritionCacheStore? cache,
  })  : _spoonacular = spoonacular ?? SpoonacularService(),
        _theMealDb = theMealDb ?? TheMealDbService(),
        _cache = cache ?? DbNutritionCache();

  final SpoonacularService _spoonacular;
  final TheMealDbService _theMealDb;
  final NutritionCacheStore _cache;

  /// Searches recipes by name. Tries Spoonacular, falls back to TheMealDB when
  /// Spoonacular fails or finds nothing. Results with nutrition are cached.
  Future<List<Recipe>> searchByName(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];

    List<Recipe> results;
    try {
      results = await _spoonacular.searchByName(trimmed);
    } on ApiException {
      results = const [];
    }

    // Backup source when the primary errored out or simply had no matches.
    if (results.isEmpty) {
      results = await _searchBackup(trimmed);
    }

    await _cacheAll(results);
    return results;
  }

  /// Browses recipes in a category via TheMealDB (e.g. `Chicken`, `Seafood`).
  Future<List<Recipe>> browseCategory(String category) async {
    return _searchBackup(category, byCategory: true);
  }

  /// Searches recipes by a nutrition window (calories / macros). Spoonacular
  /// only — TheMealDB can't filter by nutrition, so there's no fallback.
  Future<List<Recipe>> searchByNutrition({
    int? minCalories,
    int? maxCalories,
    int? minProtein,
    int? maxProtein,
    int? minCarbs,
    int? maxCarbs,
    int? minFat,
    int? maxFat,
    int number = 10,
  }) async {
    try {
      final results = await _spoonacular.searchByNutrition(
        minCalories: minCalories,
        maxCalories: maxCalories,
        minProtein: minProtein,
        maxProtein: maxProtein,
        minCarbs: minCarbs,
        maxCarbs: maxCarbs,
        minFat: minFat,
        maxFat: maxFat,
        number: number,
      );
      await _cacheAll(results);
      return results;
    } on ApiException {
      return [];
    }
  }

  /// Returns full nutrition for a recipe, cache-first. Only Spoonacular items
  /// can be fetched on a cache miss; TheMealDB items have no nutrition, so
  /// they resolve to null unless already cached.
  Future<Recipe?> getNutrition(String apiMealId) async {
    final cached = await _cache.get(apiMealId);
    if (cached != null) return cached;

    Recipe? fetched;
    try {
      const prefix = 'spoonacular:';
      if (apiMealId.startsWith(prefix)) {
        fetched = await _spoonacular.getInformation(
          apiMealId.substring(prefix.length),
        );
      }
    } on ApiException {
      return null;
    }

    if (fetched != null && fetched.hasNutrition) {
      await _cache.put(fetched);
    }
    return fetched;
  }

  Future<List<Recipe>> _searchBackup(
    String query, {
    bool byCategory = false,
  }) async {
    try {
      return byCategory
          ? await _theMealDb.filterByCategory(query)
          : await _theMealDb.searchByName(query);
    } on ApiException {
      return [];
    }
  }

  /// Caches only results that actually carry nutrition, so we never store
  /// null-macro (TheMealDB) rows as if they were complete.
  Future<void> _cacheAll(List<Recipe> recipes) async {
    for (final recipe in recipes) {
      if (recipe.hasNutrition) await _cache.put(recipe);
    }
  }

  void dispose() {
    _spoonacular.dispose();
    _theMealDb.dispose();
  }
}
