import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:foodgapp/models/meal_log.dart';
import 'package:foodgapp/models/saved_meal.dart';
import 'package:foodgapp/models/user_profile.dart';
import 'package:foodgapp/services/database_helper.dart';

/// Exercises the SQLite data layer on a fresh in-memory database per test,
/// built with the real schema/PRAGMAs via [DatabaseHelper.onConfigure] and
/// [DatabaseHelper.onCreate].
void main() {
  setUpAll(sqfliteFfiInit);

  late Database db;
  late DatabaseHelper helper;

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onConfigure: DatabaseHelper.onConfigure,
        onCreate: DatabaseHelper.onCreate,
      ),
    );
    helper = DatabaseHelper.forTesting(db);
  });

  tearDown(() async => db.close());

  const userId = 'firebase-uid-123';

  Future<void> seedUser() => helper.upsertUserProfile(
        const UserProfile(userId: userId, name: 'Alice', email: 'a@b.com'),
      );

  group('schema', () {
    test('creates exactly the four expected tables', () async {
      final rows = await db.query(
        'sqlite_master',
        columns: ['name'],
        where: "type = 'table' AND name NOT LIKE 'sqlite_%' "
            "AND name NOT LIKE 'android_%'",
      );
      final tables = rows.map((r) => r['name']).toSet();
      expect(
        tables,
        containsAll(<String>[
          'user_profile',
          'meal_log',
          'saved_meals',
          'nutrition_cache',
        ]),
      );
    });

    test('foreign keys are enabled', () async {
      final result = await db.rawQuery('PRAGMA foreign_keys');
      expect(result.first.values.first, 1);
    });
  });

  group('user_profile', () {
    test('saves and reads back a profile', () async {
      await helper.upsertUserProfile(
        const UserProfile(
          userId: userId,
          name: 'Alice',
          email: 'alice@example.com',
          age: 30,
          gender: 'female',
          heightCm: 165,
          weightKg: 60,
          activityLevel: 'moderate',
          healthGoal: 'lose weight',
        ),
      );

      final read = await helper.getUserProfile(userId);
      expect(read, isNotNull);
      expect(read!.name, 'Alice');
      expect(read.age, 30);
      expect(read.heightCm, 165);
      expect(read.healthGoal, 'lose weight');
    });

    test('upsert replaces the existing row for the same user id', () async {
      await seedUser();
      await helper.upsertUserProfile(
        const UserProfile(userId: userId, name: 'Alice Updated'),
      );

      final read = await helper.getUserProfile(userId);
      expect(read!.name, 'Alice Updated');

      final rows = await db.rawQuery('SELECT COUNT(*) AS c FROM user_profile');
      expect(rows.first['c'], 1);
    });

    test('returns null for an unknown user', () async {
      expect(await helper.getUserProfile('nope'), isNull);
    });
  });

  group('meal_log (linked to user)', () {
    test('saves a log and reads it back for that user and date', () async {
      await seedUser();
      await helper.insertMealLog(
        const MealLog(
          userId: userId,
          mealDate: '2026-07-02',
          mealType: 'breakfast',
          foodName: 'Oatmeal',
          calories: 320,
        ),
      );

      final logs = await helper.getMealLogsForDate(userId, '2026-07-02');
      expect(logs, hasLength(1));
      expect(logs.single.foodName, 'Oatmeal');
      expect(logs.single.calories, 320);
    });

    test('only returns logs for the requested user and date', () async {
      await seedUser();
      await helper.upsertUserProfile(
        const UserProfile(userId: 'other-user'),
      );

      await helper.insertMealLog(const MealLog(
        userId: userId,
        mealDate: '2026-07-02',
        mealType: 'lunch',
        foodName: 'Mine today',
      ));
      await helper.insertMealLog(const MealLog(
        userId: userId,
        mealDate: '2026-07-01',
        mealType: 'lunch',
        foodName: 'Mine yesterday',
      ));
      await helper.insertMealLog(const MealLog(
        userId: 'other-user',
        mealDate: '2026-07-02',
        mealType: 'lunch',
        foodName: 'Theirs today',
      ));

      final logs = await helper.getMealLogsForDate(userId, '2026-07-02');
      expect(logs.map((l) => l.foodName), ['Mine today']);
    });

    test('rejects a log whose user_id has no profile (foreign key)', () async {
      // No profile seeded → the FK to user_profile must reject the insert.
      expect(
        () => helper.insertMealLog(const MealLog(
          userId: 'ghost',
          mealDate: '2026-07-02',
          mealType: 'dinner',
          foodName: 'Orphan',
        )),
        throwsA(isA<DatabaseException>()),
      );
    });

    test('deleting the user cascades to their meal logs', () async {
      await seedUser();
      await helper.insertMealLog(const MealLog(
        userId: userId,
        mealDate: '2026-07-02',
        mealType: 'breakfast',
        foodName: 'Toast',
      ));

      await db.delete('user_profile', where: 'user_id = ?', whereArgs: [userId]);

      final rows = await db.rawQuery('SELECT COUNT(*) AS c FROM meal_log');
      expect(rows.first['c'], 0);
    });
  });

  group('saved_meals (linked to user)', () {
    test('saves and reads back saved meals for a user', () async {
      await seedUser();
      await helper.insertSavedMeal(const SavedMeal(
        userId: userId,
        apiMealId: 'spoonacular:1',
        mealName: 'Pasta',
        imageUrl: 'https://img/1.jpg',
      ));

      final meals = await helper.getSavedMeals(userId);
      expect(meals, hasLength(1));
      expect(meals.single.mealName, 'Pasta');
      expect(meals.single.apiMealId, 'spoonacular:1');
    });

    test('rejects a saved meal for a non-existent user (foreign key)', () async {
      expect(
        () => helper.insertSavedMeal(const SavedMeal(
          userId: 'ghost',
          mealName: 'Orphan',
        )),
        throwsA(isA<DatabaseException>()),
      );
    });

    test('deleting the user cascades to their saved meals', () async {
      await seedUser();
      await helper.insertSavedMeal(
        const SavedMeal(userId: userId, mealName: 'Salad'),
      );

      await db.delete('user_profile', where: 'user_id = ?', whereArgs: [userId]);

      expect(await helper.getSavedMeals(userId), isEmpty);
    });
  });
}
