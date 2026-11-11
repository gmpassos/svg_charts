// The gallery's charts: one of each kind, as the README shows them.
//
// Pure Dart (no dart:io): `gallery.dart` writes them to doc/images, and
// test/gallery_test.dart checks those files are what this code renders.
import 'dart:math' as math;

import 'package:svg_charts/svg_charts.dart';

const months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// The README images' theme: light or dark by the viewer's system, on
/// their own surface. An `<img>` follows the system's scheme, not the
/// page's (GitHub's dark theme on a light system), so a transparent image
/// would put light-scheme text on a dark page.
const readmeTheme = SvgChartTheme(background: true);

/// The gallery, by file name (without `.svg`), with [theme].
Map<String, SvgChart> galleryCharts([SvgChartTheme theme = readmeTheme]) => {
  'column': ColumnChart.of(
    [42, 51, 38, 64, 72, 69, 80, 77, 61, 58, 66, 90],
    name: 'orders',
    labels: months,
    title: 'Orders per month',
    shares: true,
    theme: theme,
  ),
  'column_grouped': ColumnChart(
    const [
      Series([12, 18, 15, 22], name: 'web'),
      Series([8, 11, 14, 13], name: 'app'),
      Series([3, 4, 6, 9], name: 'api'),
    ],
    labels: const ['Q1', 'Q2', 'Q3', 'Q4'],
    title: 'Sales by channel',
    theme: theme,
  ),
  'column_stacked': ColumnChart(
    const [
      Series([120, 132, 101, 134, 90, 230, 210], name: 'delivered'),
      Series([22, 18, 19, 23, 29, 33, 31], name: 'canceled'),
    ],
    labels: const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
    mode: BarMode.stacked,
    shares: true,
    title: 'Orders by status',
    theme: theme,
  ),
  'column_negative': ColumnChart.of(
    [12, -4, 8, -9, 15, 3, -2, 6],
    name: 'net',
    labels: const ['W1', 'W2', 'W3', 'W4', 'W5', 'W6', 'W7', 'W8'],
    title: 'Net change',
    theme: theme,
  ),
  'histogram': Histogram(
    [for (var i = 0; i < 400; i++) 50 + 15 * _gauss(i) + (i % 7 == 0 ? 25 : 0)],
    bins: 16,
    title: 'Response time (ms)',
    theme: theme,
  ),
  'bar': BarChart.of(
    [4210, 3120, 960, 480, 120],
    name: 'orders',
    labels: const ['delivered', 'paid', 'canceled', 'refunded', '(no value)'],
    mutedLabels: const {4},
    sorted: true,
    shares: true,
    title: 'Orders by status',
    theme: theme,
  ),
  'bar_stacked': BarChart(
    const [
      Series([30, 22, 18, 9], name: 'new'),
      Series([12, 15, 6, 4], name: 'returning'),
    ],
    labels: const ['Lisbon', 'Porto', 'Braga', 'Faro'],
    mode: BarMode.stacked,
    title: 'Customers by city',
    theme: theme,
  ),
  'line': LineChart(
    [
      Series([
        for (var i = 0; i < 30; i++) 120 + 40 * math.sin(i / 4) + i * 2,
      ], name: 'visits'),
      Series([
        for (var i = 0; i < 30; i++)
          i == 12 || i == 13 ? null : 60 + 25 * math.cos(i / 5) + i,
      ], name: 'signups'),
    ],
    labels: [for (var i = 1; i <= 30; i++) 'Nov $i'],
    smooth: true,
    title: 'Daily traffic',
    theme: theme,
  ),
  'area': AreaChart.of(
    [
      for (var i = 0; i < 24; i++)
        20 + 60 * math.exp(-((i - 13) * (i - 13)) / 18),
    ],
    name: 'load',
    labels: [for (var i = 0; i < 24; i++) '${i}h'],
    smooth: true,
    title: 'Load by hour',
    theme: theme,
  ),
  'scatter': ScatterChart(
    [
      XYSeries([
        for (var i = 0; i < 40; i++)
          XYPoint(5 + i * 2.2, 20 + i * 1.6 + 12 * math.sin(i * 1.7)),
      ], name: 'menu A'),
      XYSeries([
        for (var i = 0; i < 30; i++)
          XYPoint(10 + i * 2.6, 60 - i * 0.9 + 10 * math.cos(i * 1.3)),
      ], name: 'menu B'),
    ],
    xName: 'price',
    yName: 'orders',
    title: 'Price vs. orders',
    theme: theme,
  ),
  'pie': PieChart.of(
    [62, 25, 13],
    labels: const ['web', 'app', 'api'],
    title: 'Orders by channel',
    theme: theme,
  ),
  'donut': PieChart.of(
    [420, 310, 96, 51, 30, 12, 8, 5, 3],
    labels: const [
      'delivered',
      'paid',
      'canceled',
      'refunded',
      'open',
      'held',
      'lost',
      'test',
      'other',
    ],
    donut: true,
    maxSlices: 6,
    title: 'Orders by status',
    theme: theme,
  ),
  'heatmap': Heatmap(
    [
      for (var d = 0; d < 7; d++)
        [
          for (var h = 0; h < 12; h++)
            d == 2 && h == 5
                ? null
                : (10 +
                          40 * math.exp(-((h - 6) * (h - 6)) / 8) +
                          (d >= 5 ? 25 : 0))
                      .round(),
        ],
    ],
    rowLabels: const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
    columnLabels: [for (var h = 0; h < 12; h++) '${h + 10}h'],
    title: 'Orders by day and hour',
    theme: theme,
  ),
  'gauge': Gauge(72, label: 'CPU %', theme: theme),
  'meter': Meter(0.42, title: 'Disk used', width: 240, theme: theme),
  'sparkline': Sparkline(
    [4, 6, 5, 9, 7, 11, 10, 14, 12, 15],
    title: 'Signups',
    area: true,
    theme: theme,
  ),
  'stat_tile': StatTile.number(
    label: 'Orders today',
    value: 5894,
    delta: '+12% vs. yesterday',
    trend: Trend.good,
    trendValues: const [40, 42, 39, 47, 52, 50, 58],
    width: 220,
    theme: theme,
  ),
};

/// A 32-bit FNV-1a hash of [text], the same on the VM and on the web (no
/// arithmetic past 2^53, which JS numbers can't hold exactly): the parity
/// test compares the gallery's output across platforms with it.
int fingerprint(String text) {
  var h = 0x811c9dc5;
  for (final c in text.codeUnits) {
    h ^= c;
    // h * 16777619 mod 2^32, as h*403 + (h mod 256) * 2^24 (16777619 is
    // 2^24 + 403, and 2^24 * h mod 2^32 only depends on h mod 256).
    h = (h * 403 + (h % 256) * 16777216) % 4294967296;
  }
  return h;
}

/// A deterministic, roughly normal value for [i] (no Random: the gallery's
/// output must not change between runs).
double _gauss(int i) {
  var s = 0.0;
  for (var k = 1; k <= 6; k++) {
    s += math.sin(i * 12.9898 * k + k * 78.233) * 43758.5453 % 1;
  }
  return s / 3 - 1;
}
