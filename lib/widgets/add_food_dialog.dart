import 'package:flutter/material.dart';

import '../models/meal_log.dart';
import '../services/database_helper.dart';
import '../utils/meal_types.dart';

/// Opens a modal to manually log a food item into [mealType] on [mealDate].
///
/// Inserts a [MealLog] and resolves to `true` when a row was added, so the
/// caller can refresh. This manual entry is the interim logger until food
/// search / the nutrition API lands.
Future<bool> showAddFoodDialog(
  BuildContext context, {
  required String userId,
  required String mealDate,
  required String mealType,
}) async {
  final added = await showDialog<bool>(
    context: context,
    builder: (_) => _AddFoodDialog(
      userId: userId,
      mealDate: mealDate,
      mealType: mealType,
    ),
  );
  return added ?? false;
}

class _AddFoodDialog extends StatefulWidget {
  const _AddFoodDialog({
    required this.userId,
    required this.mealDate,
    required this.mealType,
  });

  final String userId;
  final String mealDate;
  final String mealType;

  @override
  State<_AddFoodDialog> createState() => _AddFoodDialogState();
}

class _AddFoodDialogState extends State<_AddFoodDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _servingController = TextEditingController();
  final _caloriesController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _servingController.dispose();
    _caloriesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final db = DatabaseHelper.instance;
    // meal_log has a foreign key to user_profile; make sure a row exists.
    await db.ensureUserProfile(widget.userId);

    final serving = _servingController.text.trim();
    await db.insertMealLog(
      MealLog(
        userId: widget.userId,
        mealDate: widget.mealDate,
        mealType: widget.mealType,
        foodName: _nameController.text.trim(),
        servingSize: serving.isEmpty ? null : serving,
        calories: double.tryParse(_caloriesController.text.trim()),
      ),
    );

    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Add to ${mealTypeLabel(widget.mealType)}'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameController,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Food name'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Enter a food name' : null,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _servingController,
              decoration: const InputDecoration(
                labelText: 'Serving size (optional)',
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _caloriesController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'Calories (kcal)'),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Enter the calories';
                final n = double.tryParse(v.trim());
                if (n == null || n < 0) return 'Enter a valid number';
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Add'),
        ),
      ],
    );
  }
}
