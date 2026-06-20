import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:macrovault/core/theme.dart';
import 'package:macrovault/domain/targets.dart';
import 'package:macrovault/models/enums.dart';
import 'package:macrovault/models/goal.dart';
import 'package:macrovault/state/providers.dart';

/// Edit the active goal. Changing goal/activity/rate recomputes targets; the
/// user can still override the final calorie/protein numbers manually.
class EditGoalScreen extends ConsumerStatefulWidget {
  const EditGoalScreen({super.key});

  @override
  ConsumerState<EditGoalScreen> createState() => _EditGoalScreenState();
}

class _EditGoalScreenState extends ConsumerState<EditGoalScreen> {
  Goal? _goal;
  late GoalType _type;
  late ActivityLevel _activity;
  late double _rate;
  final _calories = TextEditingController();
  final _protein = TextEditingController();
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _calories.dispose();
    _protein.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final goal = await ref.read(activeGoalProvider.future);
    if (goal == null) return;
    setState(() {
      _goal = goal;
      _type = goal.type;
      _activity = goal.activityLevel;
      _rate = goal.weeklyRateKg;
      _calories.text = '${goal.calorieTarget}';
      _protein.text = '${goal.proteinTargetG.round()}';
      _loaded = true;
    });
  }

  Future<void> _recompute() async {
    final user = await ref.read(currentUserProvider.future);
    if (user == null) return;
    final latest = await ref.read(servicesProvider).body.latestWeight(user.id);
    final t = Targets.compute(
      sex: user.sex,
      weightKg: latest?.weightKg ?? 80,
      heightCm: user.heightCm,
      ageYears: user.ageYears,
      goal: _type,
      activity: _activity,
      weeklyRateKg: _rate,
    );
    setState(() {
      _calories.text = '${t.calorieTarget}';
      _protein.text = '${t.proteinG.round()}';
    });
  }

  Future<void> _save() async {
    final goal = _goal;
    if (goal == null) return;
    final kcal = int.tryParse(_calories.text) ?? goal.calorieTarget;
    final protein = double.tryParse(_protein.text) ?? goal.proteinTargetG;
    // Keep carbs/fat proportional to the existing split, re-deriving carbs.
    final fatKcal = kcal * 0.25;
    final fatG = fatKcal / 9;
    final carbG =
        ((kcal - protein * 4 - fatKcal) / 4).clamp(0, double.infinity).toDouble();
    final updated = goal.copyWith(
      type: _type,
      activityLevel: _activity,
      weeklyRateKg: _rate,
      calorieTarget: kcal,
      proteinTargetG: protein,
      carbTargetG: carbG,
      fatTargetG: fatG,
    );
    await ref.read(servicesProvider).profile.updateGoal(updated);
    ref.invalidate(activeGoalProvider);
    ref.bumpLogMutation();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Scaffold(
          body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Goal & targets')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Goal', style: TextStyle(fontWeight: FontWeight.w700)),
          Gap.h8,
          Wrap(
            spacing: 8,
            children: [
              for (final g in GoalType.values)
                ChoiceChip(
                  label: Text(g.label),
                  selected: _type == g,
                  onSelected: (_) {
                    setState(() {
                      _type = g;
                      _rate = Targets.defaultWeeklyRate(g);
                    });
                    _recompute();
                  },
                ),
            ],
          ),
          Gap.h16,
          const Text('Activity level',
              style: TextStyle(fontWeight: FontWeight.w700)),
          DropdownButtonFormField<ActivityLevel>(
            value: _activity,
            items: [
              for (final a in ActivityLevel.values)
                DropdownMenuItem(value: a, child: Text(a.label)),
            ],
            onChanged: (v) {
              if (v == null) return;
              setState(() => _activity = v);
              _recompute();
            },
          ),
          Gap.h16,
          Text('Weekly rate: ${_rate.toStringAsFixed(2)} kg/week',
              style: const TextStyle(fontWeight: FontWeight.w700)),
          Slider(
            value: _rate.clamp(-1.0, 0.5),
            min: -1.0,
            max: 0.5,
            divisions: 30,
            label: '${_rate.toStringAsFixed(2)} kg',
            onChanged: (v) => setState(() => _rate = v),
            onChangeEnd: (_) => _recompute(),
          ),
          Gap.h16,
          TextField(
            controller: _calories,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Calorie target (kcal)'),
          ),
          Gap.h12,
          TextField(
            controller: _protein,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Protein target (g)'),
          ),
          Gap.h24,
          FilledButton(onPressed: _save, child: const Text('Save goal')),
        ],
      ),
    );
  }
}
