/// The hints of chart marks: what a column, bar, point or slice says on
/// hover (the native `<title>` tooltip, or the web hint layer).
///
/// A hint is lines: the first is its heading (what the mark is: a category,
/// a date, a bin), the others its figures.
library;

import 'format.dart';

/// The line separator inside a `data-hint` attribute.
const hintLineBreak = '\n';

/// [lines] as one `data-hint` value.
String hintText(List<String> lines) => lines.join(hintLineBreak);

/// The lines of a `data-hint` value (empty lines dropped).
List<String> hintLines(String hint) => [
  for (final l in hint.split(hintLineBreak))
    if (l.isNotEmpty) l,
];

/// The share of [value] in [total] as [formatRate] writes it, or `null` when
/// a share means nothing: no positive total, or a negative value.
String? shareOf(num value, num total) {
  if (!value.isFinite || !total.isFinite) return null;
  if (total <= 0 || value < 0) return null;
  return formatRate(value / total);
}

/// The whole that [values] add up to, plus [others] (values left out of the
/// chart, such as groups past a limit), for [shareOf].
///
/// `null` when they don't make a whole: a negative value (a sum crossing
/// zero has no meaningful parts), or a non-finite one. Nulls are skipped.
num? totalOf(Iterable<num?> values, {num? others}) {
  num sum = others ?? 0;
  if (sum < 0 || !sum.isFinite) return null;
  for (final v in values) {
    if (v == null) continue;
    if (v < 0 || !v.isFinite) return null;
    sum += v;
  }
  return sum;
}

/// The hint of a column, bar or slice: its [label], then [measure] (when
/// named) with its [value], and its share of [total] when given.
///
/// Give a [total] only when the values make a whole (counts, sums): an
/// average's or a maximum's "share" reads as a fact and is not one.
List<String> markHint(
  String label,
  num value, {
  String? measure,
  num? total,
  NumberFormatter format = formatNumber,
}) {
  final share = total == null ? null : shareOf(value, total);
  return [
    label.isEmpty ? '(no label)' : label,
    '${measure == null || measure.isEmpty ? '' : '$measure: '}${format(value)}'
        '${share == null ? '' : ' · $share of the total'}',
  ];
}

/// The hint of a line chart at x [label]: the [hovered] series first, then,
/// with [others], every other series' value there ([values]: name → value,
/// `null` where a series has none, written `—`).
///
/// A point's hint is its own series (`others: false`); the band over an x
/// holds them all, so one hover reads the whole column.
List<String> pointHint(
  String label,
  String hovered,
  Map<String, num?> values, {
  bool others = true,
  NumberFormatter format = formatNumber,
}) {
  String line(String name, num? v) =>
      '${name.isEmpty ? '' : '$name: '}${v == null ? '—' : format(v)}';
  return [
    label.isEmpty ? '(no label)' : label,
    line(hovered, values[hovered]),
    if (others)
      for (final MapEntry(key: name, value: v) in values.entries)
        if (name != hovered) line(name, v),
  ];
}
