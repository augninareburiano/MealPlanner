import 'package:flutter/material.dart';

import '../../models/weight_entry.dart';
import '../../services/auth_service.dart';
import '../../services/database_helper.dart';
import '../../utils/date_format.dart';
import '../../widgets/glass.dart';

/// Logs weigh-ins and shows the latest weight, the change since the first
/// entry, and the full history. Stored per-user in SQLite.
class WeightTrackerSection extends StatefulWidget {
  const WeightTrackerSection({super.key});

  @override
  State<WeightTrackerSection> createState() => _WeightTrackerSectionState();
}

class _WeightTrackerSectionState extends State<WeightTrackerSection> {
  final _db = DatabaseHelper.instance;
  late final String _userId;

  List<WeightEntry> _entries = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _userId = AuthService().currentUser?.uid ?? '';
    _load();
  }

  Future<void> _load() async {
    final entries = await _db.getWeightEntries(_userId);
    if (!mounted) return;
    setState(() {
      _entries = entries;
      _loading = false;
    });
  }

  Future<void> _logWeight() async {
    final controller = TextEditingController();
    final value = await showDialog<double>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Log weight'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Weight (kg)'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(context).pop(double.tryParse(controller.text)),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (value == null || value <= 0) return;

    await _db.ensureUserProfile(_userId);
    await _db.insertWeightEntry(WeightEntry(
      userId: _userId,
      entryDate: isoDate(DateTime.now()),
      weightKg: value,
    ));
    _load();
  }

  Future<void> _delete(WeightEntry e) async {
    if (e.id == null) return;
    await _db.deleteWeightEntry(e.id!);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final latest = _entries.isNotEmpty ? _entries.first.weightKg : null;
    final first = _entries.isNotEmpty ? _entries.last.weightKg : null;
    final change =
        (latest != null && first != null) ? latest - first : null;

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _logWeight,
        icon: const Icon(Icons.add),
        label: const Text('Log weight'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                GlassCard(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Text('Current Weight',
                          style: theme.textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Text(
                        latest == null ? '—' : '${latest.toStringAsFixed(1)} kg',
                        style: theme.textTheme.displaySmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (change != null && change != 0) ...[
                        const SizedBox(height: 4),
                        Text(
                          '${change > 0 ? '+' : ''}${change.toStringAsFixed(1)} kg since you started',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (_entries.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Text('No weigh-ins yet. Tap "Log weight".',
                          style: theme.textTheme.bodyMedium),
                    ),
                  )
                else
                  GlassCard(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      children: [
                        for (final e in _entries)
                          ListTile(
                            dense: true,
                            leading: const Icon(Icons.monitor_weight_outlined),
                            title: Text('${e.weightKg.toStringAsFixed(1)} kg'),
                            subtitle: Text(e.entryDate),
                            trailing: IconButton(
                              icon: const Icon(Icons.close, size: 18),
                              onPressed: () => _delete(e),
                            ),
                          ),
                      ],
                    ),
                  ),
                const SizedBox(height: 80),
              ],
            ),
    );
  }
}
