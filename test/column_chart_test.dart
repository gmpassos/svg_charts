import 'package:svg_charts/svg_charts.dart';
import 'package:test/test.dart';
import 'package:xml/xml.dart';

import 'helpers.dart';

/// Columns: geometry to scale, grouped and stacked series, negatives, gaps,
/// hints and labels.
void main() {
  // A bar's top and bottom from its path.
  ({double top, double bottom, double left, double right}) box(XmlElement b) {
    final p = pathBounds(b.getAttribute('d')!);
    return (top: p.minY, bottom: p.maxY, left: p.minX, right: p.maxX);
  }

  test('a column per value, heights to scale, one baseline', () {
    final root = parseSvg(
      ColumnChart.of([10, 20, 40], labels: ['a', 'b', 'c']).render(),
    );
    final bars = byClass(root, 'bar');
    expect(bars, hasLength(3));
    final boxes = bars.map(box).toList();
    // One baseline.
    expect(boxes.map((b) => b.bottom).toSet(), hasLength(1));
    final h = [for (final b in boxes) b.bottom - b.top];
    expect(h[1] / h[0], closeTo(2, 0.02));
    expect(h[2] / h[0], closeTo(4, 0.05));
    // Left to right, in order.
    expect(boxes[0].left, lessThan(boxes[1].left));
    expect(root.getAttribute('viewBox'), '0 0 480 240');
    expect(root.getAttribute('role'), 'group');
  });

  test('hints: label, series, value, share; native title; data-index', () {
    final root = parseSvg(
      ColumnChart.of(
        [25, 75],
        name: 'orders',
        labels: ['open', 'paid'],
        shares: true,
      ).render(),
    );
    final marks = byClass(root, 'mark');
    expect(hintsOf(root), [
      'open\norders: 25 · 25% of the total',
      'paid\norders: 75 · 75% of the total',
    ]);
    expect(marks[1].getAttribute('data-index'), '1');
    expect(marks[1].getAttribute('data-series'), '0');
    expect(marks[1].getAttribute('role'), 'img');
    expect(
      marks[1].getAttribute('aria-label'),
      'paid, orders: 75 · 75% of the total',
    );
    expect(
      marks[1].getElement('title')!.innerText,
      'paid\norders: 75 · 75% of the total',
    );
    // Each mark has a full-height hit target.
    expect(byClass(root, 'hit'), hasLength(2));
  });

  test('no shares unless asked, nor with a negative value', () {
    expect(
      hintsOf(parseSvg(ColumnChart.of([25, 75]).render())).first,
      isNot(contains('%')),
    );
    expect(
      hintsOf(parseSvg(ColumnChart.of([25, -5], shares: true).render())).first,
      isNot(contains('%')),
    );
  });

  test('a custom hint', () {
    final root = parseSvg(
      ColumnChart.of([
        1,
        2,
      ], hint: (m) => ['#${m.index}', '${m.label}=${m.value}']).render(),
    );
    expect(hintsOf(root), ['#0\n1=1', '#1\n2=2']);
  });

  test('negatives hang below the baseline, in the negative colour', () {
    final root = parseSvg(ColumnChart.of([10, -10]).render());
    final bars = byClass(root, 'bar');
    final up = box(bars[0]), down = box(bars[1]);
    expect(up.bottom, closeTo(down.top, 0.01));
    expect(down.bottom - down.top, closeTo(up.bottom - up.top, 0.5));
    expect(bars[1].getAttribute('class'), contains('svgc-neg'));
    expect(bars[1].getAttribute('fill'), SvgPalette.light.negative);
    // Several series keep their colours below zero.
    final multi = parseSvg(
      ColumnChart(const [
        Series([-3], name: 'a'),
        Series([2], name: 'b'),
      ]).render(),
    );
    expect(
      byClass(multi, 'bar').first.getAttribute('class'),
      contains('svgc-s1'),
    );
  });

  test('gaps draw nothing; nulls are not zeros', () {
    final root = parseSvg(
      ColumnChart.of(
        [5, null, double.nan, 7],
        labels: ['a', 'b', 'c', 'd'],
      ).render(),
    );
    expect(byClass(root, 'mark'), hasLength(2));
    expect(
      [for (final m in byClass(root, 'mark')) m.getAttribute('data-index')],
      ['0', '3'],
    );
  });

  test('a zero value: its mark and hint, no visible column', () {
    final root = parseSvg(ColumnChart.of([0, 5]).render());
    expect(byClass(root, 'mark'), hasLength(2));
    expect(byClass(root, 'bar'), hasLength(1));
  });

  test('grouped: side by side, a legend, colours by series', () {
    final root = parseSvg(
      ColumnChart(
        const [
          Series([1, 2], name: 'web'),
          Series([3, 4], name: 'app'),
        ],
        labels: const ['Q1', 'Q2'],
      ).render(),
    );
    final bars = byClass(root, 'bar');
    expect(bars, hasLength(4));
    expect(bars[0].getAttribute('class'), contains('svgc-s1'));
    expect(bars[1].getAttribute('class'), contains('svgc-s2'));
    // Q1's web left of Q1's app, both left of Q2's.
    expect(box(bars[0]).right, lessThan(box(bars[1]).left));
    expect(box(bars[1]).right, lessThan(box(bars[2]).left));
    final legend = byClass(root, 'legend').single;
    expect(textsOf(legend), ['web', 'app']);
    expect(hintsOf(root)[1], 'Q1\napp: 3');
  });

  test('stacked: segments on each other, 2 px apart, shares per stack', () {
    final root = parseSvg(
      ColumnChart(
        const [
          Series([30, 10], name: 'a'),
          Series([10, 10], name: 'b'),
        ],
        labels: const ['x', 'y'],
        mode: BarMode.stacked,
        shares: true,
      ).render(),
    );
    final bars = byClass(root, 'bar');
    final a = box(bars[0]), b = box(bars[1]);
    expect(a.left, b.left);
    expect(a.top - b.bottom, closeTo(2, 0.01));
    // Proportions survive the gap: a is three times b.
    expect((a.bottom - a.top + 1) / (b.bottom - b.top + 1), closeTo(3, 0.1));
    expect(hintsOf(root)[0], 'x\na: 30 · 75% of the total');
    expect(hintsOf(root)[3], 'y\nb: 10 · 50% of the total');
  });

  test('stacked negatives go down from the baseline', () {
    final root = parseSvg(
      ColumnChart(const [
        Series([5, -5], name: 'a'),
        Series([-5, 5], name: 'b'),
      ], mode: BarMode.stacked).render(),
    );
    final boxes = byClass(root, 'bar').map(box).toList();
    // x: a up, b down; y: a down, b up — one baseline between them.
    expect(boxes[0].bottom, closeTo(boxes[1].top, 0.01));
    expect(boxes[3].bottom, closeTo(boxes[2].top, 0.01));
  });

  test('labels: escaped, kept inside the plot, thinned when crowded', () {
    final root = parseSvg(
      ColumnChart.of(
        [1, 2, 3],
        labels: ['<b>R&D</b>', 'b', 'a very long label that goes on and on'],
        width: 300,
      ).render(),
    );
    final texts = byClass(root, 'xlabels').single.findElements('text');
    expect(texts.first.innerText, '<b>R&D</b>');
    for (final t in texts) {
      expect(numAttr(t, 'x'), inInclusiveRange(0, 300));
    }
    expect(texts.last.innerText, endsWith('…'));
    // 60 labels in 480 px: not all of them, the first and last always.
    final crowded = parseSvg(
      ColumnChart.of(
        [for (var i = 0; i < 60; i++) i],
        labels: [for (var i = 0; i < 60; i++) '2026-10-${i + 1}'],
      ).render(),
    );
    final shown = byClass(crowded, 'xlabels').single.findElements('text');
    expect(shown.length, lessThan(15));
    expect(shown.first.innerText, '2026-10-1');
    expect(shown.last.innerText, '2026-10-60');
  });

  test('x labels: ends and none', () {
    final ends = parseSvg(
      ColumnChart.of(
        [1, 2, 3, 4, 5],
        labels: ['a', 'b', 'c', 'd', 'e'],
        xLabels: XLabels.ends,
      ).render(),
    );
    expect(textsOf(byClass(ends, 'xlabels').single), ['a', 'c', 'e']);
    final none = parseSvg(
      ColumnChart.of(
        [1, 2],
        labels: ['a', 'b'],
        xLabels: XLabels.none,
      ).render(),
    );
    expect(byClass(none, 'xlabels'), isEmpty);
  });

  test('unlabelled categories are numbered', () {
    expect(hintsOf(parseSvg(ColumnChart.of([4]).render())), ['1\n4']);
  });

  test('ticks: round, formatted, the axis fits them', () {
    final root = parseSvg(
      ColumnChart.of([1200, 4800], tickFormat: formatCompact).render(),
    );
    expect(textsOf(byClass(root, 'ticks').single), contains('5k'));
    final custom = parseSvg(
      ColumnChart.of([1, 2], yMax: 10, tickFormat: (v) => '\$$v').render(),
    );
    expect(textsOf(byClass(custom, 'ticks').single), contains('\$10'));
  });

  test('title, description, caption, responsive', () {
    final svg = ColumnChart.of(
      [1],
      title: 'Orders',
      description: 'per month',
      caption: 'source: db',
      responsive: true,
    ).render();
    final root = parseSvg(svg);
    expect(root.getAttribute('aria-label'), 'Orders. per month');
    expect(root.getElement('title')!.innerText, 'Orders');
    expect(root.getElement('desc')!.innerText, 'per month');
    expect(root.getAttribute('width'), '100%');
    expect(root.getAttribute('height'), isNull);
    expect(textsOf(root), containsAll(['Orders', 'source: db']));
  });

  test('empty data still renders a valid chart', () {
    final root = parseSvg(const ColumnChart([]).render());
    expect(byClass(root, 'mark'), isEmpty);
    expect(parseSvg(ColumnChart.of(const []).toString()), isNotNull);
    expect(
      byClass(parseSvg(ColumnChart.of([null, null]).render()), 'mark'),
      isEmpty,
    );
  });

  test('a bottom legend and none', () {
    const data = [
      Series([1], name: 'a'),
      Series([2], name: 'b'),
    ];
    final bottom = parseSvg(
      const ColumnChart(data, legend: LegendPosition.bottom).render(),
    );
    final legend = byClass(bottom, 'legend').single;
    final y = numAttr(legend.findElements('rect').first, 'y');
    expect(y, greaterThan(180));
    expect(
      byClass(
        parseSvg(const ColumnChart(data, legend: LegendPosition.none).render()),
        'legend',
      ),
      isEmpty,
    );
    // One series: no legend by default; a named one on request.
    expect(
      byClass(parseSvg(ColumnChart.of([1], name: 'a').render()), 'legend'),
      isEmpty,
    );
    expect(
      byClass(
        parseSvg(
          const ColumnChart([
            Series([1], name: 'a'),
          ], legend: LegendPosition.top).render(),
        ),
        'legend',
      ),
      hasLength(1),
    );
  });

  test('a histogram: touching bins, ranges, counts and shares', () {
    final root = parseSvg(
      Histogram([1, 2, 2, 3, 3, 3, 4, 4, 4, 4], bins: 4).render(),
    );
    expect(byClass(root, 'bar'), hasLength(4));
    final hints = hintsOf(root);
    expect(hints.first, '1–1.75\ncount: 1 · 10% of the total');
    expect(hints.last, '3.25–4\ncount: 4 · 40% of the total');
    expect(Histogram(const [], title: 'none').toString(), contains('none'));
  });
}
