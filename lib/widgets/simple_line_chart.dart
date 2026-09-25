import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/chart_point.dart';

/// Graphique en ligne "fait maison" (deux séries : Ancien / Nouveau) avec
/// grille, survol/curseur et infobulles.
///
/// Extrait de `resultat_screen.dart` pour garder cet écran plus léger et
/// permettre de réutiliser ce widget ailleurs si besoin.
class SimpleLineChart extends StatefulWidget {
  final List<ChartPoint> ancien;
  final List<ChartPoint> nouveau;
  final List<ChartPoint>? economies;
  final Color colorAncien;
  final Color colorNouveau;
  final Color? colorEconomies;
  final double minX;
  final double maxX;
  final double minY;
  final double maxY;
  final int xTickCount;
  final int yTickCount;
  final bool isCurrency;
  final String unit;

  const SimpleLineChart({
    Key? key,
    required this.ancien,
    required this.nouveau,
    this.economies,
    required this.colorAncien,
    required this.colorNouveau,
    this.colorEconomies,
    required this.minX,
    required this.maxX,
    required this.minY,
    required this.maxY,
    required this.xTickCount,
    required this.yTickCount,
    required this.isCurrency,
    required this.unit,
  }) : super(key: key);

  @override
  State<SimpleLineChart> createState() => _SimpleLineChartState();
}

class _SimpleLineChartState extends State<SimpleLineChart> {
  double? _hoverFraction; // 0..1 over width

  void _updateHover(Offset localPosition, double width) {
    final frac = (localPosition.dx / width).clamp(0.0, 1.0);
    setState(() => _hoverFraction = frac);
  }

  void _clearHover() => setState(() => _hoverFraction = null);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final w = constraints.maxWidth <= 0 ? 1.0 : constraints.maxWidth;
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanDown: (e) => _updateHover(e.localPosition, w),
        onPanUpdate: (e) => _updateHover(e.localPosition, w),
        onPanEnd: (_) => _clearHover(),
        child: MouseRegion(
          onHover: (e) => _updateHover(e.localPosition, w),
          onExit: (_) => _clearHover(),
          child: CustomPaint(
            painter: _SimpleLinePainter(
              ancien: widget.ancien,
              nouveau: widget.nouveau,
              economies: widget.economies,
              colorAncien: widget.colorAncien,
              colorNouveau: widget.colorNouveau,
              colorEconomies: widget.colorEconomies,
              minX: widget.minX,
              maxX: widget.maxX,
              minY: widget.minY,
              maxY: widget.maxY,
              xTickCount: widget.xTickCount,
              yTickCount: widget.yTickCount,
              hoverFraction: _hoverFraction,
              isCurrency: widget.isCurrency,
              unit: widget.unit,
            ),
            size: Size(constraints.maxWidth, constraints.maxHeight),
          ),
        ),
      );
    });
  }
}

class _SimpleLinePainter extends CustomPainter {
  final List<ChartPoint> ancien;
  final List<ChartPoint> nouveau;
  final List<ChartPoint>? economies;
  final Color colorAncien;
  final Color colorNouveau;
  final Color? colorEconomies;
  final double minX;
  final double maxX;
  final double minY;
  final double maxY;
  final int xTickCount;
  final int yTickCount;
  final double? hoverFraction; // 0..1 or null
  final bool isCurrency;
  final String unit;

