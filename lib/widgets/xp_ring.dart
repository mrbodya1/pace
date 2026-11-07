import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/theme/pace_theme.dart';

class XpRing extends StatelessWidget {
  const XpRing({
    super.key,
    required this.xp,
    required this.level,
    required this.levelStart,
    required this.levelEnd,
  });
  final int xp, level, levelStart, levelEnd;

  String _number(int value) => value.toString().replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
    (m) => '${m[1]} ',
  );

  @override
  Widget build(BuildContext context) {
    final progress = ((xp - levelStart) / (levelEnd - levelStart)).clamp(
      0.0,
      1.0,
    );
    final remaining = math.max(0, levelEnd - xp);
    if (MediaQuery.textScalerOf(context).scale(16) > 21) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Уровень $level', style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 8),
            Text(
              '${_number(xp)} XP',
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 18),
            LinearProgressIndicator(
              value: progress,
              color: lime,
              minHeight: 10,
              borderRadius: BorderRadius.circular(8),
            ),
            const SizedBox(height: 12),
            Text(
              '${_number(remaining)} XP до уровня ${level + 1}',
              style: const TextStyle(color: muted, fontSize: 16),
            ),
          ],
        ),
      );
    }
    return Semantics(
      label: 'Уровень $level, $xp XP. $remaining XP до следующего уровня',
      child: ExcludeSemantics(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final diameter = math.min(constraints.maxWidth, 260.0);
            return Center(
              child: SizedBox(
                width: diameter,
                height: diameter * 0.93,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: CustomPaint(painter: _XpArcPainter(progress)),
                    ),
                    Positioned.fill(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(30, 40, 30, 30),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Уровень $level',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 12),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                '${_number(xp)} XP',
                                style: const TextStyle(
                                  fontSize: 40,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: -1.2,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              '${_number(remaining)} XP до уровня ${level + 1}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: muted,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      left: 30,
                      right: 30,
                      bottom: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text('${_number(levelStart)} XP',
                                style: const TextStyle(color: muted, fontSize: 12)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerRight,
                              child: Text('${_number(levelEnd)} XP',
                                style: const TextStyle(color: muted, fontSize: 12)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _XpArcPainter extends CustomPainter {
  const _XpArcPainter(this.progress);
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    const start = 3 * math.pi / 4;
    const sweep = 3 * math.pi / 2;
    final radius = math.min(size.width / 2 - 14, size.height / 2 - 10);
    final center = Offset(size.width / 2, radius + 12);
    final rect = Rect.fromCircle(center: center, radius: radius);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF292D40);
    canvas.drawArc(rect, start, sweep, false, paint);
    if (progress > 0) {
      paint
        ..color = lime.withValues(alpha: 0.2)
        ..strokeWidth = 21
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawArc(rect, start, sweep * progress, false, paint);
      paint
        ..color = lime
        ..strokeWidth = 14
        ..maskFilter = null;
      canvas.drawArc(rect, start, sweep * progress, false, paint);
    }
  }

  @override
  bool shouldRepaint(_XpArcPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
