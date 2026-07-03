import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:foodgapp/models/nutrient_targets.dart';
import 'package:foodgapp/widgets/nutrient_targets_view.dart';

NutrientTargets _sample({bool personalized = true}) => NutrientTargets(
      calories: 2759,
      proteinG: 103.5,
      carbsG: 413.85,
      fatG: 76.6,
      fiberG: 25,
      calciumMg: 750,
      ironMg: 12,
      vitaminCMg: 70,
      vitaminARaeUg: 550,
      personalized: personalized,
    );

Future<void> _pump(WidgetTester tester, NutrientTargets targets) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(child: NutrientTargetsView(targets: targets)),
      ),
    ),
  );
}

void main() {
  testWidgets('shows the calorie target and key nutrients', (tester) async {
    await _pump(tester, _sample());

    expect(find.text('Daily Calorie Target'), findsOneWidget);
    expect(find.text('2759'), findsOneWidget);
    // Rounded macro grams.
    expect(find.text('104'), findsOneWidget); // protein
    expect(find.text('414'), findsOneWidget); // carbs
    // Micronutrient rows.
    expect(find.text('Calcium'), findsOneWidget);
    expect(find.text('12 mg'), findsOneWidget); // iron
    expect(find.text('550 µg RAE'), findsOneWidget); // vitamin A
  });

  testWidgets('shows a personalized badge when the profile is complete',
      (tester) async {
    await _pump(tester, _sample(personalized: true));
    expect(find.text('Personalized to your profile'), findsOneWidget);
  });

  testWidgets('shows an estimated badge when the profile is incomplete',
      (tester) async {
    await _pump(tester, _sample(personalized: false));
    expect(find.text('Estimated — complete your profile'), findsOneWidget);
  });
}
