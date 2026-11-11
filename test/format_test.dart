import 'package:svg_charts/svg_charts.dart';
import 'package:test/test.dart';

/// Numbers as charts write them. Runs on the VM and in the browser
/// (`dart test -p chrome`): the formats must agree on both, where every
/// number is a JS double and `1.0 is int` is true.
void main() {
  group('groupThousands', () {
    test('groups of three, with a sign', () {
      expect(groupThousands(0), '0');
      expect(groupThousands(999), '999');
      expect(groupThousands(1000), '1,000');
      expect(groupThousands(1234567), '1,234,567');
      expect(groupThousands(-1000), '-1,000');
      expect(groupThousands(-12), '-12');
    });
  });

  group('formatNumber', () {
    test('integral values are grouped, whatever their type', () {
      expect(formatNumber(5894), '5,894');
      expect(formatNumber(5894.0), '5,894');
      expect(formatNumber(-1200000), '-1,200,000');
      expect(formatNumber(0), '0');
      expect(formatNumber(-0.0), '0');
    });

    test('decimals by size', () {
      expect(formatNumber(1234.56), '1,234.6');
      expect(formatNumber(12.345), '12.35');
      expect(formatNumber(0.1234), '0.123');
      expect(formatNumber(-0.5), '-0.5');
      expect(formatNumber(2.5), '2.5');
    });

    test('rounding to integral drops the decimals', () {
      expect(formatNumber(0.9996), '1');
      expect(formatNumber(99.999), '100');
    });

    test('non-finite and huge values', () {
      expect(formatNumber(double.nan), 'NaN');
      expect(formatNumber(double.infinity), '∞');
      expect(formatNumber(double.negativeInfinity), '-∞');
      expect(formatNumber(1e15), '1,000,000,000,000,000');
      // Past the 64-bit range: grouped from its digits, no overflow.
      expect(formatNumber(1e20), '100,000,000,000,000,000,000');
      expect(formatNumber(1.5e21), '1.5e+21');
      expect(formatNumber(123456789012.5), '123,456,789,012.5');
    });
  });

  group('formatCompact', () {
    test('suffixes past a thousand', () {
      expect(formatCompact(950), '950');
      expect(formatCompact(1000), '1k');
      expect(formatCompact(1250), '1.3k');
      expect(formatCompact(45000), '45k');
      expect(formatCompact(250000), '250k');
      expect(formatCompact(3400000), '3.4M');
      expect(formatCompact(1.2e9), '1.2B');
      expect(formatCompact(7e12), '7T');
      expect(formatCompact(-2500), '-2.5k');
    });

    test('a value rounding to 1000 of a unit takes the next one', () {
      expect(formatCompact(999950), '1M');
      expect(formatCompact(999600), '1M');
      expect(formatCompact(999400), '999k');
      expect(formatCompact(999999999), '1B');
      // The largest unit has no next: as it rounds.
      expect(formatCompact(1e15), '1000T');
    });

    test('small values keep their decimals', () {
      expect(formatCompact(0), '0');
      expect(formatCompact(0.25), '0.25');
      expect(formatCompact(1.5), '1.5');
      expect(formatCompact(12.34), '12.3');
      expect(formatCompact(-0.5), '-0.5');
      expect(formatCompact(double.nan), 'NaN');
    });
  });

  group('formatRate', () {
    test('never rounds into 0% or 100%', () {
      expect(formatRate(0), '0%');
      expect(formatRate(1), '100%');
      expect(formatRate(0.004), '<1%');
      expect(formatRate(0.996), '>99%');
      expect(formatRate(0.42), '42%');
      expect(formatRate(0.425), '43%');
    });

    test('outside 0–1, as it is', () {
      expect(formatRate(1.5), '150%');
      expect(formatRate(-0.2), '-20%');
      expect(formatRate(double.infinity), '∞');
    });
  });
}
