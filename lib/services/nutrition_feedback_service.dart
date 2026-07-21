import '../constants/dost_fnri_guidelines.dart';
import '../models/daily_nutrition.dart';
import '../models/nutrition_feedback.dart';
import '../models/nutrition_target.dart';
import '../models/user_profile.dart';
import 'database_helper.dart';

/// Turns a day's logged meals into DOST-FNRI–based nutrition feedback.
///
/// The comparison logic is split into pure, dependency-free functions
/// ([buildTarget], [buildFeedback]) so it can be unit-tested without Firebase
/// or SQLite. [loadDailyFeedback] wires those to the local database.
class NutritionFeedbackService {
  NutritionFeedbackService({DatabaseHelper? db})
      : _db = db ?? DatabaseHelper.instance;

  final DatabaseHelper _db;

  /// Loads the given day's intake and profile from the local database and
  /// returns the feedback comparing them to DOST-FNRI guidelines.
  Future<NutritionFeedback> loadDailyFeedback(
    String userId,
    String mealDate,
  ) async {
    final profile = await _db.getUserProfile(userId);
    final intake = await _db.getDailyNutrition(userId, mealDate);
    return buildFeedback(profile: profile, intake: intake);
  }

  // --- Pure computation ----------------------------------------------------

  /// Builds a recommended daily [NutritionTarget] for [profile] by applying
  /// DOST-FNRI guidelines. Falls back to DOST-FNRI defaults when the profile
  /// lacks the height/weight/age needed to estimate a personal requirement.
  static NutritionTarget buildTarget(UserProfile? profile) {
    final energy = _estimateEnergyKcal(profile);
    final fromDefaults = energy.fromDefaults;
    final kcal = energy.kcal;

    NutrientRange gramsFor(EnergyPercentRange pct, double kcalPerGram) =>
        NutrientRange(
          pct.lowPercent / 100 * kcal / kcalPerGram,
          pct.highPercent / 100 * kcal / kcalPerGram,
        );

    return NutritionTarget(
      energyKcal: kcal,
      carbsGrams: gramsFor(
        DostFnriGuidelines.carbohydratePercent,
        DostFnriGuidelines.kcalPerGramCarb,
      ),
      proteinGrams: gramsFor(
        DostFnriGuidelines.proteinPercent,
        DostFnriGuidelines.kcalPerGramProtein,
      ),
      fatGrams: gramsFor(
        DostFnriGuidelines.fatPercent,
        DostFnriGuidelines.kcalPerGramFat,
      ),
      fromDefaults: fromDefaults,
    );
  }

  /// Compares a day's [intake] to the DOST-FNRI target for [profile] and
  /// returns per-nutrient feedback plus an overall headline.
  static NutritionFeedback buildFeedback({
    required UserProfile? profile,
    required DailyNutrition intake,
  }) {
    final target = buildTarget(profile);
    final energyBand =
        target.energyBand(DostFnriGuidelines.energyOnTrackTolerance);

    final energy = NutrientFeedback(
      label: 'Energy',
      unit: 'kcal',
      consumed: intake.calories,
      recommended: energyBand,
      status: _classify(intake.calories, energyBand),
      insight: _energyInsight(intake, target, energyBand),
    );

    NutrientFeedback macro(
      String label,
      double consumed,
      NutrientRange range,
    ) {
      final status = _classify(consumed, range);
      return NutrientFeedback(
        label: label,
        unit: 'g',
        consumed: consumed,
        recommended: range,
        status: status,
        insight: _macroInsight(label, status, range),
      );
    }

    final carbs = macro('Carbohydrates', intake.carbs, target.carbsGrams);
    final protein = macro('Protein', intake.protein, target.proteinGrams);
    final fat = macro('Fat', intake.fat, target.fatGrams);

    return NutritionFeedback(
      intake: intake,
      target: target,
      energy: energy,
      carbs: carbs,
      protein: protein,
      fat: fat,
      headline: _headline(intake, [energy, carbs, protein, fat]),
    );
  }

  // --- Helpers -------------------------------------------------------------

  static NutrientStatus _classify(double value, NutrientRange range) {
    if (value < range.low) return NutrientStatus.below;
    if (value > range.high) return NutrientStatus.above;
    return NutrientStatus.onTrack;
  }

