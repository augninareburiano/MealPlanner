import 'package:flutter/material.dart';

import '../../models/exercise_entry.dart';
import '../../models/meal_log.dart';
import '../../models/nutrient_targets.dart';
import '../../services/app_events.dart';
import '../../services/auth_service.dart';
import '../../services/daily_budget_controller.dart';
import '../../services/database_helper.dart';
import '../../services/nutrition_feedback_engine.dart';
import '../../utils/date_format.dart';
import '../../utils/meal_types.dart';
import '../../widgets/animations.dart';
import '../../widgets/daily_insights_view.dart';
import '../../widgets/glass.dart';

/// The post-login landing screen: today's calories (target − eaten + exercise),
/// macro progress, meals, water, and exercise — all on frosted-glass cards and
/// driven by real data. Refreshes when meals or the profile change.
class DashboardSection extends StatefulWidget {
  const DashboardSection({super.key, this.onOpenMealPlanner});

  final VoidCallback? onOpenMealPlanner;

  @override
  State<DashboardSection> createState() => _DashboardSectionState();
}

class _DashboardSectionState extends State<DashboardSection> {
  final _db = DatabaseHelper.instance;
  final _budget = DailyBudgetController();

  late final String _userId;
  late final String _todayIso;

  List<MealLog> _logs = [];
  List<ExerciseEntry> _exercises = [];
  int _glasses = 0;

  static const _waterGoalGlasses = 8;

  @override
  void initState() {
    super.initState();
    _userId = AuthService().currentUser?.uid ?? '';
    _todayIso = isoDate(DateTime.now());
    _loadBudget();
    _loadDay();
    AppEvents.instance.mealsChanged.addListener(_loadDay);
    AppEvents.instance.profileChanged.addListener(_loadBudget);
  }

  @override
  void dispose() {
    AppEvents.instance.mealsChanged.removeListener(_loadDay);
    AppEvents.instance.profileChanged.removeListener(_loadBudget);
    _budget.dispose();
    super.dispose();
  }

  Future<void> _loadBudget() => _budget.load(_userId);

  Future<void> _loadDay() async {
    final logs = await _db.getMealLogsForDate(_userId, _todayIso);
    final exercises = await _db.getExercisesForDate(_userId, _todayIso);
    final glasses = await _db.getWaterGlasses(_userId, _todayIso);
    if (!mounted) return;
    setState(() {
      _logs = logs;
      _exercises = exercises;
      _glasses = glasses;
    });
  }

  double get _eaten => _logs.fold(0, (s, l) => s + (l.calories ?? 0));
  double get _burned => _exercises.fold(0, (s, e) => s + e.calories);
  double _macroEaten(double Function(MealLog) pick) =>
      _logs.fold(0, (s, l) => s + pick(l));
  double _eatenFor(String type) =>
      _logs.where((l) => l.mealType == type).fold(0, (s, l) => s + (l.calories ?? 0));

  Future<void> _setGlasses(int glasses) async {
    setState(() => _glasses = glasses);
    await _db.setWaterGlasses(_userId, _todayIso, glasses);
  }

  Future<void> _addExercise() async {
    final nameController = TextEditingController();
    final calController = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Log exercise'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Activity'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: calController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Calories burned'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (result != true) return;
    final cals = double.tryParse(calController.text.trim());
    final name = nameController.text.trim();
    if (cals == null || cals <= 0 || name.isEmpty) return;
    await _db.insertExercise(ExerciseEntry(
      userId: _userId,
      entryDate: _todayIso,
      name: name,
      calories: cals,
    ));
    _loadDay();
  }

