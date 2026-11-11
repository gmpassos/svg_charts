import 'package:svg_charts/svg_charts.dart';
import 'package:test/test.dart';
import 'package:xml/xml.dart';

import 'helpers.dart';

/// Pies and donuts, scatter, sparklines, meters, gauges, heatmaps and stat
/// tiles.
void main() {
  group('PieChart', () {
    test('a slice per value, shares in hints and the legend', () {
      final root = parseSvg(
        PieChart.of([50, 30, 20], labels: ['a', 'b', 'c']).render(),
      );
      expect(byClass(root, 'slice'), hasLength(3));
      expect(hintsOf(root), [
        'a\n50 · 50% of the total',
        'b\n30 · 30% of the total',
        'c\n20 · 20% of the total',
      ]);
      expect(textsOf(byClass(root, 'legend').single), [
        'a 50%',
        'b 30%',
        'c 20%',
      ]);
    });

    test('zero, negative and non-finite slices are left out', () {
      final root = parseSvg(PieChart.of([5, 0, -3, double.nan, 5]).render());
      expect(byClass(root, 'slice'), hasLength(2));
      expect(
        [for (final m in byClass(root, 'mark')) m.getAttribute('data-index')],
        ['0', '4'],
      );
    });

    test('past maxSlices, the smallest fold into Other', () {
      final root = parseSvg(
        PieChart.of(
          [40, 1, 30, 2, 20, 3],
          labels: ['a', 'b', 'c', 'd', 'e', 'f'],
          maxSlices: 4,
        ).render(),
      );
      final heads = [for (final h in hintsOf(root)) h.split('\n').first];
      expect(heads, ['a', 'c', 'e', 'Other']);
      expect(hintsOf(root).last, 'Other\n6 · 6% of the total');
      // Other has no single index.
      expect(byClass(root, 'mark').last.getAttribute('data-index'), isNull);
    });

    test('a legend taller than the chart: what fits, then "+N more"', () {
      final root = parseSvg(
        PieChart.of([8, 7, 6, 5, 4, 3, 2, 1], height: 90).render(),
      );
      final legend = byClass(root, 'legend').single;
      final texts = textsOf(legend);
      expect(texts.last, matches(RegExp(r'^\+\d more$')));
      expect(texts.length, lessThan(8));
      // Every slice still drawn, with its hint.
      expect(byClass(root, 'slice'), hasLength(8));
      for (final t in legend.findElements('text')) {
        expect(numAttr(t, 'y'), inInclusiveRange(0, 90));
      }
    });

    test('one slice is a whole disc; a donut ring cuts its hole', () {
      final disc = parseSvg(PieChart.of([5]).render());
      final d = byClass(disc, 'slice').single.getAttribute('d')!;
      expect('A'.allMatches(d), hasLength(2));
      final ring = parseSvg(PieChart.of([5], donut: true).render());
      final rd = byClass(ring, 'slice').single;
      expect('A'.allMatches(rd.getAttribute('d')!), hasLength(4));
      expect(rd.getAttribute('fill-rule'), 'evenodd');
    });

    test('a donut writes its total, or a centre label', () {
      final root = parseSvg(
        PieChart.of([600, 400], donut: true, title: 'T').render(),
      );
      expect(textsOf(root), containsAll(['T', '1,000']));
      expect(root.getAttribute('class'), contains('svgc-donut-chart'));
      expect(
        textsOf(
          parseSvg(PieChart.of([1], donut: true, centerLabel: 'x').render()),
        ),
        contains('x'),
      );
    });

    test('a large slice takes the large arc; no legend on request; empty', () {
      final root = parseSvg(PieChart.of([80, 20], legend: false).render());
      expect(
        byClass(root, 'slice').first.getAttribute('d'),
        contains(' 0 1 1 '),
      );
      expect(byClass(root, 'legend'), isEmpty);
      expect(byClass(parseSvg(const PieChart([]).render()), 'slice'), isEmpty);
      const s = PieSlice('a', 1);
      expect(PieChart(const [s]).toString(), contains('a\n1'));
    });
  });

  group('ScatterChart', () {
    test('a dot per point, hints with x and y, a legend', () {
      final root = parseSvg(
        ScatterChart(
          const [
            XYSeries([XYPoint(1, 2, label: 'p'), XYPoint(3, 4)], name: 'A'),
            XYSeries([XYPoint(2, 3), XYPoint(double.nan, 1)], name: 'B'),
          ],
          xName: 'price',
          yName: 'sales',
        ).render(),
      );
      expect(byClass(root, 'dot'), hasLength(3));
      expect(hintsOf(root, 'point'), [
        'p\nA\nprice: 1\nsales: 2',
        'A\nprice: 3\nsales: 4',
        'B\nprice: 2\nsales: 3',
      ]);
      expect(textsOf(byClass(root, 'legend').single), ['A', 'B']);
      expect(byClass(root, 'xticks'), hasLength(1));
    });

    test('dots in place: larger x right, larger y up', () {
      final root = parseSvg(
        const ScatterChart([
          XYSeries([XYPoint(0, 0), XYPoint(10, 10)]),
        ]).render(),
      );
      final dots = byClass(root, 'dot');
      expect(numAttr(dots[1], 'cx'), greaterThan(numAttr(dots[0], 'cx')));
      expect(numAttr(dots[1], 'cy'), lessThan(numAttr(dots[0], 'cy')));
      expect(hintsOf(root, 'point').first, '1\nx: 0\ny: 0');
    });

    test('no points, no grid', () {
      final root = parseSvg(const ScatterChart([], grid: false).render());
      expect(byClass(root, 'grid'), isEmpty);
      expect(byClass(root, 'dot'), isEmpty);
    });
  });

  group('Sparkline', () {
    test('a line, the last value marked, a band per value', () {
      final root = parseSvg(
        const Sparkline([1, 3, 2], labels: ['a', 'b', 'c']).render(),
      );
      expect(byClass(root, 'line'), hasLength(1));
      expect(byClass(root, 'dot'), hasLength(1));
      expect(hintsOf(root, 'band'), ['a\n1', 'b\n3', 'c\n2']);
      expect(root.getElement('title')!.innerText, 'last 2, min 1, max 3');
    });

    test('titled: the summary is its description; gaps and dots', () {
      final root = parseSvg(
        const Sparkline([1, null, 4, 5], title: 'Signups', area: true).render(),
      );
      expect(root.getElement('desc')!.innerText, 'last 5, min 1, max 5');
      // The lone 1 is a dot; 4–5 a line with an area.
      expect(byClass(root, 'dot'), hasLength(2));
      expect(byClass(root, 'area'), hasLength(1));
      expect(hintsOf(root, 'band')[1], '2\n—');
    });

    test('no data; no hints; no last mark', () {
      final empty = parseSvg(const Sparkline([null]).render());
      expect(empty.getElement('title')!.innerText, 'no data');
      final bare = parseSvg(
        const Sparkline([1, 2], hints: false, markLast: false).render(),
      );
      expect(byClass(bare, 'band'), isEmpty);
      expect(byClass(bare, 'dot'), isEmpty);
      // One value: a dot (and the last-value mark over it), no line.
      final one = parseSvg(const Sparkline([3]).toString());
      expect(byClass(one, 'line'), isEmpty);
      expect(byClass(one, 'dot'), hasLength(2));
    });
  });

  group('Meter', () {
    test('a track, a fill to the rate, its text and exact hint', () {
      final root = parseSvg(const Meter(0.25, title: 'Disk').render());
      final fill = byClass(root, 'bar').single;
      final track = byClass(root, 'track').single;
      expect(
        numAttr(fill, 'width') / numAttr(track, 'width'),
        closeTo(0.25, 0.01),
      );
      expect(textsOf(root), contains('25%'));
      expect(hintsOf(root), ['25.0%\nDisk']);
    });

    test('clamped, a sliver for a small rate, none for zero', () {
      expect(textsOf(parseSvg(const Meter(0.001).render())), contains('<1%'));
      final small = byClass(
        parseSvg(const Meter(0.001).render()),
        'bar',
      ).single;
      expect(numAttr(small, 'width'), greaterThan(0));
      final zero = byClass(parseSvg(const Meter(0).render()), 'bar').single;
      expect(numAttr(zero, 'width'), 0);
      final over = parseSvg(const Meter(1.5).render());
      expect(
        numAttr(byClass(over, 'bar').single, 'width'),
        numAttr(byClass(over, 'track').single, 'width'),
      );
      expect(hintsOf(parseSvg(const Meter(double.nan).render())), ['NaN']);
      expect(textsOf(parseSvg(const Meter(0.5, text: 'half').render())), [
        'half',
      ]);
    });
  });

  group('Gauge', () {
    test('an arc to the value, the value and label written', () {
      final root = parseSvg(const Gauge(50, label: 'CPU %').render());
      expect(byClass(root, 'gauge-track'), hasLength(1));
      final arc = byClass(root, 'gauge-arc').single;
      // Half way: the arc ends at the top of the circle.
      final b = pathBounds(arc.getAttribute('d')!);
      final track = pathBounds(
        byClass(root, 'gauge-track').single.getAttribute('d')!,
      );
      expect(b.maxX, closeTo((track.minX + track.maxX) / 2, 0.5));
      expect(textsOf(root), ['50', 'CPU %']);
      expect(hintsOf(root), ['CPU %\n50 · 50% of 0–100']);
    });

    test('out of range is clamped; zero draws no arc; a flat range', () {
      expect(byClass(parseSvg(const Gauge(0).render()), 'gauge-arc'), isEmpty);
      expect(hintsOf(parseSvg(const Gauge(150).render())), [
        '150\n100% of 0–100',
      ]);
      expect(
        byClass(parseSvg(const Gauge(5, min: 5, max: 5).render()), 'gauge-arc'),
        isEmpty,
      );
      expect(const Gauge(1, title: 't').toString(), contains('aria-label="t"'));
    });
  });

  group('Heatmap', () {
    test('a cell per value on the ramp, empty for null', () {
      final root = parseSvg(
        const Heatmap(
          [
            [0, 5],
            [10, null],
          ],
          rowLabels: ['r1', 'r2'],
          columnLabels: ['c1', 'c2'],
        ).render(),
      );
      final cells = byClass(root, 'cell');
      expect(cells, hasLength(4));
      final rects = [for (final c in cells) c.getElement('rect')!];
      expect(rects[0].getAttribute('class'), 'svgc-q1');
      expect(rects[2].getAttribute('class'), 'svgc-q7');
      expect(rects[3].getAttribute('class'), 'svgc-empty');
      expect(hintsOf(root, 'cell'), [
        'r1 · c1\n0',
        'r1 · c2\n5',
        'r2 · c1\n10',
        'r2 · c2\nno value',
      ]);
      expect(cells[1].getAttribute('data-index'), '1');
      expect(cells[1].getAttribute('data-series'), '0');
      // The ramp's legend, low to high.
      expect(textsOf(byClass(root, 'legend').single), ['0', '10']);
    });

    test('ragged rows, no labels, a fixed height, one value', () {
      final root = parseSvg(
        const Heatmap(
          [
            [1],
            [1, 1, 1],
          ],
          height: 200,
          legend: false,
          title: 'H',
        ).render(),
      );
      expect(byClass(root, 'cell'), hasLength(6));
      expect(byClass(root, 'legend'), isEmpty);
      // One distinct value: the top step.
      expect(
        byClass(root, 'cell').first.getElement('rect')!.getAttribute('class'),
        'svgc-q7',
      );
      expect(Heatmap.stepOf(5, 0, 10, 7), 3);
      expect(Heatmap.stepOf(10, 0, 10, 7), 6);
      expect(const Heatmap([]).toString(), contains('<svg'));
    });
  });

  group('StatTile', () {
    test('label, value, delta with its arrow and colour', () {
      final root = parseSvg(
        StatTile.number(
          label: 'Orders',
          value: 5894,
          delta: '+12%',
          trend: Trend.good,
        ).render(),
      );
      expect(textsOf(root), ['Orders', '5,894', '▲ +12%']);
      expect(
        root.findAllElements('text').last.getAttribute('class'),
        contains('svgc-good'),
      );
      expect(hintsOf(root), ['Orders\n5,894 · +12%']);
    });

    test('down, bad, neutral; explicit direction', () {
      final bad = parseSvg(
        const StatTile(
          label: 'x',
          value: '1',
          delta: '-3',
          trend: Trend.bad,
        ).render(),
      );
      expect(textsOf(bad).last, '▼ -3');
      expect(
        bad.findAllElements('text').last.getAttribute('class'),
        contains('svgc-bad'),
      );
      final neutral = parseSvg(
        const StatTile(
          label: 'x',
          value: '1',
          delta: 'flat',
          up: false,
        ).render(),
      );
      expect(textsOf(neutral).last, '▼ flat');
      expect(
        neutral.findAllElements('text').last.getAttribute('class'),
        contains('svgc-tick'),
      );
    });

    test('a trend sparkline, nested and unstyled', () {
      final svg = const StatTile(
        label: 'x',
        value: '1',
        trendValues: [1, 2, 3],
      ).render();
      final root = parseSvg(svg);
      expect(root.findAllElements('svg'), hasLength(1));
      // One style sheet: the tile's.
      expect('<style>'.allMatches(svg), hasLength(1));
    });
  });

  test('every chart is a well-formed SVG with an accessible root', () {
    final charts = <SvgChart>[
      ColumnChart.of([1, 2]),
      BarChart.of([1, 2]),
      LineChart.of([1, 2]),
      AreaChart.of([1, 2]),
      Histogram([1, 2, 3]),
      PieChart.of([1, 2]),
      const ScatterChart([
        XYSeries([XYPoint(1, 1)]),
      ]),
      const Sparkline([1, 2]),
      const Meter(0.5),
      const Gauge(1),
      const Heatmap([
        [1],
      ]),
      const StatTile(label: 'a', value: 'b'),
    ];
    for (final c in charts) {
      final root = parseSvg(c.render());
      expect(root.getAttribute('xmlns'), 'http://www.w3.org/2000/svg');
      expect(root.getAttribute('role'), 'group');
      expect(c.toString(), c.render());
    }
  });
}
