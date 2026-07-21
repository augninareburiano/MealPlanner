import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../models/recipe.dart';
import 'api_exceptions.dart';

/// Backup recipe source: TheMealDB. Free and keyless (uses the public test
/// key `1`), but it has NO nutrition data — results come back with null
/// macros, which the app treats as name-only matches.
class TheMealDbService {
  TheMealDbService({
    http.Client? client,
    this.timeout = const Duration(seconds: 10),
  }) : _client = client ?? http.Client();

  static const _host = 'www.themealdb.com';
  static const _basePath = '/api/json/v1/1';

  final http.Client _client;
  final Duration timeout;

  /// Searches meals by name. Returns an empty list when nothing matches
  /// (TheMealDB sends `{"meals": null}` for no results).
  Future<List<Recipe>> searchByName(String query) async {
    final json = await _get('/search.php', {'s': query});
    final meals = (json['meals'] as List?) ?? const [];
    return meals.cast<Map<String, dynamic>>().map(Recipe.fromTheMealDb).toList();
  }

  /// Lists meals in a category (e.g. `Chicken`, `Seafood`, `Vegetarian`).
  Future<List<Recipe>> filterByCategory(String category) async {
    final json = await _get('/filter.php', {'c': category});
    final meals = (json['meals'] as List?) ?? const [];
    return meals.cast<Map<String, dynamic>>().map(Recipe.fromTheMealDb).toList();
  }

  Future<Map<String, dynamic>> _get(
    String path,
    Map<String, String> params,
  ) async {
    final uri = Uri.https(_host, '$_basePath$path', params);
    final http.Response response;
    try {
      response = await _client.get(uri).timeout(timeout);
    } on TimeoutException {
      throw const ApiUnavailableException('TheMealDB timed out.');
    } catch (e) {
      throw ApiUnavailableException('TheMealDB request failed: $e');
    }

    if (response.statusCode != 200) {
      throw ApiUnavailableException(
        'TheMealDB returned HTTP ${response.statusCode}.',
      );
    }

    try {
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const ApiUnavailableException('Unexpected TheMealDB response.');
      }
      return decoded;
    } on ApiException {
      rethrow;
    } catch (_) {
      throw const ApiUnavailableException('TheMealDB returned invalid JSON.');
    }
  }

  void dispose() => _client.close();
}
