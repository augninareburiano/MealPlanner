import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/meal_log.dart';
import '../models/saved_meal.dart';
import '../models/user_profile.dart';

/// Single point of access to the on-device SQLite database.
///
/// Data is intentionally local-only and does NOT sync across devices. Access it
/// through [DatabaseHelper.instance].
class DatabaseHelper {
  DatabaseHelper._internal();
  static final DatabaseHelper instance = DatabaseHelper._internal();

  /// Test-only: builds a helper backed by an already-open [database] (e.g. an
  /// in-memory sqflite-ffi database) instead of the on-device file. Pair with
  /// [onConfigure] and [onCreate] so the test DB uses the same schema/PRAGMAs.
  @visibleForTesting
  DatabaseHelper.forTesting(Database database) : _database = database;

  static const _databaseName = 'foodgapp.db';
  static const _databaseVersion = 1;

  Database? _database;

  Future<Database> get database async => _database ??= await _open();

  Future<Database> _open() async {
    final databasesDir = await getDatabasesPath();
    final path = p.join(databasesDir, _databaseName);
    return openDatabase(
      path,
      version: _databaseVersion,
      onConfigure: onConfigure,
      onCreate: onCreate,
    );
  }

  /// Enforces foreign-key relationships (off by default in SQLite). Exposed so
  /// tests can open an equivalent database with the same configuration.
  @visibleForTesting
  static Future<void> onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  /// Creates the four tables on first open. Exposed for tests so an in-memory
  /// database can be built with the identical schema.
  @visibleForTesting
  static Future<void> onCreate(Database db, int version) async {
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

  // --- meal_log -----------------------------------------------------------

  Future<int> insertMealLog(MealLog log) async {
    final db = await database;
    return db.insert('meal_log', log.toMap());
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
}
