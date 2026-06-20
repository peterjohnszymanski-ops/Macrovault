import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:macrovault/models/enums.dart';
import 'package:macrovault/models/food_entry.dart';
import 'package:macrovault/models/meal_template.dart';
import 'package:macrovault/state/providers.dart';
import 'package:uuid/uuid.dart';

/// Saves the current meal's entries as a reusable template, optionally marking
/// it the "usual" for this slot.
class SaveUsualDialog extends ConsumerStatefulWidget {
  const SaveUsualDialog({super.key, required this.slot, required this.entries});
  final MealSlot slot;
  final List<FoodEntry> entries;

  @override
  ConsumerState<SaveUsualDialog> createState() => _SaveUsualDialogState();
}

class _SaveUsualDialogState extends ConsumerState<SaveUsualDialog> {
  late final TextEditingController _name =
      TextEditingController(text: 'My usual ${widget.slot.label.toLowerCase()}');
  bool _markUsual = true;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final services = ref.read(servicesProvider);
    final user = await ref.read(currentUserProvider.future);
    if (user == null) return;
    final items = widget.entries
        .map((e) => MealItem(
              foodId: e.foodId,
              foodName: e.foodName,
              qty: e.qty,
              kcal: e.snapshotKcal,
              macros: e.snapshotMacros,
            ))
        .toList();
    final template = MealTemplate(
      id: const Uuid().v4(),
      userId: user.id,
      name: _name.text.trim().isEmpty ? 'Saved meal' : _name.text.trim(),
      items: items,
      usualSlot: _markUsual ? widget.slot : null,
      createdAt: DateTime.now(),
    );
    await services.foods.upsertTemplate(template);
    ref.bumpLogMutation();
    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Saved "${template.name}"')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Save as usual'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Name'),
          ),
          const SizedBox(height: 8),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _markUsual,
            onChanged: (v) => setState(() => _markUsual = v ?? true),
            title: Text('Make this my usual ${widget.slot.label.toLowerCase()}'),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}
