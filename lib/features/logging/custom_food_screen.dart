import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:macrovault/core/theme.dart';
import 'package:macrovault/models/macros.dart';
import 'package:macrovault/state/providers.dart';

/// Create a custom food. Returns the created Food via Navigator.pop so the
/// caller can immediately log it.
class CustomFoodScreen extends ConsumerStatefulWidget {
  const CustomFoodScreen({super.key, this.barcode});
  final String? barcode;

  @override
  ConsumerState<CustomFoodScreen> createState() => _CustomFoodScreenState();
}

class _CustomFoodScreenState extends ConsumerState<CustomFoodScreen> {
  final _name = TextEditingController();
  final _brand = TextEditingController();
  final _serving = TextEditingController(text: '1 serving');
  final _grams = TextEditingController(text: '100');
  final _kcal = TextEditingController();
  final _protein = TextEditingController();
  final _carbs = TextEditingController();
  final _fat = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [
      _name,
      _brand,
      _serving,
      _grams,
      _kcal,
      _protein,
      _carbs,
      _fat
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Give your food a name.')));
      return;
    }
    setState(() => _saving = true);
    final services = ref.read(servicesProvider);
    final user = await ref.read(currentUserProvider.future);
    if (user == null) return;
    final macros = Macros(
      protein: double.tryParse(_protein.text) ?? 0,
      carbs: double.tryParse(_carbs.text) ?? 0,
      fat: double.tryParse(_fat.text) ?? 0,
    );
    // If kcal left blank, derive from macros.
    final kcal = double.tryParse(_kcal.text) ?? macros.derivedKcal;
    final food = await services.logging.createCustomFood(
      userId: user.id,
      name: _name.text.trim(),
      brand: _brand.text.trim().isEmpty ? null : _brand.text.trim(),
      barcode: widget.barcode,
      servingDesc: _serving.text.trim().isEmpty ? '1 serving' : _serving.text.trim(),
      servingGrams: double.tryParse(_grams.text) ?? 100,
      kcal: kcal,
      macros: macros,
    );
    ref.bumpLogMutation();
    if (mounted) Navigator.of(context).pop(food);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Custom food')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (widget.barcode != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text('Barcode: ${widget.barcode}',
                  style: const TextStyle(fontSize: 12)),
            ),
          _field(_name, 'Name'),
          _field(_brand, 'Brand (optional)'),
          Row(children: [
            Expanded(child: _field(_serving, 'Serving description')),
            Gap.w12,
            SizedBox(
                width: 110,
                child: _field(_grams, 'Grams', number: true)),
          ]),
          Gap.h8,
          const Text('Per serving', style: TextStyle(fontWeight: FontWeight.w700)),
          Gap.h8,
          _field(_kcal, 'Calories (kcal) — blank to auto-calc', number: true),
          Row(children: [
            Expanded(child: _field(_protein, 'Protein g', number: true)),
            Gap.w8,
            Expanded(child: _field(_carbs, 'Carbs g', number: true)),
            Gap.w8,
            Expanded(child: _field(_fat, 'Fat g', number: true)),
          ]),
          Gap.h24,
          FilledButton(
            onPressed: _saving ? null : _save,
            child: const Text('Save & log'),
          ),
        ],
      ),
    );
  }

  Widget _field(TextEditingController c, String label, {bool number = false}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: c,
          keyboardType: number
              ? const TextInputType.numberWithOptions(decimal: true)
              : TextInputType.text,
          decoration: InputDecoration(labelText: label),
        ),
      );
}
