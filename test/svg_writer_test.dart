import 'package:svg_charts/svg_charts.dart';
import 'package:test/test.dart';

/// The low-level output: escaping, numbers, elements.
void main() {
  group('escapeXml', () {
    test('the five special characters', () {
      expect(
        escapeXml('<b>R&D</b> "q" \'s\''),
        '&lt;b&gt;R&amp;D&lt;/b&gt; &quot;q&quot; &#39;s&#39;',
      );
      expect(escapeXml('plain'), 'plain');
      expect(escapeXml(''), '');
    });
  });

  group('svgNum', () {
    test('at most 2 decimals, no trailing zeros', () {
      expect(svgNum(12), '12');
      expect(svgNum(12.0), '12');
      expect(svgNum(12.5), '12.5');
      expect(svgNum(12.256), '12.26');
      expect(svgNum(-3.10), '-3.1');
    });

    test('never -0, NaN or Infinity', () {
      expect(svgNum(-0.001), '0');
      expect(svgNum(-0.0), '0');
      expect(svgNum(double.nan), '0');
      expect(svgNum(double.infinity), '0');
    });

    test('huge values: whole, past 1e21 exponential (no int overflow)', () {
      expect(svgNum(2e15), '2000000000000000');
      expect(svgNum(1e19), '10000000000000000000');
      expect(svgNum(-1e21), '-1e+21');
    });
  });

  group('SvgWriter', () {
    test('elements, attributes escaped, nulls left out', () {
      final w = SvgWriter()
        ..open('g', {'class': 'a"b', 'data-x': 1.5, 'skip': null})
        ..element('text', '1 < 2', {'x': 0})
        ..empty('rect', {'width': 10})
        ..raw('<!--raw-->')
        ..text('&')
        ..close('g');
      expect(
        w.toString(),
        '<g class="a&quot;b" data-x="1.5"><text x="0">1 &lt; 2</text>'
        '<rect width="10"/><!--raw-->&amp;</g>',
      );
    });
  });
}
