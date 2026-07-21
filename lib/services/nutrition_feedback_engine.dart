import '../models/meal_log.dart';
import '../models/nutrient_targets.dart';
import '../models/nutrition_feedback.dart';

/// Turns a day's meal logs into plain-language nutrition feedback by comparing
/// them against the user's [NutrientTargets] and the DOST-FNRI dietary
/// guidelines those targets came from.
///
/// Pure and stateless — the same logs and targets always produce the same
/// [DailyFeedback], which makes the rules straightforward to unit-test.
///
/// Two kinds of comparison are made:
///  * **Against the daily budget** — total energy and each macro vs the target,
///    with a tolerance band so "close enough" doesn't read as a miss.
///  * **Against the DOST-FNRI AMDR** — the share of total energy coming from
///    protein, carbohydrate and fat, which is how the FNRI expresses a balanced
///    Filipino diet. A day can hit its calorie goal and still be badly skewed,
///    so this catches what the budget comparison alone would miss.
///
/// Scope: only energy, protein, carbohydrate and fat are assessed, because
/// those are the only values `meal_log` records. The micronutrient targets
/// (calcium, iron, vitamins) have no logged intake to compare against, so no
/// claims are made about them. Adding them later means storing them per food
/// item and extending [_assess] — the rest of the shape already fits.
class NutritionFeedbackEngine {
  const NutritionFeedbackEngine._();

  /// Intake within ±10% of a target counts as on track.
  static const double _tolerance = 0.10;

  /// Below this share of the calorie budget the day reads as under-eating
  /// rather than merely light.
  static const double _underEatingRatio = 0.60;

  /// DOST-FNRI acceptable macronutrient distribution ranges (AMDR): the share
  /// of total energy each macro should supply in a balanced Filipino diet.
  static const _proteinAmdr = _Band(0.10, 0.15);
  static const _carbAmdr = _Band(0.55, 0.70);
  static const _fatAmdr = _Band(0.20, 0.30);

  /// Energy per gram (Atwater factors), used to convert macro grams to kcal.
  static const double _kcalPerGramProtein = 4;
  static const double _kcalPerGramCarb = 4;
  static const double _kcalPerGramFat = 9;

  /// Energy-share advice is unreliable on a nearly-empty day, so the AMDR rules
  /// only run once this much has been logged.
  static const double _minCaloriesForShareAdvice = 400;

  /// Assesses [logs] — all the items logged for a single day — against
  /// [targets].
  static DailyFeedback evaluate({
    required NutrientTargets targets,
    required List<MealLog> logs,
  }) {
    final eatenCalories = _sum(logs, (l) => l.calories);
    final eatenProtein = _sum(logs, (l) => l.protein);
    final eatenCarbs = _sum(logs, (l) => l.carbs);
    final eatenFat = _sum(logs, (l) => l.fat);

    final calories = _assess(
      label: 'Calories',
      consumed: eatenCalories,
      target: targets.calories.toDouble(),
      unit: 'kcal',
    );
    final protein = _assess(
      label: 'Protein',
      consumed: eatenProtein,
      target: targets.proteinG,
      unit: 'g',
    );
    final carbs = _assess(
      label: 'Carbs',
      consumed: eatenCarbs,
      target: targets.carbsG,
      unit: 'g',
    );
    final fat = _assess(
      label: 'Fat',
      consumed: eatenFat,
      target: targets.fatG,
      unit: 'g',
    );

    return DailyFeedback(
      calories: calories,
      macros: [protein, carbs, fat],
      itemsLogged: logs.length,
      personalized: targets.personalized,
      insights: _buildInsights(
        targets: targets,
        itemsLogged: logs.length,
        calories: calories,
        protein: protein,
        carbs: carbs,
        fat: fat,
      ),
    );
  }

  static double _sum(List<MealLog> logs, double? Function(MealLog) pick) =>
      logs.fold(0, (total, log) => total + (pick(log) ?? 0));

