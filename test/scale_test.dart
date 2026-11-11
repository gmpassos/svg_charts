import 'package:svg_charts/svg_charts.dart';
import 'package:test/test.dart';

/// Scales, ticks, extents and the statistics charts are built on.
void main() {
  group('isDrawable / dataExtent', () {
    test('nulls, NaN and infinities are gaps', () {
      expect(isDrawable(null), isFalse);
      expect(isDrawable(double.nan), isFalse);
      expect(isDrawable(double.infinity), isFalse);
      expect(isDrawable(0), isTrue);
      expect(dataExtent([3, null, -2, double.nan, 7]), (min: -2, max: 7));
      expect(dataExtent([null, double.infinity]), isNull);
      expect(dataExtent(const []), isNull);
    });
  });

  group('niceStep', () {
    test('1, 2, 2.5 or 5 times a power of ten', () {
      expect(niceStep(100, 5), 20);
      expect(niceStep(10, 5), 2);
      expect(niceStep(1, 4), 0.25);
      expect(niceStep(7, 5), 2);
      expect(niceStep(0.03, 3), 0.01);
      expect(niceStep(48, 5), 10);
    });

    test('a non-positive or non-finite span steps by 1', () {
      expect(niceStep(0, 5), 1);
      expect(niceStep(-3, 5), 1);
      expect(niceStep(double.nan, 5), 1);
    });
  });

  group('niceTicks', () {
    test('cover the data with round values', () {
      expect(niceTicks(0, 90), [0, 20, 40, 60, 80, 100]);
      expect(niceTicks(-9, 15), [-10, -5, 0, 5, 10, 15]);
      expect(niceTicks(0.1, 0.9, maxTicks: 4), [0, 0.2, 0.4, 0.6, 0.8, 1]);
      expect(niceTicks(0, 1, maxTicks: 4), [0, 0.25, 0.5, 0.75, 1]);
    });

    test('no floating-point noise', () {
      final ticks = niceTicks(0, 0.3, maxTicks: 3);
      expect(ticks, [0, 0.1, 0.2, 0.3]);
      for (final t in ticks) {
        expect(t.toString().length, lessThan(5));
      }
    });

    test('a flat range is widened, not below zero for a positive value', () {
      expect(niceTicks(5, 5).first, lessThanOrEqualTo(2.5));
      expect(niceTicks(5, 5).last, greaterThanOrEqualTo(7.5));
      expect(niceTicks(5, 5).first, greaterThanOrEqualTo(0));
      expect(niceTicks(0, 0), [0, 0.2, 0.4, 0.6, 0.8, 1]);
      expect(niceTicks(-4, -4).first, lessThan(-4));
    });

    test('reversed or non-finite bounds', () {
      expect(niceTicks(10, 0), niceTicks(0, 10));
      expect(niceTicks(double.nan, 1), [0, 1]);
    });
  });

  group('LinearScale', () {
    test('maps the domain onto the range, backwards too', () {
      const y = LinearScale(0, 100, 200, 0);
      expect(y(0), 200);
      expect(y(100), 0);
      expect(y(25), 150);
      const x = LinearScale(-10, 10, 0, 100);
      expect(x(0), 50);
    });

    test('a flat domain maps to the middle', () {
      expect(const LinearScale(3, 3, 0, 100)(3), 50);
    });
  });

  group('histogramBins', () {
    test('equal-width bins, the maximum in the last', () {
      final bins = histogramBins([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10], 5);
      expect(bins, hasLength(5));
      expect([for (final b in bins) b.count], [2, 2, 2, 2, 3]);
      expect(bins.first.start, 0);
      expect(bins.last.end, 10);
    });

    test('gaps are skipped; one value, one bin; none, none', () {
      expect(histogramBins([null, double.nan], 4), isEmpty);
      final one = histogramBins([3, 3, null], 4);
      expect(one, hasLength(1));
      expect(one.single.count, 2);
      expect(histogramBins([1, 2], 0), hasLength(1));
    });

    test('finiteValues keeps the drawable ones in order', () {
      expect(finiteValues([3, null, double.nan, -1]), [3, -1]);
    });
  });
}
