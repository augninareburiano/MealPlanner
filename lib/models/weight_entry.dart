/// A single weigh-in, stored in the `weight_log` table.
///
/// Linked to a [UserProfile] via [userId] (the Firebase user id).
class WeightEntry {
  final int? id;
  final String userId;

  /// Date of the weigh-in, formatted as `yyyy-MM-dd`.
  final String entryDate;
  final double weightKg;

  const WeightEntry({
    this.id,
    required this.userId,
    required this.entryDate,
    required this.weightKg,
  });

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'user_id': userId,
        'entry_date': entryDate,
        'weight_kg': weightKg,
      };

  factory WeightEntry.fromMap(Map<String, Object?> map) => WeightEntry(
        id: (map['id'] as num?)?.toInt(),
        userId: map['user_id'] as String,
        entryDate: map['entry_date'] as String,
        weightKg: (map['weight_kg'] as num).toDouble(),
      );
}