  static NutrientAssessment _assess({
    required String label,
    required double consumed,
    required double target,
    required String unit,
  }) {
    final NutrientStatus status;
    if (target <= 0) {
      status = NutrientStatus.onTrack;
    } else {
      final ratio = consumed / target;
      if (ratio < 1 - _tolerance) {
        status = NutrientStatus.under;
      } else if (ratio > 1 + _tolerance) {
        status = NutrientStatus.over;
      } else {
        status = NutrientStatus.onTrack;
      }
    }
    return NutrientAssessment(
      label: label,
      consumed: consumed,
      target: target,
      unit: unit,
      status: status,
    );
  }

  /// Applies the advice rules in priority order: nothing-logged first, then
  /// energy, then individual shortfalls, then diet balance, then context.
  static List<Insight> _buildInsights({
    required NutrientTargets targets,
    required int itemsLogged,
    required NutrientAssessment calories,
    required NutrientAssessment protein,
    required NutrientAssessment carbs,
    required NutrientAssessment fat,
  }) {
    if (itemsLogged == 0) {
      return const [
        Insight(
          title: 'Nothing logged yet today',
          body: 'Log what you eat and this page will show how your day '
              'compares with your DOST-FNRI nutrient goals.',
          tone: InsightTone.info,
        ),
      ];
    }

    final insights = <Insight>[
      ..._energyInsights(calories),
      ..._macroShortfallInsights(protein: protein, carbs: carbs, fat: fat),
      ..._balanceInsights(
        eatenCalories: calories.consumed,
        protein: protein,
        carbs: carbs,
        fat: fat,
      ),
    ];

    // Nothing needed flagging, so say so — with the numbers behind it.
    if (insights.isEmpty) {
      insights.add(Insight(
        title: 'Well-balanced day',
        body: '${calories.consumed.round()} kcal against a goal of '
            '${calories.target.round()}, with protein, carbohydrate and fat '
            'all inside the DOST-FNRI recommended ranges. Keep it up!',
        tone: InsightTone.positive,
      ));
    }

    if (!targets.personalized) {
      insights.add(const Insight(
        title: 'Using general targets',
        body: 'These goals are the reference values for an average adult. '
            'Add your age, sex, height and weight in your profile for targets '
            'matched to you.',
        tone: InsightTone.info,
      ));
    }

    return List.unmodifiable(insights);
  }

  static List<Insight> _energyInsights(NutrientAssessment calories) {
    final short = calories.difference.abs().round();
    switch (calories.status) {
      case NutrientStatus.under:
        if (calories.ratio < _underEatingRatio) {
          return [
            Insight(
              title: 'Well under your energy goal',
              body: "You're $short kcal short of your "
                  '${calories.target.round()} kcal budget. If the day is over, '
                  'that is less energy than the DOST-FNRI recommends — try not '
                  'to skip meals.',
              tone: InsightTone.warning,
            ),
          ];
        }
        return [
          Insight(
            title: '$short kcal left today',
            body: "You've eaten ${calories.consumed.round()} of "
                '${calories.target.round()} kcal. There is still room for a '
                'balanced meal or snack.',
            tone: InsightTone.info,
          ),
        ];
      case NutrientStatus.over:
        return [
          Insight(
            title: 'Over your energy goal',
            body: "You're $short kcal above your "
                '${calories.target.round()} kcal budget. A lighter next meal or '
                'some activity would even the day out.',
            tone: InsightTone.warning,
          ),
        ];
      case NutrientStatus.onTrack:
        // Energy needs no comment. If the macros are fine too, the caller's
        // "well-balanced day" fallback delivers the praise; if they aren't,
        // the advice below is what the user should be reading instead.
        return const [];
    }
  }

