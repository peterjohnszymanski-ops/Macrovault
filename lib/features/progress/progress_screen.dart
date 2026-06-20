import 'package:collection/collection.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:macrovault/core/date_utils.dart';
import 'package:macrovault/core/formatters.dart';
import 'package:macrovault/core/theme.dart';
import 'package:macrovault/domain/body_fat.dart';
import 'package:macrovault/features/common/widgets.dart';
import 'package:macrovault/models/metric.dart';
import 'package:macrovault/models/user.dart';
import 'package:macrovault/state/providers.dart';
import 'package:uuid/uuid.dart';

/// A single plottable series (weight or a metric), already reduced to (day,value).
class _Series {
  _Series(this.def, this.points);
  final MetricDef def;
  final List<({String day, double value})> points;

  double get first => points.first.value;
  double get last => points.last.value;
  double get delta => last - first;
  bool get improved =>
      def.higherIsBetter ? delta > 0 : delta < 0;
}

class _ProgressData {
  _ProgressData(this.series, this.allDays);
  final List<_Series> series;
  final List<String> allDays;
}

final _progressProvider = FutureProvider<_ProgressData>((ref) async {
  ref.logMutationToken;
  final services = ref.watch(servicesProvider);
  final user = await ref.watch(currentUserProvider.future);
  if (user == null) return _ProgressData([], []);

  final series = <_Series>[];

  // Weight trend, sourced from the weight table.
  final weights = await services.body.weights(user.id);
  if (weights.isNotEmpty) {
    series.add(_Series(
      MetricDef(
        key: kWeightMetricKey,
        name: 'Weight (trend)',
        unit: Fmt.weightUnit(user.units),
        higherIsBetter: false,
        builtin: true,
      ),
      weights
          .map((w) => (day: w.day, value: Fmt.kgToDisplay(w.trendValueKg, user.units)))
          .toList(),
    ));
  }

  // Each defined metric with at least one point.
  final defs = await services.metrics.defs();
  for (final def in defs) {
    final entries = await services.metrics.series(def.key);
    if (entries.isEmpty) continue;
    series.add(_Series(
      def,
      entries.map((e) => (day: e.day, value: e.value)).toList(),
    ));
  }

  final allDays = (series.expand((s) => s.points.map((p) => p.day)).toSet()
        .toList())
    ..sort();
  return _ProgressData(series, allDays);
});