  Future<void> _deleteExercise(ExerciseEntry e) async {
    if (e.id == null) return;
    await _db.deleteExercise(e.id!);
    _loadDay();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final email = AuthService().currentUser?.email ?? '';
    final name = email.contains('@') ? email.split('@').first : 'there';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        FadeSlideIn(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Hi, $name 👋', style: theme.textTheme.headlineSmall),
              const SizedBox(height: 4),
              Text("Here's your day at a glance.",
                  style: theme.textTheme.bodyMedium),
            ],
          ),
        ),
        const SizedBox(height: 16),
        FadeSlideIn(delay: _d(1), child: _caloriesCard(context)),
        const SizedBox(height: 12),
        FadeSlideIn(delay: _d(2), child: _macrosCard(context)),
        const SizedBox(height: 12),
        FadeSlideIn(delay: _d(3), child: _insightsCard(context)),
        const SizedBox(height: 12),
        FadeSlideIn(delay: _d(4), child: _todaysMealsCard(context)),
        const SizedBox(height: 12),
        FadeSlideIn(delay: _d(5), child: _waterCard(context)),
        const SizedBox(height: 12),
        FadeSlideIn(delay: _d(6), child: _exerciseCard(context)),
      ],
    );
  }

  Duration _d(int i) => Duration(milliseconds: 80 * i);

  Widget _caloriesCard(BuildContext context) {
    final theme = Theme.of(context);
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: AnimatedBuilder(
        animation: _budget,
        builder: (context, _) {
          final target = _budget.targets?.calories;
          final remaining =
              target == null ? null : (target - _eaten + _burned).round();
          final progress = (target == null || target <= 0)
              ? 0.0
              : (_eaten / target).clamp(0.0, 1.0);
          return Column(
            children: [
              Text('Calories Remaining', style: theme.textTheme.titleMedium),
              const SizedBox(height: 12),
              remaining == null
                  ? Text('—', style: theme.textTheme.displaySmall)
                  : AnimatedCount(
                      value: remaining,
                      style: theme.textTheme.displaySmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
              Text(
                target == null
                    ? 'Loading your target…'
                    : 'goal $target · ${_eaten.round()} eaten · ${_burned.round()} burned',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: const BorderRadius.all(Radius.circular(8)),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: progress),
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeOut,
                  builder: (context, value, _) => LinearProgressIndicator(
                    value: value,
                    minHeight: 8,
                    backgroundColor: Colors.white.withValues(alpha: 0.4),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _macrosCard(BuildContext context) {
    final theme = Theme.of(context);
    return GlassCard(
      child: AnimatedBuilder(
        animation: _budget,
        builder: (context, _) {
          final NutrientTargets? t = _budget.targets;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Macros', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              _macroBar('Protein', _macroEaten((l) => l.protein ?? 0),
                  t?.proteinG, Colors.redAccent),
              _macroBar('Carbs', _macroEaten((l) => l.carbs ?? 0), t?.carbsG,
                  Colors.orangeAccent),
              _macroBar('Fat', _macroEaten((l) => l.fat ?? 0), t?.fatG,
                  Colors.blueAccent),
            ],
          );
        },
      ),
    );
  }

  Widget _macroBar(String label, double eaten, double? target, Color color) {
    final theme = Theme.of(context);
    final pct = (target == null || target <= 0)
        ? 0.0
        : (eaten / target).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
              Text(
                target == null
                    ? '${eaten.round()} g'
                    : '${eaten.round()} / ${target.round()} g',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: pct),
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeOut,
              builder: (context, v, _) => LinearProgressIndicator(
                value: v,
                minHeight: 6,
                color: color,
                backgroundColor: color.withValues(alpha: 0.15),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Daily feedback: today's logged intake assessed against the user's
  /// DOST-FNRI-derived targets. Rebuilds whenever meals or targets change.
  ///
  /// Intake is compared as eaten, without crediting exercise, because the
  /// comparison being made is against dietary guidelines rather than against
  /// the day's net energy balance shown in the calories card.
  Widget _insightsCard(BuildContext context) {
    return AnimatedBuilder(
      animation: _budget,
      builder: (context, _) {
        final targets = _budget.targets;
        if (targets == null) {
          return const GlassCard(
            child: Center(child: CircularProgressIndicator()),
          );
        }
        return DailyInsightsView(
          feedback: NutritionFeedbackEngine.evaluate(
            targets: targets,
            logs: _logs,
          ),
        );
      },
    );
  }

  Widget _todaysMealsCard(BuildContext context) {
    final theme = Theme.of(context);
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child:
                    Text("Today's Meals", style: theme.textTheme.titleMedium),
              ),
              TextButton(
                onPressed: widget.onOpenMealPlanner,
                child: const Text('Plan'),
              ),
            ],
          ),
          for (final type in kMealTypes)
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: Icon(
                _eatenFor(type) > 0
                    ? Icons.check_circle
                    : Icons.circle_outlined,
                size: 20,
                color: _eatenFor(type) > 0 ? theme.colorScheme.primary : null,
              ),
              title: Text(mealTypeLabel(type)),
              trailing: Text(
                _eatenFor(type) > 0
                    ? '${_eatenFor(type).round()} kcal'
                    : 'Not logged',
                style: theme.textTheme.bodySmall,
              ),
              onTap: widget.onOpenMealPlanner,
            ),
        ],
      ),
    );
  }

  Widget _waterCard(BuildContext context) {
    final theme = Theme.of(context);
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.water_drop, color: Colors.blue),
              const SizedBox(width: 8),
              Expanded(
                child:
                    Text('Water Tracker', style: theme.textTheme.titleMedium),
              ),
              Text('$_glasses / $_waterGoalGlasses glasses',
                  style: theme.textTheme.titleSmall),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: _glasses / _waterGoalGlasses),
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOut,
              builder: (context, value, _) => LinearProgressIndicator(
                value: value,
                minHeight: 8,
                backgroundColor: Colors.blue.withValues(alpha: 0.15),
                color: Colors.blue,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton.outlined(
                onPressed:
                    _glasses > 0 ? () => _setGlasses(_glasses - 1) : null,
                icon: const Icon(Icons.remove),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: _glasses < _waterGoalGlasses
                    ? () => _setGlasses(_glasses + 1)
                    : null,
                icon: const Icon(Icons.add),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _exerciseCard(BuildContext context) {
    final theme = Theme.of(context);
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.directions_run, color: Colors.deepOrange),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Exercise', style: theme.textTheme.titleMedium),
              ),
              Text('${_burned.round()} kcal',
                  style: theme.textTheme.titleSmall),
            ],
          ),
          if (_exercises.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text('No exercise logged.',
                  style: theme.textTheme.bodySmall),
            )
          else
            for (final e in _exercises)
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(e.name),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${e.calories.round()} kcal'),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => _deleteExercise(e),
                    ),
                  ],
                ),
              ),
          const Divider(),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _addExercise,
              icon: const Icon(Icons.add),
              label: const Text('Log exercise'),
            ),
          ),
        ],
      ),
    );
  }
}
