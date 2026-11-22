import 'package:svg_charts/svg_charts.dart';
import 'package:test/test.dart';
import 'package:xml/xml.dart';

import 'helpers.dart';

/// ScaleBaseline: a value axis that includes zero, or one fitted to the
/// data; bars and areas start from the axis' end nearest zero either way.
void main() {
  /// The value axis' tick labels, bottom to top.
  List<num> ticksOf(XmlElement root) => [
    for (final t in textsOf(byClass(root, 'ticks').single))
      num.parse(t.replaceAll(',', '')),
  ];

  /// The plot's top and bottom: the extreme tick lines.
  ({double top, double bottom}) plotOf(XmlElement root) {
    final ys = [
      for (final l in byClass(root, 'ticks').single.findElements('line'))
        numAttr(l, 'y1'),
    ];
    return (
      top: ys.reduce((a, b) => a < b ? a : b),
      bottom: ys.reduce((a, b) => a > b ? a : b),
    );
  }

  /// Each column's top and bottom, in order.
  List<({double top, double bottom})> columnsOf(XmlElement root) => [
    for (final b in byClass(root, 'bar'))
      (
        top: pathBounds(b.getAttribute('d')!).minY,
        bottom: pathBounds(b.getAttribute('d')!).maxY,
      ),
  ];

  group('ColumnChart', () {
    test('zero by default: the axis starts at zero', () {
      final root = parseSvg(ColumnChart.of([100, 110, 120]).render());
      expect(ticksOf(root).first, 0);
      expect(
        ColumnChart.of([100, 110, 120]).render(),
        ColumnChart.of([100, 110, 120], baseline: ScaleBaseline.zero).render(),
      );
    });

    test('min: fitted, the lowest column still shows', () {
      final root = parseSvg(
        ColumnChart.of([100, 110, 120], baseline: ScaleBaseline.min).render(),
      );
      final ticks = ticksOf(root);
      expect(ticks.first, greaterThan(0));
      // Strictly below the lowest value, so its column has a height.
      expect(ticks.first, lessThan(100));
      expect(ticks.last, greaterThanOrEqualTo(120));
      final plot = plotOf(root);
      final cols = columnsOf(root);
      expect(cols, hasLength(3));
      // Every column stands on the plot's bottom, the axis' low end.
      for (final c in cols) {
        expect(c.bottom, closeTo(plot.bottom, 0.01));
      }
      final h = [for (final c in cols) c.bottom - c.top];
      expect(h[0], greaterThan(1));
      expect(h[0], lessThan(h[1]));
      expect(h[1], lessThan(h[2]));
      // Zero isn't a tick: the axis line is the plot's bottom.
      final axis = byClass(root, 'axis').single;
      expect(numAttr(axis, 'y1'), closeTo(plot.bottom, 0.01));
    });

    test('min, all negative: columns hang from the top, the axis there', () {
      final root = parseSvg(
        ColumnChart.of([
          -120,
          -110,
          -100,
        ], baseline: ScaleBaseline.min).render(),
      );
      final ticks = ticksOf(root);
      expect(ticks.last, lessThan(0));
      expect(ticks.last, greaterThan(-100));
      final plot = plotOf(root);
      final cols = columnsOf(root);
      for (final c in cols) {
        expect(c.top, closeTo(plot.top, 0.01));
        expect(c.bottom - c.top, greaterThan(1));
      }
      final axis = byClass(root, 'axis').single;
      expect(numAttr(axis, 'y1'), closeTo(plot.top, 0.01));
    });

    test('min, data crossing zero: the same as zero', () {
      expect(
        ColumnChart.of([-5, 10], baseline: ScaleBaseline.min).render(),
        ColumnChart.of([-5, 10]).render(),
      );
    });

    test('min, all equal: a widened axis, equal visible columns', () {
      final root = parseSvg(
        ColumnChart.of([50, 50, 50], baseline: ScaleBaseline.min).render(),
      );
      final ticks = ticksOf(root);
      expect(ticks.first, greaterThan(0));
      expect(ticks.first, lessThan(50));
      expect(ticks.last, greaterThan(50));
      final h = {for (final c in columnsOf(root)) c.bottom - c.top};
      expect(h, hasLength(1));
      expect(h.single, greaterThan(1));
    });

    test('min, stacked: fitted to the stacks, not pinned to zero', () {
      final root = parseSvg(
        ColumnChart(
          [
            Series([100, 110]),
            Series([20, 25]),
          ],
          mode: BarMode.stacked,
          baseline: ScaleBaseline.min,
        ).render(),
      );
      final ticks = ticksOf(root);
      expect(ticks.first, greaterThan(0));
      expect(ticks.first, lessThan(120));
      // The first series' segments lie wholly below the axis: not drawn.
      // The second's start below it, so they are cut at the axis line,
      // with no stacking gap left above it.
      final plot = plotOf(root);
      final cols = columnsOf(root);
      expect(cols, hasLength(2));
      for (final c in cols) {
        expect(c.bottom, closeTo(plot.bottom, 0.01));
        expect(c.bottom - c.top, greaterThan(1));
      }
    });

    test('an explicit yMin wins over the baseline', () {
      final root = parseSvg(
        ColumnChart.of(
          [100, 120],
          yMin: 50,
          baseline: ScaleBaseline.zero,
        ).render(),
      );
      // Rounded down to a tick, as any axis end is, but not to zero.
      final first = ticksOf(root).first;
      expect(first, greaterThan(0));
      expect(first, lessThanOrEqualTo(50));
    });
  });

  group('LineChart and AreaChart', () {
    test('a line fits by default; zero includes it', () {
      final fitted = parseSvg(LineChart.of([100, 110, 120]).render());
      expect(ticksOf(fitted).first, greaterThan(0));
      expect(
        LineChart.of([100, 110, 120]).render(),
        LineChart.of([100, 110, 120], baseline: ScaleBaseline.min).render(),
      );
      final zero = parseSvg(
        LineChart.of([100, 110, 120], baseline: ScaleBaseline.zero).render(),
      );
      expect(ticksOf(zero).first, 0);
      // All negative: zero is the top.
      final negative = parseSvg(
        LineChart(const [
          Series([-120, -100]),
        ], baseline: ScaleBaseline.zero).render(),
      );
      expect(ticksOf(negative).last, 0);
    });

    test('an area includes zero by default; min fits it', () {
      final zero = parseSvg(AreaChart.of([100, 110, 120]).render());
      expect(ticksOf(zero).first, 0);
      final fitted = parseSvg(
        AreaChart.of([100, 110, 120], baseline: ScaleBaseline.min).render(),
      );
      final ticks = ticksOf(fitted);
      expect(ticks.first, greaterThan(0));
      expect(ticks.first, lessThan(100));
      // Filled down to the plot's bottom, the axis' low end.
      final plot = plotOf(fitted);
      final area = pathBounds(
        byClass(fitted, 'area').single.getAttribute('d')!,
      );
      expect(area.maxY, closeTo(plot.bottom, 0.01));
      expect(
        numAttr(byClass(fitted, 'axis').single, 'y1'),
        closeTo(plot.bottom, 0.01),
      );
    });
  });

  group('ScatterChart', () {
    final data = [
      const XYSeries([XYPoint(100, 200), XYPoint(120, 260)]),
    ];

    List<num> xTicksOf(XmlElement root) => [
      for (final t in textsOf(byClass(root, 'xticks').single)) num.parse(t),
    ];

    test('both axes fit by default', () {
      final root = parseSvg(ScatterChart(data).render());
      expect(ticksOf(root).first, greaterThan(0));
      expect(xTicksOf(root).first, greaterThan(0));
    });

    test('each axis can include zero on its own', () {
      final y = parseSvg(
        ScatterChart(data, yBaseline: ScaleBaseline.zero).render(),
      );
      expect(ticksOf(y).first, 0);
      expect(xTicksOf(y).first, greaterThan(0));
      final x = parseSvg(
        ScatterChart(data, xBaseline: ScaleBaseline.zero).render(),
      );
      expect(xTicksOf(x).first, 0);
      expect(ticksOf(x).first, greaterThan(0));
    });
  });
}