  _SimpleLinePainter({
    required this.ancien,
    required this.nouveau,
    this.economies,
    required this.colorAncien,
    required this.colorNouveau,
    this.colorEconomies,
    required this.minX,
    required this.maxX,
    required this.minY,
    required this.maxY,
    required this.xTickCount,
    required this.yTickCount,
    this.hoverFraction,
    required this.isCurrency,
    required this.unit,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paintAnc = Paint()..color = colorAncien..style = PaintingStyle.stroke..strokeWidth = 2.0..isAntiAlias = true;
    final paintNouv = Paint()..color = colorNouveau..style = PaintingStyle.stroke..strokeWidth = 2.0..isAntiAlias = true;
    final paintEcon = colorEconomies != null ? (Paint()..color = colorEconomies!..style = PaintingStyle.stroke..strokeWidth = 2.0..isAntiAlias = true) : null;
    final paintGrid = Paint()..color = Colors.grey.withValues(alpha: 0.25)..style = PaintingStyle.stroke..strokeWidth = 1.0;

    Offset toOffset(ChartPoint s) {
      final dx = (s.x - minX) / (maxX - minX) * size.width;
      final dy = size.height - (s.y - minY) / (maxY - minY) * size.height;
      return Offset(dx.clamp(0.0, size.width), dy.clamp(0.0, size.height));
    }

    // Draw hover cursor if available
    if (hoverFraction != null) {
      final hoverX = minX + (maxX - minX) * hoverFraction!;
      final dx = (hoverFraction! * size.width).clamp(0.0, size.width);
      final paintCursor = Paint()..color = Colors.black.withValues(alpha: 0.6)..strokeWidth = 1.0;
      canvas.drawLine(Offset(dx, 0), Offset(dx, size.height), paintCursor);

      // Draw markers at nearest points on each series
      ChartPoint? nearestAnc;
      ChartPoint? nearestNouv;
      ChartPoint? nearestEcon;
      double bestAnc = double.infinity;
      double bestNouv = double.infinity;
      double bestEcon = double.infinity;
      for (var s in ancien) {
        final d = (s.x - hoverX).abs();
        if (d < bestAnc) {
          bestAnc = d;
          nearestAnc = s;
        }
      }
      for (var s in nouveau) {
        final d = (s.x - hoverX).abs();
        if (d < bestNouv) {
          bestNouv = d;
          nearestNouv = s;
        }
      }
      if (economies != null) {
        for (var s in economies!) {
          final d = (s.x - hoverX).abs();
          if (d < bestEcon) {
            bestEcon = d;
            nearestEcon = s;
          }
        }
      }
      if (nearestAnc != null) {
        final o = toOffset(nearestAnc);
        final p = Paint()..color = colorAncien..style = PaintingStyle.fill;
        canvas.drawCircle(o, 4.0, p);
        // horizontal line
        final paintH = Paint()..color = colorAncien.withValues(alpha: 0.2)..strokeWidth = 1.0;
        canvas.drawLine(Offset(0, o.dy), Offset(size.width, o.dy), paintH);
        // tooltip
        final fmt = isCurrency ? NumberFormat.currency(symbol: '', decimalDigits: 2, locale: 'fr_FR') : NumberFormat('#,##0.00', 'fr_FR');
        final text = '${fmt.format(nearestAnc.y)} $unit';
        final tp = TextPainter(text: TextSpan(text: text, style: const TextStyle(color: Colors.white, fontSize: 11)), textDirection: ui.TextDirection.ltr);
        tp.layout();
        final rect = RRect.fromRectAndRadius(Rect.fromLTWH((o.dx + 6).clamp(0.0, size.width - tp.width - 8), (o.dy - tp.height - 8).clamp(0.0, size.height - tp.height), tp.width + 8, tp.height + 4), const Radius.circular(4));
        final back = Paint()..color = colorAncien.withValues(alpha: 0.9);
        canvas.drawRRect(rect, back);
        tp.paint(canvas, Offset(rect.left + 4, rect.top + 2));
      }
      if (nearestNouv != null) {
        final o = toOffset(nearestNouv);
        final p = Paint()..color = colorNouveau..style = PaintingStyle.fill;
        canvas.drawCircle(o, 4.0, p);
        final paintH = Paint()..color = colorNouveau.withValues(alpha: 0.2)..strokeWidth = 1.0;
        canvas.drawLine(Offset(0, o.dy), Offset(size.width, o.dy), paintH);
        final fmt = isCurrency ? NumberFormat.currency(symbol: '', decimalDigits: 2, locale: 'fr_FR') : NumberFormat('#,##0.00', 'fr_FR');
        final text = '${fmt.format(nearestNouv.y)} $unit';
        final tp = TextPainter(text: TextSpan(text: text, style: const TextStyle(color: Colors.white, fontSize: 11)), textDirection: ui.TextDirection.ltr);
        tp.layout();
        final rect = RRect.fromRectAndRadius(Rect.fromLTWH((o.dx + 6).clamp(0.0, size.width - tp.width - 8), (o.dy - tp.height - 8).clamp(0.0, size.height - tp.height), tp.width + 8, tp.height + 4), const Radius.circular(4));
        final back = Paint()..color = colorNouveau.withValues(alpha: 0.9);
        canvas.drawRRect(rect, back);
        tp.paint(canvas, Offset(rect.left + 4, rect.top + 2));
      }
      if (nearestEcon != null && colorEconomies != null) {
        final o = toOffset(nearestEcon);
        final p = Paint()..color = colorEconomies!..style = PaintingStyle.fill;
        canvas.drawCircle(o, 4.0, p);
        final paintH = Paint()..color = colorEconomies!.withValues(alpha: 0.2)..strokeWidth = 1.0;
        canvas.drawLine(Offset(0, o.dy), Offset(size.width, o.dy), paintH);
        final fmt = isCurrency ? NumberFormat.currency(symbol: '', decimalDigits: 2, locale: 'fr_FR') : NumberFormat('#,##0.00', 'fr_FR');
        final text = '${fmt.format(nearestEcon.y)} $unit';
        final tp = TextPainter(text: TextSpan(text: text, style: const TextStyle(color: Colors.white, fontSize: 11)), textDirection: ui.TextDirection.ltr);
        tp.layout();
        final rect = RRect.fromRectAndRadius(Rect.fromLTWH((o.dx + 6).clamp(0.0, size.width - tp.width - 8), (o.dy - tp.height - 8).clamp(0.0, size.height - tp.height), tp.width + 8, tp.height + 4), const Radius.circular(4));
        final back = Paint()..color = colorEconomies!.withValues(alpha: 0.9);
        canvas.drawRRect(rect, back);
        tp.paint(canvas, Offset(rect.left + 4, rect.top + 2));
      }
    }

    // Draw vertical grid lines, one per x tick.
    final int vCount = xTickCount > 1 ? xTickCount : 5;
    for (var i = 0; i < vCount; i++) {
      final dx = (i / (vCount - 1)) * size.width;
      canvas.drawLine(Offset(dx, 0), Offset(dx, size.height), paintGrid);
    }
    // Draw horizontal grid lines aligned with Y axis ticks
    // Calculate actual Y values for each tick to align grid lines with axis labels
    for (var i = 0; i <= yTickCount; i++) {
      // Calculate the value at this tick position (same formula as in _buildGraphiqueFromSpots)
      final v = minY + (maxY - minY) * ((yTickCount - i) / yTickCount);
      // Convert value to Y position (same formula as toOffset)
      final dy = size.height - ((v - minY) / (maxY - minY)) * size.height;
      canvas.drawLine(Offset(0, dy), Offset(size.width, dy), paintGrid);
    }

    // Draw horizontal line at Y=0 with dashed style
    if (minY <= 0 && maxY >= 0) {
      final dyZero = size.height - ((0 - minY) / (maxY - minY)) * size.height;
      final paintZero = Paint()
        ..color = Colors.grey.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..isAntiAlias = true;
      // Draw dashed line: alternate between drawing and skipping
      const dashWidth = 5.0;
      const dashSpace = 3.0;
      final totalWidth = size.width;
      for (var x = 0.0; x < totalWidth; x += dashWidth + dashSpace) {
        final endX = (x + dashWidth).clamp(0.0, totalWidth);
        canvas.drawLine(Offset(x, dyZero), Offset(endX, dyZero), paintZero);
      }
    }

    if (ancien.length >= 2) {
      final path = Path();
      for (var i = 0; i < ancien.length; i++) {
        final o = toOffset(ancien[i]);
        if (i == 0) {
          path.moveTo(o.dx, o.dy);
        } else {
          path.lineTo(o.dx, o.dy);
        }
      }
      canvas.drawPath(path, paintAnc);
    }

    if (nouveau.length >= 2) {
      final path2 = Path();
      for (var i = 0; i < nouveau.length; i++) {
        final o = toOffset(nouveau[i]);
        if (i == 0) {
          path2.moveTo(o.dx, o.dy);
        } else {
          path2.lineTo(o.dx, o.dy);
        }
      }
      canvas.drawPath(path2, paintNouv);
    }

    // Draw economies line
    if (economies != null && paintEcon != null && economies!.isNotEmpty) {
      final pathEcon = Path();
      for (var i = 0; i < economies!.length; i++) {
        final o = toOffset(economies![i]);
        if (i == 0) {
          pathEcon.moveTo(o.dx, o.dy);
        } else {
          pathEcon.lineTo(o.dx, o.dy);
        }
      }
      canvas.drawPath(pathEcon, paintEcon);
    }
  }

  @override
  bool shouldRepaint(covariant _SimpleLinePainter oldDelegate) {
    return oldDelegate.ancien != ancien ||
        oldDelegate.nouveau != nouveau ||
        oldDelegate.economies != economies ||
        oldDelegate.hoverFraction != hoverFraction ||
        oldDelegate.minX != minX ||
        oldDelegate.maxX != maxX ||
        oldDelegate.minY != minY ||
        oldDelegate.maxY != maxY ||
        oldDelegate.colorAncien != colorAncien ||
        oldDelegate.colorNouveau != colorNouveau ||
        oldDelegate.colorEconomies != colorEconomies;
  }
}
