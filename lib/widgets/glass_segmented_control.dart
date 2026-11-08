import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/theme/pace_theme.dart';
import 'glass_lens.dart';
import 'glass_widgets.dart';

class GlassSegmentedControl extends StatefulWidget {
  const GlassSegmentedControl({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onChanged,
  }) : assert(labels.length > 0),
       assert(
         selectedIndex == null ||
             (selectedIndex >= 0 && selectedIndex < labels.length),
       );

  final List<String> labels;
  final int? selectedIndex;
  final ValueChanged<int>? onChanged;

  @override
  State<GlassSegmentedControl> createState() => _GlassSegmentedControlState();
}

class _GlassSegmentedControlState extends State<GlassSegmentedControl> {
  final scroll = ScrollController();
  int lastSelected = 0;
  List<double> widths = [];
  double viewportWidth = 0;

  @override
  void initState() {
    super.initState();
    lastSelected = widget.selectedIndex ?? 0;
  }

  @override
  void didUpdateWidget(GlassSegmentedControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedIndex != null) lastSelected = widget.selectedIndex!;
    if (oldWidget.selectedIndex != widget.selectedIndex &&
        widget.selectedIndex != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !scroll.hasClients || widths.isEmpty) return;
        final index = widget.selectedIndex;
        if (index == null || index >= widths.length) return;
        final start = widths
            .take(index)
            .fold<double>(0, (sum, width) => sum + width);
        final target = (start + widths[index] / 2 - viewportWidth / 2).clamp(
          0.0,
          scroll.position.maxScrollExtent,
        );
        if (glassMotionDuration(context) == Duration.zero) {
          scroll.jumpTo(target);
        } else {
          scroll.animateTo(
            target,
            duration: glassMotionDuration(context),
            curve: glassMotionCurve,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelLarge!
        .copyWith(fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0);
    final height = math.max(
      48.0,
      MediaQuery.textScalerOf(context).scale(14) * 1.5 + 20,
    );
    final duration = glassMotionDuration(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        viewportWidth = math.max(0.0, constraints.maxWidth - 8);
        final naturalWidths = widget.labels.map((label) {
          final text = TextPainter(
            text: TextSpan(text: label, style: style),
            textScaler: MediaQuery.textScalerOf(context),
            textDirection: Directionality.of(context),
            maxLines: 1,
          )..layout();
          final width = math.max(68.0, text.width + 24);
          text.dispose();
          return width;
        }).toList();
        final natural = naturalWidths.fold<double>(
          0,
          (sum, width) => sum + width,
        );
        final extra =
            math.max(0.0, viewportWidth - natural) / naturalWidths.length;
        widths = naturalWidths.map((width) => width + extra).toList();
        final contentWidth = widths.fold<double>(
          0,
          (sum, width) => sum + width,
        );
        final index = (widget.selectedIndex ?? lastSelected).clamp(
          0,
          widths.length - 1,
        );
        final start = widths
            .take(index)
            .fold<double>(0, (sum, width) => sum + width);
        return GlassPanel(
          radius: (height + 8) / 2,
          padding: const EdgeInsets.all(4),
          child: SingleChildScrollView(
            controller: scroll,
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: contentWidth,
              height: height,
              child: Stack(
                children: [
                  AnimatedPositionedDirectional(
                    key: const ValueKey('sport-lens-position'),
                    duration: duration,
                    curve: glassMotionCurve,
                    start: start + 1,
                    width: widths[index] - 2,
                    top: 1,
                    bottom: 1,
                    child: IgnorePointer(
                      child: AnimatedOpacity(
                        opacity: widget.selectedIndex == null ? 0 : 1,
                        duration: duration,
                        child: DecoratedBox(
                          key: const ValueKey('sport-lens'),
                          decoration: glassLensDecoration(
                            context,
                            radius: height / 2,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      for (var i = 0; i < widget.labels.length; i++)
                        SizedBox(
                          width: widths[i],
                          height: height,
                          child: Semantics(
                            button: true,
                            selected: widget.selectedIndex == i,
                            enabled: widget.onChanged != null,
                            label: widget.labels[i],
                            child: ExcludeSemantics(
                              child: InkWell(
                                onTap: widget.onChanged == null
                                    ? null
                                    : () => widget.onChanged!(i),
                                borderRadius: BorderRadius.circular(height / 2),
                                child: Center(
                                  child: AnimatedDefaultTextStyle(
                                    duration: duration,
                                    style: style.copyWith(
                                      color: widget.selectedIndex == i
                                          ? lime
                                          : muted,
                                      fontWeight: widget.selectedIndex == i
                                          ? FontWeight.w600
                                          : FontWeight.w400,
                                    ),
                                    child: Text(
                                      widget.labels[i],
                                      maxLines: 1,
                                      softWrap: false,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
