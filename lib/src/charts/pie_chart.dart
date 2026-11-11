/// Parts of a whole: pie and donut charts.
library;

import 'dart:math' as math;

import '../chart.dart';
import '../format.dart';
import '../hints.dart';
import '../svg_writer.dart';
import '../theme.dart';

/// One slice of a [PieChart].
class PieSlice {
  /// A slice of [value], named [label].
  const PieSlice(this.label, this.value);

  /// What the slice is.
  final String label;

  /// Its size; zero, negative and non-finite values are left out (a part
  /// of a whole can't be negative).
  final num value;
}

/// A pie or, with [donut], a donut chart: [slices] as shares of their sum,
/// clockwise from the top in the given order, a legend beside it with each
/// slice's share.
///
/// Past [maxSlices], the smallest slices fold into one "Other" slice: more
/// than about eight colours can't be told apart, and their slivers can't
/// be compared anyway. A donut writes [centerLabel] (by default the total)
/// in its hole.
///
/// ```dart
/// final svg = PieChart.of([62, 25, 13], labels: ['web', 'app', 'api']).render();
/// ```
class PieChart implements SvgChart {
  /// A chart of [slices].
  const PieChart(
    this.slices, {
    this.width = 360,
    this.height = 200,
    this.title,
    this.description,
    this.theme = SvgChartTheme.auto,
    this.responsive = false,
    this.donut = false,
    this.centerLabel,
    this.maxSlices = 8,
    this.otherLabel = 'Other',
    this.valueFormat = formatNumber,
    this.legend = true,
  });

  /// A chart of [values], named by [labels].
  PieChart.of(
    List<num> values, {
    List<String> labels = const [],
    double width = 360,
    double height = 200,
    String? title,
    String? description,
    SvgChartTheme theme = SvgChartTheme.auto,
    bool responsive = false,
    bool donut = false,
    String? centerLabel,
    int maxSlices = 8,
    NumberFormatter valueFormat = formatNumber,
    bool legend = true,
  }) : this(
         [
           for (final (i, v) in values.indexed)
             PieSlice(i < labels.length ? labels[i] : '${i + 1}', v),
         ],
         width: width,
         height: height,
         title: title,
         description: description,
         theme: theme,
         responsive: responsive,
         donut: donut,
         centerLabel: centerLabel,
         maxSlices: maxSlices,
         valueFormat: valueFormat,
         legend: legend,
       );

  /// The slices, in drawing order.
  final List<PieSlice> slices;

  /// The chart's width in px.
  final double width;

  /// The chart's height in px.
  final double height;

  /// Drawn above the chart, and its accessible name.
  final String? title;

  /// The chart's accessible description.
  final String? description;

  /// Colours and type.
  final SvgChartTheme theme;

  /// Whether the SVG takes its container's width.
  final bool responsive;

  /// Whether to draw a ring instead of a disc.
  final bool donut;

  /// The donut's centre text; by default the total.
  final String? centerLabel;

  /// The most slices drawn; the smallest past it fold into "Other".
  final int maxSlices;

  /// The name of the folded slice.
  final String otherLabel;

  /// Values in hints and the default centre text.
  final NumberFormatter valueFormat;

  /// Whether to draw the legend beside the chart.
  final bool legend;

  /// The slices drawn: the drawable ones, the smallest past [maxSlices]
  /// folded into one [otherLabel] slice (kept last).
  List<(PieSlice, int)> _drawn() {
    final valid = [
      for (final (i, s) in slices.indexed)
        if (s.value.isFinite && s.value > 0) (s, i),
    ];
    final cap = math.max(1, maxSlices);
    if (valid.length <= cap) return valid;
    final bySize = [...valid]..sort((a, b) => b.$1.value.compareTo(a.$1.value));
    final kept = bySize.take(cap - 1).map((e) => e.$2).toSet();
    final other = bySize.skip(cap - 1).fold<num>(0, (a, e) => a + e.$1.value);
    return [
      for (final e in valid)
        if (kept.contains(e.$2)) e,
      (PieSlice(otherLabel, other), -1),
    ];
  }

