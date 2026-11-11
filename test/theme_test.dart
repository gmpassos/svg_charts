import 'package:svg_charts/svg_charts.dart';
import 'package:test/test.dart';

import 'helpers.dart';

/// Themes: the embedded style sheet, custom properties, dark mode, prefix.
void main() {
  const chart = [
    Series([1, 2, 3], name: 'a'),
    Series([3, 2, 1], name: 'b'),
  ];

  test('the style sheet reads custom properties with fallbacks', () {
    final css = svgChartsCss();
    expect(css, contains('--svgc-c-series-1:var(--svgc-series-1,#2a78d6)'));
    expect(css, contains('--svgc-c-text:var(--svgc-text,#0b0b0b)'));
    expect(css, contains('.svgc-root .svgc-s1:not(.svgc-line)'));
    expect(css, contains('fill:var(--svgc-c-series-1)'));
  });

  test('auto: dark colours under the media query and data-theme', () {
    final css = svgChartsCss(SvgChartTheme.auto);
    expect(css, contains('@media (prefers-color-scheme:dark)'));
    expect(css, contains(':root:not([data-theme="light"]) .svgc-root,'));
    expect(css, contains(':root[data-theme="dark"] .svgc-root,'));
    expect(css, contains('var(--svgc-series-1,#3987e5)'));
  });

  test('one scheme only: no dark rules', () {
    final css = svgChartsCss(SvgChartTheme.light);
    expect(css, isNot(contains('prefers-color-scheme')));
    expect(svgChartsCss(SvgChartTheme.dark), contains('#1a1a19'));
    expect(svgChartsCss(SvgChartTheme.dark), isNot(contains('#fcfcfb')));
  });

  test('sizes are written the same on every platform', () {
    // `12.0` on the VM, `12` on the web if interpolated as a double.
    final css = svgChartsCss();
    expect(css, contains('font-size:12px'));
    expect(css, contains('font-size:11px'));
    expect(
      svgChartsCss(const SvgChartTheme(fontSize: 13.5)),
      contains('font-size:13.5px'),
    );
  });

  test('embedStyle off: classes only; the page includes svgChartsCss', () {
    final on = LineChart(chart).render();
    final off = LineChart(
      chart,
      theme: SvgChartTheme.auto.copyWith(embedStyle: false),
    ).render();
    expect(on, contains('<style>'));
    expect(off, isNot(contains('<style>')));
    expect(off, contains('class="svgc-line svgc-s1"'));
    // Presentation attributes: colours for renderers without CSS.
    expect(off, contains('stroke="#2a78d6"'));
  });

  test('a prefix renames classes and properties', () {
    final svg = ColumnChart(
      chart,
      theme: const SvgChartTheme(prefix: 'my'),
    ).render();
    final root = parseSvg(svg);
    expect(root.getAttribute('class'), 'my-root my-column-chart');
    expect(byClass(root, 'bar', prefix: 'my'), hasLength(6));
    expect(svg, isNot(contains('svgc-')));
    expect(svg, contains('--my-c-series-1'));
  });

  test('background paints the surface', () {
    final root = parseSvg(
      ColumnChart(chart, theme: SvgChartTheme.dark).render(),
    );
    final bg = byClass(root, 'bg');
    expect(bg, hasLength(1));
    expect(bg.single.getAttribute('fill'), '#1a1a19');
    expect(byClass(parseSvg(ColumnChart(chart).render()), 'bg'), isEmpty);
  });

  test('copyWith keeps what it is not given', () {
    const t = SvgChartTheme(fontSize: 14, prefix: 'x');
    final c = t.copyWith(background: true);
    expect(c.fontSize, 14);
    expect(c.prefix, 'x');
    expect(c.background, isTrue);
    expect(c.darkPalette, same(SvgPalette.dark));
    expect(
      t
          .copyWith(
            palette: SvgPalette.dark,
            darkPalette: SvgPalette.light,
            fontFamily: 'serif',
            embedStyle: false,
          )
          .fontFamily,
      'serif',
    );
    expect(t.cls('bar'), 'x-bar');
    expect(t.smallFontSize, 13);
  });

  test('series colours are reused past the palette', () {
    expect(SvgPalette.light.seriesColor(0), '#2a78d6');
    expect(SvgPalette.light.seriesColor(8), '#2a78d6');
    expect(SvgPalette.light.series, hasLength(8));
    expect(SvgPalette.dark.series, hasLength(8));
    expect(SvgPalette.light.sequential, hasLength(7));
    final svg = ColumnChart([
      for (var i = 0; i < 9; i++) Series([i + 1], name: 's$i'),
    ]).render();
    final bars = byClass(parseSvg(svg), 'bar');
    expect(bars.last.getAttribute('class'), contains('svgc-s1'));
  });
}
