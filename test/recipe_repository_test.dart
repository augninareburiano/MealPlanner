import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:foodgapp/models/recipe.dart';
import 'package:foodgapp/services/api/spoonacular_service.dart';
import 'package:foodgapp/services/api/the_meal_db_service.dart';
import 'package:foodgapp/services/nutrition_cache_store.dart';
import 'package:foodgapp/services/recipe_repository.dart';

/// In-memory [NutritionCacheStore] so the repository can be tested without
/// sqflite.
class _MemoryCache implements NutritionCacheStore {
  final Map<String, Recipe> store = {};

  @override
  Future<Recipe?> get(String apiMealId) async => store[apiMealId];

  @override
  Future<void> put(Recipe recipe) async => store[recipe.apiMealId] = recipe;
}

/// Spoonacular `complexSearch` body with one fully-nutritioned result.
String _spoonSearchBody(int id, String title) => jsonEncode({
      'results': [
        {
          'id': id,
          'title': title,
          'image': 'https://img/$id.jpg',
          'nutrition': {
            'nutrients': [
              {'name': 'Calories', 'amount': 500.0, 'unit': 'kcal'},
              {'name': 'Protein', 'amount': 20.0, 'unit': 'g'},
              {'name': 'Carbohydrates', 'amount': 60.0, 'unit': 'g'},
              {'name': 'Fat', 'amount': 15.0, 'unit': 'g'},
            ],
          },
        },
      ],
    });

String _theMealDbBody(String id, String name) => jsonEncode({
      'meals': [
        {'idMeal': id, 'strMeal': name, 'strMealThumb': 'https://img/$id.jpg'},
      ],
    });

/// A TheMealDB service that always errors, for tests that shouldn't fall back.
TheMealDbService _deadMealDb() => TheMealDbService(
      client: MockClient((_) async => http.Response('nope', 500)),
    );

