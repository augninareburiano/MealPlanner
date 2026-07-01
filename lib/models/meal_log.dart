/// A single logged food item, stored in the `meal_log` table.
///
/// Linked to a [UserProfile] via [userId] (the Firebase user id).
class MealLog {
  final int? id;
  final String userId;

  /// Date the meal was eaten, formatted as `yyyy-MM-dd`.
  final String mealDate;

  /// One of: `breakfast`, `lunch`, `dinner`, `snack`.
  final String mealType;

  final String foodName;
  final String? servingSize;
  final double? calories;
  final double? protein;
  final double? carbs;
  final double? fat;

  /// Optional id of the source recipe from the nutrition API (Spoonacular/TheMealDB).
  final String? apiMealId;

  const MealLog({
    this.id,
    required this.userId,
    required this.mealDate,
    required this.mealType,
    required this.foodName,
    this.servingSize,
    this.calories,
    this.protein,
    this.carbs,
    this.fat,
    this.apiMealId,
  });

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'user_id': userId,
        'meal_date': mealDate,
        'meal_type': mealType,
        'food_name': foodName,
        'serving_size': servingSize,
        'calories': calories,
        'protein': protein,
        'carbs': carbs,
        'fat': fat,
        'api_meal_id': apiMealId,
      };

  factory MealLog.fromMap(Map<String, Object?> map) => MealLog(
        id: (map['id'] as num?)?.toInt(),
        userId: map['user_id'] as String,
        mealDate: map['meal_date'] as String,
        mealType: map['meal_type'] as String,
        foodName: map['food_name'] as String,
        servingSize: map['serving_size'] as String?,
        calories: (map['calories'] as num?)?.toDouble(),
        protein: (map['protein'] as num?)?.toDouble(),
        carbs: (map['carbs'] as num?)?.toDouble(),
        fat: (map['fat'] as num?)?.toDouble(),
        apiMealId: map['api_meal_id'] as String?,
      );
}
