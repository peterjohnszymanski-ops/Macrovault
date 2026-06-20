import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:macrovault/core/theme.dart';
import 'package:macrovault/models/enums.dart';
import 'package:macrovault/models/food.dart';
import 'package:macrovault/state/providers.dart';

/// Bottom sheet to confirm a food log. Pre-fills your last portion + usual meal
/// for this food, lets you log by servings or grams, and star it as a favorite.
class LogFoodSheet extends ConsumerStatefulWidget {
  const LogFoodSheet({
    super.key,
    required this.food,
    required this.day,
    required this.initialSlot,
    required this.source,
  });

  final Food food;
  final String day;
  final MealSlot initialSlot;
  final EntrySource source;

  @override
  ConsumerState<LogFoodSheet> createState() => _LogFoodSheetState();
}

class _LogFoodSheetState extends ConsumerState<LogFoodSheet> {
  late MealSlot _slot = widget.food.lastMealSlot ?? widget.initialSlot;
  late bool _fav = widget.food.isFavorite;
  bool _byGrams = false;
  // The number in the input box (servings when !_byGrams, grams when _byGrams).
  late final TextEditingController _amount =
      TextEditingController(text: _trim(widget.food.lastQty));
  bool _saving = false;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  String _trim(double v) =>
      v % 1 == 0 ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

  /// Effective servings, derived from the input + mode.
  double get _servings {
    final raw = double.tryParse(_amount.text) ?? 0;
    if (!_byGrams) return raw;
    final g = widget.food.servingGrams;
    return g > 0 ? raw / g : raw;
  }

  void _switchMode(bool byGrams) {
    if (byGrams == _byGrams) return;
    final servings = _servings;
    setState(() {
      _byGrams = byGrams;
      if (byGrams) {
        _amount.text = _trim(servings * widget.food.servingGrams);
      } else {
        _amount.text = _trim(servings);
      }
    });
  }

  Future<void> _toggleFav() async {
    setState(() => _fav = !_fav);
    await ref.read(servicesProvider).foods.setFavorite(widget.food.id, _fav);
    ref.bumpLogMutation();
  }

  Future<void> _log() async {
    setState(() => _saving = true);
    final services = ref.read(servicesProvider);
    final user = await ref.read(currentUserProvider.future);
    if (user == null) return;
    await services.logging.logFood(
      userId: user.id,
      day: widget.day,
      slot: _slot,
      food: widget.food,
      qty: _servings,
      source: widget.source,
    );
    ref.bumpLogMutation();
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final f = widget.food;
    final s = _servings;
    final kcal = (f.kcal * s).round();
    final m = f.macros.scale(s);
    return Padding(
      padding: EdgeInsets.fromLTRB(
          16, 8, 16, MediaQuery.of(context).viewInsets.bottom + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(f.displayName,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700)),
              ),
              IconButton(
                tooltip: _fav ? 'Unfavorite' : 'Favorite',
                icon: Icon(_fav ? Icons.star : Icons.star_border,
                    color: _fav ? AppColors.carbs : null),
                onPressed: _toggleFav,
              ),
              if (f.isEstimated)
                const Chip(
                  label: Text('estimated', style: TextStyle(fontSize: 11)),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
          Text('Per serving: ${f.servingDesc} · ${f.kcal.round()} kcal',
              style: const TextStyle(fontSize: 12)),
          Gap.h16,
          Row(
            children: [
              SizedBox(
                width: 100,
                child: TextField(
                  controller: _amount,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                      labelText: _byGrams ? 'Grams' : 'Servings'),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              Gap.w12,
              if (f.servingGrams > 0)
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: false, label: Text('Serving')),
                    ButtonSegment(value: true, label: Text('Grams')),
                  ],
                  selected: {_byGrams},
                  onSelectionChanged: (sel) => _switchMode(sel.first),
                  style: const ButtonStyle(visualDensity: VisualDensity.compact),
                ),
              const Spacer(),
              Text('$kcal kcal',
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w800)),
            ],
          ),
          Gap.h8,
          Text(
              'P ${m.protein.round()}g · C ${m.carbs.round()}g · F ${m.fat.round()}g',
              style: const TextStyle(color: AppColors.protein)),
          Gap.h16,
          const Text('Meal', style: TextStyle(fontWeight: FontWeight.w600)),
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
            onPressed: _saving || s <= 0 ? null : _log,
            child: Text('Log to ${_slot.label}'),
          ),
        ],
      ),
    );
  }
}

/// Convenience to present the sheet.
Future<bool> showLogFoodSheet(
  BuildContext context, {
  required Food food,
  required String day,
  required MealSlot slot,
  required EntrySource source,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => LogFoodSheet(
        food: food, day: day, initialSlot: slot, source: source),
  );
  return result ?? false;
}
