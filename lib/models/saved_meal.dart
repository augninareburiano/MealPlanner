/// A meal the user saved for later, stored in the `saved_meals` table.
///
/// Linked to a [UserProfile] via [userId] (the Firebase user id).
class SavedMeal {
  final int? id;
  final String userId;

  /// Id of the recipe from the nutrition API (Spoonacular/TheMealDB).
  final String? apiMealId;
  final String? mealName;
  final String? imageUrl;

  const SavedMeal({
    this.id,
    required this.userId,
    this.apiMealId,
    this.mealName,
    this.imageUrl,
  });

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'user_id': userId,
        'api_meal_id': apiMealId,
        'meal_name': mealName,
        'image_url': imageUrl,
      };

  factory SavedMeal.fromMap(Map<String, Object?> map) => SavedMeal(
        id: (map['id'] as num?)?.toInt(),
        userId: map['user_id'] as String,
        apiMealId: map['api_meal_id'] as String?,
        mealName: map['meal_name'] as String?,
        imageUrl: map['image_url'] as String?,
      );
}
