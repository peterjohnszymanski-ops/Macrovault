import 'package:macrovault/models/enums.dart';

/// Unit conversions + display formatting. Internally weight is kg and lengths
/// are cm; this converts for imperial display only.
class Fmt {
  Fmt._();

  static const double _kgPerLb = 0.45359237;
  static const double _cmPerInch = 2.54;

  // --- Weight ---
  static double kgToDisplay(double kg, Units units) =>
      units == Units.imperial ? kg / _kgPerLb : kg;

  static double displayToKg(double value, Units units) =>
      units == Units.imperial ? value * _kgPerLb : value;

  static String weightUnit(Units units) =>
      units == Units.imperial ? 'lb' : 'kg';

  static String weight(double kg, Units units, {int decimals = 1}) =>
      '${kgToDisplay(kg, units).toStringAsFixed(decimals)} ${weightUnit(units)}';

  // --- Length ---
  static double cmToDisplay(double cm, Units units) =>
      units == Units.imperial ? cm / _cmPerInch : cm;

  static double displayToCm(double value, Units units) =>
      units == Units.imperial ? value * _cmPerInch : value;

  static String lengthUnit(Units units) =>
      units == Units.imperial ? 'in' : 'cm';

  static String length(double cm, Units units, {int decimals = 1}) =>
      '${cmToDisplay(cm, units).toStringAsFixed(decimals)} ${lengthUnit(units)}';

  // --- Macros / energy ---
  static String kcal(double v) => '${v.round()}';
  static String grams(double v) => '${v.round()}g';

  static String signedKg(double kg, Units units) {
    final v = kgToDisplay(kg, units);
    final sign = v > 0 ? '+' : '';
    return '$sign${v.toStringAsFixed(2)} ${weightUnit(units)}';
  }

  static String percent(double frac) => '${(frac * 100).round()}%';

  /// Human label for a measurement site key.
  static String site(String key) {
    switch (key) {
      case 'waist':
        return 'Waist';
      case 'hips':
        return 'Hips';
      case 'chest':
        return 'Chest';
      case 'arm_l':
        return 'Left arm';
      case 'arm_r':
        return 'Right arm';
      case 'thigh_l':
        return 'Left thigh';
      case 'thigh_r':
        return 'Right thigh';
      case 'neck':
        return 'Neck';
      default:
        return key.isEmpty
            ? 'Custom'
            : key[0].toUpperCase() + key.substring(1).replaceAll('_', ' ');
    }
  }
}
