import 'package:flutter/material.dart';

import '../models/meal_log.dart';
import '../services/auth_service.dart';
import '../services/database_helper.dart';
import '../utils/date_format.dart';
import '../utils/meal_types.dart';
import '../widgets/meal_section_card.dart';

/// History view: pick a date on the calendar and see that day's logged meals,
/// with the calorie total per meal category.
class DiaryScreen extends StatefulWidget {
  const DiaryScreen({super.key});

  @override
  State<DiaryScreen> createState() => _DiaryScreenState();
}

class _DiaryScreenState extends State<DiaryScreen> {
  final _authService = AuthService();
  final _db = DatabaseHelper.instance;

  late final String _userId;
  DateTime _selectedDate = DateTime.now();
  List<MealLog> _logs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _userId = _authService.currentUser?.uid ?? '';
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final logs = await _db.getMealLogsForDate(_userId, isoDate(_selectedDate));
    if (!mounted) return;
    setState(() {
      _logs = logs;
      _loading = false;
    });
  }

  void _onDateChanged(DateTime date) {
    setState(() => _selectedDate = date);
    _load();
  }

  List<MealLog> _logsFor(String mealType) =>
      _logs.where((log) => log.mealType == mealType).toList();

  double get _dayTotal =>
      _logs.fold(0, (sum, log) => sum + (log.calories ?? 0));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Diary')),
      body: ListView(
        children: [
          Card(
            margin: const EdgeInsets.all(16),
            child: CalendarDatePicker(
              initialDate: _selectedDate,
              firstDate: DateTime(2020),
              lastDate: DateTime.now(),
              onDateChanged: _onDateChanged,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    friendlyDate(_selectedDate),
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                Text(
                  '${_dayTotal.round()} kcal',
                  style: theme.textTheme.titleMedium,
                ),
              ],
            ),
          ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            )
          else
            for (final mealType in kMealTypes)
              MealSectionCard(mealType: mealType, items: _logsFor(mealType)),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
