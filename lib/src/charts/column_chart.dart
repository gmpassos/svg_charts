/// Vertical columns: single, grouped or stacked, and histograms.
library;

import 'dart:math' as math;

import '../chart.dart';
import '../format.dart';
import '../hints.dart';
import '../scale.dart';
import '../series.dart';
import '../stats.dart';
import '../svg_writer.dart';
import '../theme.dart';

/// How a column or bar chart draws several series.
enum BarMode {
  /// Side by side within each category.
  grouped,

  /// On top of each other: positives up from the baseline, negatives down.
  stacked,
}

/// A vertical column chart: one column per category, or per category and
/// series ([BarMode.grouped] or [BarMode.stacked]).
///
/// Columns start at a zero baseline, so negative values hang below it
/// (drawn in the palette's negative colour for a single series; several
/// series keep their own colours, as colour names the series). A `null`
/// value draws no column. Each column has a hint: its category, its
/// series and value, and with [shares] its share of the whole.
///
/// ```dart
/// final svg = ColumnChart.of(
///   [12, 30, 18],
///   labels: ['Jan', 'Feb', 'Mar'],
///   title: 'Orders',
/// ).render();
/// ```
class ColumnChart implements SvgChart {
  /// A chart of [series], one value per category in [labels].
  const ColumnChart(
    this.series, {
    this.labels = const [],
    this.width = 480,
    this.height = 240,
    this.title,
    this.description,
    this.theme = SvgChartTheme.auto,
    this.responsive = false,
    this.mode = BarMode.grouped,
    this.xLabels = XLabels.auto,
    this.legend = LegendPosition.auto,
    this.valueFormat = formatNumber,
    this.tickFormat = formatCompact,
    this.shares = false,
    this.hint,
    this.yMin,
    this.yMax,
    this.groupGap = 0.2,
    this.caption,
    this.grid = true,
  });

  /// A chart of one series of [values]; [name] names it in hints.
  ColumnChart.of(
    List<num?> values, {
    String name = '',
    List<String> labels = const [],
    double width = 480,
    double height = 240,
    String? title,
    String? description,
    SvgChartTheme theme = SvgChartTheme.auto,
    bool responsive = false,
    XLabels xLabels = XLabels.auto,
    NumberFormatter valueFormat = formatNumber,
    NumberFormatter tickFormat = formatCompact,
    bool shares = false,
    HintBuilder? hint,
    num? yMin,
    num? yMax,
    double groupGap = 0.2,
    String? caption,
    bool grid = true,
  }) : this(
         [Series(values, name: name)],
         labels: labels,
         width: width,
         height: height,
         title: title,
         description: description,
         theme: theme,
         responsive: responsive,
         xLabels: xLabels,
         valueFormat: valueFormat,
         tickFormat: tickFormat,
         shares: shares,
         hint: hint,
         yMin: yMin,
         yMax: yMax,
         groupGap: groupGap,
         caption: caption,
         grid: grid,
       );

  /// The data: one value per category in each series.
  final List<Series> series;

  /// The categories' names, under the columns and in the hints.
  final List<String> labels;

  /// The chart's width in px (its view box width when [responsive]).
  final double width;

  /// The chart's height in px.
  final double height;

  /// Drawn above the chart, and its accessible name.
  final String? title;

  /// The chart's accessible description (`<desc>`).
  final String? description;

  /// Colours and type.
  final SvgChartTheme theme;

  /// Whether the SVG takes its container's width.
  final bool responsive;

  /// How several series are drawn.
  final BarMode mode;

  /// Which category labels are written.
  final XLabels xLabels;

  /// Where the legend goes (by default: at the top for 2+ series).
  final LegendPosition legend;

  /// Values in hints.
  final NumberFormatter valueFormat;

  /// Values on the axis.
  final NumberFormatter tickFormat;

  /// Whether hints show each value's share of the whole: of its series'
  /// total when grouped, of its category's stack when stacked. Only for
  /// values that add up (counts, sums), never averages; no share is shown
  /// where a negative value makes the whole meaningless.
  final bool shares;

  /// Writes each column's hint instead of the default.
  final HintBuilder? hint;

  /// The value axis' low end (by default the lowest value, or zero).
  final num? yMin;

  /// The value axis' high end (by default the highest value, or zero).
  final num? yMax;

  /// The space between categories, as a fraction of each one's slot.
  final double groupGap;

  /// A line under the chart (what the axes show, a source).
  final String? caption;

  /// Whether to draw grid lines at the ticks.
  final bool grid;

