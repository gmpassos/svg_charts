import 'package:svg_charts/svg_charts.dart';
import 'package:test/test.dart';
import 'package:xml/xml.dart';

import 'helpers.dart';

/// Bugs found in review, each pinned where it was.
void main() {
  test('a gauge follows the dark scheme: classes, no inline colour', () {
    final root = parseSvg(const Gauge(72).render());
    final arc = byClass(root, 'gauge-arc').single;
    expect(arc.getAttribute('class'), contains('svgc-arc'));
    expect(arc.getAttribute('class'), contains('svgc-s1'));
    // An inline style would beat the dark scheme's rules.
    expect(arc.getAttribute('style'), isNull);
    final css = svgChartsCss();
    expect(
      css,
      contains(
        '.svgc-root .svgc-gauge-track{fill:none;'
        'stroke:var(--svgc-c-grid)}',
      ),
    );
    expect(css, contains('.svgc-root .svgc-s1.svgc-arc'));
    expect(css, contains('.svgc-s1:not(.svgc-line):not(.svgc-arc)'));
  });

  test('a standalone .svg file switches to dark: its root is :root', () {
    final css = svgChartsCss();
    expect(css, contains(':root.svgc-root:not([data-theme="light"])'));
    expect(css, contains(':root.svgc-root[data-theme="dark"]'));
    // Still inside a page too.
    expect(css, contains(':root:not([data-theme="light"]) .svgc-root'));
  });

  test('series of one name keep their own values in hints', () {
    final root = parseSvg(
      const LineChart(
        [
          Series([1, 2], name: 'A'),
          Series([10, 20], name: 'A'),
          Series([5, 6]),
          Series([7, 8], name: 'series 3'),
        ],
        labels: ['x', 'y'],
      ).render(),
    );
    expect(
      hintsOf(root, 'band').first,
      'x\nA: 1\nA (2): 10\nseries 3: 5\nseries 3 (2): 7',
    );
    final points = hintsOf(root, 'point');
    expect(points[0], 'x\nA: 1');
    expect(points[2], 'x\nA (2): 10');
  });

  test('small values never read "0" or "-0"', () {
    expect(formatNumber(0.0004), '0.0004');
    expect(formatNumber(-0.0004), '-0.0004');
    expect(formatNumber(0.000412345), '0.000412');
    expect(formatCompact(0.0002), '0.0002');
    expect(formatCompact(0.00025), '0.00025');
    expect(formatCompact(-0.0005), '-0.0005');
    final root = parseSvg(LineChart.of([0.0002, 0.0007, 0.001]).render());
    final ticks = textsOf(byClass(root, 'ticks').single);
    expect(ticks.toSet(), hasLength(ticks.length), reason: '$ticks');
    expect(ticks.where((t) => t == '0'), hasLength(lessThan(2)));
  });

  test('values past yMin / yMax stay inside the plot', () {
    final root = parseSvg(
      ColumnChart.of([5, 50], yMax: 10, title: 'T').render(),
    );
    final grid = [
      for (final l in byClass(byClass(root, 'ticks').single, 'grid'))
        numAttr(l, 'y1'),
      for (final l in byClass(byClass(root, 'ticks').single, 'axis'))
        numAttr(l, 'y1'),
    ];
    final plotTop = grid.reduce((a, b) => a < b ? a : b);
    final plotBottom = grid.reduce((a, b) => a > b ? a : b);
    for (final b in byClass(root, 'bar')) {
      final p = pathBounds(b.getAttribute('d')!);
      expect(p.minY, greaterThanOrEqualTo(plotTop - 0.01));
      expect(p.maxY, lessThanOrEqualTo(plotBottom + 0.01));
    }
    // The hint keeps the true value.
    expect(hintsOf(root)[1], '2\n50');

    // Stacked from a raised yMin: not below the axis.
    final stacked = parseSvg(
      ColumnChart(
        const [
          Series([5, 8], name: 'a'),
          Series([3, 2], name: 'b'),
        ],
        mode: BarMode.stacked,
        yMin: 4,
      ).render(),
    );
    final bottoms = [
      for (final l in stacked.findAllElements('line')) numAttr(l, 'y1'),
    ];
    final axisBottom = bottoms.reduce((a, b) => a > b ? a : b);
    for (final b in byClass(stacked, 'bar')) {
      expect(
        pathBounds(b.getAttribute('d')!).maxY,
        lessThanOrEqualTo(axisBottom + 0.01),
      );
    }

    // Lines too.
    final line = parseSvg(LineChart.of([1, 100, 2], yMax: 10).render());
    for (final d in byClass(line, 'dot')) {
      expect(numAttr(d, 'cy'), greaterThanOrEqualTo(0));
    }
  });

  test('a NaN gap does not switch shares off', () {
    expect(
      hintsOf(
        parseSvg(ColumnChart.of([1, double.nan, 3], shares: true).render()),
      ),
      ['1\n1 · 25% of the total', '3\n3 · 75% of the total'],
    );
    expect(
      hintsOf(
        parseSvg(BarChart.of([1, double.infinity, 3], shares: true).render()),
      ).first,
      '1\n1 · 25% of the total',
    );
  });

  test('ticks past 9.2e18 reach the top (no int overflow)', () {
    final ticks = niceTicks(0, 3e19);
    expect(ticks.length, lessThan(12));
    expect(ticks.last, greaterThanOrEqualTo(3e19));
  });

  test('a line band shades on hover: the rule targets its rect', () {
    final root = parseSvg(LineChart.of([1, 2]).render());
    final band = byClass(root, 'band').first;
    expect(band.getElement('rect')!.getAttribute('class'), 'svgc-band-bg');
    expect(svgChartsCss(), contains('.svgc-band:hover .svgc-band-bg{'));
  });

  test('heatmap headers are cut before they are thinned', () {
    final root = parseSvg(
      Heatmap(
        [List.filled(24, 1)],
        columnLabels: [
          for (var i = 0; i < 24; i++) i == 5 ? 'x' * 60 : '${i}h',
        ],
      ).render(),
    );
    final headers = [
      for (final t in root.findAllElements('text'))
        if (t.getAttribute('y') ==
            root.findAllElements('text').first.getAttribute('y'))
          t.innerText,
    ];
    expect(headers.length, greaterThan(3), reason: '$headers');
  });
}
