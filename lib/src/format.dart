/// Number formats for charts: values in hints and labels, compact ticks,
/// rates.
library;

/// Formats a value for display: what charts use for hints, value labels and
/// ticks. Any function of this shape can replace the defaults.
typedef NumberFormatter = String Function(num value);

/// [value] with its whole part in groups of three: `1,234,567`, `-1,000`.
String groupThousands(int value) =>
    '${value < 0 ? '-' : ''}${_groupDigits(value.abs().toString())}';

/// A string of [digits] in groups of three. Works on the text, so a whole
/// part past the 64-bit range (a double of 1e20) needs no `int.parse`,
/// which would overflow on the VM.
String _groupDigits(String digits) {
  final out = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) out.write(',');
    out.write(digits[i]);
  }
  return out.toString();
}

/// A number in full, as hints and value labels show it: integers grouped
/// (`1,234,567`), decimals to 1–3 digits by size (`1,234.5`, `12.35`,
/// `0.123`).
///
/// Integral values are recognised by value, not by `is int`: on the web
/// every number is a JS double and `1.0 is int` is true, while on the VM it
/// is false. Testing the value gives one output on both platforms.
///
/// NaN and infinity are written as `NaN`, `∞` and `-∞`.
String formatNumber(num value) {
  if (value.isNaN) return 'NaN';
  if (value.isInfinite) return value > 0 ? '∞' : '-∞';
  final abs = value.abs();
  final sign = value < 0 ? '-' : '';
  if (value == value.roundToDouble() && abs < 1e15) {
    return groupThousands(value.round());
  }
  final digits = abs >= 100 ? 1 : (abs >= 1 ? 2 : 3);
  final fixed = abs.toStringAsFixed(digits);
  final dot = fixed.indexOf('.');
  // From 1e21 up toStringAsFixed is exponential ("1e+21"): kept as is.
  if (dot < 0) return '$sign$fixed';
  // Rounding may have made it integral (0.9996 → "1.000"): drop the zeros.
  var decimals = fixed.substring(dot).replaceFirst(RegExp(r'0+$'), '');
  if (decimals == '.') decimals = '';
  return '$sign${_groupDigits(fixed.substring(0, dot))}$decimals';
}

/// A number short enough for an axis tick: `950`, `1.2k`, `45k`, `3.4M`,
/// `1.2B`, `0.25`, `1.5`.
///
/// One decimal at most past a thousand, the suffix carrying the scale; below
/// a thousand as [formatNumber] without grouping.
String formatCompact(num value) {
  if (!value.isFinite) return formatNumber(value);
  final abs = value.abs();
  final sign = value < 0 ? '-' : '';
  const units = [(1e3, 'k'), (1e6, 'M'), (1e9, 'B'), (1e12, 'T')];
  // The largest unit the value reaches.
  var u = units.lastIndexWhere((e) => abs >= e.$1);
  if (u >= 0) {
    String written(int u) {
      final scaled = abs / units[u].$1;
      return _trimmed(scaled, scaled >= 100 ? 0 : 1);
    }

    // 999,600 rounds to "1000k": the next unit's "1M" instead (judged on
    // the text, which is what would be shown).
    if (u < units.length - 1 && double.parse(written(u)) >= 1000) u++;
    return '$sign${written(u)}${units[u].$2}';
  }
  if (abs == abs.roundToDouble()) return '$sign${abs.round()}';
  return '$sign${_trimmed(abs, abs >= 10 ? 1 : 2)}';
}

/// [v] to [digits] decimals, trailing zeros dropped.
String _trimmed(num v, int digits) {
  var s = v.toStringAsFixed(digits);
  if (s.contains('.')) {
    s = s.replaceFirst(RegExp(r'0+$'), '');
    if (s.endsWith('.')) s = s.substring(0, s.length - 1);
  }
  return s;
}

/// A rate (0–1) in percent: `0%`, `<1%`, `42%`, `>99%`, `100%`.
///
/// Only exactly 0 and exactly 1 are written `0%` and `100%`: a rate of
/// 0.004 is not nothing, and 0.996 is not everything, so they read `<1%`
/// and `>99%` instead of rounding into a claim the data doesn't make.
/// Values outside 0–1 are written as they are (`150%`, `-20%`).
String formatRate(num rate) {
  if (!rate.isFinite) return formatNumber(rate);
  final p = rate * 100;
  if (p == 0 || p == 100) return '${p.round()}%';
  if (p > 0 && p < 1) return '<1%';
  if (p > 99 && p < 100) return '>99%';
  return '${p.round()}%';
}
