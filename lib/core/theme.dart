import 'package:flutter/material.dart';

/// MacroVault visual system — a dark, vibrant "MacroFactor / Cal AI" vibe:
/// near-black surfaces, a confident lime accent, and distinct macro colors so
/// the donut + bars read instantly. A light theme is provided for completeness
/// but the app defaults to dark (see app.dart).
class AppColors {
  AppColors._();

  // Surfaces (dark)
  static const Color bg = Color(0xFF0E1217);
  static const Color surface = Color(0xFF161C24);
  static const Color surfaceHigh = Color(0xFF1C2530);

  // Brand accent
  static const Color brand = Color(0xFFBEF264); // lime
  static const Color brandInk = Color(0xFF0E1217); // text on lime

  // Macros (consistent across donut, bars, legends)
  static const Color protein = Color(0xFF2DD4BF); // teal
  static const Color carbs = Color(0xFFF6B73C); // amber
  static const Color fat = Color(0xFFA78BFA); // violet
  static const Color water = Color(0xFF38BDF8); // sky

  // Metric / progress lines
  static const Color strength = Color(0xFFBEF264); // lime
  static const Color bodyFat = Color(0xFFF6735A); // coral
  static const Color weight = Color(0xFF2DD4BF); // teal

  // Semantic
  static const Color good = Color(0xFFBEF264);
  static const Color warn = Color(0xFFF6B73C);
  static const Color danger = Color(0xFFF6735A);

  // Text
  static const Color text = Color(0xFFE7ECEF);
  static const Color textMuted = Color(0xFF8A949C);

  /// A stable color per metric key so each line keeps its identity everywhere.
  static Color forMetric(String key) {
    switch (key) {
      case 'bodyfat':
        return bodyFat;
      case 'weight':
        return weight;
      case 'bench':
        return brand;
      case 'squat':
        return carbs;
      case 'deadlift':
        return fat;
      default:
        // Deterministic hue from the key so custom metrics get a stable color.
        final h = (key.codeUnits.fold<int>(0, (a, b) => a + b) * 47) % 360;
        return HSLColor.fromAHSL(1, h.toDouble(), 0.55, 0.62).toColor();
    }
  }
}

class AppTheme {
  AppTheme._();

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final scheme = (isDark
            ? const ColorScheme.dark(
                primary: AppColors.brand,
                onPrimary: AppColors.brandInk,
                surface: AppColors.bg,
                onSurface: AppColors.text,
                secondary: AppColors.protein,
              )
            : ColorScheme.fromSeed(seedColor: AppColors.brand))
        .copyWith(
      surfaceContainerHighest: isDark ? AppColors.surfaceHigh : null,
    );

    final radius = BorderRadius.circular(20);
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: isDark ? AppColors.bg : scheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: isDark ? AppColors.bg : scheme.surface,
        foregroundColor: isDark ? AppColors.text : scheme.onSurface,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: isDark ? AppColors.text : scheme.onSurface,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: isDark
            ? AppColors.surface
            : scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        shape: RoundedRectangleBorder(borderRadius: radius),
        margin: EdgeInsets.zero,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: isDark ? AppColors.bg : scheme.surface,
        indicatorColor: AppColors.brand.withValues(alpha: 0.18),
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        ),
        height: 64,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.brand,
          foregroundColor: AppColors.brandInk,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? AppColors.surfaceHigh : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

/// Common spacing tokens.
class Gap {
  static const w8 = SizedBox(width: 8);
  static const w12 = SizedBox(width: 12);
  static const h4 = SizedBox(height: 4);
  static const h8 = SizedBox(height: 8);
  static const h12 = SizedBox(height: 12);
  static const h16 = SizedBox(height: 16);
  static const h24 = SizedBox(height: 24);
  static const h32 = SizedBox(height: 32);
}
