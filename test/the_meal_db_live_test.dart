@Tags(['live'])
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:foodgapp/services/api/the_meal_db_service.dart';

/// Hits the real TheMealDB API (keyless). Network-dependent, so it's tagged
/// `live` and skipped by default (see dart_test.yaml). Run it on demand with:
///   flutter test --tags live --run-skipped
void main() {
  test('live: TheMealDB returns real recipes for a name search', () async {
    final service = TheMealDbService();
    addTearDown(service.dispose);

    final results = await service.searchByName('chicken');

    expect(results, isNotEmpty);
    expect(results.first.name, isNotEmpty);
    expect(results.first.source, 'themealdb');
  });
}
