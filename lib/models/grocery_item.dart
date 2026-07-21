/// A single grocery-list line, stored in the `grocery_item` table.
///
/// Linked to a [UserProfile] via [userId] (the Firebase user id).
class GroceryItem {
  final int? id;
  final String userId;
  final String name;
  final bool checked;

  const GroceryItem({
    this.id,
    required this.userId,
    required this.name,
    this.checked = false,
  });

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'user_id': userId,
        'name': name,
        'checked': checked ? 1 : 0,
      };

  factory GroceryItem.fromMap(Map<String, Object?> map) => GroceryItem(
        id: (map['id'] as num?)?.toInt(),
        userId: map['user_id'] as String,
        name: map['name'] as String,
        checked: ((map['checked'] as num?)?.toInt() ?? 0) == 1,
      );

  GroceryItem copyWith({bool? checked}) => GroceryItem(
        id: id,
        userId: userId,
        name: name,
        checked: checked ?? this.checked,
      );
}
