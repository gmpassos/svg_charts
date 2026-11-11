/// Points on two value axes.
library;

import 'dart:math' as math;

import '../chart.dart';
import '../format.dart';
import '../scale.dart';
import '../series.dart';
import '../svg_writer.dart';
import '../theme.dart';

/// A scatter chart: each point of each series at its x and y value.
///
/// Both axes are value axes with round ticks fitted to the data. Points
/// are 8 px dots with a surface-coloured ring, so overlapping points stay
/// apart. Each hint gives the point's label (when it has one), its series,
/// and its x and y values.
///
/// Keep it to three series or fewer: on a scatter every colour sits next to
/// every other, and more than three can't all be told apart by everyone.
///
/// ```dart
/// final svg = ScatterChart([
///   XYSeries([XYPoint(1, 2), XYPoint(3, 5)], name: 'A'),
/// ], xName: 'price', yName: 'sales').render();
/// ```
class ScatterChart implements SvgChart {
  /// A chart of [series].
  const ScatterChart(
    this.series, {
    this.width = 480,
    this.height = 300,
    this.title,
    this.description,
    this.theme = SvgChartTheme.auto,
    this.responsive = false,
    this.legend = LegendPosition.auto,
    this.xName = 'x',
    this.yName = 'y',
    this.valueFormat = formatNumber,
    this.tickFormat = formatCompact,
    this.radius = 4,
    this.caption,
    this.grid = true,
  });

  /// The data.
  final List<XYSeries> series;

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

  /// Where the legend goes (by default: at the top for 2+ series).
  final LegendPosition legend;

  /// What x measures, in the hints.
  final String xName;

  /// What y measures, in the hints.
  final String yName;

  /// Values in hints.
  final NumberFormatter valueFormat;

  /// Values on the axes.
  final NumberFormatter tickFormat;

  /// The dots' radius in px.
  final double radius;

  /// A line under the chart (what the axes are).
  final String? caption;

  /// Whether to draw grid lines at the ticks.
  final bool grid;

  @override
  String render() {
    final points = [
      for (final s in series)
        for (final p in s.points)
          if (p.x.isFinite && p.y.isFinite) p,
    ];
    final w = SvgWriter();
    openChart(
      w,
      theme,
      width: width,
      height: height,
      title: title,
      description: description,
      responsive: responsive,
      kind: 'scatter-chart',
    );
    final frame = writeFrame(
      w,
      theme,
      width: width,
      height: height,
      domain: valueDomain([for (final p in points) p.y], baseline: false),
      title: title,
      legend: [for (final s in series) s.name],
      legendPosition: legend,
      tickFormat: tickFormat,
      grid: grid,
      caption: caption,
    );
    final area = frame.area;
    final y = frame.scale;
    // The x axis: its own round ticks over the x values.
    final xe = dataExtent([for (final p in points) p.x]) ?? (min: 0, max: 1);
    final xTicks = niceTicks(
      xe.min,
      xe.max,
      maxTicks: math.max(2, area.width ~/ 72),
    );
    final x = LinearScale(xTicks.first, xTicks.last, area.left, area.right);
    final small = theme.smallFontSize;
    w.open('g', {'class': theme.cls('xticks')});
    for (final t in xTicks) {
      final text = tickFormat(t);
      final half = estimateTextWidth(text, small) / 2;
      if (grid) {
        w.empty('line', {
          'class': theme.cls('grid'),
          'x1': x(t),
          'y1': area.top,
          'x2': x(t),
          'y2': area.bottom,
          'stroke': theme.palette.grid,
        });
      }
      w.element('text', text, {
        'class': '${theme.cls('tick')} ${theme.cls('small')}',
        'x': x(t).clamp(half, math.max(half, width - half)),
        'y': area.bottom + small + 4,
        'text-anchor': 'middle',
        'fill': theme.palette.muted,
      });
    }
    w.close('g');
    for (final (s, data) in series.indexed) {
      final cls = seriesClass(theme, s);
      w.open('g', {'class': '${theme.cls('series')} $cls'});
      for (final (i, p) in data.points.indexed) {
        if (!p.x.isFinite || !p.y.isFinite) continue;
        openMark(
          w,
          theme,
          [
            p.label ?? (data.name.isEmpty ? '${i + 1}' : data.name),
            if (p.label != null && data.name.isNotEmpty) data.name,
            '$xName: ${valueFormat(p.x)}',
            '$yName: ${valueFormat(p.y)}',
          ],
          cls: 'point',
          index: i,
          series: s,
        );
        w
          ..empty('circle', {
            'class': '${theme.cls('dot')} $cls',
            'cx': x(p.x),
            'cy': y(p.y),
            'r': radius,
            'fill': theme.palette.seriesColor(s),
            'stroke': theme.palette.surface,
            'stroke-width': 2,
          })
          ..empty('circle', {
            'class': theme.cls('hit'),
            'cx': x(p.x),
            'cy': y(p.y),
            'r': radius + 6,
            'fill': 'transparent',
          })
          ..close('g');
      }
      w.close('g');
    }
    w.close('svg');
    return w.toString();
  }

  @override
  String toString() => render();
}
