import 'package:flutter/foundation.dart';

import '../models/nutrient_targets.dart';
import '../models/user_profile.dart';
import 'daily_budget_calculator.dart';
import 'database_helper.dart';

/// Shared, listenable source of the current user's daily [NutrientTargets].
///
/// This is how targets are made available to the other screens: they read
/// [targets] and rebuild via [ChangeNotifier] (e.g. `AnimatedBuilder` or a
/// provider). Targets are recomputed automatically whenever the profile
/// changes — either after a fresh [load] from the database, or immediately via
/// [updateFromProfile] when a screen edits the profile.
class DailyBudgetController extends ChangeNotifier {
  DailyBudgetController({Future<UserProfile?> Function(String userId)? profileLoader})
      : _loadProfile =
            profileLoader ?? DatabaseHelper.instance.getUserProfile;

  final Future<UserProfile?> Function(String userId) _loadProfile;

  NutrientTargets? _targets;

  /// The latest computed targets, or null before the first [load].
  NutrientTargets? get targets => _targets;

  /// Loads the profile for [userId] and recomputes the targets.
  Future<void> load(String userId) async {
    final profile = await _loadProfile(userId);
    _setTargets(DailyBudgetCalculator.forProfile(profile));
  }

  /// Recomputes immediately from an in-hand [profile] (e.g. right after the
  /// user saves profile edits), so screens update without a DB round-trip.
  void updateFromProfile(UserProfile? profile) {
    _setTargets(DailyBudgetCalculator.forProfile(profile));
  }

  void _setTargets(NutrientTargets next) {
    if (next == _targets) return; // No change -> no needless rebuild.
    _targets = next;
    notifyListeners();
  }
}