  /// Flags macros that fell short of their gram target, with a suggestion
  /// pitched at foods that are easy to find locally.
  static List<Insight> _macroShortfallInsights({
    required NutrientAssessment protein,
    required NutrientAssessment carbs,
    required NutrientAssessment fat,
  }) {
    final insights = <Insight>[];

    if (protein.status == NutrientStatus.under) {
      insights.add(Insight(
        title: 'Protein is low',
        body: '${protein.consumed.round()} g of '
            '${protein.target.round()} g. The DOST-FNRI protein reference is a '
            'floor, not a ceiling — fish, eggs, chicken, tokwa or monggo would '
            'close the gap.',
        tone: InsightTone.warning,
      ));
    }

    if (fat.status == NutrientStatus.over) {
      insights.add(Insight(
        title: 'Fat is running high',
        body: '${fat.consumed.round()} g against a ${fat.target.round()} g '
            'goal. Grilling, boiling or steaming instead of frying is the '
            'easiest way to bring this down.',
        tone: InsightTone.warning,
      ));
    }

    if (carbs.status == NutrientStatus.over) {
      insights.add(Insight(
        title: 'Carbohydrates above target',
        body: '${carbs.consumed.round()} g against a ${carbs.target.round()} g '
            'goal. Rice and bread portions are usually the lever here.',
        tone: InsightTone.warning,
      ));
    }

    return insights;
  }

  /// Compares the *shape* of the day — the share of energy from each macro —
  /// against the DOST-FNRI AMDR. This is what catches a day that hits its
  /// calorie goal but is, say, almost entirely rice.
  static List<Insight> _balanceInsights({
    required double eatenCalories,
    required NutrientAssessment protein,
    required NutrientAssessment carbs,
    required NutrientAssessment fat,
  }) {
    if (eatenCalories < _minCaloriesForShareAdvice) return const [];

    final proteinShare = protein.consumed * _kcalPerGramProtein / eatenCalories;
    final carbShare = carbs.consumed * _kcalPerGramCarb / eatenCalories;
    final fatShare = fat.consumed * _kcalPerGramFat / eatenCalories;

    final insights = <Insight>[];

    if (carbShare > _carbAmdr.max) {
      insights.add(Insight(
        title: 'Carb-heavy day',
        body: '${_pct(carbShare)} of your energy came from carbohydrates; the '
            'DOST-FNRI range is ${_pct(_carbAmdr.min)}–${_pct(_carbAmdr.max)}. '
            'Swapping part of your rice for vegetables and a protein dish '
            'would rebalance it.',
        tone: InsightTone.warning,
      ));
    } else if (carbShare < _carbAmdr.min && carbShare > 0) {
      insights.add(Insight(
        title: 'Low on carbohydrates',
        body: 'Only ${_pct(carbShare)} of your energy came from carbohydrates, '
            'below the DOST-FNRI ${_pct(_carbAmdr.min)}–${_pct(_carbAmdr.max)} '
            'range. Rice, root crops or fruit are the usual sources.',
        tone: InsightTone.info,
      ));
    }

    if (fatShare > _fatAmdr.max) {
      insights.add(Insight(
        title: 'Fat share above the guideline',
        body: '${_pct(fatShare)} of your energy came from fat, against a '
            'DOST-FNRI range of ${_pct(_fatAmdr.min)}–${_pct(_fatAmdr.max)}.',
        tone: InsightTone.warning,
      ));
    }

    if (proteinShare < _proteinAmdr.min && proteinShare > 0) {
      insights.add(Insight(
        title: 'Protein share is thin',
        body: 'Protein supplied ${_pct(proteinShare)} of your energy; the '
            'DOST-FNRI range is ${_pct(_proteinAmdr.min)}–'
            '${_pct(_proteinAmdr.max)}. Adding a protein dish to each meal '
            'helps more than one large serving.',
        tone: InsightTone.info,
      ));
    }

    return insights;
  }

  static String _pct(double share) => '${(share * 100).round()}%';
}

/// An inclusive acceptable range, expressed as a share of total energy.
class _Band {
  final double min;
  final double max;

  const _Band(this.min, this.max);
}