  /// Estimates daily energy from the profile using the PDRI's
  /// Basal Metabolic Rate × Physical Activity Level model. BMR uses the
  /// Mifflin–St Jeor equation.
  static ({double kcal, bool fromDefaults}) _estimateEnergyKcal(
    UserProfile? profile,
  ) {
    final weight = profile?.weightKg;
    final height = profile?.heightCm;
    final age = profile?.age;

    if (profile == null ||
        weight == null ||
        weight <= 0 ||
        height == null ||
        height <= 0 ||
        age == null ||
        age <= 0) {
      return (kcal: DostFnriGuidelines.defaultEnergyKcal, fromDefaults: true);
    }

    final bmr = 10 * weight +
        6.25 * height -
        5 * age +
        _sexConstant(profile.gender);
    final pal = DostFnriGuidelines.palForActivityLevel(profile.activityLevel);
    var energy = bmr * pal + _goalDelta(profile.healthGoal);
    if (energy < DostFnriGuidelines.minSafeEnergyKcal) {
      energy = DostFnriGuidelines.minSafeEnergyKcal;
    }
    return (kcal: energy, fromDefaults: false);
  }

  /// Sex constant in the Mifflin–St Jeor equation (+5 male, −161 female).
  /// When sex is unknown we use their average, a neutral middle value.
  static double _sexConstant(String? gender) {
    final value = gender?.toLowerCase().trim() ?? '';
    if (value.startsWith('m')) return 5;
    if (value.startsWith('f') || value.startsWith('w')) return -161;
    return -78;
  }

  /// Energy adjustment for a weight-change goal: eat below maintenance to
  /// lose, above to gain.
  static double _goalDelta(String? healthGoal) {
    final value = healthGoal?.toLowerCase().trim() ?? '';
    if (value.contains('lose') || value.contains('loss')) {
      return -DostFnriGuidelines.goalEnergyDelta;
    }
    if (value.contains('gain') || value.contains('build')) {
      return DostFnriGuidelines.goalEnergyDelta;
    }
    return 0;
  }

  static String _energyInsight(
    DailyNutrition intake,
    NutritionTarget target,
    NutrientRange band,
  ) {
    final targetKcal = target.energyKcal.round();
    switch (_classify(intake.calories, band)) {
      case NutrientStatus.below:
        final short = (target.energyKcal - intake.calories).round();
        return 'About $short kcal under your estimated need of '
            '$targetKcal kcal. Add a balanced meal or snack to fuel your day.';
      case NutrientStatus.above:
        final over = (intake.calories - target.energyKcal).round();
        return 'About $over kcal over your estimated need of '
            '$targetKcal kcal. Lighter portions can bring it back in line.';
      case NutrientStatus.onTrack:
        return 'Right around your estimated need of $targetKcal kcal — '
            'nicely balanced.';
    }
  }

  static String _macroInsight(
    String label,
    NutrientStatus status,
    NutrientRange range,
  ) {
    final low = range.low.round();
    final high = range.high.round();
    switch (status) {
      case NutrientStatus.below:
        return 'Below the DOST-FNRI range of $low–$high g. '
            '${_lowTip(label)}';
      case NutrientStatus.above:
        return 'Above the DOST-FNRI range of $low–$high g. '
            '${_highTip(label)}';
      case NutrientStatus.onTrack:
        return 'Within the DOST-FNRI range of $low–$high g. Keep it up!';
    }
  }

  static String _lowTip(String label) {
    switch (label) {
      case 'Carbohydrates':
        return 'Add rice, root crops or whole grains for steady energy.';
      case 'Protein':
        return 'Include fish, lean meat, eggs or beans to reach it.';
      case 'Fat':
        return 'A little healthy fat (nuts, fish, oil) helps absorb vitamins.';
      default:
        return 'Aim for a more balanced plate.';
    }
  }

  static String _highTip(String label) {
    switch (label) {
      case 'Carbohydrates':
        return 'Trim sugary drinks and refined carbs; favour vegetables.';
      case 'Protein':
        return 'Slightly smaller protein portions are fine.';
      case 'Fat':
        return 'Go easy on fried and fatty foods.';
      default:
        return 'Aim for a more balanced plate.';
    }
  }

  static String _headline(
    DailyNutrition intake,
    List<NutrientFeedback> nutrients,
  ) {
    if (intake.isEmpty) {
      return 'No meals logged yet today — log a meal to see how it compares '
          'to DOST-FNRI guidelines.';
    }
    final onTrack =
        nutrients.where((n) => n.status == NutrientStatus.onTrack).length;
    final total = nutrients.length;
    if (onTrack == total) {
      return 'Great balance today — every nutrient is within DOST-FNRI '
          'recommendations.';
    }
    if (onTrack >= total - 1) {
      return 'Well balanced — $onTrack of $total nutrients are on track with '
          'DOST-FNRI guidelines.';
    }
    if (onTrack == 0) {
      return 'Today\'s intake is off balance. Aim for a "Pinggang Pinoy" '
          'plate — go, grow and glow foods in the right proportions.';
    }
    return '$onTrack of $total nutrients are on track. A few tweaks will get '
        'you closer to DOST-FNRI guidelines.';
  }
}
