@TestOn('browser')
library;

import 'dart:js_interop';

import 'package:svg_charts/svg_charts.dart';
import 'package:svg_charts/svg_charts_web.dart';
import 'package:test/test.dart';
import 'package:web/web.dart' as web;

/// The browser companion: the hint tooltip and clickable marks, in a real
/// page.
void main() {
  late web.HTMLDivElement host;

  setUp(() {
    host = web.HTMLDivElement();
    web.document.body!.append(host);
  });

  tearDown(() {
    host.remove();
    installSVGChartHints().remove();
  });

  /// A pointer event of [type] on [target] at fractional coordinates, as a
  /// real mouse gives on hi-DPI screens. (`PointerEventInit` takes ints,
  /// hence the plain JS object: read as `clientX`, typed `int`, these once
  /// threw in the dev compiler and no hint ever showed.)
  void pointer(
    web.Element target,
    String type, {
    String pointerType = 'mouse',
    double x = 20.37,
    double y = 30.61,
  }) => target.dispatchEvent(
    web.PointerEvent(
      type,
      {
            'bubbles': true,
            'pointerType': pointerType,
            'clientX': x,
            'clientY': y,
          }.jsify()
          as web.PointerEventInit,
    ),
  );

  web.HTMLDivElement tip() =>
      web.document.querySelector('.svgc-hint')! as web.HTMLDivElement;
  bool shown() => tip().classList.contains('svgc-hint-on');

  test('installSVGChartHints: one tooltip, its styles, once', () {
    final a = installSVGChartHints();
    final b = installSVGChartHints();
    expect(identical(a, b), isTrue);
    expect(web.document.querySelectorAll('.svgc-hint').length, 1);
    expect(a.tooltip.getAttribute('role'), 'tooltip');
    final styles = web.document.querySelectorAll('style');
    var found = false;
    for (var i = 0; i < styles.length; i++) {
      if ((styles.item(i)!.textContent ?? '').contains('.svgc-hint{')) {
        found = true;
      }
    }
    expect(found, isTrue);
  });

  test('hover shows the mark\'s hint and drops its native title', () {
    final svg = insertSVGChart(
      host,
      ColumnChart.of([25, 75], name: 'orders', labels: ['open', 'paid']),
    )!;
    final mark = svg.querySelectorAll('.svgc-mark').item(1)! as web.Element;
    expect(mark.querySelector(':scope > title'), isNotNull);
    pointer(mark.querySelector('.svgc-bar')!, 'pointermove');
    expect(shown(), isTrue);
    expect(tip().querySelector('.svgc-hint-head')!.textContent, 'paid');
    expect(tip().querySelector('.svgc-hint-line')!.textContent, 'orders: 75');
    expect(tip().style.left, '34px');
    expect(tip().style.top, '45px');
    // No second, native tooltip.
    expect(mark.querySelector(':scope > title'), isNull);
    expect(mark.getAttribute('aria-label'), 'paid, orders: 75');

    // Off any mark: hidden.
    pointer(svg, 'pointermove');
    expect(shown(), isFalse);
  });

  test('a scroll hides it; a tap shows it on touch screens', () {
    final svg = insertSVGChart(host, LineChart.of([1, 2, 3]))!;
    final band = svg.querySelector('.svgc-band rect')!;
    pointer(band, 'pointermove');
    expect(shown(), isTrue);
    web.document.dispatchEvent(web.Event('scroll'));
    expect(shown(), isFalse);

    // Touch: moves are ignored, a tap shows, a tap elsewhere hides.
    pointer(band, 'pointermove', pointerType: 'touch');
    expect(shown(), isFalse);
    pointer(band, 'pointerdown', pointerType: 'touch');
    expect(shown(), isTrue);
    // The first band: x "1", value 1.
    expect(tip().querySelector('.svgc-hint-head')!.textContent, '1');
    expect(tip().querySelector('.svgc-hint-line')!.textContent, '1');
    pointer(web.document.body!, 'pointerdown', pointerType: 'touch');
    expect(shown(), isFalse);
  });

  test('near the window\'s edge the tooltip flips to stay inside', () {
    final svg = insertSVGChart(host, ColumnChart.of([5]))!;
    final w = web.window.innerWidth.toDouble();
    final h = web.window.innerHeight.toDouble();
    pointer(svg.querySelector('.svgc-bar')!, 'pointermove', x: w - 2, y: h - 2);
    expect(shown(), isTrue);
    final left = double.parse(tip().style.left.replaceAll('px', ''));
    final top = double.parse(tip().style.top.replaceAll('px', ''));
    expect(left + tip().offsetWidth, lessThanOrEqualTo(w));
    expect(top + tip().offsetHeight, lessThanOrEqualTo(h));
  });

  test('a mark removed by a click takes its tooltip away', () async {
    final svg = insertSVGChart(host, ColumnChart.of([5]))!;
    final bar = svg.querySelector('.svgc-bar')!;
    pointer(bar, 'pointermove');
    expect(shown(), isTrue);
    host.innerHTML = ''.toJS;
    web.document.dispatchEvent(web.Event('click'));
    await Future<void>.delayed(const Duration(milliseconds: 120));
    expect(shown(), isFalse);
  });

  test('marks of another prefix are not this layer\'s', () {
    insertSVGChart(
      host,
      ColumnChart.of([5], theme: const SvgChartTheme(prefix: 'other')),
      hints: false,
    );
    installSVGChartHints();
    pointer(host.querySelector('.other-bar')!, 'pointermove');
    expect(shown(), isFalse);
  });

  test('insertSVGChart: onMark gets the index and series of a click', () {
    final clicks = <(int, int?)>[];
    final svg = insertSVGChart(
      host,
      ColumnChart(const [
        Series([1, 2], name: 'a'),
        Series([3, 4], name: 'b'),
      ]),
      onMark: (i, s) => clicks.add((i, s)),
    )!;
    expect(svg.classList.contains('svgc-clickable'), isTrue);
    final bars = svg.querySelectorAll('.svgc-bar');
    (bars.item(3)! as web.Element).dispatchEvent(
      web.MouseEvent('click', web.MouseEventInit(bubbles: true)),
    );
    // A click off any mark: nothing.
    svg.dispatchEvent(
      web.MouseEvent('click', web.MouseEventInit(bubbles: true)),
    );
    expect(clicks, [(1, 1)]);

    // A line's band has no series.
    final line = insertSVGChart(
      host,
      LineChart.of([1, 2]),
      onMark: (i, s) {
        clicks.add((i, s));
      },
    )!;
    line
        .querySelector('.svgc-band rect')!
        .dispatchEvent(
          web.MouseEvent('click', web.MouseEventInit(bubbles: true)),
        );
    expect(clicks.last, (0, null));
  });

  test('insertSVGChart without onMark: not clickable', () {
    final svg = insertSVGChart(host, ColumnChart.of([1]))!;
    expect(svg.classList.contains('svgc-clickable'), isFalse);
  });

  test('remove takes the tooltip, styles and listeners away', () {
    final hints = installSVGChartHints(injectStyle: false);
    expect(web.document.querySelector('.svgc-hint'), isNotNull);
    hints.remove();
    expect(web.document.querySelector('.svgc-hint'), isNull);
    // A new one after removal.
    expect(identical(installSVGChartHints(), hints), isFalse);
  });

  test('svgChartHintCss: the inverse colours, with properties', () {
    final css = svgChartHintCss('x');
    expect(css, contains('.x-hint{'));
    expect(css, contains('background:var(--x-text,#0b0b0b)'));
    expect(css, contains('prefers-color-scheme:dark'));
  });
}
