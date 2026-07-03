import '../models/recipe.dart';
import 'database_helper.dart';

/// A small read/write cache for recipe nutrition, keyed by
/// [Recipe.apiMealId].
///
/// Kept as an interface so [RecipeRepository] can be unit-tested with an
/// in-memory fake, while production uses the SQLite-backed [DbNutritionCache].
abstract class NutritionCacheStore {
  Future<Recipe?> get(String apiMealId);
  Future<void> put(Recipe recipe);
}

/// SQLite-backed cache using the `nutrition_cache` table via [DatabaseHelper].
class DbNutritionCache implements NutritionCacheStore {
  DbNutritionCache({
    DatabaseHelper? db,
    this.maxAge = const Duration(days: 7),
  }) : _db = db ?? DatabaseHelper.instance;

  final DatabaseHelper _db;

  /// Cached entries older than this are treated as a miss and re-fetched.
  final Duration maxAge;

  @override
  Future<Recipe?> get(String apiMealId) =>
      _db.getCachedRecipe(apiMealId, maxAge: maxAge);

  @override
  Future<void> put(Recipe recipe) => _db.cacheRecipe(recipe);
}
