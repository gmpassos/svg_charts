// Writes the gallery: doc/images/<name>.svg (the README's images) and
// doc/gallery.html (every chart, light and dark, with the web hints off —
// open it in a browser and hover the marks for their native tooltips).
//
//   dart run example/gallery.dart
//
// test/gallery_test.dart fails when doc/images is out of date.
import 'dart:io';

import 'package:svg_charts/svg_charts.dart';

import 'gallery_charts.dart';

void main() {
  final images = Directory('doc/images')..createSync(recursive: true);
  for (final MapEntry(key: name, value: chart) in galleryCharts().entries) {
    File('${images.path}/$name.svg').writeAsStringSync('${chart.render()}\n');
  }
  File('doc/gallery.html').writeAsStringSync(galleryHtml());
  // The fingerprints test/parity_test.dart checks on every platform.
  final fingerprints = StringBuffer(
    '// Written by `dart run example/gallery.dart`: do not edit.\n'
    '// The gallery\'s output fingerprints on the VM (see parity_test.dart).\n'
    'const galleryFingerprints = {\n',
  );
  for (final MapEntry(key: name, value: chart) in galleryCharts().entries) {
    fingerprints.writeln("  '$name': ${fingerprint(chart.render())},");
  }
  fingerprints.writeln('};');
  File('test/gallery_fingerprints.dart').writeAsStringSync('$fingerprints');
  stdout.writeln(
    'Wrote ${galleryCharts().length} charts to ${images.path}/ '
    'and doc/gallery.html',
  );
}

/// Every chart twice: on a light page and on a dark one (forced with
/// `data-theme`, as a page's theme switch would).
String galleryHtml() {
  final out = StringBuffer('''
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>svg_charts gallery</title>
<style>
body { margin: 0; font: 14px system-ui, sans-serif; }
section { padding: 16px; display: flex; flex-wrap: wrap; gap: 16px;
  align-items: flex-start; }
section.light { background: #f9f9f7; color: #0b0b0b; }
section.dark { background: #0d0d0d; color: #f0efec; }
figure { margin: 0; padding: 8px; border-radius: 8px; }
.light figure { background: #fcfcfb; }
.dark figure { background: #1a1a19; }
figcaption { font-size: 12px; opacity: .6; margin-top: 4px; }
</style>
</head>
<body>
''');
  for (final scheme in ['light', 'dark']) {
    out.writeln('<h2 style="margin:0;padding:16px 16px 0">$scheme</h2>');
    // An inline SVG's <style> applies to the whole page, so the dark
    // charts take their own class prefix: their rules don't repaint the
    // light ones (and vice versa).
    final theme = scheme == 'light'
        ? SvgChartTheme.light
        : SvgChartTheme.dark.copyWith(prefix: 'svgcd');
    out.writeln('<section class="$scheme">');
    for (final MapEntry(key: name, value: chart) in galleryCharts(
      theme.copyWith(background: false),
    ).entries) {
      out.writeln(
        '<figure>${chart.render()}<figcaption>$name</figcaption></figure>',
      );
    }
    out.writeln('</section>');
  }
  out.writeln('</body>\n</html>');
  return out.toString();
}
