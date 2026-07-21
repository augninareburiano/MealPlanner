import 'package:flutter/foundation.dart';

/// A tiny app-wide event bus so screens can react to each other's changes
/// (e.g. the Dashboard refreshing after a meal is logged on the Planner tab,
/// or targets recomputing after the profile is edited).
class AppEvents {
  AppEvents._();
  static final AppEvents instance = AppEvents._();

  /// Bumped whenever meal logs change (add/delete).
  final ValueNotifier<int> mealsChanged = ValueNotifier(0);

  /// Bumped whenever the user's profile changes.
  final ValueNotifier<int> profileChanged = ValueNotifier(0);

  void bumpMeals() => mealsChanged.value++;
  void bumpProfile() => profileChanged.value++;
}
