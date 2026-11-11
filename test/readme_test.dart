import 'package:svg_charts/svg_charts.dart';
import 'package:test/test.dart';
import 'package:xml/xml.dart';

import 'helpers.dart';

/// The README states what charts say and do. Claims in documentation rot
/// silently: they stay plausible long after they stop being true. These pin
/// the README's samples (its images are pinned by gallery_test.dart).
void main() {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  test('the opening chart: the April hint', () {
    final root = parseSvg(
      ColumnChart.of(
        [42, 51, 38, 64, 72, 69, 80, 77, 61, 58, 66, 90],
        name: 'orders',
        labels: months,
        title: 'Orders per month',
        shares: true,
      ).render(),
    );
    expect(hintsOf(root)[3], 'Apr\norders: 64 · 8% of the total');
  });

  test('the ranked bars: the delivered hint, the muted row', () {
    final root = parseSvg(
      BarChart.of(
        [4210, 3120, 960, 480, 120],
        name: 'orders',
        labels: ['delivered', 'paid', 'canceled', 'refunded', '(no value)'],
        mutedLabels: {4},
        sorted: true,
        shares: true,
      ).render(),
    );
    expect(hintsOf(root).first, 'delivered\norders: 4,210 · 47% of the total');
    final muted = root
        .findAllElements('text')
        .firstWhere((t) => t.innerText == '(no value)');
    expect(muted.getAttribute('class'), contains('svgc-tick'));
  });

  test('a gap is not a zero: two runs', () {
    final root = parseSvg(
      LineChart.of([5, 6, null, 7, 6], points: false).render(),
    );
    expect(byClass(root, 'line'), hasLength(2));
  });

  test('a meter never says 0% for a non-zero rate', () {
    expect(textsOf(parseSvg(const Meter(0.004).render())), ['<1%']);
    expect(textsOf(parseSvg(const Meter(0.42, title: 'Disk used').render())), [
      '42%',
    ]);
  });

  test('the stat tile carries its arrow', () {
    final root = parseSvg(
      StatTile.number(
        label: 'Orders today',
        value: 5894,
        delta: '+12% vs. yesterday',
        trend: Trend.good,
        trendValues: const [40, 42, 39, 47, 52, 50, 58],
      ).render(),
    );
    expect(textsOf(root), contains('▲ +12% vs. yesterday'));
  });

  test('the theming custom properties exist', () {
    final css = svgChartsCss();
    for (final p in ['series-1', 'text', 'grid', 'surface']) {
      expect(css, contains('var(--svgc-$p,'));
    }
    expect(css, contains('data-theme="dark"'));
    expect(css, contains('data-theme="light"'));
  });

  test('labels are escaped', () {
    final svg = ColumnChart.of([1], labels: ['<b>R&D</b>']).render();
    expect(svg, contains('&lt;b&gt;R&amp;D&lt;/b&gt;'));
    expect(svg, isNot(contains('<b>')));
  });
}
