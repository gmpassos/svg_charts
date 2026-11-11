@TestOn('vm')
library;

import 'dart:io';

import 'package:test/test.dart';

/// Mechanical proof of the package's central constraint.
///
/// `package:svg_charts/svg_charts.dart` renders strings, so it must run
/// anywhere: a browser, a server, an isolate with no DOM. One import of
/// `dart:io` (a convenience file write) or of `package:web` (a quick DOM
/// call) would break that for every user, and nothing else in the suite
/// would notice until a build failed. Only `svg_charts_web.dart`, the
/// browser companion, may import the web libraries.
///
/// This test reads the source (it needs `dart:io` itself, which is fine:
/// pub.dev scores platform support from `lib/`, not `test/`).
void main() {
  const banned = [
    'dart:io',
    'dart:ffi',
    'dart:isolate',
    'dart:mirrors',
    'dart:html',
    'dart:js',
    'dart:js_interop',
    'dart:js_interop_unsafe',
    'package:web/',
  ];
  final import = RegExp(r'''^\s*(?:import|export)\s+['"]([^'"]+)['"]''');

  /// The imports of [file].
  List<String> importsOf(File file) => [
    for (final line in file.readAsLinesSync())
      if (import.firstMatch(line) case final m?) m[1]!,
  ];

  /// The library files [entry] reaches through relative imports.
  Set<String> reachable(String entry) {
    final seen = <String>{};
    final queue = [File(entry).absolute.path];
    while (queue.isNotEmpty) {
      final path = queue.removeLast();
      if (!seen.add(path)) continue;
      for (final uri in importsOf(File(path))) {
        if (uri.contains(':')) continue;
        queue.add(File(path).parent.uri.resolve(uri).toFilePath());
      }
    }
    return seen;
  }

  test('svg_charts.dart reaches no platform-specific library', () {
    final offenders = <String>[];
    for (final path in reachable('lib/svg_charts.dart')) {
      for (final uri in importsOf(File(path))) {
        if (banned.any(uri.startsWith)) offenders.add('$path: $uri');
      }
    }
    expect(offenders, isEmpty);
  });

  test('every file under lib/src is reached by svg_charts.dart', () {
    // A file only the web library uses would escape the check above.
    final reached = reachable('lib/svg_charts.dart');
    final all = Directory('lib/src')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .map((f) => f.absolute.path);
    expect(all.where((p) => !reached.contains(p)), isEmpty);
  });

  test('only svg_charts_web.dart imports package:web', () {
    final users = [
      for (final f in Directory('lib').listSync(recursive: true))
        if (f is File &&
            f.path.endsWith('.dart') &&
            importsOf(f).any((u) => u.startsWith('package:web/')))
          f.path.replaceAll(r'\', '/'),
    ];
    expect(users, ['lib/svg_charts_web.dart']);
  });
}
