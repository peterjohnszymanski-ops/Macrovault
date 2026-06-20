import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:macrovault/core/date_utils.dart';
import 'package:macrovault/core/formatters.dart';
import 'package:macrovault/core/theme.dart';
import 'package:macrovault/domain/targets.dart';
import 'package:macrovault/models/enums.dart';
import 'package:macrovault/models/goal.dart';
import 'package:macrovault/models/user.dart';
import 'package:macrovault/models/weight_entry.dart';
import 'package:macrovault/state/providers.dart';
import 'package:uuid/uuid.dart';

/// First-run setup: identity, stats, goal → computed targets. Designed to be
/// completed quickly; nothing here blocks the first food log.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _name = TextEditingController(text: 'You');
  Units _units = Units.metric;
  Sex _sex = Sex.male;
  int _birthYear = 1995;
  final _height = TextEditingController(text: '178');
  final _weight = TextEditingController(text: '80');
  GoalType _goal = GoalType.recomp;
  ActivityLevel _activity = ActivityLevel.moderate;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _height.dispose();
    _weight.dispose();
    super.dispose();
  }

  double get _heightCm =>
      Fmt.displayToCm(double.tryParse(_height.text) ?? 178, _units);
  double get _weightKg =>
      Fmt.displayToKg(double.tryParse(_weight.text) ?? 80, _units);

  TargetResult get _preview => Targets.compute(
        sex: _sex,
        weightKg: _weightKg,
        heightCm: _heightCm,
        ageYears: DateTime.now().year - _birthYear,
        goal: _goal,
        activity: _activity,
        weeklyRateKg: Targets.defaultWeeklyRate(_goal),
      );

  Future<void> _finish() async {
    setState(() => _saving = true);
    final services = ref.read(servicesProvider);
    const uuid = Uuid();
    final userId = uuid.v4();
    final now = DateTime.now();

    final user = AppUser(
      id: userId,
      name: _name.text.trim().isEmpty ? 'You' : _name.text.trim(),
      units: _units,
      sex: _sex,
      birthYear: _birthYear,
      heightCm: _heightCm,
      vaultLockEnabled: false,
      aiConsent: false,
      createdAt: now,
    );
    await services.profile.upsertUser(user);

    final t = _preview;
    final goal = Goal(
      id: uuid.v4(),
      userId: userId,
      type: _goal,
      activityLevel: _activity,
      weeklyRateKg: Targets.defaultWeeklyRate(_goal),
      calorieTarget: t.calorieTarget,
      proteinTargetG: t.proteinG,
      carbTargetG: t.carbG,
      fatTargetG: t.fatG,
      startDate: now,
      active: true,
    );
    await services.profile.setActiveGoal(goal);

    // Seed the first weigh-in so the trend has a starting point.
    await services.body.upsertWeight(WeightEntry(
      id: uuid.v4(),
      userId: userId,
      day: Days.today(),
      weightKg: _weightKg,
      trendValueKg: _weightKg,
      createdAt: now,
    ));

    ref.invalidate(currentUserProvider);
    ref.invalidate(activeGoalProvider);
  }

  @override
  Widget build(BuildContext context) {
    final t = _preview;
    return Scaffold(
      appBar: AppBar(title: const Text('Welcome to MacroVault')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          const Text(
            'A private proof-of-progress tracker. Fast logging that feeds a '
            'searchable Vault so you can see what actually works.',
            style: TextStyle(fontSize: 14, height: 1.4),
          ),
          Gap.h24,
          _label('Your name'),
          TextField(controller: _name),
          Gap.h16,
          _label('Units'),
          SegmentedButton<Units>(
            segments: const [
              ButtonSegment(value: Units.metric, label: Text('Metric (kg/cm)')),
              ButtonSegment(
                  value: Units.imperial, label: Text('Imperial (lb/in)')),
            ],
            selected: {_units},
            onSelectionChanged: (s) => setState(() => _units = s.first),
          ),
          Gap.h16,
          _label('Sex (for calorie math)'),
          SegmentedButton<Sex>(
            segments: const [
              ButtonSegment(value: Sex.male, label: Text('Male')),
              ButtonSegment(value: Sex.female, label: Text('Female')),
            ],
            selected: {_sex},
            onSelectionChanged: (s) => setState(() => _sex = s.first),
          ),
          Gap.h16,
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('Birth year'),
                    DropdownButtonFormField<int>(
                      value: _birthYear,
                      items: [
                        for (var y = DateTime.now().year - 13;
                            y >= 1940;
                            y--)
                          DropdownMenuItem(value: y, child: Text('$y')),
                      ],
                      onChanged: (v) => setState(() => _birthYear = v ?? 1995),
                    ),
                  ],
                ),
              ),
              Gap.w12,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('Height (${Fmt.lengthUnit(_units)})'),
                    TextField(
                      controller: _height,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setState(() {}),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Gap.h16,
          _label('Current weight (${Fmt.weightUnit(_units)})'),
          TextField(
            controller: _weight,
            keyboardType: TextInputType.number,
            onChanged: (_) => setState(() {}),
          ),
          Gap.h24,
          _label('Goal'),
          Wrap(
            spacing: 8,
            children: [
              for (final g in GoalType.values)
                ChoiceChip(
                  label: Text(g.label),
                  selected: _goal == g,
                  onSelected: (_) => setState(() => _goal = g),
                ),
            ],
          ),
          Gap.h16,
          _label('Activity level'),
          DropdownButtonFormField<ActivityLevel>(
            value: _activity,
            items: [
              for (final a in ActivityLevel.values)
                DropdownMenuItem(value: a, child: Text(a.label)),
            ],
            onChanged: (v) => setState(() => _activity = v ?? _activity),
          ),
          Gap.h24,
          _TargetPreview(target: t),
          Gap.h24,
          FilledButton(
            onPressed: _saving ? null : _finish,
            child: _saving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Create my dashboard'),
          ),
        ],
      ),
    );
  }

  Widget _label(String s) => Padding(
        padding: const EdgeInsets.only(bottom: 6, top: 4),
        child: Text(s,
            style:
                const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
      );
}

class _TargetPreview extends StatelessWidget {
  const _TargetPreview({required this.target});
  final TargetResult target;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.brand.withValues(alpha: 0.10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Your starting targets',
                style: TextStyle(fontWeight: FontWeight.w700)),
            Gap.h12,
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _stat('${target.calorieTarget}', 'kcal/day'),
                _stat('${target.proteinG.round()}g', 'protein',
                    color: AppColors.protein),
                _stat('${target.carbG.round()}g', 'carbs',
                    color: AppColors.carbs),
                _stat('${target.fatG.round()}g', 'fat', color: AppColors.fat),
              ],
            ),
            if (target.warning != null) ...[
              Gap.h12,
              Text(target.warning!,
                  style: const TextStyle(
                      color: AppColors.warn, fontSize: 12)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _stat(String value, String label, {Color? color}) => Column(
        children: [
          Text(value,
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w800, color: color)),
          Text(label, style: const TextStyle(fontSize: 11)),
        ],
      );
}
