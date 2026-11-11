/// One value against a range: linear meters and radial gauges.
library;

import 'dart:math' as math;

import '../chart.dart';
import '../format.dart';
import '../svg_writer.dart';
import '../theme.dart';

/// A meter: a rate (0–1) as a filled track, its text beside it.
///
/// The text is [text], by default the rate as [formatRate] writes it
/// (`<1%` for a small non-zero rate, never a misleading `0%`). The hint
/// gives the exact rate, then [title] (what it measures).
///
/// ```dart
/// final svg = Meter(0.42, title: 'Disk used').render();
/// ```
class Meter implements SvgChart {
  /// A meter of [rate], clamped to 0–1 when drawn.
  const Meter(
    this.rate, {
    this.width = 200,
    this.height = 16,
    this.title,
    this.text,
    this.theme = SvgChartTheme.auto,
    this.color = 0,
  });

  /// The rate, 0–1.
  final num rate;

  /// The width in px, text included.
  final double width;

  /// The height in px.
  final double height;

  /// What it measures: the hint and accessible name.
  final String? title;

  /// The text beside the track; by default the rate in %.
  final String? text;

  /// Colours.
  final SvgChartTheme theme;

  /// The series colour index of the fill.
  final int color;

  @override
  String render() {
    final r = rate.isFinite ? rate.clamp(0, 1).toDouble() : 0.0;
    final label = text ?? formatRate(rate);
    final small = theme.smallFontSize;
    final textW = estimateTextWidth(label, small) + 8;
    final trackW = math.max(8.0, width - textW);
    final exact = rate.isFinite
        ? '${(rate * 100).toStringAsFixed(rate * 100 < 10 ? 2 : 1)}%'
        : formatNumber(rate);
    final w = SvgWriter();
    openChart(
      w,
      theme,
      width: width,
      height: height,
      title: title ?? exact,
      kind: 'meter',
    );
    final barH = math.min(8.0, height);
    final y = (height - barH) / 2;
    openMark(w, theme, [exact, ?title]);
    w
      ..empty('rect', {
        'class': theme.cls('track'),
        'x': 0,
        'y': y,
        'width': trackW,
        'height': barH,
        'rx': barH / 2,
        'fill': theme.palette.grid,
      })
      ..empty('rect', {
        'class': '${theme.cls('bar')} ${seriesClass(theme, color)}',
        'x': 0,
        'y': y,
        // A non-zero rate shows at least a sliver.
        'width': r == 0 ? 0 : math.max(barH / 2, trackW * r),
        'height': barH,
        'rx': barH / 2,
        'fill': theme.palette.seriesColor(color),
      })
      ..element('text', label, {
        'class': '${theme.cls('text')} ${theme.cls('small')}',
        'x': trackW + 6,
        'y': height / 2 + small * 0.35,
        'fill': theme.palette.text,
      })
      ..close('g')
      ..close('svg');
    return w.toString();
  }

  @override
  String toString() => render();
}

/// A radial gauge: [value] on a half-circle arc from [min] to [max], the
/// value written in its middle and [label] under it.
///
/// ```dart
/// final svg = Gauge(72, max: 100, label: 'CPU %').render();
/// ```
class Gauge implements SvgChart {
  /// A gauge of [value] in [min]–[max].
  const Gauge(
    this.value, {
    this.min = 0,
    this.max = 100,
    this.width = 200,
    this.height = 120,
    this.label,
    this.title,
    this.theme = SvgChartTheme.auto,
    this.valueFormat = formatNumber,
    this.color = 0,
  });

  /// The value shown.
  final num value;

  /// The arc's start.
  final num min;

  /// The arc's end.
  final num max;

  /// The width in px.
  final double width;

  /// The height in px.
  final double height;

  /// What the value is, under it.
  final String? label;

  /// The accessible name; by default [label].
  final String? title;

  /// Colours and type.
  final SvgChartTheme theme;

  /// The value's text.
  final NumberFormatter valueFormat;

  /// The series colour index of the arc.
  final int color;

  @override
  String render() {
    final span = max - min;
    final rate = !value.isFinite || span <= 0
        ? 0.0
        : ((value - min) / span).clamp(0, 1).toDouble();
    final name = title ?? label;
    final w = SvgWriter();
    openChart(
      w,
      theme,
      width: width,
      height: height,
      title: name,
      kind: 'gauge',
    );
    final labelH = (label ?? '').isEmpty ? 0.0 : theme.smallFontSize + 6;
    final r = math.max(8.0, math.min(width / 2 - 8, height - labelH - 12));
    final thick = math.max(4.0, r * 0.18);
    final cx = width / 2, cy = 8 + r;
    String arc(double from, double to) {
      // Angles from π (left) to 2π (right), through the top.
      final a0 = math.pi + from * math.pi, a1 = math.pi + to * math.pi;
      final rr = r - thick / 2;
      return 'M${svgNum(cx + rr * math.cos(a0))} ${svgNum(cy + rr * math.sin(a0))} '
          'A${svgNum(rr)} ${svgNum(rr)} 0 0 1 '
          '${svgNum(cx + rr * math.cos(a1))} ${svgNum(cy + rr * math.sin(a1))}';
    }

    final text = valueFormat(value);
    openMark(w, theme, [
      name ?? text,
      '${name == null ? '' : '$text · '}${formatRate(rate)} of '
          '${valueFormat(min)}–${valueFormat(max)}',
    ]);
    w.empty('path', {
      'class': theme.cls('gauge-track'),
      'd': arc(0, 1),
      'fill': 'none',
      'stroke': theme.palette.grid,
      'stroke-width': thick,
      'stroke-linecap': 'round',
    });
    if (rate > 0) {
      w.empty('path', {
        'class': '${theme.cls('gauge-arc')} ${seriesClass(theme, color)}',
        'd': arc(0, math.max(rate, 0.005)),
        'fill': 'none',
        'stroke': theme.palette.seriesColor(color),
        'stroke-width': thick,
        'stroke-linecap': 'round',
        // The series rule paints fills; this arc is a stroke.
        'style':
            'fill:none;stroke:var(--${theme.prefix}-series-${color % theme.palette.series.length + 1},'
            '${theme.palette.seriesColor(color)})',
      });
    }
    w
      ..element('text', text, {
        'class': '${theme.cls('text')} ${theme.cls('strong')}',
        'x': cx,
        'y': cy - 2,
        'text-anchor': 'middle',
        'font-size': math.max(theme.fontSize, r / 2.6),
        'fill': theme.palette.text,
      })
      ..close('g');
    if (labelH > 0) {
      w.element('text', truncateText(label!, width - 16, theme.smallFontSize), {
        'class': '${theme.cls('label')} ${theme.cls('small')}',
        'x': cx,
        'y': cy + labelH + 2,
        'text-anchor': 'middle',
        'fill': theme.palette.textSecondary,
      });
    }
    w.close('svg');
    return w.toString();
  }

  @override
  String toString() => render();
}
