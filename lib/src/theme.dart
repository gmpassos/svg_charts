/// Colours, type and the embedded style sheet of the charts.
library;

import 'svg_writer.dart' show svgNum;

/// The colours of one colour scheme (light or dark).
///
/// The defaults ([SvgPalette.light], [SvgPalette.dark]) are a validated
/// data-visualisation palette: eight categorical hues ordered so adjacent
/// series stay distinct under the common colour-vision deficiencies, each
/// stepped separately for the light and the dark surface (not an automatic
/// inversion), a one-hue sequential ramp for magnitudes, and recessive
/// chrome (grid, axis, ticks).
class SvgPalette {
  /// A palette. [series] needs at least one colour; [sequential] runs from
  /// "near nothing" to "most".
  const SvgPalette({
    required this.series,
    required this.sequential,
    required this.surface,
    required this.text,
    required this.textSecondary,
    required this.muted,
    required this.grid,
    required this.axis,
    required this.negative,
    required this.good,
    required this.bad,
  });

  /// Categorical colours, assigned to series in this order. A chart with
  /// more series than colours reuses them from the start; past eight
  /// series, fold the smallest into an "Other" series instead.
  final List<String> series;

  /// The sequential ramp for heatmaps, from the lowest value to the
  /// highest.
  final List<String> sequential;

  /// The chart's background (drawn only with [SvgChartTheme.background]),
  /// and the ring around points and between slices.
  final String surface;

  /// Primary text: titles, values.
  final String text;

  /// Secondary text: category labels, legend names.
  final String textSecondary;

  /// Muted text: axis ticks.
  final String muted;

  /// Grid lines.
  final String grid;

  /// The baseline and axes, and the tracks of meters and gauges.
  final String axis;

  /// Marks of negative values.
  final String negative;

  /// A change for the better (a stat tile's delta, always with ▲ or ▼).
  final String good;

  /// A change for the worse.
  final String bad;

  /// The light scheme.
  static const light = SvgPalette(
    series: [
      '#2a78d6', // blue
      '#eb6834', // orange
      '#1baf7a', // aqua
      '#eda100', // yellow
      '#e87ba4', // magenta
      '#008300', // green
      '#6250d6', // violet
      '#e34948', // red
    ],
    sequential: [
      '#cde2fb',
      '#9ec5f4',
      '#6da7ec',
      '#3987e5',
      '#256abf',
      '#184f95',
      '#0d366b',
    ],
    surface: '#fcfcfb',
    text: '#0b0b0b',
    textSecondary: '#52514e',
    muted: '#898781',
    grid: '#e1e0d9',
    axis: '#c3c2b7',
    negative: '#e34948',
    good: '#006300',
    bad: '#d03b3b',
  );

  /// The dark scheme: the same hues stepped for a dark surface.
  static const dark = SvgPalette(
    series: [
      '#3987e5',
      '#d95926',
      '#199e70',
      '#c98500',
      '#d55181',
      '#008300',
      '#9085e9',
      '#e66767',
    ],
    // Reversed: on a dark surface "near nothing" is the darkest step, so a
    // low value recedes toward the background as it does on light.
    sequential: [
      '#104281',
      '#184f95',
      '#256abf',
      '#2a78d6',
      '#5598e7',
      '#86b6ef',
      '#b7d3f6',
    ],
    surface: '#1a1a19',
    text: '#f0efec',
    textSecondary: '#c3c2b7',
    muted: '#898781',
    grid: '#2c2c2a',
    axis: '#383835',
    negative: '#e66767',
    good: '#0ca30c',
    bad: '#e66767',
  );

  /// The [i]th series colour (reused past the last).
  String seriesColor(int i) => series[i % series.length];
}

