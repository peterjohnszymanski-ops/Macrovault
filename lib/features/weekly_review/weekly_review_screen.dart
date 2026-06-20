import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:macrovault/core/date_utils.dart';
import 'package:macrovault/core/formatters.dart';
import 'package:macrovault/core/theme.dart';
import 'package:macrovault/features/common/widgets.dart';
import 'package:macrovault/models/user.dart';
import 'package:macrovault/models/weekly_review.dart';
import 'package:macrovault/state/providers.dart';

/// The Weekly Review ritual: auto-filled metrics + three prompts, saved to the
/// Vault as a Capsule in one tap. ~2 minutes; metrics need zero manual entry.
class WeeklyReviewScreen extends ConsumerStatefulWidget {
  const WeeklyReviewScreen({super.key});

  @override
  ConsumerState<WeeklyReviewScreen> createState() =>
      _WeeklyReviewScreenState();
}

class _WeeklyReviewScreenState extends ConsumerState<WeeklyReviewScreen> {
  late String _weekStart = Days.weekStartKey(DateTime.now());
  final _worked = TextEditingController();
  final _hurt = TextEditingController();
  final _repeat = TextEditingController();
  final _reflection = TextEditingController();
  final _tags = <String>{};
  bool _saveToVault = true;
  bool _loading = true;
  bool _saving = false;
  WeeklyMetrics _metrics = WeeklyMetrics.empty;
  bool _isBestWeek = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _worked.dispose();
    _hurt.dispose();
    _repeat.dispose();
    _reflection.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final services = ref.read(servicesProvider);
    final user = await ref.read(currentUserProvider.future);
    if (user == null) return;
    final result = await services.weeklyBuilder
        .buildMetrics(userId: user.id, weekStartKey: _weekStart);
    setState(() {
      _metrics = result.metrics;
      _isBestWeek = result.isBestWeek;
      if (_isBestWeek) _tags.add('best week');
      _loading = false;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final services = ref.read(servicesProvider);
    final user = await ref.read(currentUserProvider.future);
    if (user == null) return;
    await services.weeklyBuilder.saveReview(
      userId: user.id,
      weekStartKey: _weekStart,
      metrics: _metrics,
      answers: WeeklyAnswers(
        whatWorked: _worked.text.trim(),
        whatHurt: _hurt.text.trim(),
        whatToRepeat: _repeat.text.trim(),
        reflection: _reflection.text.trim(),
      ),
      isBestWeek: _isBestWeek,
      saveCapsule: _saveToVault,
      capsuleTags: _tags.toList(),
    );
    ref.bumpLogMutation();
    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(_saveToVault
                ? 'Saved to your Vault as a Capsule.'
                : 'Weekly review saved.')),
      );
    }
  }

  void _shiftWeek(int weeks) {
    setState(() => _weekStart = Days.addDays(_weekStart, weeks * 7));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).asData?.value;
    final weekEnd = Days.addDays(_weekStart, 6);
    return Scaffold(
      appBar: AppBar(title: const Text('Weekly review')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                        icon: const Icon(Icons.chevron_left),
                        onPressed: () => _shiftWeek(-1)),
                    Text(
                      '${Days.prettyMonthDay(_weekStart)} – ${Days.prettyMonthDay(weekEnd)}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      onPressed: _weekStart ==
                              Days.weekStartKey(DateTime.now())
                          ? null
                          : () => _shiftWeek(1),
                    ),
                  ],
                ),
                if (_isBestWeek)
                  Card(
                    color: AppColors.good.withValues(alpha: 0.15),
                    child: const Padding(
                      padding: EdgeInsets.all(12),
                      child: Row(children: [
                        Icon(Icons.emoji_events, color: AppColors.good),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Best week — strong adherence and your trend moved the right way. Worth saving.',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ]),
                    ),
                  ),
                Gap.h8,
                _MetricsCard(metrics: _metrics, user: user),
                Gap.h16,
                _prompt('What worked this week?', _worked),
                _prompt('What hurt progress?', _hurt),
                _prompt('What will you repeat next week?', _repeat),
                _prompt('Anything else (reflection)?', _reflection, lines: 3),
                Gap.h8,
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _saveToVault,
                  onChanged: (v) => setState(() => _saveToVault = v),
                  title: const Text('Save this week to my Vault'),
                  subtitle:
                      const Text('Creates a Progress Capsule with these metrics'),
                ),
                if (_saveToVault) ...[
                  const Text('Tags',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  Gap.h8,
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      for (final tag in const [
                        'cutting',
                        'bulking',
                        'maintenance',
                        'plateau',
                        'high protein',
                        'best week',
                        'reset week',
                      ])
                        FilterChip(
                          label: Text(tag),
                          selected: _tags.contains(tag),
                          onSelected: (s) => setState(() =>
                              s ? _tags.add(tag) : _tags.remove(tag)),
                        ),
                    ],
                  ),
                ],
                Gap.h24,
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: Text(_saveToVault
                      ? 'Save review & capsule'
                      : 'Save review'),
                ),
              ],
            ),
    );
  }

  Widget _prompt(String label, TextEditingController c, {int lines = 2}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: c,
          minLines: lines,
          maxLines: lines + 2,
          decoration: InputDecoration(
              labelText: label, alignLabelWithHint: true),
        ),
      );
}

class _MetricsCard extends StatelessWidget {
  const _MetricsCard({required this.metrics, required this.user});
  final WeeklyMetrics metrics;
  final AppUser? user;

  @override
  Widget build(BuildContext context) {
    final units = user?.units;
    return SectionCard(
      title: 'This week, automatically',
      child: Column(
        children: [
          _row('Days logged', '${metrics.daysLogged} / 7'),
          _row('Avg calories', '${metrics.avgKcal.round()} kcal'),
          _row('Avg protein', '${metrics.avgProtein.round()} g'),
          _row('Calorie adherence', Fmt.percent(metrics.calorieAdherence)),
          _row('Protein adherence', Fmt.percent(metrics.proteinAdherence)),
          _row(
              'Weekday vs weekend',
              '${metrics.weekdayAvgKcal.round()} / ${metrics.weekendAvgKcal.round()} kcal'),
          _row(
              'Weight trend',
              units == null
                  ? '${metrics.trendDeltaKg.toStringAsFixed(2)} kg'
                  : Fmt.signedKg(metrics.trendDeltaKg, units)),
          _row('Water consistency', Fmt.percent(metrics.waterConsistency)),
        ],
      ),
    );
  }

  Widget _row(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(k, style: const TextStyle(fontSize: 13)),
            Text(v, style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
      );
}