class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).asData?.value;
    final data = ref.watch(_progressProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Progress'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_chart),
            tooltip: 'Add a metric',
            onPressed: user == null ? null : () => _addMetric(context, ref, user),
          ),
        ],
      ),
      body: data.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (pd) {
          if (pd.series.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const EmptyHint(
                        'Track strength, body fat and weight here — they overlay on one timeline so you can see what moves together.',
                        icon: Icons.insights),
                    Gap.h16,
                    FilledButton(
                      onPressed: user == null
                          ? null
                          : () => _logMetric(context, ref, user, kBuiltinMetrics.first),
                      child: const Text('Log your first lift'),
                    ),
                  ],
                ),
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SectionCard(
                title: 'Everything on one timeline',
                child: Column(
                  children: [
                    SizedBox(
                      height: 220,
                      child: _OverlayChart(data: pd),
                    ),
                    Gap.h12,
                    Wrap(
                      spacing: 14,
                      runSpacing: 6,
                      children: [
                        for (final s in pd.series) _legend(s),
                      ],
                    ),
                  ],
                ),
              ),
              Gap.h16,
              const Text('Metrics',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              Gap.h8,
              for (final s in pd.series)
                _MetricCard(
                  series: s,
                  user: user,
                  onLog: user == null || s.def.key == kWeightMetricKey
                      ? null
                      : () => _logValue(context, ref, user, s.def),
                ),
              Gap.h8,
              if (user != null)
                OutlinedButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('Add a custom metric'),
                  onPressed: () => _addMetric(context, ref, user),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _legend(_Series s) {
    final color = AppColors.forMetric(s.def.key);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(
            color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 5),
        Text(
          '${s.def.name} ${s.improved ? '↑' : '↓'}',
          style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
        ),
      ],
    );
  }

  /// Routes body fat through the estimator option; everything else is a plain
  /// numeric entry.
  Future<void> _logValue(
      BuildContext context, WidgetRef ref, AppUser user, MetricDef def) async {
    if (def.key == 'bodyfat') {
      await _logBodyFat(context, ref, user, def);
    } else {
      await _logMetric(context, ref, user, def);
    }
  }

  Future<void> _logBodyFat(
      BuildContext context, WidgetRef ref, AppUser user, MetricDef def) async {
    final mode = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.straighten),
              title: const Text('Estimate from measurements'),
              subtitle: const Text('U.S. Navy method (waist, neck, height)'),
              onTap: () => Navigator.pop(context, 'estimate'),
            ),
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Enter manually'),
              onTap: () => Navigator.pop(context, 'manual'),
            ),
          ],
        ),
      ),
    );
    if (mode == 'manual') {
      if (context.mounted) await _logMetric(context, ref, user, def);
      return;
    }
    if (mode != 'estimate') return;

    final body = ref.read(servicesProvider).body;
    Future<double?> latest(String site) async =>
        (await body.measurements(user.id, site: site)).lastOrNull?.valueCm;
    final waist = await latest('waist');
    final neck = await latest('neck');
    final hips = await latest('hips');

    final bf = BodyFat.navy(
      sex: user.sex,
      heightCm: user.heightCm,
      waistCm: waist,
      neckCm: neck,
      hipCm: hips,
    );
    if (!context.mounted) return;
    if (bf == null) {
      final need = BodyFat.requiredSites(user.sex).map(Fmt.site).join(', ');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Log these in Measurements first: $need')));
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Estimated body fat'),
        content: Text(
          '${bf.toStringAsFixed(1)}%\n\nFrom your latest waist'
          '${user.sex.name == 'female' ? '/hip' : ''}/neck and height '
          '(U.S. Navy method). It\'s an estimate — log it as today\'s data point?',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Log ${bf.toStringAsFixed(1)}%')),
        ],
      ),
    );
    if (confirm != true) return;
    await ref.read(servicesProvider).metrics.upsertEntry(MetricEntry(
          id: const Uuid().v4(),
          userId: user.id,
          metricKey: 'bodyfat',
          day: Days.today(),
          value: bf,
          createdAt: DateTime.now(),
        ));
    ref.bumpLogMutation();
  }

  Future<void> _logMetric(
      BuildContext context, WidgetRef ref, AppUser user, MetricDef def) async {
    final controller = TextEditingController();
    final v = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Log ${def.name}'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(suffixText: def.unit),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
              onPressed: () =>
                  Navigator.pop(ctx, double.tryParse(controller.text)),
              child: const Text('Save')),
        ],
      ),
    );
    if (v == null) return;
    await ref.read(servicesProvider).metrics.upsertEntry(MetricEntry(
          id: const Uuid().v4(),
          userId: user.id,
          metricKey: def.key,
          day: Days.today(),
          value: v,
          createdAt: DateTime.now(),
        ));
    ref.bumpLogMutation();
  }

  Future<void> _addMetric(
      BuildContext context, WidgetRef ref, AppUser user) async {
    // Offer the built-ins first, then a custom option.
    final choice = await showModalBottomSheet<MetricDef>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final d in kBuiltinMetrics)
              ListTile(
                leading: Icon(Icons.show_chart,
                    color: AppColors.forMetric(d.key)),
                title: Text(d.name),
                subtitle: Text('Unit: ${d.unit}'),
                onTap: () => Navigator.pop(context, d),
              ),
            ListTile(
              leading: const Icon(Icons.add),
              title: const Text('Custom metric…'),
              onTap: () => Navigator.pop(context,
                  const MetricDef(key: '', name: '', unit: '', higherIsBetter: true)),
            ),
          ],
        ),
      ),
    );
    if (choice == null) return;
    if (choice.key.isNotEmpty) {
      await _logValue(context, ref, user, choice);
      return;
    }
    // Custom metric creation.
    if (!context.mounted) return;
    final nameC = TextEditingController();
    final unitC = TextEditingController(text: 'kg');
    var higher = true;
    final created = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('New metric'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  controller: nameC,
                  decoration: const InputDecoration(labelText: 'Name')),
              TextField(
                  controller: unitC,
                  decoration: const InputDecoration(labelText: 'Unit')),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: higher,
                onChanged: (v) => setLocal(() => higher = v),
                title: const Text('Higher is better'),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Create')),
          ],
        ),
      ),
    );
    if (created != true || nameC.text.trim().isEmpty) return;
    final key = 'c_${nameC.text.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')}';
    await ref.read(servicesProvider).metrics.addCustomDef(MetricDef(
          key: key,
          name: nameC.text.trim(),
          unit: unitC.text.trim(),
          higherIsBetter: higher,
        ));
    if (context.mounted) {
      await _logMetric(context, ref, user,
          MetricDef(key: key, name: nameC.text.trim(), unit: unitC.text.trim(), higherIsBetter: higher));
    }
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard(
      {required this.series, required this.user, required this.onLog});
  final _Series series;
  final AppUser? user;
  final VoidCallback? onLog;

  @override
  Widget build(BuildContext context) {
    final color = AppColors.forMetric(series.def.key);
    final improved = series.improved;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Container(
          width: 8,
          height: 36,
          decoration:
              BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
        ),
        title: Text(series.def.name),
        subtitle: Text(
          '${series.last.toStringAsFixed(1)} ${series.def.unit}  ·  '
          '${series.delta >= 0 ? '+' : ''}${series.delta.toStringAsFixed(1)} since start',
          style: TextStyle(
              color: improved ? AppColors.good : AppColors.textMuted),
        ),
        trailing: onLog == null
            ? null
            : IconButton(
                icon: const Icon(Icons.add_circle_outline), onPressed: onLog),
      ),
    );
  }
}

class _OverlayChart extends StatelessWidget {
  const _OverlayChart({required this.data});
  final _ProgressData data;

  @override
  Widget build(BuildContext context) {
    final dayIndex = {
      for (var i = 0; i < data.allDays.length; i++) data.allDays[i]: i,
    };
    final bars = <LineChartBarData>[];
    for (final s in data.series) {
      final values = s.points.map((p) => p.value).toList();
      final min = values.reduce((a, b) => a < b ? a : b);
      final max = values.reduce((a, b) => a > b ? a : b);
      final range = (max - min).abs() < 1e-9 ? 1.0 : (max - min);
      final spots = [
        for (final p in s.points)
          FlSpot((dayIndex[p.day] ?? 0).toDouble(), (p.value - min) / range),
      ];
      bars.add(LineChartBarData(
        spots: spots,
        isCurved: true,
        barWidth: 2.5,
        color: AppColors.forMetric(s.def.key),
        dotData: FlDotData(show: spots.length < 8),
        dashArray: s.def.key == kWeightMetricKey ? [5, 4] : null,
      ));
    }
    return LineChart(
      LineChartData(
        minY: -0.05,
        maxY: 1.05,
        gridData: FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        lineTouchData: LineTouchData(enabled: false),
        lineBarsData: bars,
        clipData: FlClipData.all(),
      ),
    );
  }
}
