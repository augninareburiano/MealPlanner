/// A single logged exercise/activity, stored in the `exercise_log` table.
///
/// Linked to a [UserProfile] via [userId] (the Firebase user id).
class ExerciseEntry {
  final int? id;
  final String userId;

  /// Date of the activity, formatted as `yyyy-MM-dd`.
  final String entryDate;
  final String name;

  /// Calories burned, in kcal.
  final double calories;

  const ExerciseEntry({
    this.id,
    required this.userId,
    required this.entryDate,
    required this.name,
    required this.calories,
  });

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'user_id': userId,
        'entry_date': entryDate,
        'name': name,
        'calories': calories,
      };

  factory ExerciseEntry.fromMap(Map<String, Object?> map) => ExerciseEntry(
        id: (map['id'] as num?)?.toInt(),
        userId: map['user_id'] as String,
        entryDate: map['entry_date'] as String,
        name: map['name'] as String,
        calories: (map['calories'] as num).toDouble(),
      );
}
