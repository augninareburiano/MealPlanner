/// Template for local API keys. This file is COMMITTED as a reference.
///
/// To use it:
///   1. Copy this file to `lib/config/api_config.dart` (which is gitignored).
///   2. Fill in your real keys there.
///   3. Never commit the real `api_config.dart`.
///
/// Later, code will import the real file:  import '../config/api_config.dart';
class ApiConfig {
  /// Spoonacular API key — the primary recipe/nutrition source.
  static const String spoonacularApiKey = '';

  // TheMealDB is a free backup and needs no key for its test endpoint.
}
