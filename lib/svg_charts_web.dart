/// The browser side of `svg_charts`: a styled hint tooltip for every chart
/// on the page, and charts inserted into the DOM with clickable marks.
///
/// ```dart
/// import 'package:svg_charts/svg_charts.dart';
/// import 'package:svg_charts/svg_charts_web.dart';
/// import 'package:web/web.dart' as web;
///
/// void main() {
///   installSVGChartHints();
///   insertSVGChart(
///     web.document.querySelector('#orders')!,
///     ColumnChart.of([12, 30, 18], labels: ['Jan', 'Feb', 'Mar']),
///     onMark: (index, series) => print('clicked $index'),
///   );
/// }
/// ```
///
/// Charts carry native `<title>` tooltips already; [installSVGChartHints]
/// replaces them with one styled tooltip that follows the pointer, shows on
/// a tap on touch screens, and never lags behind a scroll.
library;

import 'dart:js_interop';
import 'dart:math' as math;

import 'package:web/web.dart' as web;

import 'src/chart.dart' show SvgChart;
import 'src/hints.dart' show hintLines;
import 'src/theme.dart' show SvgChartTheme;

/// The tooltip's default styles for [prefix]: the inverse of the page's
/// colours (dark on light pages), from the theme's custom properties with
/// fallbacks. [installSVGChartHints] adds them to the page unless told not
/// to; a page with its own styles for `.svgc-hint` can leave them out.
String svgChartHintCss([String prefix = 'svgc']) {
  const light = SvgChartTheme.auto;
  final p = light.palette;
  return '.$prefix-hint{position:fixed;z-index:2147483000;pointer-events:none;'
      'display:none;max-width:min(320px,80vw);padding:6px 10px;'
      'border-radius:6px;background:var(--$prefix-text,${p.text});'
      'color:var(--$prefix-surface,${p.surface});'
      'box-shadow:0 6px 24px rgba(0,0,0,.25);font:13px/1.35 ${light.fontFamily};'
      'font-variant-numeric:tabular-nums}'
      '.$prefix-hint.$prefix-hint-on{display:block}'
      '.$prefix-hint-head{font-weight:600;overflow-wrap:anywhere}'
      '.$prefix-hint-line{opacity:.85}'
      '@media (prefers-color-scheme:dark){'
      ':root:not([data-theme="light"]) .$prefix-hint{'
      'background:var(--$prefix-text,${light.darkPalette!.text});'
      'color:var(--$prefix-surface,${light.darkPalette!.surface})}}'
      ':root[data-theme="dark"] .$prefix-hint{'
      'background:var(--$prefix-text,${light.darkPalette!.text});'
      'color:var(--$prefix-surface,${light.darkPalette!.surface})}';
}

/// The installed hint layers, by class prefix: one tooltip per prefix per
/// page, so calling [installSVGChartHints] again (from every component that
/// draws a chart, say) is harmless.
final Map<String, SVGChartHints> _hintsCache = {};

/// The hint layer of a page: one tooltip element shown over the chart mark
/// under the pointer.
///
/// Get it with [installSVGChartHints]; [remove] takes it out of the page.
class SVGChartHints {
  SVGChartHints._(this.prefix, this.tooltip, this._style);

  /// The class prefix of the charts it serves.
  final String prefix;

  /// The tooltip element.
  final web.HTMLDivElement tooltip;

  final web.HTMLStyleElement? _style;

  final List<({String type, JSFunction listener, bool capture})> _listeners =
      [];

  web.Element? _shown;

  /// The tooltip's size for the mark shown, resolved once per mark by
  /// [show]: measuring on every pointer move would force a layout each
  /// time, and the size only changes with the hint's text.
  ({int width, int height}) _tipSizeResolved = (width: 0, height: 0);

  /// The mark the tooltip shows, if any.
  web.Element? get shown => _shown;

  /// Whether the tooltip is showing.
  bool get visible => _shown != null;

  /// Hides the tooltip.
  void hide() {
    if (_shown == null) return;
    _shown = null;
    tooltip.classList.remove('$prefix-hint-on');
  }

  /// Shows [mark]'s hint beside the point ([x], [y]) (viewport px), kept
  /// inside the window.
  void show(web.Element mark, double x, double y) {
    if (!identical(_shown, mark)) {
      _shown = mark;
      // The native tooltip (the mark's <title>) would show beside this one
      // a second later: taken out (the mark keeps its aria-label and
      // data-hint, which say the same).
      mark.querySelector(':scope > title')?.remove();
      tooltip.textContent = '';
      final lines = hintLines(mark.getAttribute('data-hint') ?? '');
      for (final (i, line) in lines.indexed) {
        tooltip.append(
          web.HTMLDivElement()
            ..className = i == 0 ? '$prefix-hint-head' : '$prefix-hint-line'
            ..textContent = line,
        );
      }
      // Measured at the window's corner, where its width is its own (not
      // squeezed against the edge it was last shown near): once per mark.
      tooltip.style
        ..left = '0px'
        ..top = '0px';
      tooltip.classList.add('$prefix-hint-on');
      _tipSizeResolved = (
        width: tooltip.offsetWidth,
        height: tooltip.offsetHeight,
      );
    }
    final (:width, :height) = _tipSizeResolved;
    final vw = web.window.innerWidth, vh = web.window.innerHeight;
    var left = x + 14, top = y + 14;
    if (left + width > vw - 8) left = math.max(8, x - width - 14);
    if (top + height > vh - 8) top = math.max(8, y - height - 14);
    tooltip.style
      ..left = '${left.round()}px'
      ..top = '${top.round()}px';
  }

