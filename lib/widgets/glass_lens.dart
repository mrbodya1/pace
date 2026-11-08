import 'package:flutter/material.dart';

const glassMotionCurve = Curves.ease;

Duration glassMotionDuration(BuildContext context) =>
    MediaQuery.disableAnimationsOf(context)
    ? Duration.zero
    : const Duration(milliseconds: 360);

BoxDecoration glassLensDecoration(BuildContext context, {double radius = 28}) {
  final highContrast = MediaQuery.highContrastOf(context);
  return BoxDecoration(
    gradient: highContrast
        ? null
        : const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xB3C1C8E0),
              Color(0x6659607E),
              Color(0x4D202539),
              Color(0x997980A0),
            ],
            stops: [0, 0.23, 0.65, 1],
          ),
    color: highContrast ? const Color(0xFF535A72) : const Color(0x558F98BC),
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(
      color: highContrast ? Colors.white : const Color(0xA6E2E7FA),
    ),
    boxShadow: highContrast
        ? const []
        : const [
            BoxShadow(color: Color(0x26E3E8FF), blurRadius: 8),
            BoxShadow(
              color: Color(0x4D000000),
              blurRadius: 10,
              offset: Offset(0, 3),
            ),
          ],
  );
}
