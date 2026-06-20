import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:macrovault/core/theme.dart';
import 'package:macrovault/models/enums.dart';
import 'package:macrovault/services/vision_food_service.dart';
import 'package:macrovault/state/providers.dart';

/// Shows what the food-photo AI thinks it saw. Nothing is logged until the user
/// confirms — each item is individually toggleable and its calories editable.
class AiMealConfirmSheet extends ConsumerStatefulWidget {
  const AiMealConfirmSheet({
    super.key,
    required this.items,
    required this.day,
    required this.slot,
  });

  final List<ParsedFoodItem> items;
  final String day;
  final MealSlot slot;

  @override
  ConsumerState<AiMealConfirmSheet> createState() =>
      _AiMealConfirmSheetState();
}

class _AiMealConfirmSheetState extends ConsumerState<AiMealConfirmSheet> {
  late MealSlot _slot = widget.slot;
  bool _saving = false;

  Future<void> _confirm() async {
    setState(() => _saving = true);
    final services = ref.read(servicesProvider);
    final user = await ref.read(currentUserProvider.future);
    if (user == null) return;
    for (final item in widget.items.where((i) => i.selected)) {
      await services.logging.logQuickAdd(
        userId: user.id,
        day: widget.day,
        slot: _slot,
        kcal: item.kcal,
        macros: item.macros,
        label: item.name,
      );
    }
    ref.bumpLogMutation();
    if (mounted) Navigator.of(context).pop(true);
  }

  Color _confidenceColor(double c) =>
      c >= 0.75 ? AppColors.good : (c >= 0.5 ? AppColors.warn : AppColors.danger);

  @override
  Widget build(BuildContext context) {
    final anySelected = widget.items.any((i) => i.selected);
    return Padding(
      padding: EdgeInsets.fromLTRB(
          16, 8, 16, MediaQuery.of(context).viewInsets.bottom + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Detected in your photo',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          const Text(
            'AI estimates — check them before logging. Tap a calorie value to edit.',
            style: TextStyle(fontSize: 12),
          ),
          Gap.h12,
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final item in widget.items)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: item.selected,
                    onChanged: (v) =>
                        setState(() => item.selected = v ?? false),
                    title: Row(
                      children: [
                        Expanded(child: Text(item.name)),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _confidenceColor(item.confidence)
                                .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${(item.confidence * 100).round()}%',
                            style: TextStyle(
                                fontSize: 11,
                                color: _confidenceColor(item.confidence)),
                          ),
                        ),
                      ],
                    ),
                    subtitle: GestureDetector(
                      onTap: () => _editKcal(item),
                      child: Text(
                        '${item.kcal.round()} kcal · '
                        'P${item.macros.protein.round()} '
                        'C${item.macros.carbs.round()} '
                        'F${item.macros.fat.round()}  (tap to edit)',
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Gap.h8,
          Wrap(
            spacing: 8,
            children: [
              for (final slot in MealSlot.values)
                ChoiceChip(
                  label: Text(slot.label),
                  selected: _slot == slot,
                  onSelected: (_) => setState(() => _slot = slot),
                ),
            ],
          ),
          Gap.h16,
          FilledButton(
            onPressed: _saving || !anySelected ? null : _confirm,
            child: Text('Log ${widget.items.where((i) => i.selected).length} item(s)'),
          ),
        ],
      ),
    );
  }

  Future<void> _editKcal(ParsedFoodItem item) async {
    final c = TextEditingController(text: '${item.kcal.round()}');
    final v = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(item.name),
        content: TextField(
          controller: c,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Calories'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, double.tryParse(c.text)),
              child: const Text('Save')),
        ],
      ),
    );
    if (v != null) setState(() => item.kcal = v);
  }
}
