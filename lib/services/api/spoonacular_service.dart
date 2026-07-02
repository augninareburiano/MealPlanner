import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config/api_config.dart';
import '../../models/recipe.dart';
import 'api_exceptions.dart';

/// Primary recipe/nutrition source: the Spoonacular REST API.
///
/// Every method throws an [ApiException] subclass on failure so the caller
/// ([RecipeRepository]) can decide whether to fall back to the backup source.
/// The HTTP client is injectable for testing.
class SpoonacularService {
  SpoonacularService({
    http.Client? client,
    String? apiKey,
    this.timeout = const Duration(seconds: 10),
  })  : _client = client ?? http.Client(),
        _apiKey = apiKey ?? ApiConfig.spoonacularApiKey;

  static const _host = 'api.spoonacular.com';

  final http.Client _client;
  final String _apiKey;
  final Duration timeout;

  bool get isConfigured => _apiKey.isNotEmpty;

  /// Searches recipes by free text, with nutrition included in one call.
  Future<List<Recipe>> searchByName(String query, {int number = 10}) async {
    final json = await _get('/recipes/complexSearch', {
      'query': query,
      'number': '$number',
      'addRecipeNutrition': 'true',
    });
    final results = (json['results'] as List?) ?? const [];
    return results
        .cast<Map<String, dynamic>>()
        .map(Recipe.fromSpoonacular)
        .toList();
  }

  /// Searches recipes that fit a nutrition window (calories / macros).
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
    final params = <String, String>{'number': '$number'};
    void add(String key, int? value) {
      if (value != null) params[key] = '$value';
    }

    add('minCalories', minCalories);
    add('maxCalories', maxCalories);
    add('minProtein', minProtein);
    add('maxProtein', maxProtein);
    add('minCarbs', minCarbs);
    add('maxCarbs', maxCarbs);
    add('minFat', minFat);
    add('maxFat', maxFat);

    // findByNutrients returns a bare JSON array, not an object.
    final json = await _getRaw('/recipes/findByNutrients', params);
    final results = (json as List?) ?? const [];
    return results
        .cast<Map<String, dynamic>>()
        .map(Recipe.fromSpoonacularNutrients)
        .toList();
  }

  /// Fetches full nutrition for a single recipe by its numeric Spoonacular id.
  Future<Recipe> getInformation(String id) async {
    final json = await _get('/recipes/$id/information', {
      'includeNutrition': 'true',
    });
    return Recipe.fromSpoonacular(json);
  }

  /// GETs an endpoint expected to return a JSON object.
  Future<Map<String, dynamic>> _get(
    String path,
    Map<String, String> params,
  ) async {
    final decoded = await _getRaw(path, params);
    if (decoded is! Map<String, dynamic>) {
      throw const ApiUnavailableException('Unexpected Spoonacular response.');
    }
    return decoded;
  }

  /// GETs an endpoint and returns decoded JSON (object or array), translating
  /// every failure mode into a typed [ApiException].
  Future<dynamic> _getRaw(String path, Map<String, String> params) async {
    if (!isConfigured) {
      throw const ApiUnavailableException('Spoonacular API key is not set.');
    }

    final uri = Uri.https(_host, path, {...params, 'apiKey': _apiKey});
    final http.Response response;
    try {
      response = await _client.get(uri).timeout(timeout);
    } on TimeoutException {
      throw const ApiUnavailableException('Spoonacular timed out.');
    } catch (e) {
      throw ApiUnavailableException('Spoonacular request failed: $e');
    }

    if (response.statusCode == 402) {
      throw const ApiQuotaExceededException('Spoonacular daily quota reached.');
    }
    if (response.statusCode != 200) {
      throw ApiUnavailableException(
        'Spoonacular returned HTTP ${response.statusCode}.',
      );
    }

    try {
      return jsonDecode(response.body);
    } catch (_) {
      throw const ApiUnavailableException('Spoonacular returned invalid JSON.');
    }
  }

  void dispose() => _client.close();
}
