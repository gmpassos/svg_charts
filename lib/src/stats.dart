/// Statistics charts are built on.
library;

import 'dart:math' as math;

import 'scale.dart';

/// The drawable values of [values] ([isDrawable]: no nulls, NaN or
/// infinities), in order.
List<num> finiteValues(Iterable<num?> values) => [
  for (final v in values)
    if (isDrawable(v)) v!,
];

/// One histogram bin: values in [start]–[end] (the last bin includes its
/// end), and how many there are.
class HistogramBin {
  /// A bin of [count] values in [start]–[end].
  const HistogramBin(this.start, this.end, this.count);

  /// The low bound (inclusive).
  final num start;

  /// The high bound (exclusive, inclusive for the last bin).
  final num end;

  /// The values in it.
  final int count;
}

/// [values] counted into [bins] equal-width bins over their range.
///
/// No drawable values give no bins; a single distinct value gives one bin
/// around it, so it is still drawn.
List<HistogramBin> histogramBins(Iterable<num?> values, int bins) {
  final data = finiteValues(values);
  if (data.isEmpty) return const [];
  final n = math.max(1, bins);
  final lo = data.reduce(math.min), hi = data.reduce(math.max);
  if (lo == hi) return [HistogramBin(lo, hi, data.length)];
  final width = (hi - lo) / n;
  final counts = List.filled(n, 0);
  for (final v in data) {
    // The maximum falls in the last bin, not one past it.
    counts[math.min(n - 1, ((v - lo) / width).floor())]++;
  }
  return [
    for (var i = 0; i < n; i++)
      HistogramBin(
        lo + i * width,
        i == n - 1 ? hi : lo + (i + 1) * width,
        counts[i],
      ),
  ];
}
