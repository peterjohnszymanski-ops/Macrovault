import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:macrovault/features/common/widgets.dart';
import 'package:macrovault/models/enums.dart';
import 'package:macrovault/models/meal_template.dart';
import 'package:macrovault/state/providers.dart';

/// One-tap "log a usual / saved meal" surface.
class UsualsSheet extends ConsumerWidget {
  const UsualsSheet({super.key, required this.day});
  final String day;

  Future<void> _log(
      BuildContext context, WidgetRef ref, MealTemplate t) async {
    final services = ref.read(servicesProvider);
    final user = await ref.read(currentUserProvider.future);
    if (user == null) return;
    await services.logging.logTemplate(
      userId: user.id,
      day: day,
      slot: t.usualSlot ?? MealSlot.snack,
      template: t,
    );
    ref.bumpLogMutation();
    if (context.mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Logged "${t.name}"')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usuals = ref.watch(usualsProvider);
    final templates = ref.watch(templatesProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Your usuals',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          templates.maybeWhen(
            data: (all) {
              if (all.isEmpty) {
                return const EmptyHint(
                    'No saved meals yet.\nLog a meal, then "Save as my usual".',
                    icon: Icons.replay);
              }
              final usualList = usuals.asData?.value ?? [];
              final usualIds = usualList.map((e) => e.id).toSet();
              final others =
                  all.where((t) => !usualIds.contains(t.id)).toList();
              return Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final t in usualList) _tile(context, ref, t, true),
                    if (others.isNotEmpty)
                      const Padding(
                        padding: EdgeInsets.fromLTRB(0, 12, 0, 4),
                        child: Text('Saved meals',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    for (final t in others) _tile(context, ref, t, false),
                  ],
                ),
              );
            },
            orElse: () =>
                const Center(child: CircularProgressIndicator()),
          ),
        ],
      ),
    );
  }

  Widget _tile(
          BuildContext context, WidgetRef ref, MealTemplate t, bool usual) =>
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(usual ? Icons.star : Icons.restaurant_menu),
        title: Text(t.name),
        subtitle: Text(
            '${t.totalKcal.round()} kcal · P${t.totalMacros.protein.round()}g'
            '${t.usualSlot != null ? ' · ${t.usualSlot!.label}' : ''}'),
        trailing: const Icon(Icons.add_circle_outline),
        onTap: () => _log(context, ref, t),
      );
}
