import 'package:svg_charts/svg_charts.dart';
import 'package:test/test.dart';
import 'package:xml/xml.dart';

import 'helpers.dart';

/// Horizontal bars: rows, ranking, values at the ends, stacks, negatives.
void main() {
  ({double left, double right, double top}) box(XmlElement b) {
    final p = pathBounds(b.getAttribute('d')!);
    return (left: p.minX, right: p.maxX, top: p.minY);
  }

  test('a row per category: label, bar to scale, value at its end', () {
    final root = parseSvg(
      BarChart.of([100, 50], labels: ['delivered', 'paid']).render(),
    );
    final bars = byClass(root, 'bar').map(box).toList();
    expect(bars[0].left, bars[1].left);
    final w0 = bars[0].right - bars[0].left, w1 = bars[1].right - bars[1].left;
    expect(w0 / w1, closeTo(2, 0.03));
    expect(bars[0].top, lessThan(bars[1].top));
    final texts = textsOf(root);
    expect(texts, containsAll(['delivered', 'paid', '100', '50']));
    // Auto height: two rows.
    expect(numAttr(root, 'height'), lessThan(80));
  });

  test('sorted: largest first, ties in their order', () {
    final root = parseSvg(
      BarChart.of(
        [1, 3, 2, 3],
        labels: ['a', 'b', 'c', 'd'],
        sorted: true,
      ).render(),
    );
    expect(
      [for (final h in hintsOf(root)) h.split('\n').first],
      ['b', 'd', 'c', 'a'],
    );
    // data-index stays the category's own index.
    expect(byClass(root, 'mark').first.getAttribute('data-index'), '1');
  });

  test('muted labels, truncation, value format, no value labels', () {
    final root = parseSvg(
      BarChart.of(
        [1234.5, 2],
        labels: ['(no value)', 'x' * 80],
        mutedLabels: {0},
        valueFormat: (v) => '~${v.round()}',
        width: 300,
      ).render(),
    );
    final labels = root.findAllElements('text').toList();
    expect(labels.first.getAttribute('class'), contains('svgc-tick'));
    expect(labels.any((t) => t.innerText.endsWith('…')), isTrue);
    expect(textsOf(root), contains('~1235'));
    // The full label stays in the hint.
    expect(hintsOf(root)[1], startsWith('x' * 80));
    final plain = parseSvg(
      BarChart.of([1, 2], labels: ['a', 'b'], valueLabels: false).render(),
    );
    expect(textsOf(plain), ['a', 'b']);
  });

  test('negatives extend left of zero, with a zero line', () {
    final root = parseSvg(
      BarChart.of([10, -10], labels: ['up', 'down']).render(),
    );
    final bars = byClass(root, 'bar').map(box).toList();
    expect(bars[0].left, closeTo(bars[1].right, 0.01));
    expect(byClass(root, 'axis'), hasLength(1));
    expect(byClass(root, 'bar')[1].getAttribute('class'), contains('svgc-neg'));
    // The negative's value is written left of its bar.
    final value = root
        .findAllElements('text')
        .firstWhere((t) => t.innerText == '-10');
    expect(value.getAttribute('text-anchor'), 'end');
  });

  test('grouped: thinner bars per series, a value each, a legend', () {
    final root = parseSvg(
      BarChart(
        const [
          Series([3, 1], name: 'new'),
          Series([2, 4], name: 'old'),
        ],
        labels: const ['A', 'B'],
      ).render(),
    );
    expect(byClass(root, 'bar'), hasLength(4));
    expect(textsOf(byClass(root, 'legend').single), ['new', 'old']);
    expect(textsOf(root), containsAll(['3', '1', '2', '4']));
  });

  test('stacked: segments end to end, the total at the end, shares', () {
    final root = parseSvg(
      BarChart(
        const [
          Series([30, 9], name: 'new'),
          Series([10, 3], name: 'old'),
        ],
        labels: const ['A', 'B'],
        mode: BarMode.stacked,
        shares: true,
        legend: LegendPosition.bottom,
      ).render(),
    );
    final bars = byClass(root, 'bar').map(box).toList();
    expect(bars[1].left - bars[0].right, closeTo(2, 0.01));
    expect(textsOf(root), containsAll(['40', '12']));
    expect(hintsOf(root).first, 'A\nnew: 30 · 75% of the total');
    // The legend under the rows.
    final legendY = numAttr(
      byClass(root, 'legend').single.findElements('rect').first,
      'y',
    );
    expect(legendY, greaterThan(bars.last.top));
  });

  test('a fixed height spreads the rows; empty data renders', () {
    final root = parseSvg(
      BarChart.of([1, 2], labels: ['a', 'b'], height: 300, title: 'T').render(),
    );
    expect(root.getAttribute('height'), '300');
    expect(textsOf(root).first, 'T');
    expect(byClass(parseSvg(const BarChart([]).render()), 'mark'), isEmpty);
    expect(BarChart.of([null, 2]).toString(), contains('data-index="1"'));
  });

  test('shares of a single series', () {
    expect(
      hintsOf(parseSvg(BarChart.of([1, 3], name: 'n', shares: true).render())),
      ['1\nn: 1 · 25% of the total', '2\nn: 3 · 75% of the total'],
    );
  });
}
