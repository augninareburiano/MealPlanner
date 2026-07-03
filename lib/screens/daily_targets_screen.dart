import 'package:flutter/material.dart';

import '../models/user_profile.dart';
import '../services/auth_service.dart';
import '../services/daily_budget_controller.dart';
import '../services/database_helper.dart';
import '../widgets/glass.dart';
import '../widgets/nutrient_targets_view.dart';

/// Shows the logged-in user's daily calorie and nutrient targets.
///
/// It pre-fills from the saved profile (best effort) and lets you tweak the
/// details inline; the targets below recompute live via [DailyBudgetController]
/// as the profile changes — the same recalculation the rest of the app uses.
class DailyTargetsScreen extends StatefulWidget {
  const DailyTargetsScreen({super.key});

  @override
  State<DailyTargetsScreen> createState() => _DailyTargetsScreenState();
}

class _DailyTargetsScreenState extends State<DailyTargetsScreen> {
  static const _activityLevels = [
    'sedentary',
    'light',
    'moderate',
    'active',
    'extra active',
  ];
  static const _goals = ['lose weight', 'maintain', 'gain muscle'];

  final _controller = DailyBudgetController();
  final _ageController = TextEditingController();
  final _weightController = TextEditingController();
  final _heightController = TextEditingController();

  // Draft profile fields, seeded with sensible defaults.
  String _gender = 'female';
  int? _age = 25;
  double? _weight = 60;
  double? _height = 160;
  String _activity = 'sedentary';
  String _goal = 'maintain';

  @override
  void initState() {
    super.initState();
    _ageController.text = '$_age';
    _weightController.text = '${_weight!.round()}';
    _heightController.text = '${_height!.round()}';
    _prefillFromProfile();
    _recompute();
  }

  @override
  void dispose() {
    _ageController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    _controller.dispose();
    super.dispose();
  }

  /// Best-effort: fill the form from the saved profile if one exists.
  Future<void> _prefillFromProfile() async {
    final userId = AuthService().currentUser?.uid;
    if (userId == null) return;

    UserProfile? profile;
    try {
      profile = await DatabaseHelper.instance.getUserProfile(userId);
    } catch (_) {
      return; // No DB / no profile yet — keep the defaults.
    }
    if (profile == null || !mounted) return;

    setState(() {
      _gender = profile!.gender ?? _gender;
      _age = profile.age ?? _age;
      _weight = profile.weightKg ?? _weight;
      _height = profile.heightCm ?? _height;
      _activity = _activityLevels.contains(profile.activityLevel)
          ? profile.activityLevel!
          : _activity;
      _goal = _goals.contains(profile.healthGoal) ? profile.healthGoal! : _goal;
      _ageController.text = _age?.toString() ?? '';
      _weightController.text = _weight?.round().toString() ?? '';
      _heightController.text = _height?.round().toString() ?? '';
    });
    _recompute();
  }

  void _recompute() {
    _controller.updateFromProfile(
      UserProfile(
        userId: 'preview',
        gender: _gender,
        age: _age,
        weightKg: _weight,
        heightCm: _height,
        activityLevel: _activity,
        healthGoal: _goal,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GradientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          title: const Text('Daily Targets'),
        ),
        body: ListView(
          children: [
            _detailsCard(context),
          AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final targets = _controller.targets;
              if (targets == null) return const SizedBox.shrink();
              return NutrientTargetsView(targets: targets);
            },
          ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _detailsCard(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Your details', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _numberField(_ageController, 'Age', (v) {
                  _age = int.tryParse(v);
                  _recompute();
                })),
                const SizedBox(width: 12),
                Expanded(
                  child: _numberField(_weightController, 'Weight (kg)', (v) {
                    _weight = double.tryParse(v);
                    _recompute();
                  }),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _numberField(_heightController, 'Height (cm)', (v) {
                    _height = double.tryParse(v);
                    _recompute();
                  }),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'female', label: Text('Female')),
                ButtonSegment(value: 'male', label: Text('Male')),
              ],
              selected: {_gender},
              onSelectionChanged: (s) {
                setState(() => _gender = s.first);
                _recompute();
              },
            ),
            const SizedBox(height: 16),
            _dropdown('Activity level', _activity, _activityLevels, (v) {
              setState(() => _activity = v);
              _recompute();
            }),
            const SizedBox(height: 12),
            _dropdown('Goal', _goal, _goals, (v) {
              setState(() => _goal = v);
              _recompute();
            }),
          ],
        ),
      ),
    );
  }

  Widget _numberField(
    TextEditingController controller,
    String label,
    ValueChanged<String> onChanged,
  ) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(labelText: label, isDense: true),
      onChanged: onChanged,
    );
  }

  Widget _dropdown(
    String label,
    String value,
    List<String> options,
    ValueChanged<String> onChanged,
  ) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label, isDense: true),
      items: [
        for (final option in options)
          DropdownMenuItem(
            value: option,
            child: Text(_titleCase(option)),
          ),
      ],
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }

  static String _titleCase(String s) => s
      .split(' ')
      .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');
}
