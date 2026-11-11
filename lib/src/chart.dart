/// The base of every chart: the `<svg>` root, marks with hints, text
/// measuring, the legend and the cartesian frame (axes, ticks, labels).
///
/// The public part is [SvgChart] and the option enums; the rest is shared
/// by the chart classes under `charts/`.
library;

import 'dart:math' as math;

import 'format.dart';
import 'hints.dart';
import 'scale.dart';
import 'svg_writer.dart';
import 'theme.dart';

/// A chart that renders to SVG markup.
///
/// Charts are immutable values: [render] returns the markup and has no
/// side effects, so a chart can be rendered on a server, in an isolate or
/// in a browser, and rendered again with the same result.
abstract interface class SvgChart {
  /// The chart as one `<svg>` element.
  String render();
}

/// Where a chart puts its legend.
enum LegendPosition {
  /// At the top for two or more series; none for one (its title names it).
  auto,

  /// Above the plot.
  top,

  /// Below the plot.
  bottom,

  /// No legend.
  none,
}

/// Which category labels a chart writes under its x axis.
enum XLabels {
  /// As many as fit without overlapping, always the first and the last.
  auto,

  /// The first, the middle and the last only.
  ends,

  /// None.
  none,
}

/// The width [text] takes at [fontSize], estimated (no font metrics
/// outside a browser): 0.6 em per character, a little less for narrow
/// ones. Used to lay out labels and keep them inside the chart.
double estimateTextWidth(String text, double fontSize) {
  var em = 0.0;
  for (final r in text.runes) {
    final c = String.fromCharCode(r);
    em += switch (c) {
      'i' || 'l' || 'j' || '.' || ',' || ':' || ';' || '|' || '!' || "'" => 0.3,
      ' ' || 'f' || 't' || 'r' || '(' || ')' || '-' => 0.4,
      'm' || 'w' || 'M' || 'W' => 0.85,
      _ when r > 0x2e80 => 1.0, // CJK and other wide characters
      _ => 0.6,
    };
  }
  return em * fontSize;
}

/// [text] cut with `…` to fit [maxWidth] at [fontSize] ([estimateTextWidth]).
/// The full text stays in the mark's hint.
String truncateText(String text, double maxWidth, double fontSize) {
  if (estimateTextWidth(text, fontSize) <= maxWidth) return text;
  final runes = text.runes.toList();
  for (var n = runes.length - 1; n > 0; n--) {
    final cut = '${String.fromCharCodes(runes.take(n)).trimRight()}…';
    if (estimateTextWidth(cut, fontSize) <= maxWidth) return cut;
  }
  return '…';
}

/// Writes the `<svg>` root of a [width]×[height] chart: the namespace and
/// view box, the accessible name ([title], [description]), the embedded
/// style sheet and the background. Close it with `w.close('svg')`.
///
/// With [responsive], the SVG takes its container's width and keeps its
/// aspect ratio; otherwise its size is fixed.
void openChart(
  SvgWriter w,
  SvgChartTheme theme, {
  required double width,
  required double height,
  String? title,
  String? description,
  bool responsive = false,
  String kind = '',
}) {
  final label = [
    if (title != null && title.isNotEmpty) title,
    if (description != null && description.isNotEmpty) description,
  ].join('. ');
  w.open('svg', {
    'xmlns': 'http://www.w3.org/2000/svg',
    'class': '${theme.cls('root')}${kind.isEmpty ? '' : ' ${theme.cls(kind)}'}',
    'width': responsive ? '100%' : width,
    'height': responsive ? null : height,
    'viewBox': '0 0 ${svgNum(width)} ${svgNum(height)}',
    // A group, not an image: an image's children are presentational, and
    // each mark is to be announced with its hint.
    'role': 'group',
    'aria-label': label.isEmpty ? null : label,
  });
  if (title != null && title.isNotEmpty) w.element('title', title);
  if (description != null && description.isNotEmpty) {
    w.element('desc', description);
  }
  if (theme.embedStyle) {
    w
      ..open('style')
      ..raw(svgChartsCss(theme))
      ..close('style');
  }
  if (theme.background) {
    w.empty('rect', {
      'class': theme.cls('bg'),
      'width': width,
      'height': height,
      'fill': theme.palette.surface,
    });
  }
}

