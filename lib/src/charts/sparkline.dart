/// A word-sized line: a trend inline with text or in a table cell.
library;

import 'dart:math' as math;

import '../chart.dart';
import '../format.dart';
import '../scale.dart';
import '../svg_writer.dart';
import '../theme.dart';

/// A sparkline: [values] as a small line with no axes, its last value
/// marked with a dot.
///
/// The chart's name ([title], else a summary) says what it shows; each
/// value has a band with its hint ([labels] naming the positions), so a
/// pointer reads any point. `null` values are gaps.
///
/// ```dart
/// final svg = Sparkline([4, 6, 5, 9, 7, 11], title: 'Signups').render();
/// ```
class Sparkline implements SvgChart {
  /// A sparkline of [values].
  const Sparkline(
    this.values, {
    this.labels = const [],
    this.width = 120,
    this.height = 28,
    this.title,
    this.theme = SvgChartTheme.auto,
    this.area = false,
    this.color = 0,
    this.valueFormat = formatNumber,
    this.hints = true,
    this.markLast = true,
  });

  /// The values, in order.
  final List<num?> values;

  /// The positions' names, in the hints.
  final List<String> labels;

  /// The width in px.
  final double width;

  /// The height in px.
  final double height;

  /// What it shows: its accessible name.
  final String? title;

  /// Colours.
  final SvgChartTheme theme;

  /// Whether to fill under the line.
  final bool area;

  /// The series colour index.
  final int color;

  /// Values in the hints and summary.
  final NumberFormatter valueFormat;

  /// Whether each value gets a hover band with its hint.
  final bool hints;

  /// Whether the last value gets a dot.
  final bool markLast;

  @override
  String render() {
    final n = values.length;
    final extent = dataExtent(values);
    final w = SvgWriter();
    final summary = extent == null
        ? 'no data'
        : 'last ${valueFormat(values.lastWhere(isDrawable)!)}, '
              'min ${valueFormat(extent.min)}, max ${valueFormat(extent.max)}';
    openChart(
      w,
      theme,
      width: width,
      height: height,
      title: title ?? summary,
      description: title == null ? null : summary,
      kind: 'sparkline',
    );
    if (extent == null) {
      w.close('svg');
      return w.toString();
    }
    // A dot's radius of room on every side, so it isn't clipped.
    const pad = 3.0;
    final lo = area ? math.min(0, extent.min) : extent.min;
    final y = LinearScale(lo, extent.max, height - pad, pad);
    double x(int i) =>
        n <= 1 ? width / 2 : pad + i * (width - 2 * pad) / (n - 1);
    final cls = seriesClass(theme, color);
    final hex = theme.palette.seriesColor(color);
    if (hints) {
      final band = n <= 1 ? width : (width - 2 * pad) / (n - 1);
      for (var i = 0; i < n; i++) {
        final v = values[i];
        openMark(
          w,
          theme,
          [
            i < labels.length ? labels[i] : '${i + 1}',
            isDrawable(v) ? valueFormat(v!) : '—',
          ],
          cls: 'band',
          index: i,
          named: false,
        );
        w
          ..empty('rect', {
            'x': math.max(0, x(i) - band / 2),
            'y': 0,
            'width': band,
            'height': height,
            'fill': 'transparent',
          })
          ..close('g');
      }
    }
    final runs = <List<int>>[];
    for (var i = 0; i < n; i++) {
      if (!isDrawable(values[i])) continue;
      if (runs.isEmpty || runs.last.last != i - 1) runs.add([]);
      runs.last.add(i);
    }
    for (final run in runs) {
      final d = [
        for (final (k, i) in run.indexed)
          '${k == 0 ? 'M' : 'L'}${svgNum(x(i))} ${svgNum(y(values[i]!))}',
      ].join(' ');
      if (run.length == 1) {
        w.empty('circle', {
          'class': '${theme.cls('dot')} $cls',
          'cx': x(run.first),
          'cy': y(values[run.first]!),
          'r': 1.5,
          'fill': hex,
        });
        continue;
      }
      if (area) {
        w.empty('path', {
          'class': '${theme.cls('area')} $cls',
          'd':
              '$d L${svgNum(x(run.last))} ${svgNum(y(lo))} '
              'L${svgNum(x(run.first))} ${svgNum(y(lo))}Z',
          'fill': hex,
          'fill-opacity': 0.16,
        });
      }
      w.empty('path', {
        'class': '${theme.cls('line')} $cls',
        'd': d,
        'fill': 'none',
        'stroke': hex,
        'stroke-width': 1.5,
        'style': 'stroke-width:1.5px',
      });
    }
    if (markLast && runs.isNotEmpty) {
      final last = runs.last.last;
      w.empty('circle', {
        'class': '${theme.cls('dot')} $cls',
        'cx': x(last),
        'cy': y(values[last]!),
        'r': 2.5,
        'fill': hex,
        'stroke-width': 0,
      });
    }
    w.close('svg');
    return w.toString();
  }

  @override
  String toString() => render();
}
