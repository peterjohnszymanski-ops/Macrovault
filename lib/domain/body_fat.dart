import 'dart:math' as math;

import 'package:macrovault/models/enums.dart';

/// Estimated body-fat % using the U.S. Navy circumference method.
///
/// All inputs are centimetres. Men need waist + neck + height; women also need
/// hip. Returns null when inputs are missing or out of a sane range (e.g. waist
/// ≤ neck makes the log undefined).
class BodyFat {
  BodyFat._();

  static double? navy({
    required Sex sex,
    required double heightCm,
    required double? waistCm,
    required double? neckCm,
    double? hipCm,
  }) {
    if (waistCm == null || neckCm == null || heightCm <= 0) return null;

    if (sex == Sex.male) {
      final diff = waistCm - neckCm;
      if (diff <= 0) return null;
      final bf = 495 /
              (1.0324 -
                  0.19077 * _log10(diff) +
                  0.15456 * _log10(heightCm)) -
          450;
      return _clean(bf);
    } else {
      if (hipCm == null) return null;
      final sum = waistCm + hipCm - neckCm;
      if (sum <= 0) return null;
      final bf = 495 /
              (1.29579 -
                  0.35004 * _log10(sum) +
                  0.22100 * _log10(heightCm)) -
          450;
      return _clean(bf);
    }
  }

  /// Which measurement sites are required for [sex] — surfaced in the UI when
  /// data is missing.
  static List<String> requiredSites(Sex sex) =>
      sex == Sex.male ? const ['waist', 'neck'] : const ['waist', 'neck', 'hips'];

  static double _log10(double x) => math.log(x) / math.ln10;

  static double? _clean(double bf) {
    if (bf.isNaN || bf.isInfinite || bf <= 0 || bf > 75) return null;
    return double.parse(bf.toStringAsFixed(1));
  }
}
