/// A headline figure: a label, a value, its change, its trend.
library;

import '../chart.dart';
import '../format.dart';
import '../svg_writer.dart';
import '../theme.dart';
import 'sparkline.dart';

/// Whether a change is for the better, the worse, or neither.
enum Trend {
  /// For the better (▲ or ▼ by the sign, in the palette's good colour).
  good,

  /// For the worse (in the palette's bad colour).
  bad,

  /// Neither: muted.
  neutral,
}

/// A stat tile: a large [value] over its [label], with an optional
/// [delta] (its change, marked ▲ or ▼ and coloured by [trend]) and a
/// [trendValues] sparkline.
///
/// For a single number that matters more than its shape: a total, a rate,
/// a count today. The change carries its arrow and sign, so the colour is
/// never the only cue.
///
/// ```dart
/// final svg = StatTile(
///   label: 'Orders',
///   value: '5,894',
///   delta: '+12%',
///   trend: Trend.good,
/// ).render();
/// ```
class StatTile implements SvgChart {
  /// A tile of [value], named [label].
  const StatTile({
    required this.label,
    required this.value,
    this.delta,
    this.trend = Trend.neutral,
    this.up,
    this.trendValues = const [],
    this.width = 200,
    this.height = 96,
    this.theme = SvgChartTheme.auto,
  });

  /// A tile of a number, written with [format].
  StatTile.number({
    required String label,
    required num value,
    NumberFormatter format = formatNumber,
    String? delta,
    Trend trend = Trend.neutral,
    bool? up,
    List<num?> trendValues = const [],
    double width = 200,
    double height = 96,
    SvgChartTheme theme = SvgChartTheme.auto,
  }) : this(
         label: label,
         value: format(value),
         delta: delta,
         trend: trend,
         up: up,
         trendValues: trendValues,
         width: width,
         height: height,
         theme: theme,
       );

  /// What the value is.
  final String label;

  /// The value, as written.
  final String value;

  /// Its change (`+12%`, `-3 since yesterday`).
  final String? delta;

  /// Whether the change is good or bad news.
  final Trend trend;

  /// Whether the change goes up (▲) or down (▼); by default read from
  /// [delta]'s sign (a leading `-` or `−` is down).
  final bool? up;

  /// A trend drawn as a sparkline under the value.
  final List<num?> trendValues;

  /// The width in px.
  final double width;

  /// The height in px.
  final double height;

  /// Colours and type.
  final SvgChartTheme theme;

  @override
  String render() {
    final w = SvgWriter();
    openChart(
      w,
      theme,
      width: width,
      height: height,
      title: label,
      description: [value, ?delta].join(' '),
      kind: 'stat-tile',
    );
    final small = theme.smallFontSize;
    final big = theme.fontSize * 2;
    openMark(w, theme, [
      label,
      [value, ?delta].join(' · '),
    ]);
    w
      ..element('text', truncateText(label, width - 16, small), {
        'class': '${theme.cls('label')} ${theme.cls('small')}',
        'x': 8,
        'y': 8 + small,
        'fill': theme.palette.textSecondary,
      })
      ..element('text', truncateText(value, width - 16, big), {
        'class': '${theme.cls('text')} ${theme.cls('strong')}',
        'x': 8,
        'y': 8 + small + 6 + big,
        'font-size': big,
        'fill': theme.palette.text,
      });
    final d = delta;
    if (d != null && d.isNotEmpty) {
      final rising = up ?? !(d.startsWith('-') || d.startsWith('−'));
      final cls = switch (trend) {
        Trend.good => 'good',
        Trend.bad => 'bad',
        Trend.neutral => 'tick',
      };
      w.element('text', '${rising ? '▲' : '▼'} $d', {
        'class': '${theme.cls(cls)} ${theme.cls('small')}',
        'x': 8,
        'y': 8 + small + 6 + big + 6 + small,
        'fill': switch (trend) {
          Trend.good => theme.palette.good,
          Trend.bad => theme.palette.bad,
          Trend.neutral => theme.palette.muted,
        },
      });
    }
    w.close('g');
    if (trendValues.isNotEmpty) {
      // The sparkline in the tile's lower right, as nested SVG.
      final sw = width / 2 - 8, sh = 24.0;
      final spark = Sparkline(
        trendValues,
        width: sw,
        height: sh,
        theme: theme.copyWith(embedStyle: false, background: false),
        hints: false,
        title: '$label trend',
      ).render();
      w
        ..open('g', {
          'transform':
              'translate(${svgNum(width - sw - 8)} ${svgNum(height - sh - 8)})',
        })
        ..raw(spark)
        ..close('g');
    }
    w.close('svg');
    return w.toString();
  }

  @override
  String toString() => render();
}
