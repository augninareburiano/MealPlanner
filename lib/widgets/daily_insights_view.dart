import 'package:flutter/material.dart';

import '../models/nutrition_feedback.dart';
import 'glass.dart';

/// Read-only presentation of a [DailyFeedback]: how today's intake compared
/// with the user's DOST-FNRI-derived targets, followed by the advice the
/// feedback engine produced.
///
/// Pure (no data loading) so it's easy to reuse from other screens and to test
/// on its own.
class DailyInsightsView extends StatelessWidget {
  const DailyInsightsView({super.key, required this.feedback});

  final DailyFeedback feedback;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.insights, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text("Today's Insights",
                    style: theme.textTheme.titleMedium),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Compared with your DOST-FNRI nutrient goals',
            style: theme.textTheme.bodySmall,
          ),
          if (feedback.hasData) ...[
            const SizedBox(height: 12),
            for (final assessment in feedback.all)
              _AssessmentRow(assessment: assessment),
          ],
          const SizedBox(height: 8),
          for (final insight in feedback.insights)
            _InsightTile(insight: insight),
        ],
      ),
    );
  }
}

/// One nutrient's consumed-vs-target line, with a status-coloured bar.
class _AssessmentRow extends StatelessWidget {
  const _AssessmentRow({required this.assessment});

  final NutrientAssessment assessment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _statusColor(assessment.status);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(assessment.label,
                    style: theme.textTheme.bodyMedium),
              ),
              Text(
                '${assessment.consumed.round()} / '
                '${assessment.target.round()} ${assessment.unit}',
                style: theme.textTheme.bodySmall?.copyWith(color: color),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: assessment.progress),
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeOut,
              builder: (context, value, _) => LinearProgressIndicator(
                value: value,
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

  static Color _statusColor(NutrientStatus status) => switch (status) {
        NutrientStatus.under => Colors.orange,
        NutrientStatus.onTrack => Colors.green,
        NutrientStatus.over => Colors.redAccent,
      };
}

/// One piece of advice, with an icon and colour matched to its tone.
class _InsightTile extends StatelessWidget {
  const _InsightTile({required this.insight});

  final Insight insight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (icon, color) = _toneStyle(insight.tone);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(insight.title, style: theme.textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(insight.body, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static (IconData, Color) _toneStyle(InsightTone tone) => switch (tone) {
        InsightTone.positive => (Icons.check_circle, Colors.green),
        InsightTone.warning => (Icons.warning_amber_rounded, Colors.orange),
        InsightTone.info => (Icons.info_outline, Colors.blueAccent),
      };
}
