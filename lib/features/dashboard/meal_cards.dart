import 'package:flutter/material.dart';
import 'package:macrovault/core/theme.dart';
import 'package:macrovault/features/dashboard/meal_detail_screen.dart';
import 'package:macrovault/models/enums.dart';
import 'package:macrovault/state/dashboard.dart';

/// Breakfast / Lunch / Dinner / Snacks as their own tappable cards, each
/// showing its calorie subtotal. Tap to open that meal; the donut up top is the
/// running day total.
class MealCards extends StatelessWidget {
  const MealCards({super.key, required this.data});
  final DashboardData data;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 2.4,
      children: [
        for (final slot in MealSlot.values)
          _MealCard(slot: slot, data: data),
      ],
    );
  }
}

class _MealCard extends StatelessWidget {
  const _MealCard({required this.slot, required this.data});
  final MealSlot slot;
  final DashboardData data;

  @override
  Widget build(BuildContext context) {
    final entries = data.entries(slot);
    final kcal = entries.fold(0.0, (s, e) => s + e.snapshotKcal).round();
    final empty = entries.isEmpty;
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => MealDetailScreen(slot: slot, day: data.day))),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(slot.label,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(
                      empty ? 'add' : '${entries.length} item${entries.length == 1 ? '' : 's'}',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    empty ? '0' : '$kcal',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: empty ? AppColors.textMuted : AppColors.brand,
                    ),
                  ),
                  Icon(empty ? Icons.add : Icons.chevron_right,
                      size: 16,
                      color: empty ? AppColors.brand : AppColors.textMuted),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