/// Opens a mark's `<g>`: its classes, `data-index` / `data-series` (for
/// click handling), and its [hint] three ways: a `data-hint` attribute
/// (the web hint layer), a native `<title>` (a tooltip anywhere, a
/// standalone file included) and, when [named], an accessible name.
/// Close it with `w.close('g')`.
void openMark(
  SvgWriter w,
  SvgChartTheme theme,
  List<String> hint, {
  String cls = 'mark',
  int? index,
  int? series,
  bool named = true,
}) {
  w.open('g', {
    'class': theme.cls(cls),
    'data-index': index,
    'data-series': series,
    'data-hint': hintText(hint),
    'role': named ? 'img' : null,
    'aria-label': named ? hint.join(', ') : null,
  });
  w.element('title', hint.join('\n'));
}

/// The class of series [i]'s colour (`svgc-s1`…), reused past the
/// palette's last colour as [SvgPalette.seriesColor] is.
String seriesClass(SvgChartTheme theme, int i) =>
    theme.cls('s${i % theme.palette.series.length + 1}');

/// The legend's line height.
double legendRowHeight(SvgChartTheme theme) => theme.smallFontSize + 8;

/// The rows [names] take as legend entries across [width].
List<List<int>> legendRows(
  SvgChartTheme theme,
  List<String> names,
  double width,
) {
  final rows = <List<int>>[[]];
  var x = 0.0;
  for (var i = 0; i < names.length; i++) {
    final w = legendItemWidth(theme, names[i]);
    if (x > 0 && x + w > width) {
      rows.add([]);
      x = 0;
    }
    rows.last.add(i);
    x += w;
  }
  return rows;
}

/// One legend entry's width: swatch, gap, name, spacing.
double legendItemWidth(SvgChartTheme theme, String name) =>
    10 + 6 + estimateTextWidth(name, theme.smallFontSize) + 16;

/// Writes the legend for [names] (series colours in order) at ([x], [y]),
/// wrapping across [width]; returns the height it took.
double writeLegend(
  SvgWriter w,
  SvgChartTheme theme,
  List<String> names, {
  required double x,
  required double y,
  required double width,
}) {
  final rows = legendRows(theme, names, width);
  final rowH = legendRowHeight(theme);
  w.open('g', {'class': theme.cls('legend')});
  for (final (r, row) in rows.indexed) {
    var cx = x;
    final cy = y + r * rowH;
    for (final i in row) {
      w
        ..empty('rect', {
          'class': '${seriesClass(theme, i)} ${theme.cls('swatch')}',
          'x': cx,
          'y': cy + (rowH - 10) / 2,
          'width': 10,
          'height': 10,
          'rx': 2,
          'fill': theme.palette.seriesColor(i),
        })
        ..element('text', names[i], {
          'class': '${theme.cls('label')} ${theme.cls('small')}',
          'x': cx + 16,
          'y': cy + rowH / 2 + theme.smallFontSize * 0.35,
          'fill': theme.palette.textSecondary,
        });
      cx += legendItemWidth(theme, names[i]);
    }
  }
  w.close('g');
  return rows.length * rowH;
}

/// The plot area of a cartesian chart, in px.
class PlotArea {
  /// The area between [left], [top], [right] and [bottom].
  const PlotArea(this.left, this.top, this.right, this.bottom);

  /// The left edge.
  final double left;

  /// The top edge.
  final double top;

  /// The right edge.
  final double right;

  /// The bottom edge.
  final double bottom;

  /// The width.
  double get width => right - left;

  /// The height.
  double get height => bottom - top;
}

/// The frame of a chart with a value axis: what [writeFrame] laid out.
class Frame {
  /// A frame of [area] with the value [scale] and its [ticks].
  const Frame(this.area, this.scale, this.ticks);

  /// Where the data goes.
  final PlotArea area;

  /// Values to px along the value axis.
  final LinearScale scale;

  /// The value axis' ticks.
  final List<num> ticks;
}

/// The value domain for [values] with [baseline] included (bars start at
/// zero; lines need not).
({num min, num max}) valueDomain(
  Iterable<num?> values, {
  bool baseline = true,
  num? min,
  num? max,
}) {
  final e = dataExtent(values) ?? (min: 0, max: 1);
  var lo = min ?? e.min, hi = max ?? e.max;
  if (baseline) {
    if (min == null && lo > 0) lo = 0;
    if (max == null && hi < 0) hi = 0;
  }
  return (min: lo, max: hi);
}

