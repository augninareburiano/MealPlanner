import '../constants/dost_fnri_guidelines.dart';
import 'nutrient_amount.dart';
import 'nutrition_target.dart';
import 'recipe.dart';

/// How a nutrient's daily reference value should be read.
enum DailyReferenceKind {
  /// Aim for roughly this much per day (energy, macros, fibre).
  target,

  /// Stay under this much per day (sugar, saturated fat, sodium, cholesterol).
  limit,
}

/// One line of a nutrition facts panel, e.g. `Sodium — 480 mg — 24% of the
/// 2000 mg daily limit`.
class NutritionFactRow {
  final String label;
  final double amount;
  final String unit;

  /// The DOST-FNRI daily reference for this nutrient, in [unit]. Null when the
  /// app has no reference to compare against (most micronutrients), in which
  /// case the row shows the amount only.
  final double? dailyReference;

  final DailyReferenceKind referenceKind;

  /// True for lines shown indented under the one above ("of which sugars").
  final bool isSub;

  const NutritionFactRow({
    required this.label,
    required this.amount,
    required this.unit,
    this.dailyReference,
    this.referenceKind = DailyReferenceKind.target,
    this.isSub = false,
  });

  /// This amount as a fraction of the daily reference (1.0 = the whole day's
  /// worth). Null when there is no reference to compare against.
  double? get dailyShare {
    final reference = dailyReference;
    if (reference == null || reference <= 0) return null;
    return amount / reference;
  }

  /// [dailyShare] as a whole percentage, for display.
  int? get dailyPercent {
    final share = dailyShare;
    return share == null ? null : (share * 100).round();
  }

  /// True when a single serving already uses up the whole daily allowance of a
  /// nutrient you're meant to limit — worth flagging in the UI.
  bool get exceedsLimit =>
      referenceKind == DailyReferenceKind.limit && (dailyShare ?? 0) > 1;
}

/// The nutritional values of one food or meal, laid out as a facts panel and
/// compared against the user's DOST-FNRI daily target.
///
/// Built by [NutritionFacts.forRecipe]; rows for nutrients the source didn't
/// report are left out entirely rather than shown as zero, so the panel never
/// claims a food has no sodium when the truth is that nobody measured it.
class NutritionFacts {
  final String foodName;
  final String? imageUrl;

  /// `spoonacular` or `themealdb`.
  final String source;

  /// How many servings the whole dish makes, when known.
  final int? recipeServings;

  /// How many servings this panel covers (1 = a single serving).
  final double servingsShown;

  /// True when the daily references came from the user's own profile rather
  /// than DOST-FNRI defaults.
  final bool personalised;

  final NutritionFactRow? energy;

  /// Carbohydrates, protein and fat, with their "of which" lines interleaved.
  final List<NutritionFactRow> macros;

  /// Nutrients to keep an eye on: sodium, cholesterol.
  final List<NutritionFactRow> details;

  /// Vitamins and minerals, shown as amounts only.
  final List<NutritionFactRow> micronutrients;

  const NutritionFacts({
    required this.foodName,
    required this.source,
    required this.servingsShown,
    required this.personalised,
    this.imageUrl,
    this.recipeServings,
    this.energy,
    this.macros = const [],
    this.details = const [],
    this.micronutrients = const [],
  });

  /// True when there is anything at all to show.
  bool get hasData => energy != null || macros.isNotEmpty;

  /// True when the source gave more than the four headline macros.
  bool get hasBreakdown => details.isNotEmpty || micronutrients.isNotEmpty;

  List<NutritionFactRow> get allRows => [
        if (energy != null) energy!,
        ...macros,
        ...details,
        ...micronutrients,
      ];

