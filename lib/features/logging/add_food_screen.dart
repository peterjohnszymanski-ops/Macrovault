import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:macrovault/core/theme.dart';
import 'package:macrovault/features/common/widgets.dart';
import 'package:macrovault/features/logging/ai_meal_confirm_sheet.dart';
import 'package:macrovault/features/logging/barcode_scanner_screen.dart';
import 'package:macrovault/features/logging/custom_food_screen.dart';
import 'package:macrovault/features/logging/log_food_sheet.dart';
import 'package:macrovault/features/logging/quick_add_sheet.dart';
import 'package:macrovault/models/enums.dart';
import 'package:macrovault/models/food.dart';
import 'package:macrovault/services/vision_food_service.dart';
import 'package:macrovault/state/providers.dart';

/// The fast-logging hub: Recents (one-tap), Search (local + remote), Scan, and
/// Create custom. Recents/personal foods always rank above public-DB results.
class AddFoodScreen extends ConsumerStatefulWidget {
  const AddFoodScreen({
    super.key,
    required this.day,
    required this.slot,
    this.startScanning = false,
  });

  final String day;
  final MealSlot slot;
  final bool startScanning;

  @override
  ConsumerState<AddFoodScreen> createState() => _AddFoodScreenState();
}

class _AddFoodScreenState extends ConsumerState<AddFoodScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;
  String _query = '';
  List<Food> _localResults = [];
  List<Food> _remoteResults = [];
  bool _searchingRemote = false;

  @override
  void initState() {
    super.initState();
    if (widget.startScanning) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scan());
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onQueryChanged(String q) {
    _query = q;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _runSearch);
  }

  Future<void> _runSearch() async {
    final services = ref.read(servicesProvider);
    final q = _query.trim();
    final local = await services.foods.searchLocal(q);
    setState(() {
      _localResults = local;
      _remoteResults = [];
      _searchingRemote = q.length >= 2;
    });
    if (q.length >= 2) {
      final remote = await services.foodApi.search(q);
      if (mounted && _query.trim() == q) {
        // Drop remote rows that duplicate a local food by name+brand.
        final localKeys =
            local.map((f) => '${f.name}|${f.brand}'.toLowerCase()).toSet();
        setState(() {
          _remoteResults = remote
              .where((f) =>
                  !localKeys.contains('${f.name}|${f.brand}'.toLowerCase()))
              .toList();
          _searchingRemote = false;
        });
      }
    }
  }

  Future<void> _scan() async {
    final code = await Navigator.of(context).push<String>(
        MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()));
    if (code == null || !mounted) return;
    final services = ref.read(servicesProvider);
    var food = await services.foods.findByBarcode(code);
    food ??= await services.foodApi.byBarcode(code);
    if (!mounted) return;
    if (food != null) {
      await _present(food, EntrySource.scan);
    } else {
      // Not found anywhere → create a custom food prefilled with the barcode.
      final created = await Navigator.of(context).push<Food>(MaterialPageRoute(
          builder: (_) => CustomFoodScreen(barcode: code)));
      if (created != null && mounted) {
        await _present(created, EntrySource.scan);
      }
    }
  }

  Future<void> _present(Food food, EntrySource source) async {
    final logged = await showLogFoodSheet(
      context,
      food: food,
      day: widget.day,
      slot: widget.slot,
      source: source,
    );
    if (logged && mounted) Navigator.of(context).pop();
  }

  Future<void> _quickAdd() async {
    final done = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => QuickAddSheet(day: widget.day, slot: widget.slot),
    );
    if (done == true && mounted) Navigator.of(context).pop();
  }

  /// Snap a meal → AI estimates the foods → you confirm before anything saves.
  /// Off unless the user enabled it with a proxy endpoint (Settings → AI).
  Future<void> _snapMeal() async {
    final user = await ref.read(currentUserProvider.future);
    if (!mounted) return;
    if (user == null) return;
    if (!user.aiPhotoReady) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Food photo AI is off'),
          content: const Text(
            'MacroVault is local-first, so photo recognition is opt-in. Turn it '
            'on in More → Food photo AI and set your vision proxy URL. Your '
            'photo is only sent once you enable it — and you always confirm the '
            'results before anything is logged.',
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
          ],
        ),
      );
      return;
    }

    final picked = await ImagePicker()
        .pickImage(source: ImageSource.camera, imageQuality: 85);
    if (picked == null || !mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final items = await ref.read(servicesProvider).vision.recognize(
            proxyUrl: user.aiProxyUrl!,
            imagePath: picked.path,
            mealSlot: widget.slot.storageValue,
          );
      if (!mounted) return;
      Navigator.of(context).pop(); // dismiss spinner
      if (items.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('No foods detected. Try a clearer photo.')));
        return;
      }
      final done = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => AiMealConfirmSheet(
            items: items, day: widget.day, slot: widget.slot),
      );
      if (done == true && mounted) Navigator.of(context).pop();
    } on VisionException catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Photo AI failed: $e')));
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not reach the vision proxy: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final searching = _query.trim().isNotEmpty;
    return Scaffold(
      appBar: AppBar(
        title: Text('Add to ${widget.slot.label}'),
        actions: [
          IconButton(
            tooltip: 'Snap a meal',
            icon: const Icon(Icons.camera_alt_outlined),
            onPressed: _snapMeal,
          ),
          IconButton(
              icon: const Icon(Icons.qr_code_scanner), onPressed: _scan),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _searchController,
              autofocus: !widget.startScanning,
              onChanged: _onQueryChanged,
              decoration: InputDecoration(
                hintText: 'Search foods…',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: searching
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _onQueryChanged('');
                        },
                      )
                    : null,
              ),
            ),
          ),
          Expanded(
            child: searching
                ? _SearchResults(
                    local: _localResults,
                    remote: _remoteResults,
                    searchingRemote: _searchingRemote,
                    onTap: (f, src) => _present(f, src),
                  )
                : _QuickPicks(
                    slot: widget.slot,
                    onTap: (f, src) => _present(f, src),
                  ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.bolt),
                      label: const Text('Quick add'),
                      onPressed: _quickAdd,
                    ),
                  ),
                  Gap.w8,
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text('Custom food'),
                      onPressed: () async {
                        final created = await Navigator.of(context).push<Food>(
                            MaterialPageRoute(
                                builder: (_) => const CustomFoodScreen()));
                        if (created != null && mounted) {
                          await _present(created, EntrySource.manual);
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The default (non-searching) view: your favorites, then foods you usually log
/// at this meal first. Mirrors MyNetDiary surfacing your breakfast foods when
/// you open breakfast.
class _QuickPicks extends ConsumerWidget {
  const _QuickPicks({required this.slot, required this.onTap});
  final MealSlot slot;
  final void Function(Food, EntrySource) onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favorites = ref.watch(favoritesProvider);
    final recents = ref.watch(recentsForMealProvider(slot));
    return recents.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
      data: (recentList) {
        final favList = favorites.asData?.value ?? [];
        if (recentList.isEmpty && favList.isEmpty) {
          return const EmptyHint(
              'No foods yet.\nSearch, scan, or snap a meal to log your first.',
              icon: Icons.restaurant_outlined);
        }
        final favIds = favList.map((f) => f.id).toSet();
        return ListView(
          children: [
            if (favList.isNotEmpty) ...[
              _header('Favorites'),
              for (final f in favList) _tile(f),
            ],
            if (recentList.isNotEmpty) ...[
              _header('${slot.label} & recent — tap to log again'),
              for (final f in recentList)
                if (!favIds.contains(f.id)) _tile(f),
            ],
          ],
        );
      },
    );
  }

  Widget _header(String s) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child:
            Text(s, style: const TextStyle(fontWeight: FontWeight.w700)),
      );

  Widget _tile(Food f) => ListTile(
        leading: f.isFavorite
            ? const Icon(Icons.star, color: AppColors.carbs, size: 20)
            : null,
        title: Text(f.displayName),
        subtitle: Text(
            '${f.kcal.round()} kcal · last: ${f.lastQty % 1 == 0 ? f.lastQty.toInt() : f.lastQty} serving'),
        trailing: const Icon(Icons.add_circle_outline),
        onTap: () => onTap(f, EntrySource.recent),
      );
}

