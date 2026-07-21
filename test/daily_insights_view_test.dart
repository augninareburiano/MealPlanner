import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:foodgapp/models/meal_log.dart';
import 'package:foodgapp/models/nutrient_targets.dart';
import 'package:foodgapp/services/nutrition_feedback_engine.dart';
import 'package:foodgapp/widgets/daily_insights_view.dart';

const _targets = NutrientTargets(
  calories: 2000,
  proteinG: 75,
  carbsG: 300,
  fatG: 55.6,
  fiberG: 25,
  calciumMg: 750,
  ironMg: 28,
  vitaminCMg: 60,
  vitaminARaeUg: 500,
  personalized: true,
);

MealLog _log({double? calories, double? protein, double? carbs, double? fat}) =>
    MealLog(
      userId: 'u',
      mealDate: '2026-07-20',
      mealType: 'lunch',
      foodName: 'test food',
      calories: calories,
      protein: protein,
      carbs: carbs,
      fat: fat,
    );

Future<void> _pump(WidgetTester tester, List<MealLog> logs) {
  final feedback =
      NutritionFeedbackEngine.evaluate(targets: _targets, logs: logs);
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: DailyInsightsView(feedback: feedback),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('renders the nutrient comparisons for a logged day',
      (tester) async {
    await _pump(tester, [_log(calories: 1400, protein: 53, carbs: 210, fat: 39)]);

    expect(find.text("Today's Insights"), findsOneWidget);
    expect(find.text('Compared with your DOST-FNRI nutrient goals'),
        findsOneWidget);

    // One consumed/target row per nutrient, calories first.
    expect(find.text('1400 / 2000 kcal'), findsOneWidget);
    expect(find.text('53 / 75 g'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNWidgets(4));
  });

  testWidgets('renders the engine\'s advice', (tester) async {
    await _pump(tester, [_log(calories: 2500, protein: 94, carbs: 375, fat: 69)]);

    expect(find.text('Over your energy goal'), findsOneWidget);
    expect(find.byIcon(Icons.warning_amber_rounded), findsWidgets);
  });

  testWidgets('hides the comparison bars when nothing is logged',
      (tester) async {
    await _pump(tester, const []);

    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.text('Nothing logged yet today'), findsOneWidget);
    expect(find.byIcon(Icons.info_outline), findsOneWidget);
  });

  testWidgets('shows a positive tone for a well-balanced day', (tester) async {
    await _pump(tester, [_log(calories: 2000, protein: 75, carbs: 300, fat: 55.6)]);

    expect(find.text('Well-balanced day'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
    expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);
  });
}
