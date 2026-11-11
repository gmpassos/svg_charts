// Shared by the tests: parsing a chart's SVG and finding its parts.
import 'package:xml/xml.dart';

/// [svg] parsed; throws when it isn't well-formed XML, which is itself a
/// check every chart test makes.
XmlElement parseSvg(String svg) {
  final doc = XmlDocument.parse(svg);
  final root = doc.rootElement;
  if (root.name.local != 'svg') {
    throw StateError('root is <${root.name.local}>, not <svg>');
  }
  return root;
}

/// The elements under [root] whose class list has [cls] (`svgc-` added).
List<XmlElement> byClass(
  XmlElement root,
  String cls, {
  String prefix = 'svgc',
}) {
  final name = '$prefix-$cls';
  return [
    for (final e in root.descendantElements)
      if ((e.getAttribute('class') ?? '').split(' ').contains(name)) e,
  ];
}

/// The `data-hint` attributes of [root]'s marks with class [cls], in order.
List<String> hintsOf(XmlElement root, [String cls = 'mark']) => [
  for (final e in byClass(root, cls)) e.getAttribute('data-hint') ?? '',
];

/// [attr] of [e] as a number.
double numAttr(XmlElement e, String attr) =>
    double.parse(e.getAttribute(attr) ?? 'nan');

/// The visible text of [root]'s `<text>` elements.
List<String> textsOf(XmlElement root) => [
  for (final e in root.findAllElements('text')) e.innerText,
];

/// The bounds of a path's coordinates: every number pair after a command
/// letter (the paths here are M/L/H/V/Q/C/A with absolute coordinates).
({double minX, double minY, double maxX, double maxY}) pathBounds(String d) {
  final xs = <double>[], ys = <double>[];
  // H and V take one coordinate; the others pairs.
  final tokens = RegExp(r'[MLHVQCAZhv]|-?[\d.]+')
      .allMatches(d)
      .map((m) => m[0]!);
  String? cmd;
  final nums = <double>[];
  void flush() {
    if (cmd == null) return;
    switch (cmd) {
      case 'H':
        xs.addAll(nums);
      case 'V':
        ys.addAll(nums);
      case 'A':
        for (var i = 0; i + 6 < nums.length + 1; i += 7) {
          if (i + 6 < nums.length) {
            xs.add(nums[i + 5]);
            ys.add(nums[i + 6]);
          }
        }
      case 'h' || 'v' || 'Z':
        break;
      default:
        for (var i = 0; i + 1 < nums.length; i += 2) {
          xs.add(nums[i]);
          ys.add(nums[i + 1]);
        }
    }
    nums.clear();
  }

  for (final t in tokens) {
    if (RegExp('[A-Za-z]').hasMatch(t)) {
      flush();
      cmd = t;
    } else {
      nums.add(double.parse(t));
    }
  }
  flush();
  return (
    minX: xs.reduce((a, b) => a < b ? a : b),
    minY: ys.reduce((a, b) => a < b ? a : b),
    maxX: xs.reduce((a, b) => a > b ? a : b),
    maxY: ys.reduce((a, b) => a > b ? a : b),
  );
}