/// Lays out and writes a cartesian chart's frame:
///
/// - the [title] (drawn, bold) and the legend (above or below);
/// - the value axis up the left: nice ticks over [domain], grid lines and
///   tick labels ([tickFormat]);
/// - room for the category labels under the plot ([categoryLabels]) and
///   the [caption].
///
/// The tick labels' width decides the left margin, so long numbers never
/// run off the edge. (Horizontal bars, labelled directly, lay themselves
/// out: [BarChart] has no value axis.)
Frame writeFrame(
  SvgWriter w,
  SvgChartTheme theme, {
  required double width,
  required double height,
  required ({num min, num max}) domain,
  String? title,
  List<String> legend = const [],
  LegendPosition legendPosition = LegendPosition.auto,
  bool categoryLabels = true,
  NumberFormatter tickFormat = formatCompact,
  bool grid = true,
  String? caption,
}) {
  final small = theme.smallFontSize;
  var top = 8.0;
  if (title != null && title.isNotEmpty) {
    w.element('text', truncateText(title, width - 16, theme.fontSize + 1), {
      'class': '${theme.cls('text')} ${theme.cls('strong')}',
      'x': 8,
      'y': top + theme.fontSize,
      'fill': theme.palette.text,
    });
    top += theme.fontSize + 14;
  }
  final position = switch (legendPosition) {
    LegendPosition.auto =>
      legend.length >= 2 ? LegendPosition.top : LegendPosition.none,
    final p => legend.isEmpty ? LegendPosition.none : p,
  };
  final legendHeight = position == LegendPosition.none
      ? 0.0
      : legendRows(theme, legend, width - 16).length * legendRowHeight(theme);
  if (position == LegendPosition.top) {
    writeLegend(w, theme, legend, x: 8, y: top, width: width - 16);
    top += legendHeight + 6;
  }
  var bottom = height - 6;
  double? legendY;
  if (position == LegendPosition.bottom) {
    bottom -= legendHeight + 4;
    legendY = bottom + 4;
  }
  if (caption != null && caption.isNotEmpty) bottom -= small + 6;
  final captionY = bottom + small + 6;
  if (categoryLabels) bottom -= small + 8;
  // About one tick per 32 px of height.
  final ticks = niceTicks(
    domain.min,
    domain.max,
    maxTicks: math.max(2, (bottom - top) ~/ 32),
  );
  final tickTexts = [for (final t in ticks) tickFormat(t)];
  final tickWidth = tickTexts.fold<double>(
    0,
    (m, t) => math.max(m, estimateTextWidth(t, small)),
  );
  final area = PlotArea(8 + tickWidth + 6, top, width - 8, bottom);
  final scale = LinearScale(ticks.first, ticks.last, area.bottom, area.top);
  w.open('g', {'class': theme.cls('ticks')});
  for (final (i, t) in ticks.indexed) {
    final y = scale(t);
    final zero = t == 0;
    if (grid || zero) {
      w.empty('line', {
        'class': theme.cls(zero ? 'axis' : 'grid'),
        'x1': area.left,
        'y1': y,
        'x2': area.right,
        'y2': y,
        'stroke': zero ? theme.palette.axis : theme.palette.grid,
      });
    }
    w.element('text', tickTexts[i], {
      'class': '${theme.cls('tick')} ${theme.cls('small')}',
      'x': area.left - 6,
      'y': y + small * 0.35,
      'text-anchor': 'end',
      'fill': theme.palette.muted,
    });
  }
  // The baseline when zero isn't a tick (a domain above or below it).
  if (!ticks.contains(0)) {
    w.empty('line', {
      'class': theme.cls('axis'),
      'x1': area.left,
      'y1': area.bottom,
      'x2': area.right,
      'y2': area.bottom,
      'stroke': theme.palette.axis,
    });
  }
  w.close('g');
  if (caption != null && caption.isNotEmpty) {
    w.element('text', truncateText(caption, width - 16, small), {
      'class': '${theme.cls('tick')} ${theme.cls('small')}',
      'x': 8,
      'y': captionY,
      'fill': theme.palette.muted,
    });
  }
  if (legendY != null) {
    writeLegend(w, theme, legend, x: 8, y: legendY, width: width - 16);
  }
  return Frame(area, scale, ticks);
}

