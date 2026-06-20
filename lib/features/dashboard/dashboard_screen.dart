import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:macrovault/core/date_utils.dart';
import 'package:macrovault/core/formatters.dart';
import 'package:macrovault/core/theme.dart';
import 'package:macrovault/features/common/macro_donut.dart';
import 'package:macrovault/features/common/widgets.dart';
import 'package:macrovault/features/dashboard/meal_cards.dart';
import 'package:macrovault/features/dashboard/reset_prompt.dart';
import 'package:macrovault/features/logging/add_food_screen.dart';
import 'package:macrovault/features/logging/usuals_sheet.dart';
import 'package:macrovault/features/measurements/measurements_screen.dart';
import 'package:macrovault/features/photos/photos_screen.dart';
import 'package:macrovault/features/weekly_review/weekly_review_screen.dart';
import 'package:macrovault/features/weight/weight_screen.dart';
import 'package:macrovault/models/body_logs.dart';
import 'package:macrovault/models/enums.dart';
import 'package:macrovault/state/dashboard.dart';
import 'package:macrovault/state/providers.dart';
import 'package:uuid/uuid.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final day = ref.watch(selectedDayProvider);
    final async = ref.watch(dashboardProvider(day));

    return Scaffold(
      appBar: AppBar(
        title: const Text('MacroVault'),
        actions: [
          IconButton(
            tooltip: 'Weekly review',
            icon: const Icon(Icons.event_note_outlined),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const WeeklyReviewScreen())),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (data) {
          if (data == null) {
            return const Center(child: Text('Set up your goal to begin.'));
          }
          return RefreshIndicator(
            onRefresh: () async => ref.bumpLogMutation(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                _DateBar(day: day),
                Gap.h12,
                if (data.showResetPrompt) ...[
                  ResetPromptCard(data: data),
                  Gap.h16,
                ],
                _HeroCard(data: data),
                Gap.h16,
                _QuickActions(day: day),
                Gap.h16,
                Row(
                  children: [
                    const Text('Meals',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
                    const Spacer(),
                    Text('${data.consumedKcal.round()} kcal total',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textMuted)),
                  ],
                ),
                Gap.h12,
                MealCards(data: data),
                Gap.h16,
                _WaterAndWeight(data: data),
                Gap.h24,
                _Shortcuts(),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DateBar extends ConsumerWidget {
  const _DateBar({required this.day});
  final String day;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isToday = day == Days.today();
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () => ref.read(selectedDayProvider.notifier).state =
              Days.addDays(day, -1),
        ),
        Column(
          children: [
            Text(isToday ? 'Today' : Days.pretty(day),
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 16)),
            if (!isToday)
              TextButton(
                onPressed: () =>
                    ref.read(selectedDayProvider.notifier).state = Days.today(),
                child: const Text('Jump to today'),
              ),
          ],
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: isToday
              ? null
              : () => ref.read(selectedDayProvider.notifier).state =
                  Days.addDays(day, 1),
        ),
      ],
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.data});
  final DashboardData data;

  @override
  Widget build(BuildContext context) {
    final m = data.consumedMacros;
    final g = data.goal;
    return SectionCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          MacroDonut(
            consumed: m,
            caloriesLeft: data.caloriesRemaining,
          ),
          Gap.w12,
          Expanded(
            child: Column(
              children: [
                MacroBar(
                    label: 'Protein',
                    value: m.protein,
                    target: g.proteinTargetG,
                    color: AppColors.protein),
                Gap.h12,
                MacroBar(
                    label: 'Carbs',
                    value: m.carbs,
                    target: g.carbTargetG,
                    color: AppColors.carbs),
                Gap.h12,
                MacroBar(
                    label: 'Fat',
                    value: m.fat,
                    target: g.fatTargetG,
                    color: AppColors.fat),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WaterAndWeight extends ConsumerWidget {
  const _WaterAndWeight({required this.data});
  final DashboardData data;

  Future<void> _addWater(WidgetRef ref, int delta) async {
    final services = ref.read(servicesProvider);
    final next = (data.waterMl + delta).clamp(0, 100000);
    await services.body.upsertWater(WaterLog(
      id: const Uuid().v4(),
      userId: data.user.id,
      day: data.day,
      ml: next,
    ));
    ref.bumpLogMutation();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trend = data.latestWeight?.trendValueKg;
    return Row(
      children: [
        Expanded(
          child: SectionCard(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Water',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                Gap.h8,
                Text('${(data.waterMl / 1000).toStringAsFixed(2)} L',
                    style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.water)),
                Text('of ${(data.waterGoalMl / 1000).toStringAsFixed(1)} L',
                    style: const TextStyle(fontSize: 12)),
                Gap.h8,
                Row(
                  children: [
                    _waterBtn(ref, '+250', 250),
                    Gap.w8,
                    _waterBtn(ref, '−250', -250),
                  ],
                ),
              ],
            ),
          ),
        ),
        Gap.w12,
        Expanded(
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const WeightScreen())),
            child: SectionCard(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Weight trend',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  Gap.h8,
                  Text(
                    trend == null
                        ? '—'
                        : Fmt.weight(trend, data.user.units),
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.w800),
                  ),
                  Text(
                    data.weekTrendDeltaKg == 0
                        ? 'log to build trend'
                        : '${Fmt.signedKg(data.weekTrendDeltaKg, data.user.units)} this week',
                    style: TextStyle(
                      fontSize: 12,
                      color: data.weekTrendDeltaKg <= 0
                          ? AppColors.good
                          : AppColors.warn,
                    ),
                  ),
                  Gap.h8,
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Tap to log →',
                        style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _waterBtn(WidgetRef ref, String label, int delta) => Expanded(
        child: OutlinedButton(
          style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 8)),
          onPressed: () => _addWater(ref, delta),
          child: Text(label),
        ),
      );
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.day});
  final String day;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _action(context, Icons.add, 'Add food', () {
          Navigator.of(context).push(MaterialPageRoute(
              builder: (_) =>
                  AddFoodScreen(day: day, slot: MealSlot.snack)));
        }),
        _action(context, Icons.qr_code_scanner, 'Scan', () {
          Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => AddFoodScreen(
                  day: day, slot: MealSlot.snack, startScanning: true)));
        }),
        _action(context, Icons.replay, 'Usuals', () {
          showModalBottomSheet(
            context: context,
            showDragHandle: true,
            builder: (_) => UsualsSheet(day: day),
          );
        }),
      ],
    );
  }

  Widget _action(
          BuildContext context, IconData icon, String label, VoidCallback tap) =>
      Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: FilledButton.tonal(
            onPressed: tap,
            style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14)),
            child: Column(
              children: [
                Icon(icon),
                const SizedBox(height: 4),
                Text(label, style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),
        ),
      );
}

class _Shortcuts extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'More',
      child: Column(
        children: [
          _row(context, Icons.straighten, 'Measurements',
              const MeasurementsScreen()),
          _row(context, Icons.photo_camera_outlined, 'Progress photos',
              const PhotosScreen()),
          _row(context, Icons.event_note_outlined, 'Weekly review',
              const WeeklyReviewScreen()),
        ],
      ),
    );
  }

  Widget _row(
          BuildContext context, IconData icon, String label, Widget screen) =>
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(icon),
        title: Text(label),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => screen)),
      );
}
