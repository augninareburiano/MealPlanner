/// A single nutrient reading for a food or meal, e.g. `Sodium 480 mg`.
///
/// The four headline macros stay as fields on [Recipe] because the rest of the
/// app reads them constantly; this type carries the *rest* of the breakdown
/// (fibre, sugar, sodium, vitamins…) that the nutrition facts panel shows.
class NutrientAmount {
  final String name;
  final double amount;
  final String unit;

  const NutrientAmount({
    required this.name,
    required this.amount,
    required this.unit,
  });

  /// Parses one `{name, amount, unit}` entry from Spoonacular's
  /// `nutrition.nutrients` array. Returns null when the entry is unusable, so
  /// a single malformed nutrient never breaks a whole recipe.
  static NutrientAmount? tryParse(Map<String, dynamic> json) {
    final name = (json['name'] as String?)?.trim();
    final amount = (json['amount'] as num?)?.toDouble();
    if (name == null || name.isEmpty || amount == null) return null;
    return NutrientAmount(
      name: name,
      amount: amount,
      unit: (json['unit'] as String?)?.trim() ?? '',
    );
  }

  Map<String, Object?> toJson() => {
        'name': name,
        'amount': amount,
        'unit': unit,
      };

  factory NutrientAmount.fromJson(Map<String, dynamic> json) => NutrientAmount(
        name: (json['name'] as String?) ?? '',
        amount: (json['amount'] as num?)?.toDouble() ?? 0,
        unit: (json['unit'] as String?) ?? '',
      );

  NutrientAmount scaled(double factor) => NutrientAmount(
        name: name,
        amount: amount * factor,
        unit: unit,
      );
}

/// Lookup helpers over a nutrient breakdown.
extension NutrientLookup on List<NutrientAmount> {
  /// The first nutrient matching any of [names], compared case-insensitively.
  ///
  /// Several names are accepted per nutrient because the sources spell them
  /// differently (`Fiber` vs `Fibre`, `Vitamin B1` vs `Thiamin`).
  NutrientAmount? named(List<String> names) {
    for (final wanted in names) {
      final target = wanted.toLowerCase();
      for (final nutrient in this) {
        if (nutrient.name.toLowerCase() == target) return nutrient;
      }
    }
    return null;
  }
}
