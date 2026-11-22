## 0.2.0

**Where a value axis starts.** A new `ScaleBaseline` enum chooses whether a
value axis includes zero (`ScaleBaseline.zero`) or fits the data, starting at
its lowest value rounded down to a tick (`ScaleBaseline.min`). An explicit
`yMin` / `yMax` still wins. The defaults are unchanged.

- `ColumnChart` (and `ColumnChart.of`): `baseline:`, default `zero`. With
  `min`, columns start at the fitted axis' end nearest zero (the top when every
  value is negative), and that end is pulled a little past the data so the
  column nearest zero keeps a height. Stacked columns fit their stacks' ends.
- `LineChart` / `AreaChart` (and `.of`): `baseline:`, default `min` for a line
  and `zero` for an area. A fitted area fills down to the axis' end nearest
  zero.
- `ScatterChart`: `xBaseline:` and `yBaseline:`, both default `min`.
- When zero isn't a tick, the axis line of columns and areas is drawn where
  they start: at the top for a domain wholly below zero (before, it was always
  at the bottom, away from columns hanging from an explicit negative `yMax`).

## 0.1.0

The first release: charts rendered as SVG markup, grown from the charts of
OmnyRepo Explorer's statistics and reports.

**Charts.** Every chart is an immutable value whose `render()` returns one
`<svg>` string, with no DOM and no `dart:io`, so it renders in a browser, on a
server or in an isolate. The output is byte-identical on the VM and on the web
(checked in Chrome).

- `ColumnChart`: single, grouped or stacked, with negatives below the
  baseline. `Histogram` builds on it.
- `BarChart`: horizontal and labelled directly; ranked (`sorted`), grouped or
  stacked; `mutedLabels` dims a row.
- `LineChart` and `AreaChart`: multi-series; gaps break the line; `smooth:`
  draws a monotone curve; a hover band per x.
- `Sparkline` and `StatTile` (a value, its ▲/▼ change and a trend).
- `ScatterChart`; `PieChart` and `donut:`, with an "Other" slice past
  `maxSlices`.
- `Meter`, `Gauge`, and `Heatmap` (a stepped sequential ramp, with empty cells
  for missing values).

**Hints.** Every mark carries its hint as a native `<title>`, a `data-hint` and
an accessible name: what it is, its series and value, and with `shares:` its
share of the whole. Shares are never shown where a negative value makes the
whole meaningless. A `hint:` callback writes your own. A line chart's band
hint lists every series at that x.

**Themes.** `SvgChartTheme` (`auto`, `light`, `dark`) uses a validated
palette: eight categorical hues stepped for each surface, a sequential ramp and
recessive chrome. An embedded style sheet reads CSS custom properties
(`--svgc-series-1`, `--svgc-text`, …), with the theme's colours as fallbacks.
Dark mode follows `prefers-color-scheme` or `data-theme`. With
`embedStyle: false` only classes are written, styled by `svgChartsCss`.

**Browser** (`package:svg_charts/svg_charts_web.dart`):

- `installSVGChartHints`: one styled tooltip that follows the mouse, shows on a
  tap, hides on scroll, and replaces the native one;
- `insertSVGChart`: puts a chart in an element, with `onMark` for clicks.

**Building blocks:** `niceTicks`, `LinearScale`, `markHint`, `pointHint`,
`shareOf`, `totalOf`, `formatNumber`, `formatCompact`, `formatRate`,
`histogramBins`, `SvgWriter`, `escapeXml`, `svgNum`.
