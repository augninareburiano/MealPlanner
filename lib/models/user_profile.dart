/// A user's profile, stored locally in the `user_profile` SQLite table.
///
/// [userId] is the Firebase Authentication user id (the primary key), which is
/// how meal logs and saved meals are linked back to a person.
class UserProfile {
  final String userId;
  final String? name;
  final String? email;
  final String? contactNumber;
  final int? age;
  final String? gender;
  final double? heightCm;
  final double? weightKg;
  final String? activityLevel;
  final String? dietaryPreferences;
  final String? allergies;
  final String? healthGoal;

  const UserProfile({
    required this.userId,
    this.name,
    this.email,
    this.contactNumber,
    this.age,
    this.gender,
    this.heightCm,
    this.weightKg,
    this.activityLevel,
    this.dietaryPreferences,
    this.allergies,
    this.healthGoal,
  });

  Map<String, Object?> toMap() => {
        'user_id': userId,
        'name': name,
        'email': email,
        'contact_number': contactNumber,
        'age': age,
        'gender': gender,
        'height_cm': heightCm,
        'weight_kg': weightKg,
        'activity_level': activityLevel,
        'dietary_preferences': dietaryPreferences,
        'allergies': allergies,
        'health_goal': healthGoal,
      };

  factory UserProfile.fromMap(Map<String, Object?> map) => UserProfile(
        userId: map['user_id'] as String,
        name: map['name'] as String?,
        email: map['email'] as String?,
        contactNumber: map['contact_number'] as String?,
        age: (map['age'] as num?)?.toInt(),
        gender: map['gender'] as String?,
        heightCm: (map['height_cm'] as num?)?.toDouble(),
        weightKg: (map['weight_kg'] as num?)?.toDouble(),
        activityLevel: map['activity_level'] as String?,
        dietaryPreferences: map['dietary_preferences'] as String?,
        allergies: map['allergies'] as String?,
        healthGoal: map['health_goal'] as String?,
      );

  UserProfile copyWith({
    String? name,
    String? email,
    String? contactNumber,
    int? age,
    String? gender,
    double? heightCm,
    double? weightKg,
    String? activityLevel,
    String? dietaryPreferences,
    String? allergies,
    String? healthGoal,
  }) =>
      UserProfile(
        userId: userId,
        name: name ?? this.name,
        email: email ?? this.email,
        contactNumber: contactNumber ?? this.contactNumber,
        age: age ?? this.age,
        gender: gender ?? this.gender,
        heightCm: heightCm ?? this.heightCm,
        weightKg: weightKg ?? this.weightKg,
        activityLevel: activityLevel ?? this.activityLevel,
        dietaryPreferences: dietaryPreferences ?? this.dietaryPreferences,
        allergies: allergies ?? this.allergies,
        healthGoal: healthGoal ?? this.healthGoal,
      );
}