  /// The chart mark (an element with `data-hint` inside a chart of this
  /// prefix) that [e] happened on, or `null`.
  web.Element? _markOf(web.Event e) {
    final target = e.target;
    if (target == null || !target.isA<web.Element>()) return null;
    final mark = (target as web.Element).closest('[data-hint]');
    if (mark == null || mark.closest('.$prefix-root') == null) return null;
    return mark;
  }

  void _on(String type, JSFunction listener, {bool capture = false}) {
    web.document.addEventListener(type, listener, capture.toJS);
    _listeners.add((type: type, listener: listener, capture: capture));
  }

  void _install() {
    // The pointer's position is read as `e.x` / `e.y`, never `clientX` /
    // `clientY`: the same coordinates, but package:web types `clientX` as
    // `int` while a real mouse gives fractions on hi-DPI screens, and the
    // dev compiler throws on that cast (no hint would ever show).
    // `x` / `y` are typed `double`.
    _on(
      'pointermove',
      ((web.PointerEvent e) {
        if (e.pointerType == 'touch') return;
        final mark = _markOf(e);
        mark == null ? hide() : show(mark, e.x, e.y);
      }).toJS,
    );
    // Touch: a tap shows a mark's hint, a tap elsewhere hides it.
    _on(
      'pointerdown',
      ((web.PointerEvent e) {
        if (e.pointerType != 'touch') return;
        final mark = _markOf(e);
        mark == null ? hide() : show(mark, e.x, e.y);
      }).toJS,
    );
    // Leaving the window: no move comes to say the pointer left the mark.
    web.document.documentElement?.addEventListener('pointerleave', _leave);
    // Any scroll moves the mark from under the fixed tooltip; captured,
    // since a panel's scroll doesn't bubble.
    _on('scroll', ((web.Event _) => hide()).toJS, capture: true);
    // A click may redraw the chart (a drill-down): once the mark is gone,
    // its tooltip goes too, and the element isn't held on to.
    _on(
      'click',
      ((web.Event _) {
        web.window.setTimeout(
          (() {
            if (_shown != null && !_shown!.isConnected) hide();
          }).toJS,
          50.toJS,
        );
      }).toJS,
    );
  }

  late final JSFunction _leave = ((web.Event _) => hide()).toJS;

  /// Removes the tooltip, its styles and its listeners from the page.
  void remove() {
    hide();
    for (final l in _listeners) {
      web.document.removeEventListener(l.type, l.listener, l.capture.toJS);
    }
    _listeners.clear();
    web.document.documentElement?.removeEventListener('pointerleave', _leave);
    tooltip.remove();
    _style?.remove();
    _hintsCache.remove(prefix);
  }
}

/// Installs the page's chart hint layer for charts of [prefix] (the
/// theme's class prefix), once: later calls return the same one.
///
/// With [injectStyle], the tooltip's default styles ([svgChartHintCss]) are
/// added to the document's head.
SVGChartHints installSVGChartHints({
  String prefix = 'svgc',
  bool injectStyle = true,
}) {
  final installed = _hintsCache[prefix];
  if (installed != null) return installed;
  final tip = web.HTMLDivElement()
    ..className = '$prefix-hint'
    ..setAttribute('role', 'tooltip')
    // The marks are named for screen readers already; the tooltip repeats.
    ..setAttribute('aria-hidden', 'true');
  web.HTMLStyleElement? style;
  if (injectStyle) {
    style = web.HTMLStyleElement()..textContent = svgChartHintCss(prefix);
    web.document.head?.append(style);
  }
  // Before <body> is parsed (a script in <head>), into the root element:
  // a fixed element shows from there too, and the layer is cached, so it
  // must be in the page from the first call.
  (web.document.body ?? web.document.documentElement)?.append(tip);
  final hints = SVGChartHints._(prefix, tip, style).._install();
  return _hintsCache[prefix] = hints;
}

/// Puts [chart] into [host] (replacing its content) and returns the new
/// `<svg>` element.
///
/// With [onMark], a click on a mark calls it with the mark's `data-index`
/// (the category, x position or slice) and `data-series` (`null` when the
/// mark has none, as a line chart's band); the chart's marks then show a
/// pointer. With [hints] (the default), the hint layer is installed.
web.Element? insertSVGChart(
  web.Element host,
  SvgChart chart, {
  void Function(int index, int? series)? onMark,
  bool hints = true,
  String prefix = 'svgc',
}) {
  if (hints) installSVGChartHints(prefix: prefix);
  host.innerHTML = chart.render().toJS;
  final svg = host.querySelector('svg');
  if (svg == null || onMark == null) return svg;
  svg.classList.add('$prefix-clickable');
  svg.addEventListener(
    'click',
    ((web.Event e) {
      final target = e.target;
      if (target == null || !target.isA<web.Element>()) return;
      final mark = (target as web.Element).closest('[data-index]');
      final index = int.tryParse(mark?.getAttribute('data-index') ?? '');
      if (index == null) return;
      onMark(index, int.tryParse(mark?.getAttribute('data-series') ?? ''));
    }).toJS,
  );
  return svg;
}
