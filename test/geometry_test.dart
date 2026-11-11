import 'package:svg_charts/svg_charts.dart';
import 'package:test/test.dart';
import 'package:xml/xml.dart';

import 'helpers.dart';

/// Every chart, over awkward data, stays inside its view box: no
/// coordinate off the canvas, none NaN, no negative size. A chart that
/// draws outside its box is clipped or overlaps its neighbours on a page,
/// and that goes unnoticed in a happy-path test.
void main() {
  /// Datasets that break naive layouts.
  final datasets = <String, List<num?>>{
    'all zeros': [0, 0, 0],
    'one value': [7],
    'all equal': [5, 5, 5, 5],
    'huge': [1e12, 3e12, 2.5e12],
    'tiny': [0.0001, 0.0003, 0.0002],
    'negative only': [-3, -8, -1],
    'mixed sign': [12, -40, 8, -2],
    'gaps': [null, 3, double.nan, 5, double.infinity, null],
    'all gaps': [null, double.nan],
    'many': [for (var i = 0; i < 200; i++) (i * 37) % 101 - 20],
    'empty': [],
  };

  /// Charts of [values] at [width]×[height].
  List<(String, SvgChart)> chartsOf(
    List<num?> values,
    double width,
    double height,
  ) {
    final labels = [for (var i = 0; i < values.length; i++) 'category $i'];
    final two = [
      Series(values, name: 'a'),
      Series([for (final v in values) v == null ? null : v / 2], name: 'b'),
    ];
    final finite = [
      for (final v in values)
        if (v != null && v.isFinite) v,
    ];
    return [
      (
        'column',
        ColumnChart.of(
          values,
          labels: labels,
          width: width,
          height: height,
          title: 'A title that is far too long for the chart',
        ),
      ),
      (
        'column grouped',
        ColumnChart(two, labels: labels, width: width, height: height),
      ),
      (
        'column stacked',
        ColumnChart(
          two,
          labels: labels,
          width: width,
          height: height,
          mode: BarMode.stacked,
        ),
      ),
      ('bar', BarChart.of(values, labels: labels, width: width)),
      (
        'bar stacked',
        BarChart(two, labels: labels, width: width, mode: BarMode.stacked),
      ),
      (
        'bar grouped',
        BarChart(two, labels: labels, width: width, height: height),
      ),
      (
        'line',
        LineChart(
          two,
          labels: labels,
          width: width,
          height: height,
          smooth: true,
        ),
      ),
      (
        'area',
        AreaChart.of(values, labels: labels, width: width, height: height),
      ),
      ('histogram', Histogram(values, width: width, height: height)),
      (
        'scatter',
        ScatterChart(
          [
            XYSeries([for (final (i, v) in finite.indexed) XYPoint(i * v, v)]),
          ],
          width: width,
          height: height,
        ),
      ),
      (
        'pie',
        PieChart.of(
          finite,
          labels: labels,
          width: width,
          height: height,
          donut: true,
        ),
      ),
      ('sparkline', Sparkline(values, width: width / 4, height: 24)),
      (
        'heatmap',
        Heatmap(
          [values, values.reversed.toList()],
          rowLabels: const ['r1', 'r2'],
          columnLabels: labels,
          width: width,
        ),
      ),
      (
        'gauge',
        Gauge(
          finite.isEmpty ? 0 : finite.first,
          width: width / 2,
          height: height / 2,
        ),
      ),
      (
        'meter',
        Meter(finite.isEmpty ? 0 : finite.first / 10, width: width / 2),
      ),
    ];
  }

  /// The coordinates of [e]'s geometry attributes, and its path's.
  Iterable<(String, double)> coordinates(XmlElement e) sync* {
    for (final a in ['x', 'y', 'cx', 'cy', 'x1', 'y1', 'x2', 'y2']) {
      final v = e.getAttribute(a);
      if (v != null) yield (a, double.parse(v));
    }
    for (final a in ['width', 'height', 'r']) {
      final v = e.getAttribute(a);
      if (v != null && v != '100%') yield (a, double.parse(v));
    }
    final d = e.getAttribute('d');
    if (d != null) {
      for (final m in RegExp(r'-?\d+(?:\.\d+)?(?:e[+-]?\d+)?').allMatches(d)) {
        yield ('d', double.parse(m[0]!));
      }
    }
  }

  for (final size in [(480.0, 240.0), (160.0, 90.0)]) {
    for (final MapEntry(key: name, value: values) in datasets.entries) {
      test('$name at ${size.$1}×${size.$2}: inside the view box', () {
        for (final (kind, chart) in chartsOf(values, size.$1, size.$2)) {
          final root = parseSvg(chart.render());
          final box = root
              .getAttribute('viewBox')!
              .split(' ')
              .map(double.parse)
              .toList();
          final w = box[2], h = box[3];
          for (final e in root.descendantElements) {
            // A nested chart (a stat tile's sparkline) has its own box.
            if (e.name.local == 'svg') continue;
            for (final (attr, v) in coordinates(e)) {
              final where = '$kind: <${e.name.local} $attr=$v>';
              expect(v.isFinite, isTrue, reason: where);
              if (attr == 'd') {
                // Arc flags and radii are in a path too: bounded loosely.
                expect(v, inInclusiveRange(-1, w + h + 1), reason: where);
              } else if (attr == 'width' || attr == 'r') {
                expect(v, inInclusiveRange(0, w + 0.01), reason: where);
              } else if (attr == 'height') {
                expect(v, inInclusiveRange(0, h + 0.01), reason: where);
              } else if (attr.startsWith('x') || attr == 'cx') {
                expect(v, inInclusiveRange(-1, w + 1), reason: where);
              } else {
                expect(v, inInclusiveRange(-1, h + 1), reason: where);
              }
            }
          }
        }
      });
    }
  }

  test('a legend wraps to more rows in a narrow chart', () {
    final series = [
      for (var i = 0; i < 6; i++)
        Series([i + 1], name: 'a long series name $i'),
    ];
    final wide = parseSvg(ColumnChart(series, width: 1200).render());
    final narrow = parseSvg(ColumnChart(series, width: 240).render());
    double rows(XmlElement root) => byClass(
      root,
      'swatch',
    ).map((s) => numAttr(s, 'y')).toSet().length.toDouble();
    expect(rows(wide), 1);
    expect(rows(narrow), greaterThan(2));
    // Every swatch inside the narrow chart.
    for (final s in byClass(narrow, 'swatch')) {
      expect(numAttr(s, 'x') + 10, lessThanOrEqualTo(240));
    }
  });

  test('stacked bars with negatives: left of zero, end to end', () {
    final root = parseSvg(
      BarChart(
        const [
          Series([-4, 3], name: 'a'),
          Series([-2, -1], name: 'b'),
        ],
        labels: const ['x', 'y'],
        mode: BarMode.stacked,
      ).render(),
    );
    final bars = [
      for (final b in byClass(root, 'bar')) pathBounds(b.getAttribute('d')!),
    ];
    // Row x: a from zero to -4, b beyond it, 2 px apart.
    expect(bars[0].minX - bars[1].maxX, closeTo(2, 0.01));
    // Row x's total, written left of its bars.
    final total = root
        .findAllElements('text')
        .firstWhere((t) => t.innerText == '-6');
    expect(total.getAttribute('text-anchor'), 'end');
    expect(numAttr(total, 'x'), lessThan(bars[1].minX));
  });
}
