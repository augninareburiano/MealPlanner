import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:foodgapp/models/recipe.dart';
import 'package:foodgapp/screens/nutrition_search_screen.dart';
import 'package:foodgapp/services/api/spoonacular_service.dart';
import 'package:foodgapp/services/api/the_meal_db_service.dart';
import 'package:foodgapp/services/nutrition_cache_store.dart';
import 'package:foodgapp/services/nutrition_facts_service.dart';
import 'package:foodgapp/services/recipe_repository.dart';

/// In-memory cache so the screen never reaches sqflite.
class _MemoryCache implements NutritionCacheStore {
  final Map<String, Recipe> store = {};

  @override
  Future<Recipe?> get(String apiMealId) async => store[apiMealId];

  @override
  Future<void> put(Recipe recipe) async => store[recipe.apiMealId] = recipe;
}

/// One Spoonacular search hit. No `image` key: widget tests can't load network
/// images, and the thumbnail is not what these tests are about.
String _searchBody() => jsonEncode({
      'results': [
        {
          'id': 715538,
          'title': 'Chicken Adobo',
          'servings': 4,
          'nutrition': {
            'nutrients': [
              {'name': 'Calories', 'amount': 500.0, 'unit': 'kcal'},
              {'name': 'Protein', 'amount': 30.0, 'unit': 'g'},
              {'name': 'Carbohydrates', 'amount': 60.0, 'unit': 'g'},
              {'name': 'Fat', 'amount': 20.0, 'unit': 'g'},
            ],
          },
        },
      ],
    });

NutritionFactsService _service({String apiKey = 'test', String? body}) =>
    NutritionFactsService(
      repository: RecipeRepository(
        spoonacular: SpoonacularService(
          apiKey: apiKey,
          client: MockClient(
            (_) async => http.Response(body ?? _searchBody(), 200),
          ),
        ),
        theMealDb: TheMealDbService(
          client: MockClient((_) async => http.Response('nope', 500)),
        ),
        cache: _MemoryCache(),
      ),
    );

Future<void> _pump(WidgetTester tester, NutritionFactsService service) =>
    tester.pumpWidget(
      MaterialApp(home: NutritionSearchScreen(service: service)),
    );

void main() {
  testWidgets('opens on the search prompt with tappable suggestions',
      (tester) async {
    await _pump(tester, _service());

    expect(find.text('Nutrition Facts'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Chicken adobo'), findsOneWidget);
    expect(find.text('Sinigang'), findsOneWidget);
  });

  testWidgets('a search renders results with their macro summary',
      (tester) async {
    await _pump(tester, _service());

    await tester.enterText(find.byType(TextField), 'adobo');
    await tester.tap(find.byTooltip('Search'));
    await tester.pumpAndSettle();

    expect(find.text('Chicken Adobo'), findsOneWidget);
    expect(find.textContaining('500 kcal'), findsOneWidget);
    expect(find.textContaining('P 30 g'), findsOneWidget);
    expect(find.textContaining('per serving'), findsOneWidget);
  });

  testWidgets('an empty result set explains itself instead of going blank',
      (tester) async {
    await _pump(tester, _service(body: jsonEncode({'results': []})));

    await tester.enterText(find.byType(TextField), 'nothing at all');
    await tester.tap(find.byTooltip('Search'));
    await tester.pumpAndSettle();

    expect(find.textContaining('No matches for'), findsOneWidget);
  });

  testWidgets('warns up front when no nutrition source is configured',
      (tester) async {
    await _pump(tester, _service(apiKey: ''));

    expect(
      find.textContaining('Nutrition data source is not set up'),
      findsOneWidget,
    );
  });

  testWidgets('no warning banner when a nutrition source is configured',
      (tester) async {
    await _pump(tester, _service());

    expect(find.textContaining('Nutrition data source is not set up'),
        findsNothing);
  });
}
