import 'package:flutter_test/flutter_test.dart';
import 'package:macrovault/domain/targets.dart';
import 'package:macrovault/models/enums.dart';

void main() {
  group('Targets', () {
    test('BMR matches Mifflin–St Jeor for a known male case', () {
      // 80kg, 180cm, 30y male → 10*80 + 6.25*180 - 5*30 + 5 = 1780
      final bmr = Targets.bmr(
          sex: Sex.male, weightKg: 80, heightCm: 180, ageYears: 30);
      expect(bmr, closeTo(1780, 0.5));
    });

    test('loss goal produces a deficit vs TDEE', () {
      final r = Targets.compute(
        sex: Sex.male,
        weightKg: 90,
        heightCm: 180,
        ageYears: 30,
        goal: GoalType.lose,
        activity: ActivityLevel.moderate,
        weeklyRateKg: -0.5,
      );
      expect(r.calorieTarget, lessThan(r.tdee));
      expect(r.warning, isNull);
    });

    test('aggressive deficit is floored with a warning', () {
      final r = Targets.compute(
        sex: Sex.female,
        weightKg: 55,
        heightCm: 160,
        ageYears: 30,
        goal: GoalType.lose,
        activity: ActivityLevel.sedentary,
        weeklyRateKg: -1.0,
      );
      expect(r.calorieTarget, greaterThanOrEqualTo(1200));
      expect(r.warning, isNotNull);
    });

    test('recomp sets the highest protein per kg', () {
      final recomp = Targets.compute(
        sex: Sex.male,
        weightKg: 80,
        heightCm: 180,
        ageYears: 30,
        goal: GoalType.recomp,
        activity: ActivityLevel.moderate,
        weeklyRateKg: 0,
      );
      // 2.2 g/kg * 80 = 176g
      expect(recomp.proteinG, closeTo(176, 0.5));
    });

    test('macros roughly reconcile to the calorie target', () {
      final r = Targets.compute(
        sex: Sex.male,
        weightKg: 80,
        heightCm: 180,
        ageYears: 30,
        goal: GoalType.maintain,
        activity: ActivityLevel.moderate,
        weeklyRateKg: 0,
      );
      final fromMacros = r.proteinG * 4 + r.carbG * 4 + r.fatG * 9;
      expect(fromMacros, closeTo(r.calorieTarget.toDouble(), 30));
    });
  });
}
