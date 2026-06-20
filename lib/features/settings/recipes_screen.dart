import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:macrovault/core/theme.dart';
import 'package:macrovault/features/common/widgets.dart';
import 'package:macrovault/models/food.dart';
import 'package:macrovault/models/recipe.dart';
import 'package:macrovault/state/providers.dart';
import 'package:uuid/uuid.dart';

final _recipesProvider = FutureProvider<List<Recipe>>((ref) async {
  ref.logMutationToken;
  return ref.watch(servicesProvider).foods.recipes();
});

class RecipesScreen extends ConsumerWidget {
  const RecipesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recipes = ref.watch(_recipesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Recipes')),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('New recipe'),
        onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const RecipeEditorScreen())),
      ),
      body: recipes.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (list) {
          if (list.isEmpty) {
            return const EmptyHint('No recipes yet.', icon: Icons.menu_book);
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final r in list)
                Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    title: Text(r.name),
                    subtitle: Text('${r.yieldServings.round()} servings'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) =>
                            RecipeEditorScreen(recipeId: r.id))),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class RecipeEditorScreen extends ConsumerStatefulWidget {
  const RecipeEditorScreen({super.key, this.recipeId});
  final String? recipeId;

  @override
  ConsumerState<RecipeEditorScreen> createState() =>
      _RecipeEditorScreenState();
}

class _RecipeEditorScreenState extends ConsumerState<RecipeEditorScreen> {
  final _name = TextEditingController();
  final _yield = TextEditingController(text: '1');
  final _ingredients = <RecipeIngredient>[];
  String _recipeId = const Uuid().v4();
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    if (widget.recipeId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    } else {
      _loaded = true;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _yield.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final rw = await ref
        .read(servicesProvider)
        .foods
        .recipeWithIngredients(widget.recipeId!);
    if (rw == null) return;
    setState(() {
      _recipeId = rw.recipe.id;
      _name.text = rw.recipe.name;
      _yield.text = '${rw.recipe.yieldServings.round()}';
      _ingredients
        ..clear()
        ..addAll(rw.ingredients);
      _loaded = true;
    });
  }

  RecipeWithIngredients get _preview => RecipeWithIngredients(
        Recipe(
          id: _recipeId,
          userId: '',
          name: _name.text,
          yieldServings: double.tryParse(_yield.text) ?? 1,
          createdAt: DateTime.now(),
        ),
        _ingredients,
      );

  Future<void> _addIngredient() async {
    final services = ref.read(servicesProvider);
    final selected = await showModalBottomSheet<Food>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _FoodPickerSheet(search: services.foods.searchLocal),
    );
    if (selected == null) return;
    final qtyStr = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final c = TextEditingController(text: '1');
        return AlertDialog(
          title: Text(selected.displayName),
          content: TextField(
            controller: c,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Servings'),
          ),
          actions: [
            FilledButton(
                onPressed: () => Navigator.pop(ctx, c.text),
                child: const Text('Add')),
          ],
        );
      },
    );
    final qty = double.tryParse(qtyStr ?? '') ?? 1;
    setState(() {
      _ingredients.add(RecipeIngredient(
        id: const Uuid().v4(),
        recipeId: _recipeId,
        foodId: selected.id,
        foodName: selected.displayName,
        qty: qty,
        kcal: selected.kcal * qty,
        macros: selected.macros.scale(qty),
      ));
    });
  }

  Future<void> _save() async {
    final user = await ref.read(currentUserProvider.future);
    if (user == null) return;
    final recipe = Recipe(
      id: _recipeId,
      userId: user.id,
      name: _name.text.trim().isEmpty ? 'Recipe' : _name.text.trim(),
      yieldServings: double.tryParse(_yield.text) ?? 1,
      createdAt: DateTime.now(),
    );
    await ref.read(servicesProvider).foods.saveRecipe(recipe, _ingredients);
    ref.bumpLogMutation();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final p = _preview;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recipe'),
        actions: [
          IconButton(icon: const Icon(Icons.check), onPressed: _save),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Recipe name'),
          ),
          Gap.h12,
          TextField(
            controller: _yield,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Yield (servings)'),
            onChanged: (_) => setState(() {}),
          ),
          Gap.h16,
          SectionCard(
            title: 'Per serving',
            child: Text(
              '${p.perServingKcal.round()} kcal · '
              'P${p.perServingMacros.protein.round()}g '
              'C${p.perServingMacros.carbs.round()}g '
              'F${p.perServingMacros.fat.round()}g'
              '${p.isPartialEstimate ? '  (partial estimate)' : ''}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Gap.h16,
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Ingredients',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              TextButton.icon(
                onPressed: _addIngredient,
                icon: const Icon(Icons.add),
                label: const Text('Add'),
              ),
            ],
          ),
          if (_ingredients.isEmpty)
            const EmptyHint('No ingredients yet.\nAdd from your saved foods.',
                icon: Icons.egg_outlined)
          else
            for (var i = 0; i < _ingredients.length; i++)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(_ingredients[i].foodName),
                subtitle: Text(
                    '${_ingredients[i].qty} serving · ${_ingredients[i].kcal.round()} kcal'),
                trailing: IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: () => setState(() => _ingredients.removeAt(i)),
                ),
              ),
        ],
      ),
    );
  }
}

/// Minimal local-food picker used by the recipe editor.
class _FoodPickerSheet extends StatefulWidget {
  const _FoodPickerSheet({required this.search});
  final Future<List<Food>> Function(String, {int limit}) search;

  @override
  State<_FoodPickerSheet> createState() => _FoodPickerSheetState();
}

class _FoodPickerSheetState extends State<_FoodPickerSheet> {
  List<Food> _results = [];

  @override
  void initState() {
    super.initState();
    _run('');
  }

  Future<void> _run(String q) async {
    final r = await widget.search(q, limit: 40);
    if (mounted) setState(() => _results = r);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          16, 0, 16, MediaQuery.of(context).viewInsets.bottom + 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            autofocus: true,
            decoration: const InputDecoration(
                hintText: 'Search your foods…',
                prefixIcon: Icon(Icons.search)),
            onChanged: _run,
          ),
          const SizedBox(height: 8),
          if (_results.isEmpty)
            const EmptyHint('No saved foods match.', icon: Icons.search_off)
          else
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final f in _results)
                    ListTile(
                      title: Text(f.displayName),
                      subtitle: Text('${f.kcal.round()} kcal'),
                      onTap: () => Navigator.pop(context, f),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
