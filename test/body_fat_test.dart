import 'package:flutter_test/flutter_test.dart';
import 'package:macrovault/domain/body_fat.dart';
import 'package:macrovault/models/enums.dart';

void main() {
  group('Navy body-fat estimate', () {
    test('male case matches the known formula (~19.8%)', () {
      final bf = BodyFat.navy(
        sex: Sex.male,
        heightCm: 180,
        waistCm: 90,
        neckCm: 38,
      );
      expect(bf, isNotNull);
      expect(bf!, closeTo(19.8, 0.6));
    });

    test('female case requires hip and matches (~27.4%)', () {
      final bf = BodyFat.navy(
        sex: Sex.female,
        heightCm: 165,
        waistCm: 75,
        neckCm: 32,
        hipCm: 95,
      );
      expect(bf, isNotNull);
      expect(bf!, closeTo(27.4, 0.8));
    });

    test('returns null when a required input is missing', () {
      expect(
        BodyFat.navy(sex: Sex.male, heightCm: 180, waistCm: 90, neckCm: null),
        isNull,
      );
      expect(
        BodyFat.navy(sex: Sex.female, heightCm: 165, waistCm: 75, neckCm: 32),
        isNull, // no hip
      );
    });

    test('returns null when waist ≤ neck (undefined log)', () {
      expect(
        BodyFat.navy(sex: Sex.male, heightCm: 180, waistCm: 38, neckCm: 40),
        isNull,
      );
    });
  });
}