class _SearchResults extends StatelessWidget {
  const _SearchResults({
    required this.local,
    required this.remote,
    required this.searchingRemote,
    required this.onTap,
  });

  final List<Food> local;
  final List<Food> remote;
  final bool searchingRemote;
  final void Function(Food, EntrySource) onTap;

  @override
  Widget build(BuildContext context) {
    if (local.isEmpty && remote.isEmpty && !searchingRemote) {
      return const EmptyHint('No matches. Try a custom food.',
          icon: Icons.search_off);
    }
    return ListView(
      children: [
        if (local.isNotEmpty) ...[
          _header('Your foods'),
          for (final f in local)
            _tile(f, EntrySource.search, badge: f.isCustom ? 'custom' : null),
        ],
        if (searchingRemote)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Row(children: [
              SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2)),
              SizedBox(width: 12),
              Text('Searching food databases…'),
            ]),
          ),
        if (remote.isNotEmpty) ...[
          _header('Food databases'),
          for (final f in remote)
            _tile(f, EntrySource.search, badge: 'estimated'),
        ],
      ],
    );
  }

  Widget _header(String s) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child:
            Text(s, style: const TextStyle(fontWeight: FontWeight.w700)),
      );

  Widget _tile(Food f, EntrySource src, {String? badge}) => ListTile(
        title: Text(f.displayName),
        subtitle: Text('${f.kcal.round()} kcal · ${f.servingDesc}'),
        trailing: badge == null
            ? const Icon(Icons.add_circle_outline)
            : Chip(
                label: Text(badge, style: const TextStyle(fontSize: 11)),
                visualDensity: VisualDensity.compact),
        onTap: () => onTap(f, src),
      );
}
