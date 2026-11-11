/// Scales and ticks: mapping data values to pixels, and choosing round tick
/// values.
library;

import 'dart:math' as math;

/// Whether [v] is a value a chart can draw: not null, not NaN, not
/// infinite. Everything else is a gap.
bool isDrawable(num? v) => v != null && v.isFinite;

/// The smallest and largest drawable values in [values], or `null` when
/// there are none.
({num min, num max})? dataExtent(Iterable<num?> values) {
  num? min, max;
  for (final v in values) {
    if (!isDrawable(v)) continue;
    if (min == null || v! < min) min = v;
    if (max == null || v! > max) max = v;
  }
  return min == null ? null : (min: min, max: max!);
}

/// A round step for ticks over [span] with at most [maxTicks] intervals:
/// 1, 2, 2.5 or 5 times a power of ten.
num niceStep(num span, int maxTicks) {
  if (!span.isFinite || span <= 0) return 1;
  final raw = span / math.max(1, maxTicks);
  final magnitude = math.pow(10, (math.log(raw) / math.ln10).floor());
  for (final m in const [1, 2, 2.5, 5, 10]) {
    if (m * magnitude >= raw) return m * magnitude;
  }
  return 10 * magnitude;
}

/// Round tick values covering [min]–[max], at most [maxTicks] intervals.
///
/// The first tick is at or below [min] and the last at or above [max], so
/// the axis always contains the data. A flat range (`min == max`) is widened
/// around its value: a single value still gets an axis.
List<num> niceTicks(num min, num max, {int maxTicks = 5}) {
  if (!min.isFinite || !max.isFinite) return const [0, 1];
  if (min > max) (min, max) = (max, min);
  if (min == max) {
    final pad = min == 0 ? 1 : min.abs() / 2;
    // Not below zero for a non-negative value: a flat 5 reads 2.5–7.5, a
    // flat 0 reads 0–1.
    final nonNegative = min >= 0;
    min -= pad;
    max += pad;
    if (nonNegative && min < 0) min = 0;
  }
  final step = niceStep(max - min, maxTicks);
  final start = (min / step).floor() * step;
  final ticks = <num>[];
  // An index, not repeated addition: 0.1 + 0.2 drifts, 3 * 0.1 is exact
  // enough once rounded to the step's precision.
  for (var i = 0; ; i++) {
    final t = _roundToStep(start + i * step, step);
    ticks.add(t);
    if (t >= max || i > 1000) break;
  }
  return ticks;
}

/// [v] rounded to [step]'s decimal precision (no `0.30000000000000004`).
num _roundToStep(num v, num step) {
  final decimals = step >= 1
      ? 0
      : (-(math.log(step) / math.ln10).floor() + 1).clamp(0, 12);
  final factor = math.pow(10, decimals);
  final r = (v * factor).round() / factor;
  return r == r.roundToDouble() && r.abs() < 1e15 ? r.round() : r;
}

/// A linear map from a domain ([domainMin]–[domainMax]) to a pixel range
/// ([rangeStart]–[rangeEnd]); the range may run backwards (y grows down).
class LinearScale {
  /// A scale from the domain to the range.
  const LinearScale(
    this.domainMin,
    this.domainMax,
    this.rangeStart,
    this.rangeEnd,
  );

  /// The domain's low end.
  final num domainMin;

  /// The domain's high end.
  final num domainMax;

  /// The pixel [domainMin] maps to.
  final double rangeStart;

  /// The pixel [domainMax] maps to.
  final double rangeEnd;

  /// The pixel for [v]. A flat domain maps everything to the range's middle.
  double call(num v) {
    final span = domainMax - domainMin;
    if (span == 0) return (rangeStart + rangeEnd) / 2;
    return rangeStart + (v - domainMin) / span * (rangeEnd - rangeStart);
  }
}
