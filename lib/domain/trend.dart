import 'package:macrovault/models/weight_entry.dart';

/// The trend engine — the heart of "Trend, not truth".
///
/// Weight is smoothed with an exponentially-weighted moving average (EWMA).
/// The smoothed value, not the raw reading, is what the UI shows as the
/// headline, so a single fat-finger or water-weight spike barely moves it.
class Trend {
  Trend._();

  /// Smoothing factor. Lower α = smoother/slower; 0.1 ≈ a ~10-reading memory,
  /// a good match for daily weigh-ins (roughly a 1-to-2 week effective window).
  static const double defaultAlpha = 0.1;

  /// Compute the next trend value given the previous trend and a new reading.
  /// If there's no previous trend (first ever reading), the trend seeds to the
  /// reading itself.
  static double next({
    required double? previousTrend,
    required double reading,
    double alpha = defaultAlpha,
  }) {
    if (previousTrend == null) return reading;
    return previousTrend + alpha * (reading - previousTrend);
  }

  /// Recompute the full trend series for a chronological list of raw readings.
  /// Returns trend values aligned to [readings]. Used when an entry is inserted
  /// out of order, edited, or deleted and the series must be rebuilt.
  static List<double> recompute(
    List<double> readings, {
    double alpha = defaultAlpha,
  }) {
    final out = <double>[];
    double? prev;
    for (final r in readings) {
      prev = next(previousTrend: prev, reading: r, alpha: alpha);
      out.add(prev);
    }
    return out;
  }

  /// Rebuild trend values for a chronological list of entries, returning new
  /// entries with corrected [WeightEntry.trendValueKg].
  static List<WeightEntry> rebuildEntries(
    List<WeightEntry> chronological, {
    double alpha = defaultAlpha,
  }) {
    final trends = recompute(
      chronological.map((e) => e.weightKg).toList(),
      alpha: alpha,
    );
    return [
      for (var i = 0; i < chronological.length; i++)
        chronological[i].copyWith(trendValueKg: trends[i]),
    ];
  }

  /// The change in trend across a window (last - first). Negative = downward.
  static double delta(List<WeightEntry> chronological) {
    if (chronological.length < 2) return 0;
    return chronological.last.trendValueKg - chronological.first.trendValueKg;
  }
}
