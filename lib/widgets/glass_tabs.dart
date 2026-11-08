import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/theme/pace_theme.dart';
import 'glass_widgets.dart';

/// A single moving lens driven by the same controller as the page swipe.
class GlassTabs extends StatelessWidget {
  const GlassTabs({super.key, required this.labels});
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    final controller = DefaultTabController.of(context);
    assert(controller.length == labels.length);
    final highContrast = MediaQuery.highContrastOf(context);
    final style = Theme.of(context).textTheme.labelLarge!
        .copyWith(fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0);

    return LayoutBuilder(
      builder: (context, constraints) {
        // Reserve enough room for the longest Russian labels and larger type.
        // If all labels no longer fit, the native tab strip scrolls instead
        // of shrinking or truncating accessibility text.
        final widths = labels.map((label) {
          final painter = TextPainter(
            text: TextSpan(text: label, style: style),
            textDirection: Directionality.of(context),
            textScaler: MediaQuery.textScalerOf(context),
            maxLines: 1,
          )..layout();
          final width = math.max(68.0, painter.width + 24);
          painter.dispose();
          return width;
        }).toList();
        final available = math.max(0.0, constraints.maxWidth - 8);
        final occupied = widths.fold<double>(0, (sum, width) => sum + width);
        final extra = math.max(0.0, available - occupied) / widths.length;
        final labelHeight = MediaQuery.textScalerOf(context).scale(14) * 1.5;
        final height = math.max(48.0, labelHeight + 20);

        return GlassPanel(
          radius: (height + 8) / 2,
          padding: const EdgeInsets.all(4),
          child: TabBar(
            controller: controller,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            padding: EdgeInsets.zero,
            labelPadding: EdgeInsets.zero,
            labelStyle: style,
            unselectedLabelStyle: style.copyWith(fontWeight: FontWeight.w400),
            labelColor: lime,
            unselectedLabelColor: muted,
            dividerHeight: 0,
            indicatorSize: TabBarIndicatorSize.tab,
            indicatorAnimation: TabIndicatorAnimation.linear,
            indicatorPadding: const EdgeInsets.all(1),
            indicator: BoxDecoration(
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
              color: highContrast
                  ? const Color(0xFF535A72)
                  : const Color(0x558F98BC),
              borderRadius: BorderRadius.circular(height / 2),
              border: Border.all(
                color: highContrast ? Colors.white : const Color(0xA6E2E7FA),
                width: 1,
              ),
              boxShadow: highContrast
                  ? const []
                  : const [
                      BoxShadow(
                        color: Color(0x26E3E8FF),
                        blurRadius: 8,
                        spreadRadius: 0,
                      ),
                      BoxShadow(
                        color: Color(0x4D000000),
                        blurRadius: 10,
                        offset: Offset(0, 3),
                      ),
                    ],
            ),
            splashBorderRadius: BorderRadius.circular(height / 2),
            tabs: [
              for (var i = 0; i < labels.length; i++)
                Tab(
                  height: height,
                  child: SizedBox(
                    width: widths[i] + extra,
                    child: Center(
                      child: Text(labels[i], maxLines: 1, softWrap: false),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
