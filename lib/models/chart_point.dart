/// Un point (x, y) pour les graphiques "Coût" et "Consommation" de l'écran
/// Résultat.
///
/// Remplace `FlSpot` (package fl_chart) : les graphiques de cet écran sont
/// dessinés à la main avec un `CustomPainter` (voir `SimpleLineChart`), donc
/// une dépendance à tout le package fl_chart n'était nécessaire que pour
/// cette petite classe de données.
class ChartPoint {
  final double x;
  final double y;

  const ChartPoint(this.x, this.y);

  @override
  String toString() => 'ChartPoint($x, $y)';
}
