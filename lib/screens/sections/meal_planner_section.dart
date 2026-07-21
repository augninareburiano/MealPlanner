import 'package:flutter/material.dart';

import '../../models/meal_log.dart';
import '../../services/app_events.dart';
import '../../services/auth_service.dart';
import '../../services/database_helper.dart';
import '../../utils/date_format.dart';
import '../../utils/meal_types.dart';
import '../../widgets/add_food_dialog.dart';
import '../../widgets/animations.dart';
import '../../widgets/glass.dart';
import '../../widgets/meal_section_card.dart';

/// Meal Planner + Diary: pick a date, then log or review meals per category
/// (Breakfast / Lunch / Dinner / Snacks). Logs feed the Dashboard totals.
class MealPlannerSection extends StatefulWidget {
  const MealPlannerSection({super.key});

  @override
  State<MealPlannerSection> createState() => _MealPlannerSectionState();
}

class _MealPlannerSectionState extends State<MealPlannerSection> {
  final _db = DatabaseHelper.instance;
  late final String _userId;

  DateTime _date = DateTime.now();
  List<MealLog> _logs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _userId = AuthService().currentUser?.uid ?? '';
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final logs = await _db.getMealLogsForDate(_userId, isoDate(_date));
    if (!mounted) return;
    setState(() {
      _logs = logs;
      _loading = false;
    });
  }

  List<MealLog> _logsFor(String type) =>
      _logs.where((l) => l.mealType == type).toList();

  double get _dayTotal =>
      _logs.fold(0, (sum, l) => sum + (l.calories ?? 0));

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _date = picked);
      _load();
    }
  }

  Future<void> _addFood(String mealType) async {
    final added = await showAddFoodDialog(
      context,
      userId: _userId,
      mealDate: isoDate(_date),
      mealType: mealType,
    );
    if (added) {
      AppEvents.instance.bumpMeals();
      _load();
    }
  }

  Future<void> _deleteLog(MealLog log) async {
    if (log.id == null) return;
    await _db.deleteMealLog(log.id!);
    AppEvents.instance.bumpMeals();
    _load();
  }

  Future<void> _editLog(MealLog log) async {
    final nameController = TextEditingController(text: log.foodName);
    final servingController =
        TextEditingController(text: log.servingSize ?? '');
    final calController =
        TextEditingController(text: (log.calories ?? 0).round().toString());

    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Edit food'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Food name'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: servingController,
              decoration:
                  const InputDecoration(labelText: 'Serving size (optional)'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: calController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Calories (kcal)'),
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
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (saved != true) return;

    final name = nameController.text.trim();
    if (name.isEmpty) return;
    final serving = servingController.text.trim();
    await _db.updateMealLog(MealLog(
      id: log.id,
      userId: log.userId,
      mealDate: log.mealDate,
      mealType: log.mealType,
      foodName: name,
      servingSize: serving.isEmpty ? null : serving,
      calories: double.tryParse(calController.text.trim()),
      protein: log.protein,
      carbs: log.carbs,
      fat: log.fat,
      apiMealId: log.apiMealId,
    ));
    AppEvents.instance.bumpMeals();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        FadeSlideIn(
          child: GlassCard(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(friendlyDate(_date),
                          style: theme.textTheme.titleMedium),
                      const SizedBox(height: 2),
                      Text('${_dayTotal.round()} kcal logged',
                          style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.calendar_today, size: 18),
                  label: const Text('Date'),
                ),
              ],
            ),
          ),
        ),
        if (_loading)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator()),
          )
        else
          for (var i = 0; i < kMealTypes.length; i++)
            FadeSlideIn(
              delay: Duration(milliseconds: 80 * (i + 1)),
              child: MealSectionCard(
                mealType: kMealTypes[i],
                items: _logsFor(kMealTypes[i]),
                onAddFood: () => _addFood(kMealTypes[i]),
                onDeleteItem: _deleteLog,
                onEditItem: _editLog,
              ),
            ),
        const SizedBox(height: 24),
      ],
    );
  }
}
