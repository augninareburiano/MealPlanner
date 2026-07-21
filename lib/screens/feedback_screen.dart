import 'package:flutter/material.dart';

import '../models/nutrition_feedback.dart';
import '../services/auth_service.dart';
import '../services/nutrition_feedback_service.dart';

/// Daily nutrition insights: compares today's logged meals against DOST-FNRI
/// dietary guidelines and shows per-nutrient feedback.
class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final _service = NutritionFeedbackService();
  late Future<NutritionFeedback> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<NutritionFeedback> _load() {
    final userId = AuthService().currentUser?.uid ?? '';
    return _service.loadDailyFeedback(userId, _today());
  }

  void _refresh() => setState(() => _future = _load());

  /// Today's date as `yyyy-MM-dd`, matching how meal logs are stored.
  static String _today() {
    final now = DateTime.now();
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return '${now.year}-$m-$d';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Today's Nutrition"),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
          ),
        ],
      ),
      body: FutureBuilder<NutritionFeedback>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  "Couldn't load your nutrition feedback.\n${snapshot.error}",
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          final feedback = snapshot.data!;
          return RefreshIndicator(
            onRefresh: () async => _refresh(),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _HeadlineCard(feedback: feedback),
                const SizedBox(height: 16),
                _NutrientCard(nutrient: feedback.energy),
                const SizedBox(height: 12),
                for (final macro in feedback.macros) ...[
                  _NutrientCard(nutrient: macro),
                  const SizedBox(height: 12),
                ],
                const SizedBox(height: 4),
                _GuidelineNote(fromDefaults: feedback.target.fromDefaults),
              ],
            ),
          );
        },
      ),
    );
  }
}

Color _statusColor(BuildContext context, NutrientStatus status) {
  final scheme = Theme.of(context).colorScheme;
  switch (status) {
    case NutrientStatus.onTrack:
      return Colors.green.shade600;
    case NutrientStatus.below:
      return Colors.orange.shade700;
    case NutrientStatus.above:
      return scheme.error;
  }
}

IconData _statusIcon(NutrientStatus status) {
  switch (status) {
    case NutrientStatus.onTrack:
      return Icons.check_circle;
    case NutrientStatus.below:
      return Icons.arrow_downward;
    case NutrientStatus.above:
      return Icons.arrow_upward;
  }
}

String _statusLabel(NutrientStatus status) {
  switch (status) {
    case NutrientStatus.onTrack:
      return 'On track';
    case NutrientStatus.below:
      return 'Below range';
    case NutrientStatus.above:
      return 'Above range';
  }
}

class _HeadlineCard extends StatelessWidget {
  const _HeadlineCard({required this.feedback});

  final NutritionFeedback feedback;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.insights, color: scheme.onPrimaryContainer),
                const SizedBox(width: 8),
                Text(
                  'Daily Insight',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: scheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              feedback.headline,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: scheme.onPrimaryContainer,
                  ),
            ),
            if (!feedback.intake.isEmpty) ...[
              const SizedBox(height: 12),
              Text(
                '${feedback.intake.mealCount} meal'
                '${feedback.intake.mealCount == 1 ? '' : 's'} logged · '
                '${feedback.onTrackCount}/4 nutrients on track',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onPrimaryContainer.withValues(alpha: 0.8),
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _NutrientCard extends StatelessWidget {
  const _NutrientCard({required this.nutrient});

  final NutrientFeedback nutrient;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(context, nutrient.status);
    final consumed = nutrient.consumed.round();
    final low = nutrient.recommended.low.round();
    final high = nutrient.recommended.high.round();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    nutrient.label,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                Icon(_statusIcon(nutrient.status), size: 18, color: color),
                const SizedBox(width: 4),
                Text(
                  _statusLabel(nutrient.status),
                  style: TextStyle(color: color, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '$consumed ${nutrient.unit}  ·  recommended $low–$high '
              '${nutrient.unit}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: nutrient.progress,
                minHeight: 8,
                backgroundColor: color.withValues(alpha: 0.15),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              nutrient.insight,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _GuidelineNote extends StatelessWidget {
  const _GuidelineNote({required this.fromDefaults});

  final bool fromDefaults;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (fromDefaults) ...[
          Text(
            'Tip: complete your profile (age, sex, height, weight, activity) '
            'for a personalised energy target. Showing general DOST-FNRI '
            'defaults for now.',
            style: style,
          ),
          const SizedBox(height: 8),
        ],
        Text(
          'Recommendations are based on the DOST-FNRI Philippine Dietary '
          'Reference Intakes (PDRI). Energy needs are estimated from your '
          'profile and are a guide, not medical advice.',
          style: style,
        ),
      ],
    );
  }
}
