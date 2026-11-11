/// Horizontal bars: ranked, grouped or stacked, labelled directly.
library;

import 'dart:math' as math;

import '../chart.dart';
import '../format.dart';
import '../hints.dart';
import '../scale.dart';
import '../series.dart';
import '../svg_writer.dart';
import '../theme.dart';
import 'column_chart.dart' show BarMode;

/// A horizontal bar chart: a row per category with its label, its bar(s)
/// and its value written at the bar's end. No value axis: the bars are
/// labelled directly, which reads better for ranked categories with long
/// names.
///
/// Bars start at zero; negative values extend left of it. With [sorted],
/// rows are ranked by value, largest first. Labels in [mutedLabels]
/// (indexes into [labels]) are drawn muted, for a "no value" or "others"
/// category.
///
/// ```dart
/// final svg = BarChart.of(
///   [420, 310, 96],
///   labels: ['delivered', 'paid', 'canceled'],
///   sorted: true,
/// ).render();
/// ```
class BarChart implements SvgChart {
  /// A chart of [series], one value per category in [labels].
  const BarChart(
    this.series, {
    this.labels = const [],
    this.width = 480,
    this.height,
    this.title,
    this.description,
    this.theme = SvgChartTheme.auto,
    this.responsive = false,
    this.mode = BarMode.grouped,
    this.legend = LegendPosition.auto,
    this.valueFormat = formatNumber,
    this.valueLabels = true,
    this.shares = false,
    this.hint,
    this.sorted = false,
    this.mutedLabels = const {},
    this.rowHeight,
    this.maxLabelWidth,
  });

  /// A chart of one series of [values]; [name] names it in hints.
  BarChart.of(
    List<num?> values, {
    String name = '',
    List<String> labels = const [],
    double width = 480,
    double? height,
    String? title,
    String? description,
    SvgChartTheme theme = SvgChartTheme.auto,
    bool responsive = false,
    NumberFormatter valueFormat = formatNumber,
    bool valueLabels = true,
    bool shares = false,
    HintBuilder? hint,
    bool sorted = false,
    Set<int> mutedLabels = const {},
    double? rowHeight,
    double? maxLabelWidth,
  }) : this(
         [Series(values, name: name)],
         labels: labels,
         width: width,
         height: height,
         title: title,
         description: description,
         theme: theme,
         responsive: responsive,
         valueFormat: valueFormat,
         valueLabels: valueLabels,
         shares: shares,
         hint: hint,
         sorted: sorted,
         mutedLabels: mutedLabels,
         rowHeight: rowHeight,
         maxLabelWidth: maxLabelWidth,
       );

  /// The data: one value per category in each series.
  final List<Series> series;

  /// The categories' names, left of the bars and in the hints.
  final List<String> labels;

  /// The chart's width in px.
  final double width;

  /// The chart's height in px; by default as tall as its rows need.
  final double? height;

  /// Drawn above the chart, and its accessible name.
  final String? title;

  /// The chart's accessible description.
  final String? description;

  /// Colours and type.
  final SvgChartTheme theme;

  /// Whether the SVG takes its container's width.
  final bool responsive;

  /// How several series are drawn.
  final BarMode mode;

  /// Where the legend goes (by default: at the top for 2+ series).
  final LegendPosition legend;

  /// Values at the bars' ends and in hints.
  final NumberFormatter valueFormat;

  /// Whether to write each value at its bar's end (for stacked bars: the
  /// row's total).
  final bool valueLabels;

  /// Whether hints show shares of the whole (see [ColumnChart.shares]).
  final bool shares;

  /// Writes each bar's hint instead of the default.
  final HintBuilder? hint;

  /// Whether to rank rows by value (the first series, or the stack's
  /// total), largest first.
  final bool sorted;

  /// The rows (indexes into [labels]) whose labels are drawn muted.
  final Set<int> mutedLabels;

  /// One row's height; by default 24 px, more for grouped series.
  final double? rowHeight;

  /// The widest a category label may be before it is cut with `…` (the
  /// full label stays in the hint); by default a third of the width.
  final double? maxLabelWidth;

