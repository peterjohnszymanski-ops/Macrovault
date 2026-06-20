import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:macrovault/core/theme.dart';
import 'package:macrovault/models/enums.dart';
import 'package:macrovault/models/macros.dart';
import 'package:macrovault/state/providers.dart';

/// MyNetDiary-style "Quick add calories": log an amount + macros with no food
/// record. Calories auto-derive from macros if left blank.
class QuickAddSheet extends ConsumerStatefulWidget {
  const QuickAddSheet({super.key, required this.day, required this.slot});
  final String day;
  final MealSlot slot;

  @override
  ConsumerState<QuickAddSheet> createState() => _QuickAddSheetState();
}

class _QuickAddSheetState extends ConsumerState<QuickAddSheet> {
  final _label = TextEditingController(text: 'Quick add');
  final _kcal = TextEditingController();
  final _protein = TextEditingController();
  final _carbs = TextEditingController();
  final _fat = TextEditingController();
  late MealSlot _slot = widget.slot;

  @override
  void dispose() {
    for (final c in [_label, _kcal, _protein, _carbs, _fat]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final services = ref.read(servicesProvider);
    final user = await ref.read(currentUserProvider.future);
    if (user == null) return;
    final macros = Macros(
      protein: double.tryParse(_protein.text) ?? 0,
      carbs: double.tryParse(_carbs.text) ?? 0,
      fat: double.tryParse(_fat.text) ?? 0,
    );
    final kcal = double.tryParse(_kcal.text) ?? macros.derivedKcal;
    await services.logging.logQuickAdd(
      userId: user.id,
      day: widget.day,
      slot: _slot,
      kcal: kcal,
      macros: macros,
      label: _label.text.trim().isEmpty ? 'Quick add' : _label.text.trim(),
    );
    ref.bumpLogMutation();
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          16, 8, 16, MediaQuery.of(context).viewInsets.bottom + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Quick add',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          Gap.h12,
          TextField(
            controller: _label,
            decoration: const InputDecoration(labelText: 'Label'),
          ),
          Gap.h12,
          TextField(
            controller: _kcal,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration:
                const InputDecoration(labelText: 'Calories (blank = auto)'),
          ),
          Gap.h12,
          Row(children: [
            Expanded(child: _macro(_protein, 'Protein g')),
            Gap.w8,
            Expanded(child: _macro(_carbs, 'Carbs g')),
            Gap.w8,
            Expanded(child: _macro(_fat, 'Fat g')),
          ]),
          Gap.h16,
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
          FilledButton(onPressed: _save, child: const Text('Add')),
        ],
      ),
    );
  }

  Widget _macro(TextEditingController c, String label) => TextField(
        controller: c,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(labelText: label),
      );
}
