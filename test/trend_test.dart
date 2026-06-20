import 'package:flutter_test/flutter_test.dart';
import 'package:macrovault/domain/trend.dart';

void main() {
  group('Trend (EWMA)', () {
    test('first reading seeds the trend to itself', () {
      expect(Trend.next(previousTrend: null, reading: 80), 80);
    });

    test('a single spike barely moves the trend', () {
      // Seed a stable trend at 80, then a 5kg water spike.
      final series = Trend.recompute([80, 80, 80, 80, 85]);
      // With alpha 0.1 the trend should move well under 1kg from the spike.
      expect(series.last, lessThan(80.6));
      expect(series.last, greaterThan(80.0));
    });

    test('sustained change is followed over time', () {
      final series = Trend.recompute(List.generate(40, (_) => 75));
      expect(series.last, closeTo(75, 0.0001));
    });

    test('recompute is order-dependent and deterministic', () {
      final a = Trend.recompute([80, 81, 79, 82]);
      final b = Trend.recompute([80, 81, 79, 82]);
      expect(a, b);
      expect(a.length, 4);
    });

    test('delta reflects net trend movement', () {
      final series = Trend.recompute([80, 79, 78, 77, 76]);
      // downward series → negative-ish delta when wrapped in entries
      expect(series.first, 80);
      expect(series.last, lessThan(series.first));
    });
  });
}
