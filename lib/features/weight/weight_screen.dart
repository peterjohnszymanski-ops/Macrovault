import 'package:collection/collection.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:macrovault/core/date_utils.dart';
import 'package:macrovault/core/formatters.dart';
import 'package:macrovault/core/theme.dart';
import 'package:macrovault/features/common/widgets.dart';
import 'package:macrovault/models/enums.dart';
import 'package:macrovault/models/user.dart';
import 'package:macrovault/models/weight_entry.dart';
import 'package:macrovault/state/providers.dart';
import 'package:uuid/uuid.dart';

final _weightsProvider = FutureProvider<List<WeightEntry>>((ref) async {
  ref.logMutationToken;
  final user = await ref.watch(currentUserProvider.future);
  if (user == null) return [];
  return ref.watch(servicesProvider).body.weights(user.id);
});

/// Weight tracking. Headline is the *trend* (smoothed); raw points are faint.
/// This is the app's core anti-panic surface — "Trend, not truth".
class WeightScreen extends ConsumerWidget {
  const WeightScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).asData?.value;
    final weights = ref.watch(_weightsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Weight')),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Log weight'),
        onPressed: user == null
            ? null
            : () => _logDialog(context, ref, user,
                last: weights.asData?.value.lastOrNull),
      ),
      body: weights.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (list) {
          if (user == null) return const SizedBox();
          if (list.isEmpty) {
            return const EmptyHint('Log your weight to start the trend.',
                icon: Icons.monitor_weight_outlined);
          }
          final trend = list.last.trendValueKg;
          final delta = list.length < 2
              ? 0.0
              : list.last.trendValueKg - list.first.trendValueKg;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Trend weight',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    Gap.h4,
                    Text(Fmt.weight(trend, user.units),
                        style: const TextStyle(
                            fontSize: 34, fontWeight: FontWeight.w800)),
                    Text(
                      list.length < 2
                          ? 'Add a few more readings to see movement'
                          : '${Fmt.signedKg(delta, user.units)} since first reading',
                      style: TextStyle(
                          color:
                              delta <= 0 ? AppColors.good : AppColors.warn),
                    ),
                    Gap.h8,
                    const Text(
                      'The headline is your smoothed trend, not a single weigh-in. '
                      'Day-to-day swings are mostly water — ignore them.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
              Gap.h16,
              SectionCard(
                title: 'Trend over time',
                child: SizedBox(
                    height: 220,
                    child: _WeightChart(entries: list, units: user.units)),
              ),
              Gap.h16,
              SectionCard(
                title: 'History',
                child: Column(
                  children: [
                    for (final e in list.reversed)
                      Dismissible(
                        key: ValueKey(e.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 16),
                          color: AppColors.danger.withValues(alpha: 0.15),
                          child: const Icon(Icons.delete_outline),
                        ),
                        onDismissed: (_) async {
                          await ref
                              .read(servicesProvider)
                              .body
                              .deleteWeight(e.id, user.id);
                          ref.bumpLogMutation();
                        },
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(Fmt.weight(e.weightKg, user.units)),
                          subtitle: Text(Days.pretty(e.day)),
                          trailing: Text(
                            'trend ${Fmt.weight(e.trendValueKg, user.units)}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _logDialog(BuildContext context, WidgetRef ref, AppUser user,
      {WeightEntry? last}) async {
    final controller = TextEditingController(
      text: last != null
          ? Fmt.kgToDisplay(last.weightKg, user.units).toStringAsFixed(1)
          : '',
    );
    final value = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log weight'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration:
              InputDecoration(suffixText: Fmt.weightUnit(user.units)),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () =>
                Navigator.pop(ctx, double.tryParse(controller.text)),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (value == null || value <= 0) return;
    final kg = Fmt.displayToKg(value, user.units);
    final today = Days.today();
    await ref.read(servicesProvider).body.upsertWeight(WeightEntry(
          id: const Uuid().v4(),
          userId: user.id,
          day: today,
          weightKg: kg,
          trendValueKg: kg, // recomputed by the DAO
          createdAt: DateTime.now(),
        ));
    ref.bumpLogMutation();
  }
}

class _WeightChart extends StatelessWidget {
  const _WeightChart({required this.entries, required this.units});
  final List<WeightEntry> entries;
  final Units units;

  @override
  Widget build(BuildContext context) {
    final raw = <FlSpot>[];
    final trend = <FlSpot>[];
    for (var i = 0; i < entries.length; i++) {
      raw.add(FlSpot(i.toDouble(), Fmt.kgToDisplay(entries[i].weightKg, units)));
      trend.add(
          FlSpot(i.toDouble(), Fmt.kgToDisplay(entries[i].trendValueKg, units)));
    }
    return LineChart(
      LineChartData(
        gridData: FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: true, reservedSize: 36)),
          bottomTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        lineBarsData: [
          // Raw readings: faint dots, no connecting line.
          LineChartBarData(
            spots: raw,
            isCurved: false,
            barWidth: 0,
            color: Colors.transparent,
            dotData: FlDotData(
              show: true,
              getDotPainter: (s, _, __, ___) => FlDotCirclePainter(
                radius: 2.5,
                color: AppColors.brand.withValues(alpha: 0.25),
                strokeWidth: 0,
              ),
            ),
          ),
          // Trend line: the hero.
          LineChartBarData(
            spots: trend,
            isCurved: true,
            barWidth: 3,
            color: AppColors.brand,
            dotData: FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: AppColors.brand.withValues(alpha: 0.08),
            ),
          ),
        ],
      ),
    );
  }
}