  @override
  String render() {
    final n = [
      labels.length,
      for (final s in series) s.values.length,
    ].fold(0, math.max);
    final stacked = mode == BarMode.stacked && series.length > 1;
    final k = stacked ? 1 : math.max(1, series.length);
    num? at(Series s, int i) {
      final v = i < s.values.length ? s.values[i] : null;
      return isDrawable(v) ? v : null;
    }

    num rowValue(int i) => stacked
        ? series.fold<num>(0, (a, s) => a + (at(s, i) ?? 0))
        : (series.isEmpty ? 0 : at(series.first, i) ?? double.negativeInfinity);
    final order = [for (var i = 0; i < n; i++) i];
    if (sorted) {
      // Stable: equal values keep their given order.
      order.sort((a, b) {
        final c = rowValue(b).compareTo(rowValue(a));
        return c != 0 ? c : a.compareTo(b);
      });
    }
    String label(int i) => i < labels.length ? labels[i] : '${i + 1}';
    final small = theme.smallFontSize;
    final rowH = rowHeight ?? (k == 1 ? 24.0 : math.max(24.0, k * 10.0 + 10));

    // The header: title and legend.
    var top = 8.0;
    final titleH = (title ?? '').isEmpty ? 0.0 : theme.fontSize + 10;
    final names = [for (final s in series) s.name];
    final showLegend = switch (legend) {
      LegendPosition.none => false,
      LegendPosition.auto => series.length >= 2,
      _ => names.any((s) => s.isNotEmpty),
    };
    final legendH = showLegend
        ? legendRows(theme, names, width - 16).length * legendRowHeight(theme) +
              6
        : 0.0;
    final legendTop = legend != LegendPosition.bottom;
    final total =
        height ??
        top +
            titleH +
            (legendTop ? legendH : 0) +
            n * rowH +
            (legendTop ? 0 : legendH) +
            6;
    final w = SvgWriter();
    openChart(
      w,
      theme,
      width: width,
      height: total,
      title: title,
      description: description,
      responsive: responsive,
      kind: 'bar-chart',
    );
    if (titleH > 0) {
      w.element('text', truncateText(title!, width - 16, theme.fontSize + 1), {
        'class': '${theme.cls('text')} ${theme.cls('strong')}',
        'x': 8,
        'y': top + theme.fontSize,
        'fill': theme.palette.text,
      });
      top += titleH;
    }
    if (showLegend && legendTop) {
      writeLegend(w, theme, names, x: 8, y: top, width: width - 16);
      top += legendH;
    }
    // Rows fill what's left when the height is fixed.
    final rowsH = height == null
        ? n * rowH
        : math.max(0.0, total - top - (legendTop ? 0 : legendH) - 6);
    final row = n == 0 ? rowH : rowsH / n;
    final rowText = row >= small + 2;

    // Columns: labels | bars | values.
    final labelCap = maxLabelWidth ?? width / 3;
    final labelW = math.min(
      labelCap,
      [for (var i = 0; i < n; i++) estimateTextWidth(label(i), small)]
          .fold<double>(0, math.max),
    );
    final valueTexts = <int, String>{
      if (valueLabels)
        for (var i = 0; i < n; i++)
          if (stacked || series.isNotEmpty && at(series.first, i) != null)
            i: valueFormat(stacked ? rowValue(i) : at(series.first, i)!),
    };
    // Grouped bars write a value per bar; the widest of all sets the room.
    final valueW = !valueLabels
        ? 0.0
        : [
            for (final s in series)
              for (var i = 0; i < n; i++)
                if (at(s, i) != null)
                  estimateTextWidth(valueFormat(at(s, i)!), small),
            for (final t in valueTexts.values) estimateTextWidth(t, small),
          ].fold<double>(0, math.max);
    final left = 8 + labelW + 8;
    final right = width - 8 - (valueW > 0 ? valueW + 6 : 0);
    final domainValues = stacked
        ? [
            for (var i = 0; i < n; i++) ...[
              series.fold<num>(0, (a, s) => a + math.max(0, at(s, i) ?? 0)),
              series.fold<num>(0, (a, s) => a + math.min(0, at(s, i) ?? 0)),
            ],
          ]
        : [
            for (final s in series)
              for (var i = 0; i < n; i++) at(s, i),
          ];
    final domain = valueDomain(domainValues);
    // Negative values: the value text goes left of their bars, so room on
    // the left too.
    final hasNegative = domain.min < 0;
    final x = LinearScale(
      domain.min,
      domain.max == domain.min ? domain.min + 1 : domain.max,
      left + (hasNegative && valueW > 0 ? valueW + 6 : 0),
      right,
    );
    final zero = x(0);
    // Through at(): NaN and infinity are gaps here, as everywhere.
    final totals = [
      for (final s in series)
        shares ? totalOf([for (var i = 0; i < n; i++) at(s, i)]) : null,
    ];
    final single = series.length == 1;

    w.open('g', {'class': theme.cls('marks')});
    if (hasNegative && n > 0) {
      w.empty('line', {
        'class': theme.cls('axis'),
        'x1': zero,
        'y1': top,
        'x2': zero,
        'y2': top + rowsH,
        'stroke': theme.palette.axis,
      });
    }
    for (final (r, i) in order.indexed) {
      final rowTop = top + r * row;
      // Rows squeezed by a fixed height keep their bars inside them: the
      // padding and the gaps between grouped bars shrink with the row.
      final pad = math.min(4.0, row / 6);
      final barsH = math.max(0.5, row - 2 * pad);
      final gap = k > 1 ? math.min(2.0, barsH / (2 * k)) : 0.0;
      final thick = math.max(0.5, (barsH - gap * (k - 1)) / k);
      // Text only where a line of it fits (the hints still say it all).
      if (rowText) {
        w.element('text', truncateText(label(i), labelCap, small), {
          'class':
              '${theme.cls(mutedLabels.contains(i) ? 'tick' : 'label')} '
              '${theme.cls('small')}',
          'x': 8,
          'y': rowTop + row / 2 + small * 0.35,
          'fill': mutedLabels.contains(i)
              ? theme.palette.muted
              : theme.palette.textSecondary,
        });
      }
      num up = 0, down = 0;
      final stackTotal = stacked && shares
          ? totalOf([for (final s in series) at(s, i)])
          : null;
      var lastUp = -1, lastDown = -1;
      if (stacked) {
        for (var s = 0; s < series.length; s++) {
          final v = at(series[s], i);
          if (v != null && v > 0) lastUp = s;
          if (v != null && v < 0) lastDown = s;
        }
      }
      for (var s = 0; s < series.length; s++) {
        final v = at(series[s], i);
        if (v == null) continue;
        final y = rowTop + pad + (stacked ? 0 : s * (thick + gap));
        final double from, to;
        if (stacked) {
          final start = v >= 0 ? up : down;
          if (v >= 0) {
            up += v;
          } else {
            down += v;
          }
          from = x(start);
          to = x(start + v);
        } else {
          from = zero;
          to = x(v);
        }
        final mark = ChartMark(
          index: i,
          label: label(i),
          value: v,
          series: series[s].name,
          seriesIndex: s,
        );
        final lines =
            hint?.call(mark) ??
            markHint(
              mark.label,
              v,
              measure: series[s].name,
              total: stacked ? stackTotal : totals[s],
              format: valueFormat,
            );
        openMark(w, theme, lines, index: i, series: s);
        // The hit target: the whole row's width, label included.
        w.empty('rect', {
          'class': theme.cls('hit'),
          'x': 0,
          'y': stacked ? rowTop : y - gap / 2,
          'width': width,
          'height': stacked ? row : thick + gap,
          'fill': 'transparent',
        });
        var lo = math.min(from, to), hi = math.max(from, to);
        if (stacked) {
          if (v > 0 && s != lastUp) hi -= 1;
          if (v > 0 && up - v != 0) lo += 1;
          if (v < 0 && s != lastDown) lo += 1;
          if (v < 0 && down - v != 0) hi -= 1;
        }
        if (hi - lo > 0 || v != 0) {
          final rounded = !stacked || s == (v >= 0 ? lastUp : lastDown);
          final negative = v < 0 && single;
          w.empty('path', {
            'class':
                '${theme.cls('bar')} '
                '${negative ? theme.cls('neg') : seriesClass(theme, s)}',
            'd': roundedBarPath(
              lo,
              y,
              math.max(hi - lo, 1),
              stacked ? barsH : thick,
              rounded ? math.min(4, thick / 2) : 0,
              v >= 0 ? 'right' : 'left',
            ),
            'fill': negative
                ? theme.palette.negative
                : theme.palette.seriesColor(s),
          });
        }
        // Grouped: each bar's value at its end.
        if (valueLabels && !stacked && k > 1 && thick + gap >= small - 1) {
          _valueText(w, valueFormat(v), v, to, y + thick / 2, small);
        }
        w.close('g');
      }
      // One series, or a stack: the row's value at its end.
      if (rowText &&
          valueLabels &&
          (k == 1 || stacked) &&
          valueTexts[i] != null) {
        final value = rowValue(i);
        final end = stacked ? x(value >= 0 ? up : down) : x(value);
        _valueText(w, valueTexts[i]!, value, end, rowTop + row / 2, small);
      }
    }
    w.close('g');
    if (showLegend && !legendTop) {
      writeLegend(w, theme, names, x: 8, y: total - legendH, width: width - 16);
    }
    w.close('svg');
    return w.toString();
  }

  /// A value [text] at a bar's [end] (right of it, left for a negative
  /// [value]), centred on [y].
  void _valueText(
    SvgWriter w,
    String text,
    num value,
    double end,
    double y,
    double size,
  ) => w.element('text', text, {
    'class': '${theme.cls('text')} ${theme.cls('small')}',
    'x': value < 0 ? end - 4 : end + 4,
    'y': y + size * 0.35,
    'text-anchor': value < 0 ? 'end' : 'start',
    'fill': theme.palette.text,
  });

  @override
  String toString() => render();
}
