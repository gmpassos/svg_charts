/// Lines and areas over ordered categories (dates, steps), with series.
library;

import 'dart:math' as math;

import '../chart.dart';
import '../format.dart';
import '../hints.dart';
import '../scale.dart';
import '../series.dart';
import '../svg_writer.dart';
import '../theme.dart';

/// A line chart: one line per series over the x positions in [labels].
///
/// A `null` value is a gap: the line breaks there instead of diving to zero
/// (a missing day is not a day with no orders). An isolated value between
/// gaps is drawn as a dot.
///
/// Hover: each x position has a band the plot's full height, so the
/// pointer needn't aim at a 2 px line. The band's hint lists every series
/// there, and it shows a crosshair; each point's own hint is its series.
///
/// The value axis fits the data and doesn't force zero (a line's shape is
/// the point); pass [yMin]: 0 when the level matters. [AreaChart] does
/// include zero, as its filled area is a magnitude.
///
/// ```dart
/// final svg = LineChart(
///   [Series([3, 5, 4, 8], name: 'paid'), Series([1, 2, 2, 3], name: 'open')],
///   labels: ['Q1', 'Q2', 'Q3', 'Q4'],
/// ).render();
/// ```
class LineChart implements SvgChart {
  /// A chart of [series], one value per x position in [labels].
  const LineChart(
    this.series, {
    this.labels = const [],
    this.width = 480,
    this.height = 240,
    this.title,
    this.description,
    this.theme = SvgChartTheme.auto,
    this.responsive = false,
    this.xLabels = XLabels.auto,
    this.legend = LegendPosition.auto,
    this.valueFormat = formatNumber,
    this.tickFormat = formatCompact,
    this.smooth = false,
    this.points,
    this.yMin,
    this.yMax,
    this.caption,
    this.grid = true,
    this.hint,
  }) : area = false;

  /// A chart of one series of [values].
  LineChart.of(
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
    bool smooth = false,
    bool? points,
    num? yMin,
    num? yMax,
    String? caption,
    bool grid = true,
    HintBuilder? hint,
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
         smooth: smooth,
         points: points,
         yMin: yMin,
         yMax: yMax,
         caption: caption,
         grid: grid,
         hint: hint,
       );

  const LineChart._area(
    this.series, {
    required this.labels,
    required this.width,
    required this.height,
    required this.title,
    required this.description,
    required this.theme,
    required this.responsive,
    required this.xLabels,
    required this.legend,
    required this.valueFormat,
    required this.tickFormat,
    required this.smooth,
    required this.points,
    required this.yMin,
    required this.yMax,
    required this.caption,
    required this.grid,
    required this.hint,
  }) : area = true;

  /// The data: one value per x position in each series.
  final List<Series> series;

  /// The x positions' names, under the axis and in the hints.
  final List<String> labels;

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

  /// Which x labels are written.
  final XLabels xLabels;

  /// Where the legend goes (by default: at the top for 2+ series).
  final LegendPosition legend;

  /// Values in hints.
  final NumberFormatter valueFormat;

  /// Values on the axis.
  final NumberFormatter tickFormat;

  /// Whether lines are smooth curves (monotone: a curve never overshoots
  /// its points, so it invents no peaks or dips) instead of straight
  /// segments.
  final bool smooth;

  /// Whether to draw a dot per value; by default only when there are 12
  /// or fewer x positions (more dots crowd the line; the bands' hints and
  /// crosshair still read every value).
  final bool? points;

  /// The value axis' low end (by default the data's).
  final num? yMin;

  /// The value axis' high end (by default the data's).
  final num? yMax;

  /// A line under the chart.
  final String? caption;

  /// Whether to draw grid lines at the ticks.
  final bool grid;

  /// Writes each point's hint instead of the default (the band's hint
  /// stays the list of all series).
  final HintBuilder? hint;

  /// Whether the area under each line is filled ([AreaChart]).
  final bool area;

