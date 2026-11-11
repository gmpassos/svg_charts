/// A grid of values coloured by magnitude.
library;

import 'dart:math' as math;

import '../chart.dart';
import '../format.dart';
import '../scale.dart';
import '../svg_writer.dart';
import '../theme.dart';

/// A heatmap: [values] (rows × columns) as cells coloured on the palette's
/// sequential ramp, from the lowest value (lightest on a light surface) to
/// the highest.
///
/// The ramp is in steps (the palette's [SvgPalette.sequential], seven by
/// default), so each colour is a range one can read off the [legend].
/// `null` cells are drawn empty, never as the lowest step: "no data" is not
/// "least". Each cell's hint gives its row, column and value.
///
/// ```dart
/// final svg = Heatmap(
///   [[1, 4, 2], [3, null, 8]],
///   rowLabels: ['Mon', 'Tue'],
///   columnLabels: ['9h', '12h', '18h'],
/// ).render();
/// ```
class Heatmap implements SvgChart {
  /// A heatmap of [values]; rows may differ in length.
  const Heatmap(
    this.values, {
    this.rowLabels = const [],
    this.columnLabels = const [],
    this.width = 480,
    this.height,
    this.title,
    this.description,
    this.theme = SvgChartTheme.auto,
    this.responsive = false,
    this.valueFormat = formatNumber,
    this.legend = true,
    this.cellHeight = 24,
  });

  /// The values, by row then column.
  final List<List<num?>> values;

  /// The rows' names, left of them.
  final List<String> rowLabels;

  /// The columns' names, above them.
  final List<String> columnLabels;

  /// The chart's width in px.
  final double width;

  /// The chart's height in px; by default as tall as its rows need.
  final double? height;

  /// Drawn above the chart, and its accessible name.
  final String? title;

  /// The chart's accessible description.
  final String? description;

  /// Colours and type.
  final SvgChartTheme theme;

  /// Whether the SVG takes its container's width.
  final bool responsive;

  /// Values in hints and the legend.
  final NumberFormatter valueFormat;

  /// Whether to draw the ramp's legend (low to high) under the grid.
  final bool legend;

  /// A row's height when [height] isn't given.
  final double cellHeight;

  /// The ramp step (0-based) of [v] in [lo]–[hi], over [steps] steps.
  static int stepOf(num v, num lo, num hi, int steps) {
    if (hi == lo) return steps - 1;
    return math.min(steps - 1, ((v - lo) / (hi - lo) * steps).floor());
  }

  @override
  String render() {
    final rows = values.length;
    final cols = [
      columnLabels.length,
      for (final r in values) r.length,
    ].fold(0, math.max);
    final extent = dataExtent([for (final r in values) ...r]);
    final steps = theme.palette.sequential.length;
    final small = theme.smallFontSize;
    var top = 8.0;
    final titleH = (title ?? '').isEmpty ? 0.0 : theme.fontSize + 10;
    final headerH = columnLabels.isEmpty ? 0.0 : small + 8;
    final legendH = legend && extent != null ? small + 22 : 0.0;
    final total =
        height ?? top + titleH + headerH + rows * cellHeight + legendH + 8;
    final w = SvgWriter();
    openChart(
      w,
      theme,
      width: width,
      height: total,
      title: title,
      description: description,
      responsive: responsive,
      kind: 'heatmap',
    );
    if (titleH > 0) {
      w.element('text', truncateText(title!, width - 16, theme.fontSize + 1), {
        'class': '${theme.cls('text')} ${theme.cls('strong')}',
        'x': 8,
        'y': top + theme.fontSize,
        'fill': theme.palette.text,
      });
      top += titleH;
    }
    String rowLabel(int r) => r < rowLabels.length ? rowLabels[r] : '${r + 1}';
    String colLabel(int c) =>
        c < columnLabels.length ? columnLabels[c] : '${c + 1}';
    final labelW = rowLabels.isEmpty
        ? 0.0
        : math.min(
            width / 3,
            rowLabels.fold<double>(
              0,
              (m, l) => math.max(m, estimateTextWidth(l, small)),
            ),
          );
    final left = 8 + (labelW > 0 ? labelW + 8 : 0);
    final gridW = math.max(0.0, width - left - 8);
    final cellW = cols == 0 ? 0.0 : gridW / cols;
    final gridTop = top + headerH;
    final cellH = height == null
        ? cellHeight
        : (rows == 0
              ? 0.0
              : math.max(0.0, (total - gridTop - legendH - 8) / rows));
    if (headerH > 0) {
      final shown = visibleLabels(
        [for (var c = 0; c < cols; c++) colLabel(c)],
        gridW,
        small,
        XLabels.auto,
      );
      for (final c in shown) {
        w.element('text', truncateText(colLabel(c), cellW * 3, small), {
          'class': '${theme.cls('tick')} ${theme.cls('small')}',
          'x': left + (c + 0.5) * cellW,
          'y': top + small,
          'text-anchor': 'middle',
          'fill': theme.palette.muted,
        });
      }
    }
    w.open('g', {'class': theme.cls('marks')});
    for (var r = 0; r < rows; r++) {
      final y = gridTop + r * cellH;
      if (labelW > 0) {
        w.element('text', truncateText(rowLabel(r), labelW, small), {
          'class': '${theme.cls('label')} ${theme.cls('small')}',
          'x': 8,
          'y': y + cellH / 2 + small * 0.35,
          'fill': theme.palette.textSecondary,
        });
      }
      for (var c = 0; c < cols; c++) {
        final v = c < values[r].length ? values[r][c] : null;
        final drawable = isDrawable(v);
        final step = drawable && extent != null
            ? stepOf(v!, extent.min, extent.max, steps)
            : -1;
        openMark(
          w,
          theme,
          [
            '${rowLabel(r)} · ${colLabel(c)}',
            drawable ? valueFormat(v!) : 'no value',
          ],
          cls: 'cell',
          index: c,
          series: r,
        );
        // A 2 px surface gap between cells.
        w
          ..empty('rect', {
            'class': theme.cls(step < 0 ? 'empty' : 'q${step + 1}'),
            'x': left + c * cellW + 1,
            'y': y + 1,
            'width': math.max(0, cellW - 2),
            'height': math.max(0, cellH - 2),
            'rx': 2,
            'fill': step < 0
                ? theme.palette.grid
                : theme.palette.sequential[step],
            'fill-opacity': step < 0 ? 0.4 : null,
          })
          ..close('g');
      }
    }
    w.close('g');
    if (legendH > 0) {
      final ly = gridTop + rows * cellH + 8;
      final stepW = math.min(28.0, gridW / steps);
      w.open('g', {'class': theme.cls('legend')});
      for (var s = 0; s < steps; s++) {
        w.empty('rect', {
          'class': theme.cls('q${s + 1}'),
          'x': left + s * stepW,
          'y': ly,
          'width': stepW - 1,
          'height': 8,
          'fill': theme.palette.sequential[s],
        });
      }
      w
        ..element('text', valueFormat(extent!.min), {
          'class': '${theme.cls('tick')} ${theme.cls('small')}',
          'x': left,
          'y': ly + 10 + small,
          'fill': theme.palette.muted,
        })
        ..element('text', valueFormat(extent.max), {
          'class': '${theme.cls('tick')} ${theme.cls('small')}',
          'x': left + steps * stepW - 1,
          'y': ly + 10 + small,
          'text-anchor': 'end',
          'fill': theme.palette.muted,
        })
        ..close('g');
    }
    w.close('svg');
    return w.toString();
  }

  @override
  String toString() => render();
}
