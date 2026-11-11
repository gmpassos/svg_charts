/// The data charts draw.
library;

/// A named list of values, one per category or x position.
///
/// `null` is a gap ("no value here"), not a zero: a line breaks there and
/// a column is left out. NaN and infinity are treated as gaps too.
class Series {
  /// A series of [values], named [name] (in legends and hints).
  const Series(this.values, {this.name = ''});

  /// The series' name; empty for a single unnamed series.
  final String name;

  /// One value per category or x position.
  final List<num?> values;
}

/// One point of a scatter chart.
class XYPoint {
  /// A point at ([x], [y]), with an optional [label] for its hint.
  const XYPoint(this.x, this.y, {this.label});

  /// The horizontal value.
  final num x;

  /// The vertical value.
  final num y;

  /// What the point is (its hint's heading).
  final String? label;
}

/// A named list of points.
class XYSeries {
  /// A series of [points], named [name].
  const XYSeries(this.points, {this.name = ''});

  /// The series' name; empty for a single unnamed series.
  final String name;

  /// The points.
  final List<XYPoint> points;
}

/// A drawn mark, as given to a chart's `hint` callback to write its own
/// hint lines.
class ChartMark {
  /// A mark of [series] (its index [seriesIndex]) at [index].
  const ChartMark({
    required this.index,
    required this.label,
    required this.value,
    this.series = '',
    this.seriesIndex = 0,
  });

  /// The category or x position (the `data-index` attribute).
  final int index;

  /// The category's label.
  final String label;

  /// The value drawn.
  final num value;

  /// The series' name.
  final String series;

  /// The series' index (its colour).
  final int seriesIndex;
}

/// Writes a mark's hint lines; the first line is the heading.
typedef HintBuilder = List<String> Function(ChartMark mark);
