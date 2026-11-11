/// The low-level SVG output every chart is written with: escaping, number
/// output, and an element buffer.
library;

/// The characters [escapeXml] escapes: compiled once, as every label,
/// attribute and hint of every chart is checked against it.
final _xmlSpecial = RegExp('[&<>"\']');

/// [text] escaped for SVG/XML text and attribute values: `&`, `<`, `>`,
/// `"` and `'`.
///
/// Every label, series name and hint goes through this, so a category named
/// `<b>R&D</b>` is drawn as those characters, never as markup.
String escapeXml(String text) {
  // Most labels need no escaping: skip the buffer for them.
  if (!text.contains(_xmlSpecial)) return text;
  final out = StringBuffer();
  for (final c in text.split('')) {
    out.write(switch (c) {
      '&' => '&amp;',
      '<' => '&lt;',
      '>' => '&gt;',
      '"' => '&quot;',
      "'" => '&#39;',
      _ => c,
    });
  }
  return out.toString();
}

/// [v] as an SVG coordinate or length: at most 2 decimals, trailing zeros
/// dropped (`12`, `12.5`, `12.25`).
///
/// Never `-0`, never `NaN` or `Infinity` (both written as `0`): SVG parsers
/// reject the last two, and a coordinate like that is a bug upstream that
/// should not also break the whole document. From 1e21 up the number is
/// exponential (`1e+21`), which SVG's number grammar accepts.
String svgNum(num v) {
  if (!v.isFinite) return '0';
  // Past 1e15 a double can't hold 2 decimals anyway; and rounding through
  // an int would overflow on the VM past 9.2e18.
  if (v.abs() >= 1e15) return v.toStringAsFixed(0);
  // Rounded to 2 decimals first, so -0.001 becomes 0, not "-0".
  final rounded = (v * 100).round() / 100;
  if (rounded == 0) return '0';
  var s = rounded.toStringAsFixed(2);
  if (s.contains('.')) {
    s = s.replaceFirst(RegExp(r'0+$'), '');
    if (s.endsWith('.')) s = s.substring(0, s.length - 1);
  }
  return s;
}

/// An append-only SVG document buffer.
///
/// Attributes are given as a map; a `null` value leaves the attribute out,
/// so optional attributes need no `if` at the call site. Values are escaped
/// and numbers written with [svgNum].
class SvgWriter {
  final StringBuffer _out = StringBuffer();

  /// Opens `<tag …>`; [close] it later. With [selfClose], writes `<tag …/>`.
  void open(
    String tag, [
    Map<String, Object?> attributes = const {},
    bool selfClose = false,
  ]) {
    _out
      ..write('<')
      ..write(tag);
    _attributes(attributes);
    _out.write(selfClose ? '/>' : '>');
  }

  /// A childless element: `<tag …/>`.
  void empty(String tag, [Map<String, Object?> attributes = const {}]) =>
      open(tag, attributes, true);

  /// Closes [tag].
  void close(String tag) => _out
    ..write('</')
    ..write(tag)
    ..write('>');

  /// An element holding only [text] (escaped): `<tag …>text</tag>`.
  void element(
    String tag,
    String text, [
    Map<String, Object?> attributes = const {},
  ]) {
    open(tag, attributes);
    this.text(text);
    close(tag);
  }

  /// Escaped text content.
  void text(String text) => _out.write(escapeXml(text));

  /// Markup written as is: for nested output already escaped.
  void raw(String markup) => _out.write(markup);

  void _attributes(Map<String, Object?> attributes) {
    for (final MapEntry(:key, :value) in attributes.entries) {
      if (value == null) continue;
      final text = value is num ? svgNum(value) : escapeXml('$value');
      _out
        ..write(' ')
        ..write(key)
        ..write('="')
        ..write(text)
        ..write('"');
    }
  }

  @override
  String toString() => _out.toString();
}
