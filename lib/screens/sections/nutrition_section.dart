import 'package:flutter/material.dart';

import '../../services/app_events.dart';
import '../../services/auth_service.dart';
import '../../services/daily_budget_controller.dart';
import '../../widgets/animations.dart';
import '../../widgets/nutrient_targets_view.dart';
import '../daily_targets_screen.dart';

/// The Nutrition tab: the user's daily calorie and macro/micronutrient targets,
/// worked out from their profile using the DOST-FNRI RENI values.
///
/// Read-only here; the "Customize" action opens the interactive editor.
class NutritionSection extends StatefulWidget {
  const NutritionSection({super.key});

  @override
  State<NutritionSection> createState() => _NutritionSectionState();
}

class _NutritionSectionState extends State<NutritionSection> {
  final _budget = DailyBudgetController();

  @override
  void initState() {
    super.initState();
    _load();
    AppEvents.instance.profileChanged.addListener(_load);
  }

  @override
  void dispose() {
    AppEvents.instance.profileChanged.removeListener(_load);
    _budget.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final userId = AuthService().currentUser?.uid;
    if (userId != null) await _budget.load(userId);
  }

  Future<void> _openEditor() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const DailyTargetsScreen()),
    );
    // Refresh in case the profile was tweaked while customizing.
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _budget,
      builder: (context, _) {
        final targets = _budget.targets;
        if (targets == null) {
          return const Center(child: CircularProgressIndicator());
        }
        return ListView(
          children: [
            const SizedBox(height: 8),
            FadeSlideIn(child: NutrientTargetsView(targets: targets)),
            const SizedBox(height: 16),
            FadeSlideIn(
              delay: const Duration(milliseconds: 150),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: OutlinedButton.icon(
                  onPressed: _openEditor,
                  icon: const Icon(Icons.tune),
                  label: const Text('Customize targets'),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        );
      },
    );
  }
}
