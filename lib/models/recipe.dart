import 'dart:convert';

/// A recipe with its nutrition facts, normalised across the two data sources
/// (Spoonacular and TheMealDB) so the rest of the app doesn't care where it
/// came from.
///
/// [apiMealId] is source-prefixed (e.g. `spoonacular:715538`,
/// `themealdb:52772`) so ids from the two sources can never collide as
/// `nutrition_cache` keys.
class Recipe {
  final String apiMealId;
  final String name;
  final String? imageUrl;
  final double? calories;
  final double? protein;
  final double? carbs;
  final double? fat;

  /// Where this came from: `spoonacular` or `themealdb`.
  final String source;

  const Recipe({
    required this.apiMealId,
    required this.name,
    required this.source,
    this.imageUrl,
    this.calories,
    this.protein,
    this.carbs,
    this.fat,
  });

  /// True when the four macro/energy figures are all present.
  bool get hasNutrition =>
      calories != null && protein != null && carbs != null && fat != null;

  // --- Spoonacular --------------------------------------------------------

  /// Parses one item from Spoonacular `complexSearch` (with
  /// `addRecipeNutrition=true`) or `recipes/{id}/information?includeNutrition`.
  ///
  /// Both shapes carry `nutrition.nutrients: [{name, amount, unit}, ...]`.
  factory Recipe.fromSpoonacular(Map<String, dynamic> json) {
    final nutrients =
        (json['nutrition']?['nutrients'] as List?)?.cast<Map<String, dynamic>>();

    double? nutrient(String name) {
      if (nutrients == null) return null;
      for (final n in nutrients) {
        if ((n['name'] as String?)?.toLowerCase() == name.toLowerCase()) {
          return (n['amount'] as num?)?.toDouble();
        }
      }
      return null;
    }

    return Recipe(
      apiMealId: 'spoonacular:${json['id']}',
      name: (json['title'] as String?) ?? 'Untitled',
      source: 'spoonacular',
      imageUrl: json['image'] as String?,
      calories: nutrient('Calories'),
      protein: nutrient('Protein'),
      carbs: nutrient('Carbohydrates'),
      fat: nutrient('Fat'),
    );
  }

  /// Parses one item from Spoonacular `findByNutrients`, which returns the
  /// macro fields as flat top-level numbers instead of a nutrients list.
  factory Recipe.fromSpoonacularNutrients(Map<String, dynamic> json) => Recipe(
        apiMealId: 'spoonacular:${json['id']}',
        name: (json['title'] as String?) ?? 'Untitled',
        source: 'spoonacular',
        imageUrl: json['image'] as String?,
        calories: (json['calories'] as num?)?.toDouble(),
        protein: _stripGrams(json['protein']),
        carbs: _stripGrams(json['carbs']),
        fat: _stripGrams(json['fat']),
      );

  // --- TheMealDB ----------------------------------------------------------

  /// Parses one `meals[]` item from TheMealDB. TheMealDB has no nutrition
  /// data, so the macro fields stay null (the app treats it as a name-only
  /// backup result).
  factory Recipe.fromTheMealDb(Map<String, dynamic> json) => Recipe(
        apiMealId: 'themealdb:${json['idMeal']}',
        name: (json['strMeal'] as String?) ?? 'Untitled',
        source: 'themealdb',
        imageUrl: json['strMealThumb'] as String?,
      );

  // --- nutrition_cache ----------------------------------------------------

  Map<String, Object?> toCacheMap() => {
        'api_meal_id': apiMealId,
        'meal_name': name,
        'calories': calories,
        'protein': protein,
        'carbs': carbs,
        'fat': fat,
        'raw_json': jsonEncode({
          'image_url': imageUrl,
          'source': source,
        }),
        'cached_at': DateTime.now().millisecondsSinceEpoch,
      };

  factory Recipe.fromCacheMap(Map<String, Object?> map) {
    final raw = map['raw_json'] as String?;
    final extra = raw == null
        ? const <String, dynamic>{}
        : jsonDecode(raw) as Map<String, dynamic>;
    return Recipe(
      apiMealId: map['api_meal_id'] as String,
      name: (map['meal_name'] as String?) ?? 'Untitled',
      source: (extra['source'] as String?) ?? 'cache',
      imageUrl: extra['image_url'] as String?,
      calories: (map['calories'] as num?)?.toDouble(),
      protein: (map['protein'] as num?)?.toDouble(),
      carbs: (map['carbs'] as num?)?.toDouble(),
      fat: (map['fat'] as num?)?.toDouble(),
    );
  }

  /// Spoonacular's `findByNutrients` returns macros as strings like `"12g"`.
  static double? _stripGrams(Object? value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    final digits = RegExp(r'[\d.]+').firstMatch(value.toString())?.group(0);
    return digits == null ? null : double.tryParse(digits);
  }
}
