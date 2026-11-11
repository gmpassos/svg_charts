import 'package:svg_charts/svg_charts.dart';
import 'package:test/test.dart';

import 'helpers.dart';

/// Lines and areas: series, gaps, bands with every value, points, smooth
/// curves, the axis.
void main() {
  const two = [
    Series([3, 5, 4], name: 'paid'),
    Series([1, null, 2], name: 'open'),
  ];

  test('a line per series, colours in order, a legend', () {
    final root = parseSvg(
      LineChart(two, labels: const ['a', 'b', 'c']).render(),
    );
    final lines = byClass(root, 'line');
    // "open" has a gap: two runs of one point each — no line, two dots.
    expect(lines, hasLength(1));
    expect(lines.single.getAttribute('class'), 'svgc-line svgc-s1');
    expect(lines.single.getAttribute('fill'), 'none');
    expect(textsOf(byClass(root, 'legend').single), ['paid', 'open']);
  });

  test('bands: one per x, every series in the hint, a crosshair', () {
    final root = parseSvg(
      LineChart(two, labels: const ['a', 'b', 'c']).render(),
    );
    final bands = byClass(root, 'band');
    expect(bands, hasLength(3));
    expect(hintsOf(root, 'band'), [
      'a\npaid: 3\nopen: 1',
      'b\npaid: 5\nopen: —',
      'c\npaid: 4\nopen: 2',
    ]);
    expect(byClass(root, 'cross'), hasLength(3));
    expect(bands.first.getAttribute('data-index'), '0');
  });

  test('points: their own series, not named twice', () {
    final root = parseSvg(
      LineChart(two, labels: const ['a', 'b', 'c']).render(),
    );
    final points = byClass(root, 'point');
    expect(points, hasLength(5));
    expect(points.first.getAttribute('data-hint'), 'a\npaid: 3');
    expect(points.first.getAttribute('aria-label'), isNull);
    expect(points.last.getAttribute('data-series'), '1');
  });

  test('a gap breaks the line', () {
    final root = parseSvg(
      LineChart.of([1, 2, null, 4, 5], points: false).render(),
    );
    expect(byClass(root, 'line'), hasLength(2));
    expect(byClass(root, 'point'), isEmpty);
  });

  test('an isolated value is a dot even without points', () {
    final root = parseSvg(
      LineChart.of([1, null, 3, null], points: false).render(),
    );
    expect(byClass(root, 'point'), hasLength(2));
  });

  test('points by default only up to 12 x positions', () {
    expect(
      byClass(parseSvg(LineChart.of(List.filled(12, 1)).render()), 'point'),
      hasLength(12),
    );
    expect(
      byClass(parseSvg(LineChart.of(List.filled(13, 1)).render()), 'point'),
      isEmpty,
    );
  });

  test('the axis fits the data without forcing zero; the area includes it', () {
    final line = parseSvg(LineChart.of([100, 110, 120]).render());
    final ticks = textsOf(byClass(line, 'ticks').single);
    expect(ticks, isNot(contains('0')));
    final area = parseSvg(AreaChart.of([100, 110, 120]).render());
    expect(textsOf(byClass(area, 'ticks').single), contains('0'));
    expect(byClass(area, 'area'), hasLength(1));
    expect(area.getAttribute('class'), contains('svgc-area-chart'));
    // yMin pins it.
    expect(
      textsOf(
        byClass(
          parseSvg(LineChart.of([100, 120], yMin: 0).render()),
          'ticks',
        ).single,
      ),
      contains('0'),
    );
  });

  test('smooth: cubic curves that stay within their points', () {
    final root = parseSvg(
      LineChart.of([0, 10, 0, 10], smooth: true, yMin: 0, yMax: 10).render(),
    );
    final d = byClass(root, 'line').single.getAttribute('d')!;
    expect(d, contains('C'));
    final b = pathBounds(d);
    final dots = byClass(root, 'dot');
    final ys = [for (final dot in dots) numAttr(dot, 'cy')];
    // Control points of a monotone curve never pass its extremes.
    expect(
      b.minY,
      greaterThanOrEqualTo(ys.reduce((a, c) => a < c ? a : c) - 0.01),
    );
    expect(
      b.maxY,
      lessThanOrEqualTo(ys.reduce((a, c) => a > c ? a : c) + 0.01),
    );
    // Two points: a straight segment.
    expect(
      byClass(
        parseSvg(LineChart.of([1, 2], smooth: true).render()),
        'line',
      ).single.getAttribute('d'),
      isNot(contains('C')),
    );
  });

  test('custom point hints; unnamed series are numbered in bands', () {
    final root = parseSvg(
      LineChart.of([5, 6], hint: (m) => ['p${m.index}', '${m.value}']).render(),
    );
    expect(hintsOf(root, 'point'), ['p0\n5', 'p1\n6']);
    final unnamed = parseSvg(
      const LineChart([
        Series([1]),
        Series([2]),
      ]).render(),
    );
    expect(hintsOf(unnamed, 'band').single, '1\nseries 1: 1\nseries 2: 2');
  });

  test('a single x and no data', () {
    final one = parseSvg(LineChart.of([7]).render());
    expect(byClass(one, 'point'), hasLength(1));
    expect(byClass(parseSvg(const LineChart([]).render()), 'band'), isEmpty);
    expect(AreaChart.of(const [], title: 'x').toString(), contains('<svg'));
  });

  test('AreaChart passes its options on', () {
    final root = parseSvg(
      const AreaChart(
        two,
        labels: ['a', 'b', 'c'],
        title: 'T',
        caption: 'c',
        xLabels: XLabels.none,
        legend: LegendPosition.none,
        grid: false,
      ).render(),
    );
    expect(byClass(root, 'legend'), isEmpty);
    expect(byClass(root, 'xlabels'), isEmpty);
    expect(byClass(root, 'grid'), isEmpty);
    expect(textsOf(root), containsAll(['T', 'c']));
  });
}
