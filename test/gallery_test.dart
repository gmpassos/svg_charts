@TestOn('vm')
library;

import 'dart:io';

import 'package:svg_charts/svg_charts.dart';
import 'package:test/test.dart';

import '../example/gallery.dart' show galleryHtml;
import '../example/gallery_charts.dart';
import 'gallery_fingerprints.dart';
import 'helpers.dart';

/// The README shows doc/images/*.svg. Images in documentation rot
/// silently: they stay plausible long after they stop being what the code
/// draws. This pins them, and the fingerprints the parity test checks on
/// the web, to what the gallery code renders now.
///
/// After changing a chart on purpose: `dart run example/gallery.dart`.
void main() {
  final charts = galleryCharts();

  test('doc/images holds exactly the gallery', () {
    final files = Directory('doc/images')
        .listSync()
        .map((f) => f.uri.pathSegments.last)
        .where((n) => n.endsWith('.svg'))
        .map((n) => n.substring(0, n.length - 4))
        .toSet();
    expect(files, charts.keys.toSet());
  });

  for (final MapEntry(key: name, value: chart) in charts.entries) {
    test('doc/images/$name.svg is up to date', () {
      final file = File('doc/images/$name.svg').readAsStringSync();
      expect(
        file,
        '${chart.render()}\n',
        reason: 'run `dart run example/gallery.dart`',
      );
      parseSvg(file);
    });
  }

  test('the fingerprints are up to date', () {
    expect(galleryFingerprints, {
      for (final MapEntry(key: name, value: chart) in charts.entries)
        name: fingerprint(chart.render()),
    }, reason: 'run `dart run example/gallery.dart`');
  });

  test('doc/gallery.html is up to date', () {
    expect(File('doc/gallery.html').readAsStringSync(), galleryHtml());
  });

  test('the dark gallery takes its own prefix', () {
    final html = galleryHtml();
    expect(html, contains('svgcd-root'));
    expect(html, contains('svgc-root'));
    expect(SvgChartTheme.dark.copyWith(prefix: 'svgcd').prefix, 'svgcd');
  });
}
