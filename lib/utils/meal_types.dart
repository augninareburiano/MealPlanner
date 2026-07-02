/// Meal categories used by `meal_log.meal_type`, in display order.
const List<String> kMealTypes = ['breakfast', 'lunch', 'dinner', 'snack'];

/// The meal categories shown as sections on the Home dashboard.
const List<String> kMainMealTypes = ['breakfast', 'lunch', 'dinner'];

/// Capitalises a meal type for display, e.g. `breakfast` -> `Breakfast`.
String mealTypeLabel(String type) =>
    type.isEmpty ? type : type[0].toUpperCase() + type.substring(1);
