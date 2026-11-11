import 'package:test/test.dart';

import '../example/gallery_charts.dart';
import 'gallery_fingerprints.dart';

/// The same chart must render to the same bytes on the VM and on the web.
///
/// Numbers are where they diverge: a double interpolated into a string is
/// `12.0` on the VM and `12` under dart2js, and `1.0 is int` is true on the
/// web only. A server rendering a report and a browser rendering the same
/// chart would then disagree, invisibly, until someone compared them.
///
/// The gallery's fingerprints are written on the VM (`example/gallery.dart`,
/// checked by gallery_test.dart); this test checks them on every platform it
/// runs on, CI's Chrome job included.
void main() {
  for (final MapEntry(key: name, value: chart) in galleryCharts().entries) {
    test('$name renders the same here as on the VM', () {
      expect(fingerprint(chart.render()), galleryFingerprints[name]);
    });
  }
}
