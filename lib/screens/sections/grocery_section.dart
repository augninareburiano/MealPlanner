import 'package:flutter/material.dart';

import '../../models/grocery_item.dart';
import '../../services/auth_service.dart';
import '../../services/database_helper.dart';
import '../../widgets/glass.dart';

/// A working grocery list: add items, tick them off, delete, and clear the
/// checked ones. Stored per-user in SQLite.
class GrocerySection extends StatefulWidget {
  const GrocerySection({super.key});

  @override
  State<GrocerySection> createState() => _GrocerySectionState();
}

class _GrocerySectionState extends State<GrocerySection> {
  final _db = DatabaseHelper.instance;
  final _addController = TextEditingController();
  late final String _userId;

  List<GroceryItem> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _userId = AuthService().currentUser?.uid ?? '';
    _load();
  }

  @override
  void dispose() {
    _addController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final items = await _db.getGroceryItems(_userId);
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  Future<void> _add() async {
    final name = _addController.text.trim();
    if (name.isEmpty) return;
    await _db.ensureUserProfile(_userId);
    await _db.insertGroceryItem(GroceryItem(userId: _userId, name: name));
    _addController.clear();
    _load();
  }

  Future<void> _toggle(GroceryItem item, bool checked) async {
    if (item.id == null) return;
    await _db.setGroceryChecked(item.id!, checked);
    _load();
  }

  Future<void> _delete(GroceryItem item) async {
    if (item.id == null) return;
    await _db.deleteGroceryItem(item.id!);
    _load();
  }

  Future<void> _clearChecked() async {
    await _db.clearCheckedGroceryItems(_userId);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final checkedCount = _items.where((i) => i.checked).length;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: GlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _addController,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _add(),
                    decoration: const InputDecoration(
                      hintText: 'Add an item…',
                      border: InputBorder.none,
                    ),
                  ),
                ),
                IconButton(icon: const Icon(Icons.add), onPressed: _add),
              ],
            ),
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _items.isEmpty
                  ? Center(
                      child: Text('Your grocery list is empty.',
                          style: theme.textTheme.bodyMedium),
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      children: [
                        GlassCard(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Column(
                            children: [
                              for (final item in _items)
                                Dismissible(
                                  key: ValueKey(item.id),
                                  direction: DismissDirection.endToStart,
                                  onDismissed: (_) => _delete(item),
                                  background: Container(
                                    alignment: Alignment.centerRight,
                                    padding: const EdgeInsets.only(right: 20),
                                    child: const Icon(Icons.delete_outline),
                                  ),
                                  child: CheckboxListTile(
                                    value: item.checked,
                                    onChanged: (v) => _toggle(item, v ?? false),
                                    title: Text(
                                      item.name,
                                      style: item.checked
                                          ? const TextStyle(
                                              decoration:
                                                  TextDecoration.lineThrough)
                                          : null,
                                    ),
                                    controlAffinity:
                                        ListTileControlAffinity.leading,
                                    dense: true,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (checkedCount > 0)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: OutlinedButton.icon(
                              onPressed: _clearChecked,
                              icon: const Icon(Icons.clear_all),
                              label: Text('Clear $checkedCount checked'),
                            ),
                          ),
                      ],
                    ),
        ),
      ],
    );
  }
}