  @override
  String render() {
    final n = [
      labels.length,
      for (final s in series) s.values.length,
    ].fold(0, math.max);
    num? at(Series s, int i) {
      final v = i < s.values.length ? s.values[i] : null;
      return isDrawable(v) ? v : null;
    }

    final w = SvgWriter();
    openChart(
      w,
      theme,
      width: width,
      height: height,
      title: title,
      description: description,
      responsive: responsive,
      kind: area ? 'area-chart' : 'line-chart',
    );
    final frame = writeFrame(
      w,
      theme,
      width: width,
      height: height,
      domain: valueDomain(
        [
          for (final s in series)
            for (var i = 0; i < n; i++) at(s, i),
        ],
        baseline: area,
        min: yMin,
        max: yMax,
      ),
      title: title,
      legend: [for (final s in series) s.name],
      legendPosition: legend,
      categoryLabels: xLabels != XLabels.none && n > 0,
      tickFormat: tickFormat,
      grid: grid,
      caption: caption,
    );
    final plot = frame.area;
    final y = frame.scale;
    double x(int i) =>
        plot.left + (n <= 1 ? plot.width / 2 : i * plot.width / (n - 1));
    String label(int i) => i < labels.length ? labels[i] : '${i + 1}';
    final base = y(math.max(frame.ticks.first, math.min(0, frame.ticks.last)));
    final names = [
      for (final (i, s) in series.indexed)
        s.name.isEmpty && series.length > 1 ? 'series ${i + 1}' : s.name,
    ];
    Map<String, num?> valuesAt(int i) => {
      for (final (s, name) in names.indexed) name: at(series[s], i),
    };

    // Bands first (under the lines): a hint per x with every series, and a
    // crosshair shown on hover.
    final band = n <= 1 ? plot.width : plot.width / (n - 1);
    w.open('g', {'class': theme.cls('bands')});
    for (var i = 0; i < n; i++) {
      final left = math.max(plot.left, x(i) - band / 2);
      final right = math.min(plot.right, x(i) + band / 2);
      openMark(
        w,
        theme,
        pointHint(
          label(i),
          names.isEmpty ? '' : names.first,
          valuesAt(i),
          format: valueFormat,
        ),
        cls: 'band',
        index: i,
      );
      w
        ..empty('rect', {
          'x': left,
          'y': plot.top,
          'width': right - left,
          'height': plot.height,
          'fill': 'transparent',
        })
        ..empty('line', {
          'class': theme.cls('cross'),
          'x1': x(i),
          'y1': plot.top,
          'x2': x(i),
          'y2': plot.bottom,
        })
        ..close('g');
    }
    w.close('g');

    final showPoints = points ?? n <= 12;
    for (final (s, data) in series.indexed) {
      final color = seriesClass(theme, s);
      final hex = theme.palette.seriesColor(s);
      // The runs of values between gaps.
      final runs = <List<int>>[];
      for (var i = 0; i < n; i++) {
        if (at(data, i) == null) continue;
        if (runs.isEmpty || runs.last.last != i - 1) runs.add([]);
        runs.last.add(i);
      }
      w.open('g', {'class': '${theme.cls('series')} $color'});
      for (final run in runs) {
        final pts = [for (final i in run) (x(i), y(at(data, i)!))];
        final line = smooth ? _monotonePath(pts) : _polylinePath(pts);
        if (area && pts.length > 1) {
          w.empty('path', {
            'class': '${theme.cls('area')} $color',
            'd':
                '$line L${svgNum(pts.last.$1)} ${svgNum(base)} '
                'L${svgNum(pts.first.$1)} ${svgNum(base)}Z',
            'fill': hex,
            'fill-opacity': 0.16,
          });
        }
        if (pts.length > 1) {
          w.empty('path', {
            'class': '${theme.cls('line')} $color',
            'd': line,
            'fill': 'none',
            'stroke': hex,
            'stroke-width': 2,
          });
        }
      }
      // Points: each with its own series' hint; an isolated value always
      // gets one, or it would not be drawn at all.
      for (final run in runs) {
        for (final i in run) {
          if (!showPoints && run.length > 1) continue;
          final v = at(data, i)!;
          final mark = ChartMark(
            index: i,
            label: label(i),
            value: v,
            series: data.name,
            seriesIndex: s,
          );
          openMark(
            w,
            theme,
            hint?.call(mark) ??
                pointHint(
                  label(i),
                  names[s],
                  valuesAt(i),
                  others: false,
                  format: valueFormat,
                ),
            cls: 'point',
            index: i,
            series: s,
            named: false,
          );
          w
            ..empty('circle', {
              'class': '${theme.cls('dot')} $color',
              'cx': x(i),
              'cy': y(v),
              'r': 4,
              'fill': hex,
              'stroke': theme.palette.surface,
              'stroke-width': 2,
            })
            ..empty('circle', {
              'class': theme.cls('hit'),
              'cx': x(i),
              'cy': y(v),
              'r': 10,
              'fill': 'transparent',
            })
            ..close('g');
        }
      }
      w.close('g');
    }
    if (xLabels != XLabels.none && n > 0) {
      writeXLabels(
        w,
        theme,
        [for (var i = 0; i < n; i++) label(i)],
        [for (var i = 0; i < n; i++) x(i)],
        plot,
        xLabels,
      );
    }
    w.close('svg');
    return w.toString();
  }

