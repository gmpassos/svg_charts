// Renders a few charts and prints their SVG markup. Run it:
//
//   dart run example/svg_charts_example.dart > chart.svg
//
// Nothing here imports dart:io (`print` is in dart:core), so the same file
// runs compiled to JavaScript too. example/gallery.dart writes one file per
// chart; example/web/ shows the hint tooltip in a page.
import 'package:svg_charts/svg_charts.dart';

void main() {
  // A column per month, with shares in the hints.
  final columns = ColumnChart.of(
    [42, 51, 38, 64, 72, 69],
    name: 'orders',
    labels: ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun'],
    title: 'Orders per month',
    shares: true,
  );
  print(columns.render());

  // Two series as lines; the gap stays a gap.
  final lines = LineChart(
    const [
      Series([3, 5, 4, null, 8, 9], name: 'paid'),
      Series([1, 2, 2, 3, 3, 4], name: 'open'),
    ],
    labels: const ['W1', 'W2', 'W3', 'W4', 'W5', 'W6'],
    title: 'Invoices',
  );
  print(lines.render());

  // Parts of a whole.
  print(PieChart.of([62, 25, 13], labels: ['web', 'app', 'api'], donut: true));
}
