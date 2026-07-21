import 'package:flutter_test/flutter_test.dart';

import 'package:foodgapp/models/user_profile.dart';
import 'package:foodgapp/services/daily_budget_controller.dart';

void main() {
  test('load() computes targets from the loaded profile', () async {
    const profile = UserProfile(
      userId: 'u',
      age: 30,
      gender: 'male',
      weightKg: 80,
      heightCm: 180,
      activityLevel: 'moderate',
      healthGoal: 'maintain',
    );
    final controller = DailyBudgetController(
      profileLoader: (_) async => profile,
    );

    expect(controller.targets, isNull);
    await controller.load('u');

    expect(controller.targets, isNotNull);
    expect(controller.targets!.calories, 2759);
  });

  test('recomputes and notifies when the profile changes', () async {
    final controller = DailyBudgetController(
      profileLoader: (_) async => null,
    );
    var notifications = 0;
    controller.addListener(() => notifications++);

    controller.updateFromProfile(
      const UserProfile(
        userId: 'u',
        age: 30,
        gender: 'male',
        weightKg: 80,
        heightCm: 180,
        activityLevel: 'moderate',
        healthGoal: 'maintain',
      ),
    );
    final first = controller.targets!.calories;

    // Same person, now cutting weight -> lower target, another notification.
    controller.updateFromProfile(
      const UserProfile(
        userId: 'u',
        age: 30,
        gender: 'male',
        weightKg: 80,
        heightCm: 180,
        activityLevel: 'moderate',
        healthGoal: 'lose weight',
      ),
    );
    final second = controller.targets!.calories;

    expect(second, first - 500);
    expect(notifications, 2);
  });

  test('identical profile update does not fire a needless notification',
      () async {
    final controller = DailyBudgetController(profileLoader: (_) async => null);
    const profile = UserProfile(
      userId: 'u',
      age: 30,
      gender: 'female',
      weightKg: 60,
      heightCm: 165,
      activityLevel: 'light',
      healthGoal: 'maintain',
    );

    var notifications = 0;
    controller.addListener(() => notifications++);

    controller.updateFromProfile(profile);
    controller.updateFromProfile(profile); // no change

    expect(notifications, 1);
  });
}