  @override
  String render() {
    final n = [
      labels.length,
      for (final s in series) s.values.length,
    ].fold(0, math.max);
    final w = SvgWriter();
    openChart(
      w,
      theme,
      width: width,
      height: height,
      title: title,
      description: description,
      responsive: responsive,
      kind: 'column-chart',
    );
    final stacked = mode == BarMode.stacked && series.length > 1;
    num? at(Series s, int i) {
      final v = i < s.values.length ? s.values[i] : null;
      return isDrawable(v) ? v : null;
    }

    // Stacked: each category's positive and negative sums bound the axis.
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
    final frame = writeFrame(
      w,
      theme,
      width: width,
      height: height,
      domain: valueDomain(domainValues, min: yMin, max: yMax),
      title: title,
      legend: [for (final s in series) s.name],
      legendPosition: legend,
      categoryLabels: xLabels != XLabels.none && n > 0,
      tickFormat: tickFormat,
      grid: grid,
      caption: caption,
    );
    final area = frame.area;
    final y = frame.scale;
    // The baseline: zero, or the axis' end nearest it.
    final base = y(math.max(frame.ticks.first, math.min(0, frame.ticks.last)));
    // A value past an explicit yMin / yMax is cut at the axis' end, never
    // drawn over the title, legend or labels (its hint keeps the value).
    double yIn(num v) => y(v).clamp(area.top, area.bottom);
    final slot = n == 0 ? 0.0 : area.width / n;
    final groupW = slot * (1 - groupGap.clamp(0, 0.9));
    final k = stacked ? 1 : math.max(1, series.length);
    final barW = math.max(1.0, (groupW - 2 * (k - 1)) / k);
    String label(int i) => i < labels.length ? labels[i] : '${i + 1}';
    // Through at(): NaN and infinity are gaps here, as everywhere (raw, one
    // NaN would make no whole, and no share would show).
    final totals = [
      for (final s in series)
        shares ? totalOf([for (var i = 0; i < n; i++) at(s, i)]) : null,
    ];
    final single = series.length == 1;

    w.open('g', {'class': theme.cls('marks')});
    for (var i = 0; i < n; i++) {
      final groupX = area.left + i * slot + (slot - groupW) / 2;
      // Stacked: the running sums above and below the baseline.
      num up = 0, down = 0;
      final stackTotal = stacked && shares
          ? totalOf([for (final s in series) at(s, i)])
          : null;
      // The outermost segment each way gets the rounded end.
      var lastUp = -1, lastDown = -1;
      if (stacked) {
        for (var s = 0; s < series.length; s++) {
          final v = at(series[s], i);
          if (v == null || v == 0) continue;
          if (v > 0) lastUp = s;
          if (v < 0) lastDown = s;
        }
      }
      for (var s = 0; s < series.length; s++) {
        final v = at(series[s], i);
        if (v == null) continue;
        final x = stacked ? groupX : groupX + s * (barW + 2);
        final double y0, y1;
        if (stacked) {
          final from = v >= 0 ? up : down;
          final to = from + v;
          if (v >= 0) {
            up = to;
          } else {
            down = to;
          }
          y0 = yIn(from);
          y1 = yIn(to);
        } else {
          y0 = base;
          y1 = yIn(v);
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
        // The hit target: the column's whole height, so a short column is
        // as easy to point at as a tall one.
        w.empty('rect', {
          'class': theme.cls('hit'),
          'x': x,
          'y': area.top,
          'width': barW,
          'height': area.height,
          'fill': 'transparent',
        });
        var top = math.min(y0, y1), bottom = math.max(y0, y1);
        // Stacked segments: a 2 px surface gap between neighbours.
        if (stacked) {
          if (v > 0 && s != lastUp) top += 1;
          if (v > 0 && up - v != 0) bottom -= 1;
          if (v < 0 && s != lastDown) bottom -= 1;
          if (v < 0 && down - v != 0) top += 1;
        }
        final h = bottom - top;
        if (h > 0) {
          final rounded = !stacked || s == (v >= 0 ? lastUp : lastDown);
          final negative = v < 0 && single;
          w.empty('path', {
            'class':
                '${theme.cls('bar')} '
                '${negative ? theme.cls('neg') : seriesClass(theme, s)}',
            'd': roundedBarPath(
              x,
              top,
              barW,
              // A non-zero value is at least a sliver: 1 px.
              math.max(h, 1),
              rounded ? math.min(4, barW / 2) : 0,
              v >= 0 ? 'top' : 'bottom',
            ),
            'fill': negative
                ? theme.palette.negative
                : theme.palette.seriesColor(s),
          });
        }
        w.close('g');
      }
    }
    w.close('g');
    if (xLabels != XLabels.none && n > 0) {
      writeXLabels(
        w,
        theme,
        [for (var i = 0; i < n; i++) label(i)],
        [for (var i = 0; i < n; i++) area.left + (i + 0.5) * slot],
        area,
        xLabels,
      );
    }
    w.close('svg');
    return w.toString();
  }

  @override
  String toString() => render();
}

/// A histogram: [values] counted into equal-width bins, drawn as touching
/// columns, each hint giving its range, count and share of all values.
class Histogram implements SvgChart {
  /// A histogram of [values] in [bins] bins (non-finite values skipped).
  const Histogram(
    this.values, {
    this.bins = 10,
    this.width = 480,
    this.height = 240,
    this.title,
    this.description,
    this.theme = SvgChartTheme.auto,
    this.responsive = false,
    this.binFormat = formatCompact,
    this.measure = 'count',
    this.caption,
  });

  /// The values counted.
  final List<num?> values;

  /// How many bins.
  final int bins;

  /// The chart's width in px.
  final double width;

  /// The chart's height in px.
  final double height;

  /// Drawn above the chart, and its accessible name.
  final String? title;

  /// The chart's accessible description.
  final String? description;

  /// Colours and type.
  final SvgChartTheme theme;

  /// Whether the SVG takes its container's width.
  final bool responsive;

  /// The bins' bounds in labels and hints.
  final NumberFormatter binFormat;

  /// The name of what a bin counts, in hints.
  final String measure;

  /// A line under the chart.
  final String? caption;

  @override
  String render() {
    final b = histogramBins(values, bins);
    return ColumnChart(
      [
        Series([for (final bin in b) bin.count], name: measure),
      ],
      labels: [
        for (final bin in b) '${binFormat(bin.start)}–${binFormat(bin.end)}',
      ],
      width: width,
      height: height,
      title: title,
      description: description,
      theme: theme,
      responsive: responsive,
      groupGap: 0.04,
      shares: true,
      caption: caption,
    ).render();
  }

  @override
  String toString() => render();
}
