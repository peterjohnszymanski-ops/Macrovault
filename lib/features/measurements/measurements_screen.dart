import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:macrovault/core/date_utils.dart';
import 'package:macrovault/core/formatters.dart';
import 'package:macrovault/core/theme.dart';
import 'package:macrovault/features/common/widgets.dart';
import 'package:macrovault/models/body_logs.dart';
import 'package:macrovault/models/user.dart';
import 'package:macrovault/state/providers.dart';
import 'package:uuid/uuid.dart';

final _measProvider =
    FutureProvider<List<MeasurementEntry>>((ref) async {
  ref.logMutationToken;
  final user = await ref.watch(currentUserProvider.future);
  if (user == null) return [];
  return ref.watch(servicesProvider).body.measurements(user.id);
});

class MeasurementsScreen extends ConsumerWidget {
  const MeasurementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).asData?.value;
    final meas = ref.watch(_measProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Measurements')),
      body: meas.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (all) {
          if (user == null) return const SizedBox();
          final bySite = groupBy(all, (m) => m.site);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final site in kDefaultMeasurementSites)
                _SiteTile(
                  site: site,
                  history: (bySite[site] ?? [])
                    ..sort((a, b) => a.day.compareTo(b.day)),
                  user: user,
                ),
            ],
          );
        },
      ),
    );
  }
}

class _SiteTile extends ConsumerWidget {
  const _SiteTile(
      {required this.site, required this.history, required this.user});
  final String site;
  final List<MeasurementEntry> history;
  final AppUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final latest = history.lastOrNull;
    final delta = history.length < 2
        ? null
        : history.last.valueCm - history.first.valueCm;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        title: Text(Fmt.site(site)),
        subtitle: latest == null
            ? const Text('Not logged')
            : Text('${Fmt.length(latest.valueCm, user.units)} · '
                '${Days.prettyMonthDay(latest.day)}'
                '${delta != null ? '  (${delta <= 0 ? '' : '+'}${Fmt.cmToDisplay(delta, user.units).toStringAsFixed(1)} ${Fmt.lengthUnit(user.units)})' : ''}'),
        trailing: const Icon(Icons.add_circle_outline),
        onTap: () => _log(context, ref),
      ),
    );
  }

  Future<void> _log(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final value = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Log ${Fmt.site(site)}'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(suffixText: Fmt.lengthUnit(user.units)),
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
    await ref.read(servicesProvider).body.insertMeasurement(MeasurementEntry(
          id: const Uuid().v4(),
          userId: user.id,
          day: Days.today(),
          site: site,
          valueCm: Fmt.displayToCm(value, user.units),
          createdAt: DateTime.now(),
        ));
    ref.bumpLogMutation();
  }
}
