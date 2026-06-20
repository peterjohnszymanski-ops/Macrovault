import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:macrovault/core/theme.dart';
import 'package:macrovault/features/logging/add_food_screen.dart';
import 'package:macrovault/features/logging/save_usual_dialog.dart';
import 'package:macrovault/models/enums.dart';
import 'package:macrovault/models/food_entry.dart';
import 'package:macrovault/state/providers.dart';

/// One meal slot's entries on the diary, with a per-meal total and an add
/// button. Tapping an entry edits the quantity; swipe/long-press deletes.
class MealSection extends ConsumerWidget {
  const MealSection({
    super.key,
    required this.slot,
    required this.entries,
    required this.day,
  });

  final MealSlot slot;
  final List<FoodEntry> entries;
  final String day;

  double get _kcal => entries.fold(0.0, (s, e) => s + e.snapshotKcal);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(slot.label,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700)),
                const Spacer(),
                if (entries.isNotEmpty)
                  Text('${_kcal.round()} kcal',
                      style: TextStyle(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.6))),
                if (entries.isNotEmpty)
                  PopupMenuButton<String>(
                    onSelected: (v) {
                      if (v == 'usual') {
                        showDialog(
                          context: context,
                          builder: (_) =>
                              SaveUsualDialog(slot: slot, entries: entries),
                        );
                      }
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                          value: 'usual',
                          child: Text('Save as my usual')),
                    ],
                  ),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => AddFoodScreen(day: day, slot: slot))),
                ),
              ],
            ),
            if (entries.isEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 0, bottom: 4, top: 2),
                child: Text('Nothing logged',
                    style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.4))),
              )
            else
              for (final e in entries) _EntryTile(entry: e),
          ],
        ),
      ),
    );
  }
}

class _EntryTile extends ConsumerWidget {
  const _EntryTile({required this.entry});
  final FoodEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Dismissible(
      key: ValueKey(entry.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        color: AppColors.danger.withValues(alpha: 0.15),
        child: const Icon(Icons.delete_outline, color: AppColors.danger),
      ),
      onDismissed: (_) async {
        await ref.read(servicesProvider).entries.delete(entry.id);
        ref.bumpLogMutation();
      },
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 0),
        dense: true,
        title: Text(entry.foodName),
        subtitle: Text(
            '${entry.qty % 1 == 0 ? entry.qty.toInt() : entry.qty} serving · '
            'P${entry.snapshotMacros.protein.round()} '
            'C${entry.snapshotMacros.carbs.round()} '
            'F${entry.snapshotMacros.fat.round()}'),
        trailing: Text('${entry.snapshotKcal.round()}',
            style: const TextStyle(fontWeight: FontWeight.w600)),
        onTap: () => _editQty(context, ref),
      ),
    );
  }

  Future<void> _editQty(BuildContext context, WidgetRef ref) async {
    final controller =
        TextEditingController(text: '${entry.qty}');
    final result = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(entry.foodName),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Servings'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(
                ctx, double.tryParse(controller.text) ?? entry.qty),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result == null || result <= 0) return;
    // Rescale the snapshot proportionally to the new quantity.
    final factor = result / entry.qty;
    final updated = entry.copyWith(
      qty: result,
      snapshotKcal: entry.snapshotKcal * factor,
      snapshotMacros: entry.snapshotMacros.scale(factor),
    );
    await ref.read(servicesProvider).entries.update(updated);
    ref.bumpLogMutation();
  }
}
