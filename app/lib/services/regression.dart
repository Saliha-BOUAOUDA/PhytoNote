import 'dart:math' as math;

class RegressionResult {
  final double slope;
  final double intercept;
  final double r2;
  final int n;

  const RegressionResult({
    required this.slope,
    required this.intercept,
    required this.r2,
    required this.n,
  });

  bool get isLinearityValid => r2 >= 0.97;

  /// y = slope·x + intercept
  String formatEquation({String unitX = '', int decimals = 4}) {
    final sign = intercept >= 0 ? '+' : '-';
    return 'y = ${slope.toStringAsFixed(decimals)}·x $sign ${intercept.abs().toStringAsFixed(decimals)}';
  }
}

/// Régression linéaire par moindres carrés ordinaires.
/// Renvoie null si moins de 2 points distincts ou points colinéaires sur l'axe x.
RegressionResult? linearRegression(List<({double x, double y})> points) {
  if (points.length < 2) return null;
  final n = points.length;
  double sumX = 0, sumY = 0, sumXY = 0, sumX2 = 0, sumY2 = 0;
  for (final p in points) {
    sumX += p.x;
    sumY += p.y;
    sumXY += p.x * p.y;
    sumX2 += p.x * p.x;
    sumY2 += p.y * p.y;
  }
  final denom = n * sumX2 - sumX * sumX;
  if (denom == 0) return null;
  final slope = (n * sumXY - sumX * sumY) / denom;
  final intercept = (sumY - slope * sumX) / n;
  final rNum = n * sumXY - sumX * sumY;
  final rDen = math.sqrt(denom * (n * sumY2 - sumY * sumY));
  final r = rDen == 0 ? 0.0 : rNum / rDen;
  return RegressionResult(slope: slope, intercept: intercept, r2: r * r, n: n);
}