/// How charts look: colours, type, class names and whether the SVG carries
/// its own style sheet.
///
/// Charts are styled by classes (`svgc-bar`, `svgc-s1`, …) and an embedded
/// `<style>` whose rules read CSS custom properties with this theme's
/// colours as fallbacks (`fill: var(--svgc-series-1, #2a78d6)`). So:
///
/// - a standalone `.svg` file looks right on its own;
/// - a page can restyle every chart by setting the properties
///   (`--svgc-series-1`, `--svgc-text`, …) on any ancestor;
/// - with [darkPalette], the dark colours apply under
///   `prefers-color-scheme: dark`, or under a `data-theme="dark"` attribute
///   on the root element (and `data-theme="light"` keeps the light ones);
/// - with [embedStyle] off, only classes are written and the page's own
///   style sheet ([svgChartsCss]) styles them.
///
/// Marks also carry their colour as a presentation attribute, so renderers
/// with no CSS support still draw them in the light colours.
class SvgChartTheme {
  /// A theme.
  const SvgChartTheme({
    this.palette = SvgPalette.light,
    this.darkPalette = SvgPalette.dark,
    this.fontFamily = 'system-ui, -apple-system, "Segoe UI", sans-serif',
    this.fontSize = 12,
    this.prefix = 'svgc',
    this.embedStyle = true,
    this.background = false,
  });

  /// Light by default, dark when the viewer's system or page asks for it.
  static const auto = SvgChartTheme();

  /// Always light.
  static const light = SvgChartTheme(darkPalette: null);

  /// Always dark.
  static const dark = SvgChartTheme(
    palette: SvgPalette.dark,
    darkPalette: null,
    background: true,
  );

  /// The colours, and the fallbacks of the CSS custom properties.
  final SvgPalette palette;

  /// The colours under a dark colour scheme; `null` for one scheme only.
  final SvgPalette? darkPalette;

  /// The CSS font family of all text.
  final String fontFamily;

  /// The base font size in px; ticks and legends are a little smaller.
  final double fontSize;

  /// The prefix of class names and custom properties. Change it when two
  /// themes' style sheets share a page and must not mix.
  final String prefix;

  /// Whether each SVG embeds its `<style>`.
  final bool embedStyle;

  /// Whether to paint the surface colour behind the chart (off: the page's
  /// background shows through).
  final bool background;

  /// A copy with the given fields replaced. ([darkPalette] can't be cleared
  /// this way; use the constructor.)
  SvgChartTheme copyWith({
    SvgPalette? palette,
    SvgPalette? darkPalette,
    String? fontFamily,
    double? fontSize,
    String? prefix,
    bool? embedStyle,
    bool? background,
  }) => SvgChartTheme(
    palette: palette ?? this.palette,
    darkPalette: darkPalette ?? this.darkPalette,
    fontFamily: fontFamily ?? this.fontFamily,
    fontSize: fontSize ?? this.fontSize,
    prefix: prefix ?? this.prefix,
    embedStyle: embedStyle ?? this.embedStyle,
    background: background ?? this.background,
  );

  /// The class name for [name]: `svgc-name`.
  String cls(String name) => '$prefix-$name';

  /// The tick and legend font size.
  double get smallFontSize => fontSize - 1;
}

/// The style sheet of [theme]'s charts, as embedded in each SVG, for a page
/// that renders charts with `embedStyle: false` and includes it once.
String svgChartsCss([SvgChartTheme theme = SvgChartTheme.auto]) {
  final p = theme.prefix;
  final out = StringBuffer()
    // Shape rules: the same in every scheme.
    ..write(
      // Sizes through svgNum: a double prints `12.0` on the VM and `12` on
      // the web, and the output must be the same on both.
      '.$p-root{font-family:${theme.fontFamily};'
      'font-size:${svgNum(theme.fontSize)}px}'
      '.$p-root text{font-variant-numeric:tabular-nums}'
      '.$p-small{font-size:${svgNum(theme.smallFontSize)}px}'
      '.$p-strong{font-weight:600}'
      '.$p-root .$p-line{fill:none;stroke-width:2;stroke-linejoin:round;'
      'stroke-linecap:round}'
      '.$p-root .$p-area{stroke:none;fill-opacity:.16}'
      '.$p-root .$p-bar{stroke:none}'
      '.$p-hit,.$p-band{fill:transparent}'
      '.$p-cross{stroke-width:1;opacity:0}'
      '.$p-band:hover .$p-cross{opacity:1}'
      '.$p-mark:hover .$p-bar,.$p-mark:hover .$p-slice{opacity:.82}'
      '.$p-point:hover .$p-dot{stroke-width:3}'
      '.$p-grid{stroke-width:1}'
      '.$p-axis{stroke-width:1}'
      '.$p-root .$p-grid,.$p-root .$p-axis,.$p-root .$p-line,'
      '.$p-root .$p-area,.$p-root text{pointer-events:none}'
      '.$p-root [data-hint]{cursor:default}'
      // A chart whose marks are clickable (svg_charts_web's insertChart
      // with onMark) says so with the pointer.
      '.$p-clickable [data-index]{cursor:pointer}',
    )
    ..write(_colorVariables(theme, theme.palette, ''))
    ..write(_colorRules(theme));
  final dark = theme.darkPalette;
  if (dark != null) {
    // The media query follows the system; `data-theme` on the root element
    // (a page's theme switch) wins both ways. Only the variables change:
    // the rules read them.
    out
      ..write('@media (prefers-color-scheme:dark){')
      ..write(_colorVariables(theme, dark, ':root:not([data-theme="light"]) '))
      ..write('}')
      ..write(_colorVariables(theme, dark, ':root[data-theme="dark"] '));
  }
  return out.toString();
}

