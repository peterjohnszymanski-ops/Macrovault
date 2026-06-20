import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:macrovault/core/theme.dart';
import 'package:macrovault/models/macros.dart';

/// An animated macro donut. Slices are sized by each macro's *calorie*
/// contribution (4/4/9), with the calories-left figure in the hole.
class MacroDonut extends StatelessWidget {
  const MacroDonut({
    super.key,
    required this.consumed,
    required this.caloriesLeft,
    this.size = 132,
  });

  final Macros consumed;
  final int caloriesLeft;
  final double size;

  @override
  Widget build(BuildContext context) {
    final pCal = consumed.protein * 4;
    final cCal = consumed.carbs * 4;
    final fCal = consumed.fat * 9;
    final total = pCal + cCal + fCal;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 650),
      curve: Curves.easeOutCubic,
      builder: (context, t, _) {
        final sections = total <= 0
            ? [
                PieChartSectionData(
                  value: 1,
                  color: AppColors.surfaceHigh,
                  radius: size * 0.16,
                  showTitle: false,
                ),
              ]
            : [
                _slice(pCal * t, AppColors.protein),
                _slice(cCal * t, AppColors.carbs),
                _slice(fCal * t, AppColors.fat),
              ];
        return SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(
                PieChartData(
                  sections: sections,
                  sectionsSpace: total <= 0 ? 0 : 3,
                  centerSpaceRadius: size * 0.32,
                  startDegreeOffset: -90,
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${(caloriesLeft).clamp(-99999, 99999)}',
                      style: TextStyle(
                          fontSize: size * 0.22,
                          fontWeight: FontWeight.w800,
                          color: AppColors.text)),
                  Text('cal left',
                      style: TextStyle(
                          fontSize: size * 0.09, color: AppColors.textMuted)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  PieChartSectionData _slice(double value, Color color) =>
      PieChartSectionData(
        value: value <= 0 ? 0.0001 : value,
        color: color,
        radius: size * 0.16,
        showTitle: false,
      );
}
