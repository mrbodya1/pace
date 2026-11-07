import 'package:flutter/material.dart';

import '../../app/theme/pace_theme.dart';
import '../../models/workout.dart';

class RoutePainter extends CustomPainter {
  final List<RoutePoint> points;

  RoutePainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2 || size.isEmpty) return;

    final minLat = points.map((p) => p.latitude).reduce((a, b) => a < b ? a : b);
    final maxLat = points.map((p) => p.latitude).reduce((a, b) => a > b ? a : b);
    final minLon = points.map((p) => p.longitude).reduce((a, b) => a < b ? a : b);
    final maxLon = points.map((p) => p.longitude).reduce((a, b) => a > b ? a : b);

    final latRange = (maxLat - minLat).abs();
    final lonRange = (maxLon - minLon).abs();
    final safeLat = latRange < 0.000001 ? 0.000001 : latRange;
    final safeLon = lonRange < 0.000001 ? 0.000001 : lonRange;
    final scale = (size.width - 24) / safeLon < (size.height - 20) / safeLat
        ? (size.width - 24) / safeLon
        : (size.height - 20) / safeLat;
    final drawWidth = safeLon * scale;
    final drawHeight = safeLat * scale;
    final offsetX = (size.width - drawWidth) / 2;
    final offsetY = (size.height - drawHeight) / 2;

    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final point = points[i];
      final x = offsetX + (point.longitude - minLon) * scale;
      final y = size.height - offsetY - (point.latitude - minLat) * scale;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final paint = Paint()
      ..color = lime
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, paint);

    final start = points.first;
    final end = points.last;
    final startOffset = Offset(
      offsetX + (start.longitude - minLon) * scale,
      size.height - offsetY - (start.latitude - minLat) * scale,
    );
    final endOffset = Offset(
      offsetX + (end.longitude - minLon) * scale,
      size.height - offsetY - (end.latitude - minLat) * scale,
    );
    canvas.drawCircle(startOffset, 4, Paint()..color = Colors.white);
    canvas.drawCircle(endOffset, 4, Paint()..color = lime);
  }

  @override
  bool shouldRepaint(covariant RoutePainter oldDelegate) =>
      oldDelegate.points != points;
}