  @override
  String toString() => render();
}

/// A line chart with the area under each line filled, from zero.
///
/// For one series, or a few that overlap little: overlapping fills blend.
class AreaChart extends LineChart {
  /// An area chart of [series] (see [LineChart] for the options).
  const AreaChart(
    super.series, {
    super.labels = const [],
    super.width = 480,
    super.height = 240,
    super.title,
    super.description,
    super.theme = SvgChartTheme.auto,
    super.responsive = false,
    super.xLabels = XLabels.auto,
    super.legend = LegendPosition.auto,
    super.valueFormat = formatNumber,
    super.tickFormat = formatCompact,
    super.smooth = false,
    super.points,
    super.yMin,
    super.yMax,
    super.caption,
    super.grid = true,
    super.hint,
  }) : super._area();

  /// An area chart of one series of [values].
  AreaChart.of(
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
    bool smooth = false,
    bool? points,
    num? yMin,
    num? yMax,
    String? caption,
    bool grid = true,
    HintBuilder? hint,
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
         smooth: smooth,
         points: points,
         yMin: yMin,
         yMax: yMax,
         caption: caption,
         grid: grid,
         hint: hint,
       );
}

/// Straight segments through [pts].
String _polylinePath(List<(double, double)> pts) => [
  for (final (i, (x, y)) in pts.indexed)
    '${i == 0 ? 'M' : 'L'}${svgNum(x)} ${svgNum(y)}',
].join(' ');

/// A monotone cubic curve through [pts] (Fritsch–Carlson): between two
/// points it stays within their values, so it adds no peak or dip the data
/// doesn't have.
String _monotonePath(List<(double, double)> pts) {
  final n = pts.length;
  if (n < 3) return _polylinePath(pts);
  final dx = [for (var i = 0; i < n - 1; i++) pts[i + 1].$1 - pts[i].$1];
  final slope = [
    for (var i = 0; i < n - 1; i++)
      dx[i] == 0 ? 0.0 : (pts[i + 1].$2 - pts[i].$2) / dx[i],
  ];
  final tangent = List<double>.filled(n, 0);
  tangent[0] = slope[0];
  tangent[n - 1] = slope[n - 2];
  for (var i = 1; i < n - 1; i++) {
    // A local extreme (or flat) is flat; otherwise the harmonic mean.
    if (slope[i - 1] * slope[i] <= 0) {
      tangent[i] = 0;
    } else {
      tangent[i] =
          3 *
          (dx[i - 1] + dx[i]) /
          ((2 * dx[i] + dx[i - 1]) / slope[i - 1] +
              (dx[i] + 2 * dx[i - 1]) / slope[i]);
    }
  }
  final out = StringBuffer('M${svgNum(pts[0].$1)} ${svgNum(pts[0].$2)}');
  for (var i = 0; i < n - 1; i++) {
    final (x0, y0) = pts[i];
    final (x1, y1) = pts[i + 1];
    final h = dx[i] / 3;
    out.write(
      ' C${svgNum(x0 + h)} ${svgNum(y0 + tangent[i] * h)} '
      '${svgNum(x1 - h)} ${svgNum(y1 - tangent[i + 1] * h)} '
      '${svgNum(x1)} ${svgNum(y1)}',
    );
  }
  return out.toString();
}