  /// Builds the panel for [recipe], scaled to [servingsShown] servings and
  /// compared against [target].
  ///
  /// Recipe nutrition is per serving, so scaling is a straight multiplication.
  factory NutritionFacts.forRecipe(
    Recipe recipe, {
    required NutritionTarget target,
    double servingsShown = 1,
  }) {
    final factor = servingsShown <= 0 ? 1.0 : servingsShown;
    final nutrients = recipe.nutrients;

    double? scale(double? value) => value == null ? null : value * factor;

    // Prefers the headline field (present even for `findByNutrients` results,
    // which carry no breakdown) and falls back to the breakdown.
    double? headline(double? value, List<String> names) =>
        scale(value ?? nutrients.named(names)?.amount);

    NutritionFactRow? row(
      String label,
      List<String> names, {
      String fallbackUnit = 'g',
      double? amount,
      double? dailyReference,
      DailyReferenceKind referenceKind = DailyReferenceKind.target,
      bool isSub = false,
    }) {
      final found = nutrients.named(names);
      final value = amount ?? scale(found?.amount);
      if (value == null) return null;
      return NutritionFactRow(
        label: label,
        amount: value,
        unit: found?.unit.isNotEmpty == true ? found!.unit : fallbackUnit,
        dailyReference: dailyReference,
        referenceKind: referenceKind,
        isSub: isSub,
      );
    }

    // Energy-derived ceilings: both are "under 10% of the day's calories".
    final sugarLimit = DostFnriGuidelines.sugarPercentLimit /
        100 *
        target.energyKcal /
        DostFnriGuidelines.kcalPerGramCarb;
    final saturatedFatLimit = DostFnriGuidelines.saturatedFatPercentLimit /
        100 *
        target.energyKcal /
        DostFnriGuidelines.kcalPerGramFat;

    final macros = <NutritionFactRow?>[
      row(
        'Carbohydrates',
        const ['Carbohydrates'],
        amount: headline(recipe.carbs, const ['Carbohydrates']),
        dailyReference: target.carbsGrams.mid,
      ),
      row(
        'Dietary fibre',
        const ['Fiber', 'Fibre'],
        dailyReference: DostFnriGuidelines.fibreGramsPerDay,
        isSub: true,
      ),
      row(
        'Sugars',
        const ['Sugar', 'Sugars'],
        dailyReference: sugarLimit,
        referenceKind: DailyReferenceKind.limit,
        isSub: true,
      ),
      row(
        'Protein',
        const ['Protein'],
        amount: headline(recipe.protein, const ['Protein']),
        dailyReference: target.proteinGrams.mid,
      ),
      row(
        'Fat',
        const ['Fat'],
        amount: headline(recipe.fat, const ['Fat']),
        dailyReference: target.fatGrams.mid,
      ),
      row(
        'Saturated fat',
        const ['Saturated Fat'],
        dailyReference: saturatedFatLimit,
        referenceKind: DailyReferenceKind.limit,
        isSub: true,
      ),
    ];

    final details = <NutritionFactRow?>[
      row(
        'Sodium',
        const ['Sodium'],
        fallbackUnit: 'mg',
        dailyReference: DostFnriGuidelines.sodiumMgLimit,
        referenceKind: DailyReferenceKind.limit,
      ),
      row(
        'Cholesterol',
        const ['Cholesterol'],
        fallbackUnit: 'mg',
        dailyReference: DostFnriGuidelines.cholesterolMgLimit,
        referenceKind: DailyReferenceKind.limit,
      ),
    ];

    // Vitamins and minerals are shown as plain amounts: the PDRI sets these
    // per age and sex, which is more than this panel models.
    final micronutrients = <NutritionFactRow?>[
      row('Calcium', const ['Calcium'], fallbackUnit: 'mg'),
      row('Iron', const ['Iron'], fallbackUnit: 'mg'),
      row('Potassium', const ['Potassium'], fallbackUnit: 'mg'),
      row('Vitamin A', const ['Vitamin A'], fallbackUnit: 'µg'),
      row('Vitamin C', const ['Vitamin C'], fallbackUnit: 'mg'),
    ];

    final energyAmount = headline(recipe.calories, const ['Calories']);

    return NutritionFacts(
      foodName: recipe.name,
      imageUrl: recipe.imageUrl,
      source: recipe.source,
      recipeServings: recipe.servings,
      servingsShown: factor,
      personalised: !target.fromDefaults,
      energy: energyAmount == null
          ? null
          : NutritionFactRow(
              label: 'Energy',
              amount: energyAmount,
              unit: 'kcal',
              dailyReference: target.energyKcal,
            ),
      macros: macros.whereType<NutritionFactRow>().toList(growable: false),
      details: details.whereType<NutritionFactRow>().toList(growable: false),
      micronutrients:
          micronutrients.whereType<NutritionFactRow>().toList(growable: false),
    );
  }
}