void main() {
  group('searchByName', () {
    test('returns Spoonacular recipes with nutrition and caches them',
        () async {
      final cache = _MemoryCache();
      final repo = RecipeRepository(
        spoonacular: SpoonacularService(
          apiKey: 'test',
          client: MockClient(
            (_) async => http.Response(_spoonSearchBody(716429, 'Pasta'), 200),
          ),
        ),
        theMealDb: _deadMealDb(),
        cache: cache,
      );

      final results = await repo.searchByName('pasta');

      expect(results, hasLength(1));
      final recipe = results.single;
      expect(recipe.apiMealId, 'spoonacular:716429');
      expect(recipe.name, 'Pasta');
      expect(recipe.calories, 500.0);
      expect(recipe.protein, 20.0);
      expect(recipe.hasNutrition, isTrue);
      // Cached as a side effect of the search.
      expect(cache.store['spoonacular:716429'], isNotNull);
    });

    test('falls back to TheMealDB when Spoonacular is over quota (402)',
        () async {
      final repo = RecipeRepository(
        spoonacular: SpoonacularService(
          apiKey: 'test',
          client: MockClient((_) async => http.Response('quota', 402)),
        ),
        theMealDb: TheMealDbService(
          client: MockClient(
            (_) async =>
                http.Response(_theMealDbBody('52772', 'Teriyaki Chicken'), 200),
          ),
        ),
        cache: _MemoryCache(),
      );

      final results = await repo.searchByName('chicken');

      expect(results, hasLength(1));
      expect(results.single.source, 'themealdb');
      expect(results.single.name, 'Teriyaki Chicken');
    });

    test('falls back to TheMealDB when Spoonacular has a network error',
        () async {
      final repo = RecipeRepository(
        spoonacular: SpoonacularService(
          apiKey: 'test',
          client: MockClient((_) async => throw Exception('no network')),
        ),
        theMealDb: TheMealDbService(
          client: MockClient(
            (_) async => http.Response(_theMealDbBody('1', 'Soup'), 200),
          ),
        ),
        cache: _MemoryCache(),
      );

      final results = await repo.searchByName('soup');
      expect(results.single.source, 'themealdb');
    });

    test('falls back when Spoonacular succeeds but returns no matches',
        () async {
      final repo = RecipeRepository(
        spoonacular: SpoonacularService(
          apiKey: 'test',
          client: MockClient(
            (_) async => http.Response(jsonEncode({'results': []}), 200),
          ),
        ),
        theMealDb: TheMealDbService(
          client: MockClient(
            (_) async => http.Response(_theMealDbBody('9', 'Backup'), 200),
          ),
        ),
        cache: _MemoryCache(),
      );

      final results = await repo.searchByName('obscure');
      expect(results.single.name, 'Backup');
    });

    test('returns empty list (no throw) when both sources fail', () async {
      final repo = RecipeRepository(
        spoonacular: SpoonacularService(
          apiKey: 'test',
          client: MockClient((_) async => http.Response('boom', 500)),
        ),
        theMealDb: _deadMealDb(),
        cache: _MemoryCache(),
      );

      expect(await repo.searchByName('anything'), isEmpty);
    });

    test('empty query short-circuits without any HTTP call', () async {
      var called = false;
      final repo = RecipeRepository(
        spoonacular: SpoonacularService(
          apiKey: 'test',
          client: MockClient((_) async {
            called = true;
            return http.Response('{}', 200);
          }),
        ),
        theMealDb: _deadMealDb(),
        cache: _MemoryCache(),
      );

      expect(await repo.searchByName('   '), isEmpty);
      expect(called, isFalse);
    });
  });

  group('getNutrition (cache-first)', () {
    test('serves from cache without any HTTP call on repeat lookup', () async {
      var infoCalls = 0;
      final repo = RecipeRepository(
        spoonacular: SpoonacularService(
          apiKey: 'test',
          client: MockClient((request) async {
            if (request.url.path.contains('/information')) infoCalls++;
            return http.Response(
              jsonEncode({
                'id': 999,
                'title': 'Omelette',
                'image': 'https://img/999.jpg',
                'nutrition': {
                  'nutrients': [
                    {'name': 'Calories', 'amount': 300.0},
                    {'name': 'Protein', 'amount': 21.0},
                    {'name': 'Carbohydrates', 'amount': 2.0},
                    {'name': 'Fat', 'amount': 22.0},
                  ],
                },
              }),
              200,
            );
          }),
        ),
        theMealDb: _deadMealDb(),
        cache: _MemoryCache(),
      );

      // First lookup: cache miss -> one network call.
      final first = await repo.getNutrition('spoonacular:999');
      expect(first?.name, 'Omelette');
      expect(infoCalls, 1);

      // Second lookup: served from cache -> no additional network call.
      final second = await repo.getNutrition('spoonacular:999');
      expect(second?.calories, 300.0);
      expect(infoCalls, 1, reason: 'repeat lookup must hit the cache');
    });

    test('returns null for TheMealDB items (no nutrition to fetch)', () async {
      final repo = RecipeRepository(
        spoonacular: SpoonacularService(
          apiKey: 'test',
          client: MockClient((_) async => http.Response('{}', 200)),
        ),
        theMealDb: _deadMealDb(),
        cache: _MemoryCache(),
      );

      expect(await repo.getNutrition('themealdb:52772'), isNull);
    });
  });

  group('searchByNutrition', () {
    test('parses findByNutrients string macros like "13g"', () async {
      final repo = RecipeRepository(
        spoonacular: SpoonacularService(
          apiKey: 'test',
          client: MockClient(
            (_) async => http.Response(
              jsonEncode([
                {
                  'id': 123,
                  'title': 'Boiled Egg',
                  'image': 'https://img/123.jpg',
                  'calories': 155,
                  'protein': '13g',
                  'carbs': '1g',
                  'fat': '11g',
                },
              ]),
              200,
            ),
          ),
        ),
        theMealDb: _deadMealDb(),
        cache: _MemoryCache(),
      );

      final results = await repo.searchByNutrition(
        minProtein: 10,
        maxCalories: 200,
      );

      expect(results.single.name, 'Boiled Egg');
      expect(results.single.protein, 13.0);
      expect(results.single.calories, 155.0);
    });

    test('returns empty (no throw) when Spoonacular is unavailable', () async {
      final repo = RecipeRepository(
        spoonacular: SpoonacularService(
          apiKey: 'test',
          client: MockClient((_) async => http.Response('down', 503)),
        ),
        theMealDb: _deadMealDb(),
        cache: _MemoryCache(),
      );

      expect(await repo.searchByNutrition(maxCalories: 500), isEmpty);
    });

    test('missing API key is treated as unavailable', () async {
      final repo = RecipeRepository(
        spoonacular: SpoonacularService(
          apiKey: '', // not configured
          client: MockClient((_) async => http.Response('{}', 200)),
        ),
        theMealDb: _deadMealDb(),
        cache: _MemoryCache(),
      );

      expect(await repo.searchByNutrition(maxCalories: 500), isEmpty);
    });
  });
}
