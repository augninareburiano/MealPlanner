import 'package:flutter/material.dart';

import '../models/meal_log.dart';
import '../models/user_profile.dart';
import '../services/auth_service.dart';
import '../services/calorie_calculator.dart';
import '../services/database_helper.dart';
import '../utils/date_format.dart';
import '../utils/meal_types.dart';
import '../widgets/add_food_dialog.dart';
import '../widgets/calorie_summary_card.dart';
import '../widgets/meal_section_card.dart';

/// Main dashboard: today's calorie budget plus the breakfast / lunch / dinner
/// sections, each able to log food or (later) generate a food plan.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _authService = AuthService();
  final _db = DatabaseHelper.instance;

  late final String _userId;
  late final String _todayIso;

  UserProfile? _profile;
  List<MealLog> _logs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _userId = _authService.currentUser?.uid ?? '';
    _todayIso = isoDate(DateTime.now());
    _load();
  }

  Future<void> _load() async {
    final profile = await _db.getUserProfile(_userId);
    final logs = await _db.getMealLogsForDate(_userId, _todayIso);
    if (!mounted) return;
    setState(() {
      _profile = profile;
      _logs = logs;
      _loading = false;
    });
  }

  List<MealLog> _logsFor(String mealType) =>
      _logs.where((log) => log.mealType == mealType).toList();

  double get _foodCalories =>
      _logs.fold(0, (sum, log) => sum + (log.calories ?? 0));

  Future<void> _addFood(String mealType) async {
    final added = await showAddFoodDialog(
      context,
      userId: _userId,
      mealDate: _todayIso,
      mealType: mealType,
    );
    if (added) _load();
  }

  Future<void> _deleteLog(MealLog log) async {
    if (log.id == null) return;
    await _db.deleteMealLog(log.id!);
    _load();
  }

  void _generatePlan(String mealType) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Food plan generation is coming soon.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final target = CalorieCalculator.dailyTarget(_profile);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: _authService.signOut,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(
                      top: 12,
                      left: 16,
                      right: 16,
                    ),
                    child: Text(
                      friendlyDate(DateTime.now()),
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  CalorieSummaryCard(
                    target: target,
                    foodCalories: _foodCalories,
                  ),
                  for (final mealType in kMainMealTypes)
                    MealSectionCard(
                      mealType: mealType,
                      items: _logsFor(mealType),
                      onAddFood: () => _addFood(mealType),
                      onGeneratePlan: () => _generatePlan(mealType),
                      onDeleteItem: _deleteLog,
                    ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }
}
