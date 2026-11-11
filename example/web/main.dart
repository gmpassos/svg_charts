// The web example: charts inserted into a page, with the styled hint
// tooltip and clickable marks.
//
//   dart compile js -o example/web/main.dart.js example/web/main.dart
//   (then open example/web/index.html through any static server)
import 'package:svg_charts/svg_charts.dart';
import 'package:svg_charts/svg_charts_web.dart';
import 'package:web/web.dart' as web;

import '../gallery_charts.dart';

void main() {
  installChartHints();
  final log = web.document.querySelector('#log');
  final grid = web.document.querySelector('#charts');
  if (grid == null) return;
  for (final MapEntry(key: name, value: chart) in galleryCharts(
    SvgChartTheme.auto,
  ).entries) {
    final figure = web.document.createElement('figure');
    final host = web.document.createElement('div');
    final caption = web.document.createElement('figcaption')
      ..textContent = name;
    figure
      ..append(host)
      ..append(caption);
    grid.append(figure);
    insertChart(
      host,
      chart,
      onMark: (index, series) => log?.textContent =
          'clicked $name: index $index${series == null ? '' : ', series $series'}',
    );
  }
}
