/// One row of DOST-FNRI RENI reference intakes: the reference protein and key
/// micronutrient amounts for a given sex and age bracket.
class ReniValues {
  final double proteinG;
  final double fiberG;
  final double calciumMg;
  final double ironMg;
  final double vitaminCMg;
  final double vitaminARaeUg;

  const ReniValues({
    required this.proteinG,
    required this.fiberG,
    required this.calciumMg,
    required this.ironMg,
    required this.vitaminCMg,
    required this.vitaminARaeUg,
  });
}

/// Reference intakes from the DOST-FNRI Recommended Energy and Nutrient Intakes
/// (RENI) tables, used to set daily nutrient targets.
///
/// The figures below are representative reference points drawn from the
/// DOST-FNRI RENI / Philippine Dietary Reference Intakes (PDRI) tables for
/// Filipinos. They are grouped by sex and age bracket. Notable Filipino-diet
/// specifics reflected here: iron for menstruating women is high (~28 mg/day)
/// because of the low bioavailability of iron in the typical diet.
///
/// These values should be validated against the current official DOST-FNRI
/// publication before any clinical use; they live in one place so they are easy
/// to correct.
class ReniReference {
  const ReniReference._();

  /// Looks up the reference values for [gender] and [age]. Unknown/blank
  /// genders are treated as female (the more conservative micronutrient set),
  /// and ages below the youngest bracket fall back to it.
  static ReniValues lookup({required String? gender, required int? age}) {
    final isMale = (gender ?? '').toLowerCase().startsWith('m');
    final years = age ?? _defaultAdultAge;
    final table = isMale ? _male : _female;

    for (final bracket in table) {
      if (years >= bracket.minAge && years <= bracket.maxAge) {
        return bracket.values;
      }
    }
    // Older than the last bracket -> use the oldest (65+) row.
    return table.last.values;
  }

  static const int _defaultAdultAge = 30;

  // Brackets ordered youngest -> oldest. Ages below the first bracket's minAge
  // still resolve to it via the loop's `>=`/`<=` on a wide first range.
  static const List<_Bracket> _male = [
    _Bracket(0, 18, ReniValues(
      proteinG: 59,
      fiberG: 22,
      calciumMg: 1000,
      ironMg: 19,
      vitaminCMg: 65,
      vitaminARaeUg: 600,
    )),
    _Bracket(19, 29, ReniValues(
      proteinG: 68,
      fiberG: 25,
      calciumMg: 750,
      ironMg: 12,
      vitaminCMg: 70,
      vitaminARaeUg: 550,
    )),
    _Bracket(30, 49, ReniValues(
      proteinG: 68,
      fiberG: 25,
      calciumMg: 750,
      ironMg: 12,
      vitaminCMg: 70,
      vitaminARaeUg: 550,
    )),
    _Bracket(50, 64, ReniValues(
      proteinG: 66,
      fiberG: 22,
      calciumMg: 800,
      ironMg: 12,
      vitaminCMg: 70,
      vitaminARaeUg: 550,
    )),
    _Bracket(65, 200, ReniValues(
      proteinG: 65,
      fiberG: 20,
      calciumMg: 800,
      ironMg: 12,
      vitaminCMg: 70,
      vitaminARaeUg: 550,
    )),
  ];

  static const List<_Bracket> _female = [
    _Bracket(0, 18, ReniValues(
      proteinG: 55,
      fiberG: 20,
      calciumMg: 1000,
      ironMg: 28,
      vitaminCMg: 65,
      vitaminARaeUg: 600,
    )),
    _Bracket(19, 29, ReniValues(
      proteinG: 59,
      fiberG: 25,
      calciumMg: 750,
      ironMg: 28,
      vitaminCMg: 60,
      vitaminARaeUg: 500,
    )),
    _Bracket(30, 49, ReniValues(
      proteinG: 59,
      fiberG: 25,
      calciumMg: 750,
      ironMg: 28,
      vitaminCMg: 60,
      vitaminARaeUg: 500,
    )),
    _Bracket(50, 64, ReniValues(
      proteinG: 58,
      fiberG: 22,
      calciumMg: 800,
      ironMg: 10,
      vitaminCMg: 60,
      vitaminARaeUg: 500,
    )),
    _Bracket(65, 200, ReniValues(
      proteinG: 57,
      fiberG: 20,
      calciumMg: 800,
      ironMg: 10,
      vitaminCMg: 60,
      vitaminARaeUg: 500,
    )),
  ];
}

class _Bracket {
  final int minAge;
  final int maxAge;
  final ReniValues values;

  const _Bracket(this.minAge, this.maxAge, this.values);
}