  @override
  String render() {
    final drawn = _drawn();
    final total = drawn.fold<num>(0, (a, e) => a + e.$1.value);
    final w = SvgWriter();
    openChart(
      w,
      theme,
      width: width,
      height: height,
      title: title,
      description: description,
      responsive: responsive,
      kind: donut ? 'donut-chart' : 'pie-chart',
    );
    var top = 8.0;
    if ((title ?? '').isNotEmpty) {
      w.element('text', truncateText(title!, width - 16, theme.fontSize + 1), {
        'class': '${theme.cls('text')} ${theme.cls('strong')}',
        'x': 8,
        'y': top + theme.fontSize,
        'fill': theme.palette.text,
      });
      top += theme.fontSize + 10;
    }
    final small = theme.smallFontSize;
    final legendTexts = [
      for (final (s, _) in drawn) '${s.label} ${shareOf(s.value, total) ?? ''}',
    ];
    final legendW = !legend || drawn.isEmpty
        ? 0.0
        : math.min(
            width / 2,
            legendTexts.fold<double>(
                  0,
                  (m, t) => math.max(m, estimateTextWidth(t, small)),
                ) +
                26,
          );
    final r = math.max(
      4.0,
      math.min((width - legendW - 24) / 2, (height - top - 8) / 2),
    );
    final cx = 8 + r + (width - legendW - 16 - 2 * r) / 2;
    final cy = top + (height - top - 8) / 2;
    final inner = donut ? r * 0.6 : 0.0;
    var angle = -math.pi / 2;
    w.open('g', {'class': theme.cls('marks')});
    for (final (k, (slice, index)) in drawn.indexed) {
      final sweep = slice.value / total * 2 * math.pi;
      openMark(
        w,
        theme,
        markHint(slice.label, slice.value, total: total, format: valueFormat),
        index: index < 0 ? null : index,
        series: k,
      );
      w.empty('path', {
        'class': '${theme.cls('slice')} ${seriesClass(theme, k)}',
        'd': _slicePath(cx, cy, r, inner, angle, sweep),
        'fill': theme.palette.seriesColor(k),
        // A whole ring is two circles: the inner one cuts the hole.
        'fill-rule': donut ? 'evenodd' : null,
        // A 2 px surface gap between neighbours (none for a whole disc).
        'stroke': drawn.length > 1 ? theme.palette.surface : 'none',
        'stroke-width': drawn.length > 1 ? 2 : null,
        'stroke-linejoin': 'round',
      });
      w.close('g');
      angle += sweep;
    }
    w.close('g');
    if (donut && drawn.isNotEmpty) {
      w.element('text', centerLabel ?? valueFormat(total), {
        'class': '${theme.cls('text')} ${theme.cls('strong')}',
        'x': cx,
        'y': cy + theme.fontSize * 0.35,
        'text-anchor': 'middle',
        'fill': theme.palette.text,
      });
    }
    if (legendW > 0) {
      final rowH = legendRowHeight(theme);
      final lx = width - legendW - 8;
      // As many entries as the height holds; past them, one "+N more" row
      // (every slice keeps its hint).
      final fit = math.max(1, (height - top - 8) ~/ rowH);
      final shown = legendTexts.length <= fit ? legendTexts.length : fit - 1;
      final rows = shown + (shown < legendTexts.length ? 1 : 0);
      var ly = math.max(top, cy - rows * rowH / 2);
      w.open('g', {'class': theme.cls('legend')});
      for (final (k, text) in legendTexts.take(shown).indexed) {
        w
          ..empty('rect', {
            'class': '${seriesClass(theme, k)} ${theme.cls('swatch')}',
            'x': lx,
            'y': ly + (rowH - 10) / 2,
            'width': 10,
            'height': 10,
            'rx': 2,
            'fill': theme.palette.seriesColor(k),
          })
          ..element('text', truncateText(text, legendW - 16, small), {
            'class': '${theme.cls('label')} ${theme.cls('small')}',
            'x': lx + 16,
            'y': ly + rowH / 2 + small * 0.35,
            'fill': theme.palette.textSecondary,
          });
        ly += rowH;
      }
      if (shown < legendTexts.length) {
        w.element('text', '+${legendTexts.length - shown} more', {
          'class': '${theme.cls('tick')} ${theme.cls('small')}',
          'x': lx + 16,
          'y': ly + rowH / 2 + small * 0.35,
          'fill': theme.palette.muted,
        });
      }
      w.close('g');
    }
    w.close('svg');
    return w.toString();
  }

  @override
  String toString() => render();
}

/// A slice of a disc (or ring, with [inner] > 0) centred at ([cx], [cy]),
/// from [start] through [sweep] radians, clockwise.
String _slicePath(
  double cx,
  double cy,
  double r,
  double inner,
  double start,
  double sweep,
) {
  String pt(double radius, double a) =>
      '${svgNum(cx + radius * math.cos(a))} ${svgNum(cy + radius * math.sin(a))}';
  // A whole circle can't be one arc (its ends coincide): two halves.
  if (sweep >= 2 * math.pi - 1e-9) {
    final outer =
        'M${pt(r, start)} A${svgNum(r)} ${svgNum(r)} 0 1 1 ${pt(r, start + math.pi)} '
        'A${svgNum(r)} ${svgNum(r)} 0 1 1 ${pt(r, start)}Z';
    if (inner <= 0) return outer;
    return '$outer M${pt(inner, start)} '
        'A${svgNum(inner)} ${svgNum(inner)} 0 1 0 ${pt(inner, start + math.pi)} '
        'A${svgNum(inner)} ${svgNum(inner)} 0 1 0 ${pt(inner, start)}Z';
  }
  final end = start + sweep;
  final large = sweep > math.pi ? 1 : 0;
  if (inner <= 0) {
    return 'M${svgNum(cx)} ${svgNum(cy)} L${pt(r, start)} '
        'A${svgNum(r)} ${svgNum(r)} 0 $large 1 ${pt(r, end)}Z';
  }
  return 'M${pt(r, start)} A${svgNum(r)} ${svgNum(r)} 0 $large 1 ${pt(r, end)} '
      'L${pt(inner, end)} '
      'A${svgNum(inner)} ${svgNum(inner)} 0 $large 0 ${pt(inner, start)}Z';
}
