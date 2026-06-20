import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:macrovault/core/theme.dart';
import 'package:macrovault/features/dashboard/meal_section.dart';
import 'package:macrovault/features/logging/add_food_screen.dart';
import 'package:macrovault/models/enums.dart';
import 'package:macrovault/state/dashboard.dart';

/// A single meal opened from its dashboard card: its entries (edit/delete/save-
/// as-usual) plus a prominent add button.
class MealDetailScreen extends ConsumerWidget {
  const MealDetailScreen({super.key, required this.slot, required this.day});
  final MealSlot slot;
  final String day;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(dashboardProvider(day));
    return Scaffold(
      appBar: AppBar(title: Text(slot.label)),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.brand,
        foregroundColor: AppColors.brandInk,
        icon: const Icon(Icons.add),
        label: const Text('Add food'),
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => AddFoodScreen(day: day, slot: slot))),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (data) {
          if (data == null) return const SizedBox();
          final entries = data.entries(slot);
          final kcal = entries.fold(0.0, (s, e) => s + e.snapshotKcal).round();
          final macros = data.entries(slot).fold(
              0.0, (s, e) => s + e.snapshotMacros.protein);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _stat('$kcal', 'calories', AppColors.brand),
                      _stat('${macros.round()}g', 'protein',
                          AppColors.protein),
                      _stat('${entries.length}', 'items', AppColors.text),
                    ],
                  ),
                ),
              ),
              Gap.h16,
              MealSection(slot: slot, entries: entries, day: day),
              const SizedBox(height: 80),
            ],
          );
        },
      ),
    );
  }

  Widget _stat(String v, String l, Color c) => Column(
        children: [
          Text(v,
              style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w800, color: c)),
          Text(l, style: const TextStyle(fontSize: 12)),
        ],
      );
}
