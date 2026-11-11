/// Charts rendered as SVG markup: columns, bars, lines, areas, sparklines,
/// scatter plots, pies and donuts, meters, gauges, heatmaps and stat tiles.
///
/// Every chart is an immutable value whose `render()` returns one `<svg>`
/// element as a `String`. Nothing touches the DOM and nothing imports
/// `dart:io` or `dart:js_interop`, so the same chart renders in a browser,
/// on a server (an HTML report, an e-mail, a `.svg` file) or in an isolate.
///
/// ```dart
/// import 'package:svg_charts/svg_charts.dart';
///
/// void main() {
///   final svg = ColumnChart.of(
///     [12, 30, 18],
///     labels: ['Jan', 'Feb', 'Mar'],
///     title: 'Orders',
///   ).render();
///   print(svg);
/// }
/// ```
///
/// ## Hints
///
/// Each mark (a column, a point, a slice, a cell) carries its hint three
/// ways: a native `<title>` (a tooltip in any browser, even in a standalone
/// file), a `data-hint` attribute and an accessible name. The companion
/// library `package:svg_charts/svg_charts_web.dart` shows `data-hint` in a
/// styled tooltip and wires clicks on marks.
///
/// ## Styling
///
/// Charts are styled by classes and an embedded style sheet whose rules
/// read CSS custom properties, the [SvgChartTheme]'s colours as fallbacks.
/// A standalone file looks right; a page restyles charts by setting the
/// properties; dark mode follows `prefers-color-scheme` or a
/// `data-theme` attribute. See [SvgChartTheme].
///
/// ## Gaps are not zeros
///
/// A `null` value (or NaN, or infinity) is a gap: no column, a break in
/// the line, an empty cell. It is never drawn as zero.
library;

export 'src/chart.dart'
    show LegendPosition, SvgChart, XLabels, estimateTextWidth, truncateText;
export 'src/charts/bar_chart.dart' show BarChart;
export 'src/charts/column_chart.dart' show BarMode, ColumnChart, Histogram;
export 'src/charts/gauge.dart' show Gauge, Meter;
export 'src/charts/heatmap.dart' show Heatmap;
export 'src/charts/line_chart.dart' show AreaChart, LineChart;
export 'src/charts/pie_chart.dart' show PieChart, PieSlice;
export 'src/charts/scatter_chart.dart' show ScatterChart;
export 'src/charts/sparkline.dart' show Sparkline;
export 'src/charts/stat_tile.dart' show StatTile, Trend;
export 'src/format.dart'
    show
        NumberFormatter,
        formatCompact,
        formatNumber,
        formatRate,
        groupThousands;
export 'src/hints.dart'
    show
        hintLineBreak,
        hintLines,
        hintText,
        markHint,
        pointHint,
        shareOf,
        totalOf;
export 'src/scale.dart'
    show LinearScale, dataExtent, isDrawable, niceStep, niceTicks;
export 'src/series.dart' show ChartMark, HintBuilder, Series, XYPoint, XYSeries;
export 'src/stats.dart' show HistogramBin, finiteValues, histogramBins;
export 'src/svg_writer.dart' show SvgWriter, escapeXml, svgNum;
export 'src/theme.dart' show SvgChartTheme, SvgPalette, svgChartsCss;
