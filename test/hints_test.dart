import 'package:svg_charts/svg_charts.dart';
import 'package:test/test.dart';

/// What a mark's hint says: the lines the tooltip and `<title>` show.
void main() {
  String f(num v) => v.toString();

  group('markHint', () {
    test('its label, the measure and value, its share', () {
      expect(
        markHint('delivered', 75, measure: 'count', total: 100, format: f),
        ['delivered', 'count: 75 · 75% of the total'],
      );
    });

    test('no measure, no total: the value alone', () {
      expect(markHint('2026-03', 4, format: f), ['2026-03', '4']);
      expect(markHint('x', 4, measure: '', format: f), ['x', '4']);
    });

    test('an empty label is named', () {
      expect(markHint('', 0, total: 10).first, '(no label)');
    });

    test('a negative value has no share', () {
      expect(markHint('x', -1, measure: 'delta', total: 10, format: f), [
        'x',
        'delta: -1',
      ]);
    });

    test('the default format groups thousands', () {
      expect(markHint('a', 1234567), ['a', '1,234,567']);
    });
  });

  group('shareOf', () {
    test('the edges of a share', () {
      expect(shareOf(1, 1000), '<1%');
      expect(shareOf(999, 1000), '>99%');
      expect(shareOf(10, 10), '100%');
      expect(shareOf(0, 10), '0%');
    });

    test('no share without a positive whole, or for a negative value', () {
      expect(shareOf(-1, 10), isNull);
      expect(shareOf(1, 0), isNull);
      expect(shareOf(1, -5), isNull);
      expect(shareOf(double.nan, 10), isNull);
      expect(shareOf(1, double.infinity), isNull);
    });
  });

  group('totalOf', () {
    test('sums, nulls skipped, others included', () {
      expect(totalOf([3, 1, 2]), 6);
      expect(totalOf([3, null, 2]), 5);
      expect(totalOf([3, 1], others: 6), 10);
      expect(totalOf(const []), 0);
    });

    test('values crossing zero make no whole', () {
      expect(totalOf([3, -1, 2]), isNull);
      expect(totalOf([3, 1], others: -1), isNull);
      expect(totalOf([3, double.infinity]), isNull);
    });
  });

  group('pointHint', () {
    test('the hovered series first, then the others at that x', () {
      expect(
        pointHint('2026-03', 'paid', {
          'open': 3,
          'paid': 7,
          'void': null,
        }, format: f),
        ['2026-03', 'paid: 7', 'open: 3', 'void: —'],
      );
    });

    test('a point: its own series only', () {
      expect(
        pointHint(
          '2026-03',
          'paid',
          {'open': 3, 'paid': 7},
          others: false,
          format: f,
        ),
        ['2026-03', 'paid: 7'],
      );
    });

    test('an unnamed single series: the value alone', () {
      expect(pointHint('Q1', '', {'': 7}, format: f), ['Q1', '7']);
      expect(pointHint('', '', {'': null}), ['(no label)', '—']);
    });
  });

  group('hint text', () {
    test('lines as an attribute and back', () {
      final text = hintText(['delivered', 'count: 75']);
      expect(text, 'delivered${hintLineBreak}count: 75');
      expect(hintLines(text), ['delivered', 'count: 75']);
      expect(hintLines(''), isEmpty);
      expect(hintLines('a\n\nb'), ['a', 'b']);
    });
  });
}