/// The indexes of [labels] to write along an axis [area].width wide, one
/// per [centers] position, by [mode]: as many as fit with a gap, the first
/// and the last always.
List<int> visibleLabels(
  List<String> labels,
  double span,
  double fontSize,
  XLabels mode,
) {
  final n = labels.length;
  if (n == 0 || mode == XLabels.none) return const [];
  if (mode == XLabels.ends || n <= 2) {
    return {0, if (mode == XLabels.ends) n ~/ 2, n - 1}.toList()..sort();
  }
  final widest = labels.fold<double>(
    0,
    (m, l) => math.max(m, estimateTextWidth(l, fontSize)),
  );
  final slot = span / n;
  final step = math.max(1, ((widest + 12) / slot).ceil());
  final shown = [for (var i = 0; i < n; i += step) i];
  // The last label replaces the one before it when they'd collide.
  if (shown.last != n - 1) {
    if ((n - 1 - shown.last) * slot < widest + 12) shown.removeLast();
    shown.add(n - 1);
  }
  return shown;
}

/// Writes category [labels] at [centers] (the x of each category) under
/// [area]: those [visibleLabels] picks, each cut to a third of the plot and
/// kept inside it (the first and last ones otherwise run past the edges).
void writeXLabels(
  SvgWriter w,
  SvgChartTheme theme,
  List<String> labels,
  List<double> centers,
  PlotArea area,
  XLabels mode,
) {
  final small = theme.smallFontSize;
  // Cut first, then thinned by the cut widths: one long label must not
  // hide all the others.
  final texts = [
    for (final l in labels) truncateText(l, area.width / 3, small),
  ];
  final shown = visibleLabels(texts, area.width, small, mode);
  w.open('g', {'class': theme.cls('xlabels')});
  for (final i in shown) {
    final text = texts[i];
    final half = estimateTextWidth(text, small) / 2;
    final x = centers[i].clamp(
      area.left + half,
      math.max(area.left + half, area.right - half),
    );
    w.element('text', text, {
      'class': '${theme.cls('tick')} ${theme.cls('small')}',
      'x': x,
      'y': area.bottom + small + 4,
      'text-anchor': 'middle',
      'fill': theme.palette.muted,
    });
  }
  w.close('g');
}

/// A rectangle with the corners at one end rounded by [r] (the data end of
/// a bar: the baseline end stays square), as a path.
///
/// [end] is which end is rounded: `top`, `bottom`, `right` or `left`.
String roundedBarPath(
  double x,
  double y,
  double width,
  double height,
  double r,
  String end,
) {
  final rr = math.min(r, math.min(width, height) / 2);
  final x2 = x + width, y2 = y + height;
  if (rr <= 0 || width <= 0 || height <= 0) {
    return 'M${svgNum(x)} ${svgNum(y)}H${svgNum(x2)}V${svgNum(y2)}'
        'H${svgNum(x)}Z';
  }
  String p(double a, double b) => '${svgNum(a)} ${svgNum(b)}';
  return switch (end) {
    'top' =>
      'M${p(x, y2)}V${svgNum(y + rr)}Q${p(x, y)} ${p(x + rr, y)}'
          'H${svgNum(x2 - rr)}Q${p(x2, y)} ${p(x2, y + rr)}V${svgNum(y2)}Z',
    'bottom' =>
      'M${p(x, y)}H${svgNum(x2)}V${svgNum(y2 - rr)}Q${p(x2, y2)} '
          '${p(x2 - rr, y2)}H${svgNum(x + rr)}Q${p(x, y2)} ${p(x, y2 - rr)}Z',
    'right' =>
      'M${p(x, y)}H${svgNum(x2 - rr)}Q${p(x2, y)} ${p(x2, y + rr)}'
          'V${svgNum(y2 - rr)}Q${p(x2, y2)} ${p(x2 - rr, y2)}H${svgNum(x)}Z',
    _ =>
      'M${p(x2, y)}V${svgNum(y2)}H${svgNum(x + rr)}Q${p(x, y2)} '
          '${p(x, y2 - rr)}V${svgNum(y + rr)}Q${p(x, y)} ${p(x + rr, y)}Z',
  };
}
