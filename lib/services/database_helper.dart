import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/exercise_entry.dart';
import '../models/grocery_item.dart';
import '../models/meal_log.dart';
import '../models/recipe.dart';
import '../models/saved_meal.dart';
import '../models/user_profile.dart';
import '../models/weight_entry.dart';

/// Single point of access to the on-device SQLite database.
///
/// Data is intentionally local-only and does NOT sync across devices. Access it
/// through [DatabaseHelper.instance].
class DatabaseHelper {
  DatabaseHelper._internal();
  static final DatabaseHelper instance = DatabaseHelper._internal();

  static const _databaseName = 'foodgapp.db';
  static const _databaseVersion = 3;

  Database? _database;

  Future<Database> get database async => _database ??= await _open();

  Future<Database> _open() async {
    final databasesDir = await getDatabasesPath();
    final path = p.join(databasesDir, _databaseName);
    return openDatabase(
      path,
      version: _databaseVersion,
      onConfigure: (db) async {
        // Enforce foreign-key relationships (off by default in SQLite).
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  /// Adds tables introduced after v1 to already-installed databases.
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createWeightAndGrocery(db);
    }
    if (oldVersion < 3) {
      await _createWaterAndExercise(db);
      await db.execute('ALTER TABLE user_profile ADD COLUMN allergies TEXT');
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE user_profile (
        user_id TEXT PRIMARY KEY,
        name TEXT,
        email TEXT,
        contact_number TEXT,
        age INTEGER,
        gender TEXT,
        height_cm REAL,
        weight_kg REAL,
        activity_level TEXT,
        dietary_preferences TEXT,
        allergies TEXT,
        health_goal TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE meal_log (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT NOT NULL,
        meal_date TEXT NOT NULL,
        meal_type TEXT NOT NULL,
        food_name TEXT NOT NULL,
        serving_size TEXT,
        calories REAL,
        protein REAL,
        carbs REAL,
        fat REAL,
        api_meal_id TEXT,
        FOREIGN KEY (user_id) REFERENCES user_profile (user_id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE saved_meals (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT NOT NULL,
        api_meal_id TEXT,
        meal_name TEXT,
        image_url TEXT,
        FOREIGN KEY (user_id) REFERENCES user_profile (user_id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE nutrition_cache (
        api_meal_id TEXT PRIMARY KEY,
        meal_name TEXT,
        calories REAL,
        protein REAL,
        carbs REAL,
        fat REAL,
        raw_json TEXT,
        cached_at INTEGER
      )
    ''');

    await _createWeightAndGrocery(db);
    await _createWaterAndExercise(db);
  }

  Future<void> _createWaterAndExercise(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS water_log (
        user_id TEXT NOT NULL,
        entry_date TEXT NOT NULL,
        glasses INTEGER NOT NULL DEFAULT 0,
        PRIMARY KEY (user_id, entry_date),
        FOREIGN KEY (user_id) REFERENCES user_profile (user_id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS exercise_log (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT NOT NULL,
        entry_date TEXT NOT NULL,
        name TEXT NOT NULL,
        calories REAL NOT NULL,
        FOREIGN KEY (user_id) REFERENCES user_profile (user_id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> _createWeightAndGrocery(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS weight_log (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT NOT NULL,
        entry_date TEXT NOT NULL,
        weight_kg REAL NOT NULL,
        FOREIGN KEY (user_id) REFERENCES user_profile (user_id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS grocery_item (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT NOT NULL,
        name TEXT NOT NULL,
        checked INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (user_id) REFERENCES user_profile (user_id) ON DELETE CASCADE
      )
    ''');
  }

  // --- user_profile -------------------------------------------------------

  /// Inserts or replaces the profile row keyed by [UserProfile.userId].
  Future<void> upsertUserProfile(UserProfile profile) async {
    final db = await database;
    await db.insert(
      'user_profile',
      profile.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<UserProfile?> getUserProfile(String userId) async {
    final db = await database;
    final rows = await db.query(
      'user_profile',
      where: 'user_id = ?',
      whereArgs: [userId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return UserProfile.fromMap(rows.first);
  }

  /// Ensures a `user_profile` row exists for [userId] so linked rows satisfy
  /// the foreign key. Inserts a minimal row only when one isn't there yet.
  Future<void> ensureUserProfile(String userId, {String? email}) async {
    final db = await database;
    await db.insert(
      'user_profile',
      {'user_id': userId, 'email': email},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  // --- meal_log -----------------------------------------------------------

  Future<int> insertMealLog(MealLog log) async {
    final db = await database;
    return db.insert('meal_log', log.toMap());
  }

  Future<int> updateMealLog(MealLog log) async {
    final db = await database;
    return db.update(
      'meal_log',
      log.toMap(),
      where: 'id = ?',
      whereArgs: [log.id],
    );
  }

  Future<int> deleteMealLog(int id) async {
    final db = await database;
    return db.delete('meal_log', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<MealLog>> getMealLogsForDate(
    String userId,
    String mealDate,
  ) async {
    final db = await database;
    final rows = await db.query(
      'meal_log',
      where: 'user_id = ? AND meal_date = ?',
      whereArgs: [userId, mealDate],
      orderBy: 'id ASC',
    );
    return rows.map(MealLog.fromMap).toList();
  }

  // --- saved_meals --------------------------------------------------------

  Future<int> insertSavedMeal(SavedMeal meal) async {
    final db = await database;
    return db.insert('saved_meals', meal.toMap());
  }

  Future<List<SavedMeal>> getSavedMeals(String userId) async {
    final db = await database;
    final rows = await db.query(
      'saved_meals',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'id DESC',
    );
    return rows.map(SavedMeal.fromMap).toList();
  }

  Future<int> deleteSavedMeal(int id) async {
    final db = await database;
    return db.delete('saved_meals', where: 'id = ?', whereArgs: [id]);
  }

  // --- nutrition_cache ----------------------------------------------------

  /// Returns the cached [Recipe] for [apiMealId], or null when it's missing or
  /// older than [maxAge].
  Future<Recipe?> getCachedRecipe(String apiMealId, {Duration? maxAge}) async {
    final db = await database;
    final rows = await db.query(
      'nutrition_cache',
      where: 'api_meal_id = ?',
      whereArgs: [apiMealId],
      limit: 1,
    );
    if (rows.isEmpty) return null;

    final row = rows.first;
    if (maxAge != null) {
      final cachedAt = (row['cached_at'] as num?)?.toInt() ?? 0;
      final age = DateTime.now().millisecondsSinceEpoch - cachedAt;
      if (age > maxAge.inMilliseconds) return null;
    }
    return Recipe.fromCacheMap(row);
  }

  /// Inserts or refreshes the cached nutrition for [recipe].
  Future<void> cacheRecipe(Recipe recipe) async {
    final db = await database;
    await db.insert(
      'nutrition_cache',
      recipe.toCacheMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // --- weight_log ---------------------------------------------------------

  Future<int> insertWeightEntry(WeightEntry entry) async {
    final db = await database;
    return db.insert('weight_log', entry.toMap());
  }

  /// Weigh-ins for [userId], newest first.
  Future<List<WeightEntry>> getWeightEntries(String userId) async {
    final db = await database;
    final rows = await db.query(
      'weight_log',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'entry_date DESC, id DESC',
    );
    return rows.map(WeightEntry.fromMap).toList();
  }

  Future<int> deleteWeightEntry(int id) async {
    final db = await database;
    return db.delete('weight_log', where: 'id = ?', whereArgs: [id]);
  }

  // --- grocery_item -------------------------------------------------------

  Future<int> insertGroceryItem(GroceryItem item) async {
    final db = await database;
    return db.insert('grocery_item', item.toMap());
  }

  Future<List<GroceryItem>> getGroceryItems(String userId) async {
    final db = await database;
    final rows = await db.query(
      'grocery_item',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'checked ASC, id ASC',
    );
    return rows.map(GroceryItem.fromMap).toList();
  }

  Future<int> setGroceryChecked(int id, bool checked) async {
    final db = await database;
    return db.update(
      'grocery_item',
      {'checked': checked ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteGroceryItem(int id) async {
    final db = await database;
    return db.delete('grocery_item', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> clearCheckedGroceryItems(String userId) async {
    final db = await database;
    return db.delete(
      'grocery_item',
      where: 'user_id = ? AND checked = 1',
      whereArgs: [userId],
    );
  }

  // --- water_log ----------------------------------------------------------

  Future<int> getWaterGlasses(String userId, String date) async {
    final db = await database;
    final rows = await db.query(
      'water_log',
      columns: ['glasses'],
      where: 'user_id = ? AND entry_date = ?',
      whereArgs: [userId, date],
      limit: 1,
    );
    if (rows.isEmpty) return 0;
    return (rows.first['glasses'] as num?)?.toInt() ?? 0;
  }

  Future<void> setWaterGlasses(String userId, String date, int glasses) async {
    final db = await database;
    await ensureUserProfile(userId);
    await db.insert(
      'water_log',
      {'user_id': userId, 'entry_date': date, 'glasses': glasses},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // --- exercise_log -------------------------------------------------------

  Future<int> insertExercise(ExerciseEntry entry) async {
    final db = await database;
    await ensureUserProfile(entry.userId);
    return db.insert('exercise_log', entry.toMap());
  }

  Future<List<ExerciseEntry>> getExercisesForDate(
    String userId,
    String date,
  ) async {
    final db = await database;
    final rows = await db.query(
      'exercise_log',
      where: 'user_id = ? AND entry_date = ?',
      whereArgs: [userId, date],
      orderBy: 'id ASC',
    );
    return rows.map(ExerciseEntry.fromMap).toList();
  }

  Future<int> deleteExercise(int id) async {
    final db = await database;
    return db.delete('exercise_log', where: 'id = ?', whereArgs: [id]);
  }
}