/// The public custom properties a page may set (`--svgc-text`, …), with
/// their [SvgPalette] colours. Each scheme maps them to the internal
/// `--svgc-c-…` properties the rules read, with its own colour as the
/// fallback; so a page's value wins in every scheme.
List<(String, String)> _paletteColors(SvgPalette palette) => [
  ('surface', palette.surface),
  ('text', palette.text),
  ('text-secondary', palette.textSecondary),
  ('muted', palette.muted),
  ('grid', palette.grid),
  ('axis', palette.axis),
  ('negative', palette.negative),
  ('good', palette.good),
  ('bad', palette.bad),
  for (final (i, hex) in palette.series.indexed) ('series-${i + 1}', hex),
  for (final (i, hex) in palette.sequential.indexed) ('seq-${i + 1}', hex),
];

/// [palette]'s internal colour properties on the chart root, under
/// [scope].
String _colorVariables(SvgChartTheme theme, SvgPalette palette, String scope) {
  final p = theme.prefix;
  final declarations = [
    for (final (name, hex) in _paletteColors(palette))
      '--$p-c-$name:var(--$p-$name,$hex)',
  ];
  return '$scope.$p-root{${declarations.join(';')}}';
}

/// The colour rules: every scheme's, as they read the internal properties.
String _colorRules(SvgChartTheme theme) {
  final p = theme.prefix;
  final out = StringBuffer();
  // A rule setting [prop] of class [cls] to colour [name].
  void rule(String cls, String prop, String name) =>
      out.write('.$p-root .$p-$cls{$prop:var(--$p-c-$name)}');
  rule('bg', 'fill', 'surface');
  rule('text', 'fill', 'text');
  rule('label', 'fill', 'text-secondary');
  rule('tick', 'fill', 'muted');
  rule('grid', 'stroke', 'grid');
  rule('axis', 'stroke', 'axis');
  rule('cross', 'stroke', 'muted');
  rule('track', 'fill', 'grid');
  rule('neg', 'fill', 'negative');
  rule('good', 'fill', 'good');
  rule('bad', 'fill', 'bad');
  rule('empty', 'fill', 'grid');
  // Rings between overlapping marks and slices: the surface colour.
  rule('dot', 'stroke', 'surface');
  rule('slice', 'stroke', 'surface');
  out.write('.$p-root .$p-band:hover{fill:var(--$p-c-grid);fill-opacity:.5}');
  for (var i = 1; i <= theme.palette.series.length; i++) {
    // A series colours fills; a line takes it as its stroke instead, and
    // keeps no fill.
    out.write(
      '.$p-root .$p-s$i:not(.$p-line){fill:var(--$p-c-series-$i)}'
      '.$p-root .$p-s$i.$p-line{stroke:var(--$p-c-series-$i)}',
    );
  }
  for (var i = 1; i <= theme.palette.sequential.length; i++) {
    rule('q$i', 'fill', 'seq-$i');
  }
  return out.toString();
}
